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
  """

  @timeout 30_000
  @user_agent "find_site_icon (+https://github.com/XukuLLC/find_site_icon)"
  @pool_max_idle_time 30_000

  @spec new(keyword) :: Req.Request.t()
  def new(opts \\ []) when is_list(opts) do
    Req.new(
      compressed: true,
      headers: [{"user-agent", @user_agent}],
      redirect: true,
      retry: false
    )
    |> Req.merge(normalize_options(opts))
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
    |> Req.merge(normalize_options(opts))
    |> Req.merge(headers: headers)
  end

  defp request(url, headers, opts) when is_binary(url) do
    new(Keyword.merge(opts, url: url, headers: headers))
  end

  defp normalize_options(opts) do
    {timeout, opts} = Keyword.pop(opts, :timeout, @timeout)
    {connect_timeout, opts} = Keyword.pop(opts, :connect_timeout, timeout)
    {connect_options, opts} = Keyword.pop(opts, :connect_options, [])
    {pool_max_idle_time, opts} = Keyword.pop(opts, :pool_max_idle_time, @pool_max_idle_time)
    {finch_options, opts} = Keyword.pop(opts, :finch, [])

    opts
    |> Keyword.put_new(:receive_timeout, timeout)
    |> Keyword.put(
      :finch,
      Keyword.merge(
        pool_options(opts, connect_options, connect_timeout, pool_max_idle_time),
        finch_options
      )
    )
  end

  # `:inet6` is read, not popped: Req also consults it when building the
  # request URI, so it has to stay among the top-level options.
  defp pool_options(opts, connect_options, connect_timeout, pool_max_idle_time) do
    opts
    |> Keyword.take([:inet6])
    |> Keyword.merge(
      connect_options: Keyword.put_new(connect_options, :timeout, connect_timeout),
      pool_max_idle_time: pool_max_idle_time
    )
    |> Map.new()
    |> Req.Finch.pool_options()
  end
end
