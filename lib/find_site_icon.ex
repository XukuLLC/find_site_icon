defmodule FindSiteIcon do
  @moduledoc """
  Finds the large square icon for a site given its URL.
  """

  import Meeseeks.CSS

  alias FindSiteIcon.{Cache, HTMLFetcher, IconInfo}
  alias FindSiteIcon.Util.IconUtils

  # The foolproof way to know that we have the largest
  # site icon is to actually download the images and check their sizes. It also handles
  # the case where icon is defined in html, but is not actually present.
  # What we'll do is
  # Check if we already know the site_icon, we'll have a permanent cache.
  # try to extract known link tags from the html
  # NOPE: if found, extract the largest size, that'll be the simple
  # apple-touch-icon > apple-touch-icon-precomposed > favicon > other apple_touch_icons
  # Merge the extracted link tags with known link tags.
  # Try to open all these link tags and for the ones which would open, store the
  # largest icon size along with expiration timestamp.
  # We have our largest site_icon for a page.

  @spec find_icon(binary, keyword(binary)) :: {:error, <<_::216>>} | {:ok, any}
  @doc """
  Finds the large square icon for a site given its URL.

  Can be provided with additional options in the second argument:
  * :html -> can pass an already fetched html. Will look for icon link tags within the provided
  html if present.
  * :default_icon_url -> is used if no icon_url could be fetched.

  ## Examples

      iex> FindSiteIcon.find_icon("https://nytimes.com")
      {:ok, "https://nytimes.com/vi-assets/static-assets/ios-ipad-144x144-28865b72953380a40aa43318108876cb.png"}
  """
  def find_icon(url, opts \\ []) when is_binary(url) do
    html = Keyword.get(opts, :html)
    default_icon_url = Keyword.get(opts, :default_icon_url)

    uri = URI.parse(url)

    if not is_nil(uri.host) and not is_nil(uri.scheme) do
      do_find_icon(url, html, default_icon_url)
    else
      bad_return("Invalid url", default_icon_url)
    end
  end

  defp do_find_icon(url, html, default_icon_url) do
    case Cache.get(url) do
      nil ->
        icon_info = fetch_site_icon(url, html)

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

  defp fetch_site_icon(url, html) when is_binary(url) do
    html = usable_html(url, html)

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
    |> fetch_icons()
    |> filter_empty_and_small_icons()
    |> largest_icon()
  end

  defp usable_html(url, html) do
    html = html || fetch_html(url)

    # We try to fetch the base url instead of the path if there is no valid html in the path
    base_url =
      url |> URI.parse() |> Map.put(:path, nil) |> Map.put(:query, nil) |> URI.to_string()

    html =
      if (not is_nil(html) and String.valid?(html)) or base_url == url do
        html
      else
        fetch_html(base_url)
      end

    # If even the base_url string does not match, we try to convert it to latin1
    # and pray to god that this new string works.
    # Ref: https://validator.w3.org/
    # As per this validator, if there is no encoding defined, we try to parse
    # the response as UTF-8 first and if that fails then as windows-1252.
    # We can include the wrapper around iconv and use that, but we can also work
    # with converting the string to simple latin1 format. If some character is
    # unrecognised, that's fine. The only time that'll be an issue is when the
    # character is in a link tag, and that is not something we're likely to ever see.
    if not is_nil(html) and String.valid?(html) do
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

  defp fetch_html(url) do
    case HTMLFetcher.fetch_html(url) do
      {:ok, result} -> result
      _ -> nil
    end
  end

  defp largest_icon([]), do: nil

  @image_size_considered_for_nil 256
  # The values here are based on heuristics and can/should be updated based on new info.
  @image_size_for_nil %{
    png: 2 * @image_size_considered_for_nil,
    jpeg: @image_size_considered_for_nil,
    invalid: 0
  }
  @image_format_size_multiplier_for_comparison %{png: 1, jpeg: 1.25, invalid: 0}

  defp largest_icon(icon_infos) when is_list(icon_infos) do
    # What we basically know is:
    # * PNG is lossless
    # * JPEG is compressed
    # So, if a JPEG is the same size as a PNG, its resolution must be higher.
    # All we care about is the highest resolution image.
    Enum.max_by(icon_infos, fn
      %IconInfo{url: url, size: size} ->
        format = icon_format(url)

        size_to_consider = size || @image_size_for_nil[format]

        size_to_consider * @image_format_size_multiplier_for_comparison[format]
    end)
  end

  defp icon_format(icon_url) do
    uri = URI.parse(icon_url)

    cond do
      String.ends_with?(uri.path, ".png") -> :png
      String.ends_with?(uri.path, ".jpg") || String.ends_with?(icon_url, ".jpeg") -> :jpeg
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

      %IconInfo{url: url, size: size} when is_integer(size) ->
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
        uri = URI.parse(icon_url)

        String.ends_with?(uri.path, ".png") || String.ends_with?(uri.path, ".jpg") ||
          String.ends_with?(uri.path, ".jpeg")
    end)
  end

  defp filter_base64_encoded_images(urls) when is_list(urls) do
    # Remove encoded images, which is done sometimes instead of providing an actual image
    Enum.filter(urls, fn
      "data:" <> _ -> false
      _ -> true
    end)
  end

  defp fetch_icons(urls) when is_list(urls) do
    urls
    |> Task.async_stream(fn url -> IconUtils.icon_info_for(url) end,
      on_timeout: :kill_task,
      timeout: 10_000
    )
    |> Enum.filter(fn
      {:ok, icon_info} when not is_nil(icon_info) -> true
      _ -> false
    end)
    |> Enum.map(fn {:ok, icon_info} -> icon_info end)
  end

  defp relative_to_absolute_urls(urls, base_url) when is_list(urls) do
    Enum.map(urls, &relative_to_absolute_url(&1, base_url))
  end

  defp merge_known_icon_locations(urls) when is_list(urls) do
    ["/apple-touch-icon.png"] ++ urls
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
