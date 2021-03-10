defmodule FindSiteIcon.HTMLFetcher do
  @moduledoc false

  alias FindSiteIcon.Util.HTTPUtils

  def fetch_html(url) do
    with {:ok, 200, _headers, client_ref} <-
           HTTPUtils.get(url),
         {:ok, html} <- HTTPUtils.body(client_ref) do
      {:ok, html}
    end
  end
end
