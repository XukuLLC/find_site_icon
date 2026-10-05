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
  translate just the options they are handed, layering them over whatever the
  request already carries, so passing a prebuilt `t:Req.Request.t/0` keeps its
  pool settings.

  Callers may also pass `:finch` options directly, which are merged over the
  computed pool options. `finch: [name: MyFinch]` is taken verbatim and the
  pool defaults above are not applied, since Req rejects pool options next to
  a pool name.
  """

  @timeout 30_000
  @user_agent "find_site_icon (+https://github.com/XukuLLC/find_site_icon)"
  @pool_max_idle_time 30_000

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

  # Translates only the options actually present, so merging onto an existing
  # request never resets a setting the caller did not pass this time.
  defp merge_options(%Req.Request{} = request, opts) do
    {timeout, opts} = Keyword.pop(opts, :timeout)
    {connect_timeout, opts} = Keyword.pop(opts, :connect_timeout, timeout)
    {connect_options, opts} = Keyword.pop(opts, :connect_options)
    {pool_max_idle_time, opts} = Keyword.pop(opts, :pool_max_idle_time)
    {finch_options, opts} = Keyword.pop(opts, :finch, [])

    opts =
      if timeout do
        Keyword.put_new(opts, :receive_timeout, timeout)
      else
        opts
      end

    finch =
      finch(
        request.options[:finch] || [],
        pool_options(opts, connect_options, connect_timeout, pool_max_idle_time),
        finch_options
      )

    Req.merge(request, maybe_put_finch(opts, finch))
  end

  # A caller-supplied pool name owns its pool configuration: Req raises when
  # pool options sit next to `:name`, so the defaults are not applied.
  defp finch(current, pool_options, finch_options) do
    if Keyword.has_key?(finch_options, :name) do
      finch_options
    else
      current |> Keyword.merge(pool_options) |> Keyword.merge(finch_options)
    end
  end

  defp maybe_put_finch(opts, []), do: opts
  defp maybe_put_finch(opts, finch), do: Keyword.put(opts, :finch, finch)

  # `:inet6` is read, not popped: Req also consults it when building the
  # request URI, so it has to stay among the top-level options.
  defp pool_options(opts, connect_options, connect_timeout, pool_max_idle_time) do
    connect_options = merge_connect_timeout(connect_options, connect_timeout)

    translated =
      Keyword.take(opts, [:inet6]) ++
        Enum.reject(
          [connect_options: connect_options, pool_max_idle_time: pool_max_idle_time],
          fn {_key, value} -> is_nil(value) end
        )

    case translated do
      [] -> []
      translated -> Req.Finch.pool_options(Map.new(translated))
    end
  end

  defp merge_connect_timeout(connect_options, nil), do: connect_options
  defp merge_connect_timeout(nil, connect_timeout), do: [timeout: connect_timeout]

  defp merge_connect_timeout(connect_options, connect_timeout),
    do: Keyword.put_new(connect_options, :timeout, connect_timeout)
end
