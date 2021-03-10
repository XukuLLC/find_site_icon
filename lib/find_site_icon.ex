defmodule FindSiteIcon do
  @moduledoc """
  Finds the large square icon for a site given its URL.
  """

  import Meeseeks.CSS

  alias FindSiteIcon.{Cache, HTMLFetcher, IconInfo}
  alias FindSiteIcon.Util.{IconUtils, StringUtils}

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

  @doc """
  Finds the large square icon for a site given its URL. Currently just looks for the largest
  "apple-touch-item-precomposed" with a fallback to "apple-touch-item".

  ## Examples

      iex> FindSiteIcon.find_icon("https://nytimes.com")
      "https://nytimes.com/vi-assets/static-assets/ios-ipad-144x144-28865b72953380a40aa43318108876cb.png"
  """
  def find_icon(url, html \\ nil) when is_binary(url) do
    case Cache.get(url) do
      nil ->
        icon_info = fetch_site_icon(url, html)

        if icon_info do
          Cache.update(url, icon_info)
          icon_info.url
        else
          nil
        end

      icon_url ->
        icon_url
    end
  end

  defp fetch_site_icon(url, html) when is_binary(url) do
    html =
      if html do
        html
      else
        case HTMLFetcher.fetch_html(url) do
          {:ok, result} -> result
          _ -> nil
        end
      end

    # We try to fetch the base url instead of the path if there is no valid html in the path
    base_url =
      url |> URI.parse() |> Map.put(:path, nil) |> Map.put(:query, nil) |> URI.to_string()

    html =
      cond do
        StringUtils.valid_utf8?(html) ->
          html

        base_url != url ->
          case HTMLFetcher.fetch_html(base_url) do
            {:ok, result} -> result
            _ -> nil
          end
      end

    if html do
      html
      |> Meeseeks.parse()
      |> link_tags()
      |> link_tags_to_urls()
      |> merge_known_icon_locations()
      |> relative_to_absolute_urls(url)
      |> fetch_icons()
      |> largest_icon()
    else
      # If no html found even after all this, then
      # We start with no link tags and try some known locations
      []
      |> merge_known_icon_locations()
      |> relative_to_absolute_urls(url)
      |> fetch_icons()
      |> largest_icon()
    end
  end

  defp largest_icon([]), do: nil

  defp largest_icon(icon_infos) when is_list(icon_infos) do
    # Here, png icons are usually larger for smaller size on disk. We'll prefer png icons
    # unless all we have are .ico
    case Enum.filter(icon_infos, fn %IconInfo{url: icon_url} ->
           String.ends_with?(icon_url, ".png")
         end) do
      [] -> Enum.max_by(icon_infos, & &1.size)
      only_pngs -> Enum.max_by(only_pngs, & &1.size)
    end
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
    ["/favicon.ico", "/apple-touch-icon.png"] ++ urls
  end

  defp link_tags_to_urls(tags) when is_list(tags) do
    tags |> Enum.map(&Meeseeks.attr(&1, "href")) |> Enum.reject(&(&1 == nil))
  end

  defp link_tags(%Meeseeks.Document{} = document) do
    ["apple-touch-icon", "apple-touch-icon-precomposed", "shortcut icon", "icon"]
    |> Enum.map(&link_tags(document, &1))
    |> Enum.flat_map(& &1)
  end

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

  defp relative_to_absolute_url(%URI{} = base_url, %URI{host: nil} = relative_url) do
    base_url
    |> Map.put(:path, relative_url.path)
    |> URI.to_string()
  end

  defp relative_to_absolute_url(_base_url, %URI{} = relative_url) do
    URI.to_string(relative_url)
  end
end
