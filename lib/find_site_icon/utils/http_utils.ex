defmodule FindSiteIcon.Util.HTTPUtils do
  @moduledoc """
  Small wrapper around Req with project defaults.

  Accepts the same options as `Req.new/1`, plus the following defaults that
  callers may override by passing the key explicitly:

  * `:timeout` -> applied to both connect and receive timeouts. Defaults to 30s.
  * `:compressed` -> decompresses encoded response bodies. Defaults to `true`.
  * `:pool_max_idle_time` -> milliseconds before idle Finch socket pools are
    terminated. Defaults to 30s so file descriptors are reclaimed when probing
    many distinct hosts. Pass `:infinity` to keep pools alive forever, which
    was Req's behaviour prior to find_site_icon 1.0.2. See issue #15.

  `:connect_options`, `:inet6` and `:pool_max_idle_time` are folded into a
  single `:finch` keyword list before the options reach Req. Req 0.7 deprecated
  top-level `:pool_max_idle_time` in favour of `finch: [pool_max_idle_time:
  ...]`, and it raises when `:finch` and `:connect_options` are set on the same
  request, so the two have to travel together. `Req.Finch.pool_options/1` does
  the translation, which keeps the full `:connect_options` surface working
  without restating Req's mapping here.

  The defaults above are applied by `new/1` only. `do_get/3` and `do_head/3`
  merge the options they are handed into the ones the request already
  carries, so a prebuilt `t:Req.Request.t/0` keeps its pool settings and a
  per-call `:timeout` changes only the timeouts. Nested `:connect_options`
  (such as `:transport_opts`) are merged key by key.

  Callers may also pass `:finch` options directly, which are merged over the
  computed pool options. With `finch: [name: MyFinch]` the named pool owns its
  configuration, so no pool options are added, on `new/1` or on later calls;
  Req rejects pool options next to a pool name.
  """

  @timeout 30_000
  @user_agent "find_site_icon (+https://github.com/XukuLLC/find_site_icon)"
  @pool_max_idle_time 30_000
  @pool_inputs :find_site_icon_pool_inputs

  @spec new(keyword) :: Req.Request.t()
  def new(opts \\ []) when is_list(opts) do
    defaults = [timeout: @timeout, pool_max_idle_time: @pool_max_idle_time]

    Req.new(
      compressed: true,
      headers: [{"user-agent", @user_agent}],
      redirect: true,
      retry: false
    )
    |> merge_options(Keyword.merge(defaults, opts))
  end

  @spec do_get(binary | Req.Request.t(), keyword, keyword) ::
          {:error, Exception.t()} | {:ok, Req.Response.t()}
  def do_get(url, headers \\ [], opts \\ []) do
    url
    |> request(headers, opts)
    |> Req.get()
  end

  @spec do_head(binary | Req.Request.t(), keyword, keyword) ::
          {:error, Exception.t()} | {:ok, Req.Response.t()}
  def do_head(url, headers \\ [], opts \\ []) do
    url
    |> request(headers, opts)
    |> Req.head()
  end

  defp request(%Req.Request{} = request, headers, opts) do
    request
    |> merge_options(opts)
    |> Req.merge(headers: headers)
  end

  defp request(url, headers, opts) when is_binary(url) do
    new(Keyword.merge(opts, url: url, headers: headers))
  end

  # Req builds Finch pool options from :connect_options, :inet6 and
  # :pool_max_idle_time, but it raises when :connect_options sits next to
  # :finch, and its translation fills in defaults (:protocols, :conn_opts)
  # every time. Merging translated Finch options would therefore let a
  # per-call timeout replace the request's conn_opts and protocols. Instead
  # the Req-level inputs are kept on the request, each call's options are
  # merged into them, and the full pool options are rebuilt from the result.
  defp merge_options(%Req.Request{} = request, opts) do
    {timeout, opts} = Keyword.pop(opts, :timeout)
    {connect_timeout, opts} = Keyword.pop(opts, :connect_timeout, timeout)
    {connect_options, opts} = Keyword.pop(opts, :connect_options)
    {pool_max_idle_time, opts} = Keyword.pop(opts, :pool_max_idle_time)
    {finch_options, opts} = Keyword.pop(opts, :finch)

    opts =
      if timeout do
        Keyword.put_new(opts, :receive_timeout, timeout)
      else
        opts
      end

    {request, inputs} = pool_inputs(request)

    inputs =
      inputs
      |> merge_input(:connect_options, connect_options(connect_options, connect_timeout), &deep_merge/2)
      |> merge_input(:pool_max_idle_time, pool_max_idle_time, &replace/2)
      |> merge_input(:inet6, Keyword.get(opts, :inet6), &replace/2)
      |> merge_input(:finch, finch_list(finch_options), &deep_merge/2)

    request
    |> Req.Request.put_private(@pool_inputs, inputs)
    |> Req.merge(maybe_put_finch(opts, finch(inputs)))
  end

  # A request built by new/1 carries its inputs. Any other request is adopted:
  # its pool-related options become the inputs, and :connect_options and
  # :pool_max_idle_time leave the top level, where Req would raise or warn.
  defp pool_inputs(request) do
    case Req.Request.get_private(request, @pool_inputs) do
      nil ->
        inputs =
          %{
            connect_options: request.options[:connect_options],
            finch: finch_list(request.options[:finch]),
            inet6: request.options[:inet6],
            pool_max_idle_time: request.options[:pool_max_idle_time]
          }
          |> Map.reject(fn {_key, value} -> is_nil(value) end)

        options = Map.drop(request.options, [:connect_options, :pool_max_idle_time])
        {%{request | options: options}, inputs}

      inputs ->
        {request, inputs}
    end
  end

  defp merge_input(inputs, _key, nil, _merge), do: inputs
  defp merge_input(inputs, key, value, merge), do: Map.update(inputs, key, value, &merge.(&1, value))

  defp replace(_old, new), do: new

  defp connect_options(nil, nil), do: nil
  defp connect_options(nil, connect_timeout), do: [timeout: connect_timeout]
  defp connect_options(connect_options, nil), do: connect_options

  defp connect_options(connect_options, connect_timeout),
    do: Keyword.put_new(connect_options, :timeout, connect_timeout)

  # Req still accepts the deprecated `finch: MyFinch` form.
  defp finch_list(nil), do: nil
  defp finch_list(name) when is_atom(name), do: [name: name]
  defp finch_list(options) when is_list(options), do: options

  # A pool name owns its pool configuration: Req raises when pool options sit
  # next to :name, so only the caller's own :finch options are passed on.
  defp finch(inputs) do
    finch_options = Map.get(inputs, :finch, [])
    pool_inputs = Map.take(inputs, [:connect_options, :inet6, :pool_max_idle_time])

    cond do
      Keyword.has_key?(finch_options, :name) -> finch_options
      pool_inputs == %{} -> finch_options
      true -> pool_inputs |> Req.Finch.pool_options() |> deep_merge(finch_options)
    end
  end

  defp maybe_put_finch(opts, []), do: opts
  defp maybe_put_finch(opts, finch), do: Keyword.put(opts, :finch, finch)

  # Merges keyword lists recursively, so a nested list such as
  # :transport_opts is merged key by key. Other values (including plain lists
  # such as :protocols) are replaced.
  defp deep_merge(left, right) do
    Keyword.merge(left, right, fn _key, left_value, right_value ->
      if keyword_list?(left_value) and keyword_list?(right_value) do
        deep_merge(left_value, right_value)
      else
        right_value
      end
    end)
  end

  defp keyword_list?([]), do: false
  defp keyword_list?(value), do: Keyword.keyword?(value)
end
