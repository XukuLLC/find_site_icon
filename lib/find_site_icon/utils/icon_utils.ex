defmodule FindSiteIcon.Util.IconUtils do
  @moduledoc """
  Utilities for working with icon info
  """
  alias FindSiteIcon.IconInfo
  alias FindSiteIcon.Util.HTTPUtils

  def unexpired?(timestamp), do: !expired?(timestamp)

  def expired?(%DateTime{} = timestamp) do
    case DateTime.compare(DateTime.utc_now(), timestamp) do
      :gt -> true
      _ -> false
    end
  end

  def expired?(_), do: true

  def icon_info_for(nil), do: nil

  def icon_info_for(icon_url) when is_binary(icon_url) do
    case HTTPUtils.head(icon_url) do
      {:ok, 200, headers} ->
        expiration_timestamp =
          headers |> extract_header("cache-control") |> generate_expiration_timestamp()

        content_length = extract_header(headers, "content-length") |> generate_size()
        %IconInfo{url: icon_url, expiration_timestamp: expiration_timestamp, size: content_length}

      _ ->
        nil
    end
  end

  def extract_header(headers, header_name) when is_list(headers) and is_binary(header_name) do
    case Enum.find(headers, fn
           {key, _value} -> String.downcase(key) == header_name
           _ -> false
         end) do
      {_key, value} -> value
      _ -> nil
    end
  end

  def extract_header(_, _), do: nil

  @fourteen_days_in_seconds 14 * 24 * 3600

  def generate_expiration_timestamp(_cache_control) do
    # to do: parse exact expiration timestamps. Ref: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Cache-Control
    DateTime.utc_now() |> DateTime.add(@fourteen_days_in_seconds, :second)
  end

  def generate_size(content_length) when is_binary(content_length) do
    case Integer.parse(content_length) do
      {size, _binary} -> size
      _ -> 0
    end
  end

  def generate_size(_), do: nil
end
