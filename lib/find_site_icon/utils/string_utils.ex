defmodule FindSiteIcon.Util.StringUtils do
  @moduledoc """
  Simple utilities for strings
  """
  def valid_utf8?(<<_::utf8, rest::binary>>), do: valid_utf8?(rest)
  def valid_utf8?(<<>>), do: true
  def valid_utf8?(_), do: false
end
