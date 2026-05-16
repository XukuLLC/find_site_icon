defmodule FindSiteIcon do
  @moduledoc """
  Finds the large square icon for a site given its URL.
  """

  import Meeseeks.CSS

  alias FindSiteIcon.{Cache, HTMLFetcher, IconInfo}
  alias FindSiteIcon.Util.IconUtils

  @type find_icon_option ::
          {:default_icon_url, binary}
          | {:html, binary}
          | {:http_options, keyword}
          | {:max_concurrency, pos_integer}
          | {:max_icons, pos_integer | :infinity}
          | {:timeout, timeout}

  @known_icon_locations [
    "/apple-touch-icon.png",
    "/apple-touch-icon-precomposed.png",
    "/favicon-192x192.png",
    "/favicon.png"
  ]
  @supported_image_extensions [".png", ".jpg", ".jpeg", ".webp", ".svg"]
  @default_icon_fetch_timeout 10_000
  @default_max_concurrency 8
  @default_max_icons :infinity

  @spec find_icon(binary, [find_icon_option]) :: {:error, binary} | {:ok, binary}
  @doc """
  Finds the large square icon for a site given its URL.

  Can be provided with additional options in the second argument:
  * :html -> can pass an already fetched html. Will look for icon link tags within the provided
  html if present.
  * :default_icon_url -> is used if no icon_url could be fetched.
  * :timeout -> caps the whole icon lookup and applies the same timeout to HTTP requests.
  * :http_options -> passes Req options to the internal HTTP client.
  * :max_concurrency -> limits concurrent icon probes. Defaults to 8.
  * :max_icons -> limits how many candidate icon URLs will be probed. Defaults to no limit.

  ## Examples

      iex> FindSiteIcon.find_icon("https://nytimes.com")
      {:ok, "https://nytimes.com/vi-assets/static-assets/ios-ipad-144x144-28865b72953380a40aa43318108876cb.png"}
  """
  def find_icon(url, opts \\ []) when is_binary(url) do
    default_icon_url = Keyword.get(opts, :default_icon_url)

    if valid_url?(url) do
      find_icon_with_timeout(url, opts)
    else
      bad_return("Invalid url", default_icon_url)
    end
  end

  defp find_icon_with_timeout(url, opts) do
    timeout = Keyword.get(opts, :timeout, :infinity)

    if is_integer(timeout) and timeout >= 0 do
      task = Task.async(fn -> do_find_icon(url, opts) end)
      default_icon_url = Keyword.get(opts, :default_icon_url)

      case Task.yield(task, timeout) || Task.shutdown(task, :brutal_kill) do
        {:ok, result} -> result
        _ -> bad_return("Timed out fetching icon", default_icon_url)
      end
    else
      do_find_icon(url, opts)
    end
  end

  defp do_find_icon(url, opts) do
    html = Keyword.get(opts, :html)
    default_icon_url = Keyword.get(opts, :default_icon_url)

    case Cache.get(url) do
      nil ->
        icon_info = fetch_site_icon(url, html, opts)

        if icon_info do
          Cache.update(url, icon_info)
          {:ok, icon_info.url}
        else
          bad_return("Could not find a valid icon", default_icon_url)
        end

      icon_url ->
        {:ok, icon_url}
    end
  end

  defp bad_return(error_msg, default_icon_url) do
    if default_icon_url do
      {:ok, default_icon_url}
    else
      {:error, error_msg}
    end
  end

  defp fetch_site_icon(url, html, opts) when is_binary(url) do
    html = usable_html(url, html, opts)

    html
    |> Meeseeks.parse()
    # If there is any error with parsing, link_tags will handle it by returning an empty array
    |> link_tags()
    |> link_tags_to_urls()
    |> filter_base64_encoded_images()
    |> merge_known_icon_locations()
    |> filter_invalid_urls()
    |> filter_invalid_image_formats()
    |> relative_to_absolute_urls(url)
    |> Enum.uniq()
    |> limit_icons(opts)
    |> fetch_icons(opts)
    |> filter_empty_and_small_icons()
    |> largest_icon()
  end

  defp valid_url?(url) do
    uri = URI.parse(url)

    uri.scheme in ["http", "https"] and is_binary(uri.host)
  end

  defp usable_html(url, html, opts) do
    html = initial_html(url, html, opts)
    base_url = base_url(url)

    html
    |> refetch_base_html(url, base_url, opts)
    |> normalize_html()
  end

  defp initial_html(_url, html, _opts) when is_binary(html), do: html
  defp initial_html(url, _html, opts), do: fetch_html(url, opts)

  defp base_url(url) do
    url |> URI.parse() |> Map.put(:path, nil) |> Map.put(:query, nil) |> URI.to_string()
  end

  defp refetch_base_html(html, url, base_url, opts) do
    if valid_html?(html) or base_url == url do
      html
    else
      fetch_html(base_url, opts)
    end
  end

  defp valid_html?(html), do: is_binary(html) and String.valid?(html)

  defp normalize_html(html) do
    # If even the base_url string does not match, try to convert it to latin1.
    # Ref: https://validator.w3.org/
    # As per this validator, if there is no encoding defined, we try to parse
    # the response as UTF-8 first and if that fails then as windows-1252.
    # We can include the wrapper around iconv and use that, but we can also work
    # with converting the string to simple latin1 format. If some character is
    # unrecognised, that's fine. The only time that'll be an issue is when the
    # character is in a link tag, and that is not something we're likely to ever see.
    if valid_html?(html) do
      html
    else
      try do
        # This will crash at the nil case, so we don't need to handle that separately
        case :unicode.characters_to_binary(html, :latin1) do
          encoded when is_binary(encoded) -> encoded
          _ -> ""
        end
      rescue
        # Just return an empty string and we'll try with the default icon locations
        _err -> ""
      end
    end
  end

  defp fetch_html(url, opts) do
    case fetch_html_result(url, http_options(opts)) do
      {:ok, result} -> result
      _ -> nil
    end
  end

  defp fetch_html_result(url, []), do: HTMLFetcher.fetch_html(url)
  defp fetch_html_result(url, http_options), do: HTMLFetcher.fetch_html(url, http_options)

  defp largest_icon([]), do: nil

  @image_size_considered_for_nil 256
  # The values here are based on heuristics and can/should be updated based on new info.
  @image_size_for_nil %{
    invalid: 0,
    jpeg: @image_size_considered_for_nil,
    png: 2 * @image_size_considered_for_nil,
    svg: 8 * @image_size_considered_for_nil,
    webp: @image_size_considered_for_nil
  }
  @image_format_size_multiplier_for_comparison %{
    invalid: 0,
    jpeg: 1.25,
    png: 1,
    svg: 10,
    webp: 1.25
  }

  defp largest_icon(icon_infos) when is_list(icon_infos) do
    # What we basically know is:
    # * PNG is lossless
    # * JPEG is compressed
    # So, if a JPEG is the same size as a PNG, its resolution must be higher.
    # All we care about is the highest resolution image.
    Enum.max_by(icon_infos, fn
      %IconInfo{size: size, url: url} ->
        format = icon_format(url)

        size_to_consider = size || @image_size_for_nil[format]

        size_to_consider * @image_format_size_multiplier_for_comparison[format]
    end)
  end

  defp icon_format(icon_url) do
    path =
      icon_url
      |> URI.parse()
      |> Map.get(:path)
      |> to_string()
      |> String.downcase()

    cond do
      String.ends_with?(path, ".png") -> :png
      String.ends_with?(path, ".jpg") || String.ends_with?(path, ".jpeg") -> :jpeg
      String.ends_with?(path, ".svg") -> :svg
      String.ends_with?(path, ".webp") -> :webp
      true -> :invalid
    end
  end

  defp filter_invalid_urls(urls) do
    Enum.filter(urls, fn
      icon_url ->
        try do
          uri = URI.parse(icon_url)

          !is_nil(uri.path)
        rescue
          _ -> false
        end
    end)
  end

  defp filter_empty_and_small_icons(icon_infos) when is_list(icon_infos) do
    # We'll remove icon infos with size == 0 here
    Enum.filter(icon_infos, fn
      %IconInfo{size: nil} ->
        true

      %IconInfo{size: size, url: url} when is_integer(size) ->
        format = icon_format(url)

        minimum_acceptable_size = @image_size_for_nil[format]

        size >= minimum_acceptable_size

      _ ->
        false
    end)
  end

  defp filter_invalid_image_formats(urls) when is_list(urls) do
    Enum.filter(urls, fn
      icon_url ->
        path =
          icon_url
          |> URI.parse()
          |> Map.get(:path)
          |> to_string()
          |> String.downcase()

        Enum.any?(@supported_image_extensions, &String.ends_with?(path, &1))
    end)
  end

  defp filter_base64_encoded_images(urls) when is_list(urls) do
    # Remove encoded images, which is done sometimes instead of providing an actual image
    Enum.filter(urls, fn
      "data:" <> _ -> false
      _ -> true
    end)
  end

  defp fetch_icons(urls, opts) when is_list(urls) do
    http_options = http_options(opts)

    urls
    |> Task.async_stream(fn url -> icon_info_for(url, http_options) end,
      max_concurrency: max_concurrency(opts),
      on_timeout: :kill_task,
      ordered: false,
      timeout: icon_fetch_timeout(opts)
    )
    |> Enum.filter(fn
      {:ok, icon_info} when not is_nil(icon_info) -> true
      _ -> false
    end)
    |> Enum.map(fn {:ok, icon_info} -> icon_info end)
  end

  defp icon_info_for(url, []), do: IconUtils.icon_info_for(url)
  defp icon_info_for(url, http_options), do: IconUtils.icon_info_for(url, http_options)

  defp relative_to_absolute_urls(urls, base_url) when is_list(urls) do
    Enum.map(urls, &relative_to_absolute_url(&1, base_url))
  end

  defp merge_known_icon_locations(urls) when is_list(urls) do
    @known_icon_locations ++ urls
  end

  defp http_options(opts) do
    http_options = Keyword.get(opts, :http_options, [])

    case Keyword.fetch(opts, :timeout) do
      {:ok, timeout} when is_integer(timeout) and timeout >= 0 ->
        Keyword.put_new(http_options, :timeout, timeout)

      _ ->
        http_options
    end
  end

  defp icon_fetch_timeout(opts) do
    Keyword.get(opts, :timeout, @default_icon_fetch_timeout)
  end

  defp max_concurrency(opts) do
    Keyword.get(opts, :max_concurrency, @default_max_concurrency)
  end

  defp max_icons(opts) do
    Keyword.get(opts, :max_icons, @default_max_icons)
  end

  defp limit_icons(urls, opts) do
    case max_icons(opts) do
      :infinity -> urls
      max_icons when is_integer(max_icons) and max_icons > 0 -> Enum.take(urls, max_icons)
      _ -> urls
    end
  end

  defp link_tags_to_urls(tags) when is_list(tags) do
    tags |> Enum.map(&Meeseeks.attr(&1, "href")) |> Enum.reject(&(&1 == nil))
  end

  defp link_tags(%Meeseeks.Document{} = document) do
    ["apple-touch-icon", "apple-touch-icon-precomposed", "shortcut icon", "icon"]
    |> Enum.map(&link_tags(document, &1))
    |> Enum.flat_map(& &1)
  end

  defp link_tags(_), do: []

  defp link_tags(document, rel) do
    document
    |> Meeseeks.all(css("link[rel=\"#{rel}\"]"))
  end

  defp relative_to_absolute_url(nil, _base_url), do: nil

  defp relative_to_absolute_url(url, base_url) when is_binary(base_url) and is_binary(url) do
    relative_to_absolute_url(
      URI.parse(base_url),
      URI.parse(url)
    )
  end

  defp relative_to_absolute_url(%URI{} = base_url, %URI{scheme: nil} = relative_url) do
    base_url |> URI.merge(relative_url) |> URI.to_string()
  end

  defp relative_to_absolute_url(_base_url, %URI{} = relative_url) do
    URI.to_string(relative_url)
  end
end
