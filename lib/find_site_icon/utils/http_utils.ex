defmodule FindSiteIcon.Util.HTTPUtils do
  @moduledoc """
  Small wrapper around Req with project defaults.

  Accepts the same options as `Req.new/1`, plus the following defaults that
  callers may override by passing the key explicitly:

  * `:timeout` -> applied to both connect and receive timeouts. Defaults to 30s.
  * `:pool_max_idle_time` -> milliseconds before idle Finch socket pools are
    terminated. Defaults to 30s so file descriptors are reclaimed when probing
    many distinct hosts. Pass `:infinity` to keep pools alive forever, which
    was Req's behaviour prior to find_site_icon 1.0.2. See issue #15.
  """

  @timeout 30_000
  @user_agent "find_site_icon (+https://github.com/XukuLLC/find_site_icon)"
  @pool_max_idle_time 30_000

  @spec new(keyword) :: Req.Request.t()
  def new(opts \\ []) when is_list(opts) do
    opts = normalize_options(opts)

    Req.new(
      connect_options: [timeout: @timeout],
      headers: [{"user-agent", @user_agent}],
      pool_max_idle_time: @pool_max_idle_time,
      receive_timeout: @timeout,
      redirect: true,
      retry: false
    )
    |> Req.merge(opts)
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

    connect_options =
      opts
      |> Keyword.get(:connect_options, [])
      |> Keyword.put_new(:timeout, connect_timeout)

    opts
    |> Keyword.put_new(:receive_timeout, timeout)
    |> Keyword.put(:connect_options, connect_options)
  end
end
