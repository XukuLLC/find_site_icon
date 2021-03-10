defmodule FindSiteIcon.Util.HTTPUtils do
  @moduledoc """
  Simple wrapper over our http library
  """
  @timeout 30_000
  def get(url, headers \\ [], opts \\ []) do
    :hackney.get(
      url,
      headers,
      "",
      opts ++ [follow_redirect: true, timeout: @timeout, recv_timeout: @timeout]
    )
  end

  def head(url, headers \\ [], opts \\ []) do
    :hackney.head(
      url,
      headers,
      "",
      opts ++ [follow_redirect: true, timeout: @timeout, recv_timeout: @timeout]
    )
  end

  def body(ref), do: :hackney.body(ref)
end
