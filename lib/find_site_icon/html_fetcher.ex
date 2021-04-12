defmodule FindSiteIcon.HTMLFetcher do
  @moduledoc false

  alias FindSiteIcon.Util.HTTPUtils

  def fetch_html(url) do
    with {:ok, %Tesla.Env{status: 200, body: html}} <- HTTPUtils.do_get(url) do
      {:ok, html}
    end
  end
end
