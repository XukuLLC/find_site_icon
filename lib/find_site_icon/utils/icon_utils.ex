defmodule FindSiteIcon.Util.IconUtils do
  @moduledoc """
  Utilities for working with icon info
  """
  alias FindSiteIcon.IconInfo
  alias FindSiteIcon.Util.HTTPUtils

  @spec unexpired?(any) :: boolean
  def unexpired?(timestamp), do: !expired?(timestamp)

  @spec expired?(any) :: boolean
  def expired?(%DateTime{} = timestamp) do
    case DateTime.compare(DateTime.utc_now(), timestamp) do
      :gt -> true
      _ -> false
    end
  end

  def expired?(_), do: true

  @spec icon_info_for(binary | nil) :: %IconInfo{} | nil
  def icon_info_for(nil), do: nil

  def icon_info_for(icon_url) when is_binary(icon_url) do
    try do
      icon_url
      |> HTTPUtils.do_get()
      |> reject_bad_content_type()
      |> generate_info(icon_url)
    rescue
      # {:error, Exception.message(err)} || {:error, :unknown}
      _err -> nil
    end
  end

  @spec reject_bad_content_type(any) :: nil | {:ok, %Tesla.Env{}}
  def reject_bad_content_type({:ok, %Tesla.Env{status: 200, headers: headers}} = response) do
    content_type = extract_header(headers, "content-type")

    if is_nil(content_type) || String.starts_with?(content_type, "image") do
      response
    else
      nil
    end
  end

  def reject_bad_content_type(_), do: nil

  @spec generate_info({:ok, %Tesla.Env{}} | nil, binary) :: %IconInfo{} | nil
  def generate_info({:ok, %Tesla.Env{status: 200, headers: headers}}, icon_url) do
    expiration_timestamp =
      headers |> extract_header("cache-control") |> generate_expiration_timestamp()

    content_length = extract_header(headers, "content-length") |> generate_size()
    %IconInfo{url: icon_url, expiration_timestamp: expiration_timestamp, size: content_length}
  end

  def generate_info(nil, _icon_url), do: nil

  @spec extract_header([{binary, binary}], binary) :: binary | nil
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

  @spec generate_expiration_timestamp(any) :: DateTime.t()
  def generate_expiration_timestamp(_cache_control) do
    # to do: parse exact expiration timestamps. Ref: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Cache-Control
    DateTime.utc_now() |> DateTime.add(@fourteen_days_in_seconds, :second)
  end

  @spec generate_size(any) :: integer | nil
  def generate_size(content_length) when is_binary(content_length) do
    case Integer.parse(content_length) do
      {size, _binary} -> size
      _ -> 0
    end
  end

  def generate_size(_), do: nil
end
