defmodule FindSiteIcon.Util.HTTPUtils do
  @moduledoc """
  Simple wrapper over our http library
  """

  use Tesla

  adapter(Tesla.Adapter.Mint)

  plug(Tesla.Middleware.FollowRedirects)

  @timeout 30_000

  def do_get(url, headers \\ [], opts \\ []) do
    get(
      url,
      opts: [adapter: merged_options(opts)],
      headers: headers
    )
  end

  def do_head(url, headers \\ [], opts \\ []) do
    head(
      url,
      opts: [adapter: merged_options(opts)],
      headers: headers
    )
  end

  defp merged_options(opts) do
    Keyword.merge([timeout: @timeout], opts)
  end
end
