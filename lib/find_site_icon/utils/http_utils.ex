defmodule FindSiteIcon.Util.HTTPUtils do
  @moduledoc """
  Simple wrapper over our http library
  """

  use Tesla

  plug(Tesla.Middleware.FollowRedirects)

  @timeout 30_000

  @spec do_get(binary | Tesla.Client.t(), keyword, keyword) ::
          {:error, any} | {:ok, Tesla.Env.t()}
  def do_get(url, headers \\ [], opts \\ []) do
    get(
      url,
      opts: [adapter: merged_options(opts)],
      headers: headers
    )
  end

  defp merged_options(opts) do
    Keyword.merge([timeout: @timeout], opts)
  end
end
