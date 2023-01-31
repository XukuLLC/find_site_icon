defmodule FindSiteIcon.HTMLFetcher do
  @moduledoc false

  alias FindSiteIcon.Util.HTTPUtils

  def fetch_html(url) do
    try do
      with {:ok, %Tesla.Env{status: 200, body: html}} <- HTTPUtils.do_get(url) do
        {:ok, html}
      end
    rescue
      # Return error tuple
      err -> {:error, Exception.message(err)} || {:error, :unknown}
    end
  end
end
