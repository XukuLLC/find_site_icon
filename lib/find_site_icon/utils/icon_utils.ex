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

  @spec icon_info_for(binary | nil, keyword) :: %IconInfo{} | nil
  def icon_info_for(icon_url, opts \\ [])

  def icon_info_for(nil, _opts), do: nil

  def icon_info_for(icon_url, opts) when is_binary(icon_url) do
    icon_url
    |> fetch_icon_headers(opts)
    |> reject_bad_content_type()
    |> generate_info(icon_url)
  rescue
    # {:error, Exception.message(err)} || {:error, :unknown}
    _err -> nil
  end

  defp fetch_icon_headers(icon_url, opts) do
    case HTTPUtils.do_head(icon_url, [], opts) do
      {:ok, %Req.Response{status: status}} = response when status in 200..299 ->
        response

      _ ->
        HTTPUtils.do_get(icon_url, [], opts)
    end
  end

  @spec reject_bad_content_type(any) :: nil | {:ok, Req.Response.t()}
  def reject_bad_content_type({:ok, %Req.Response{headers: headers, status: 200}} = response) do
    content_type = extract_header(headers, "content-type")

    if is_nil(content_type) || String.starts_with?(content_type, "image") do
      response
    end
  end

  def reject_bad_content_type(_), do: nil

  @spec generate_info({:ok, Req.Response.t()} | nil, binary) :: %IconInfo{} | nil
  def generate_info({:ok, %Req.Response{headers: headers, status: 200}}, icon_url) do
    expiration_timestamp =
      headers |> extract_header("cache-control") |> generate_expiration_timestamp()

    content_length = extract_header(headers, "content-length") |> generate_size()
    %IconInfo{expiration_timestamp: expiration_timestamp, size: content_length, url: icon_url}
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
  def generate_expiration_timestamp(cache_control) when is_binary(cache_control) do
    case Regex.run(~r/(?:^|,)\s*max-age=(\d+)/i, cache_control) do
      [_match, seconds] ->
        DateTime.utc_now() |> DateTime.add(String.to_integer(seconds), :second)

      _ ->
        default_expiration_timestamp()
    end
  end

  def generate_expiration_timestamp(_cache_control), do: default_expiration_timestamp()

  defp default_expiration_timestamp do
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
