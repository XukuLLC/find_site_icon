defmodule FindSiteIcon.HTMLFetcher do
  @moduledoc false

  alias FindSiteIcon.Util.HTTPUtils

  def fetch_html(url, opts \\ []) do
    with {:ok, %Req.Response{body: html, status: 200}} <- HTTPUtils.do_get(url, [], opts) do
      {:ok, html}
    end
  rescue
    # Return error tuple
    err -> {:error, Exception.message(err)}
  end
end
