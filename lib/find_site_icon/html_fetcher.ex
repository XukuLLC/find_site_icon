defmodule FindSiteIcon.HTMLFetcher do
  @moduledoc false

  def fetch_html(url) do
    with {:ok, 200, _headers, client_ref} <- :hackney.get(url, [], "", follow_redirect: true),
         {:ok, html} <- :hackney.body(client_ref) do
      html
    end
  end
end
