defmodule FindSiteIcon do
  @moduledoc """
  Finds the large square icon for a site given its URL.
  """

  import Meeseeks.CSS

  alias FindSiteIcon.HTMLFetcher

  @doc """
  Finds the large square icon for a site given its URL. Currently just looks for the largest
  "apple-touch-item-precomposed" with a fallback to "apple-touch-item".

  ## Examples

      iex> FindSiteIcon.find_icon("https://nytimes.com")
      "https://nytimes.com/vi-assets/static-assets/ios-ipad-144x144-28865b72953380a40aa43318108876cb.png"
  """
  def find_icon(url) do
    with {:ok, html} <- HTMLFetcher.fetch_html(url),
         parsed_content <- Meeseeks.parse(html) do
      parsed_content
      |> link_tags()
      |> largest()
      |> Meeseeks.attr("href")
      |> relative_to_absolute_url(url)
    else
      _ -> nil
    end
  end

  defp largest(nil), do: nil

  defp largest(link_tags) when is_list(link_tags) do
    link_tags
    |> Enum.max_by(fn link_tag ->
      (Meeseeks.attr(link_tag, "sizes") || "0x0")
      |> String.split("x")
      |> Enum.at(0)
      |> Integer.parse()
    end)
  end

  defp link_tags(document) do
    ~w(apple-touch-icon-precomposed apple-touch-icon)
    |> Enum.map(&link_tags(document, &1))
    |> Enum.find(&Enum.any?(&1))
  end

  defp link_tags(document, rel) do
    document
    |> Meeseeks.all(css("link[rel=#{rel}]"))
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
    |> Map.put(:query, relative_url.query)
    |> URI.to_string()
  end

  defp relative_to_absolute_url(_base_url, %URI{} = relative_url) do
    URI.to_string(relative_url)
  end
end
