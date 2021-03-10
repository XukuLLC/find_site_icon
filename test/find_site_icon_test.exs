defmodule FindSiteIconTest do
  use ExUnit.Case, async: true

  alias FindSiteIcon.{Cache, HTMLFetcher, IconInfo}
  alias FindSiteIcon.Util.IconUtils

  import Mock

  test "finds the site icon when cache is populated" do
    url = "https://www.nytimes.com/live/2021/01/03/us/joe-biden-trump"

    icon_url =
      "https://www.nytimes.com/vi-assets/static-assets/ios-ipad-144x144-28865b72953380a40aa43318108876cb.png"

    with_mock Cache, get: fn _url -> icon_url end do
      assert FindSiteIcon.find_icon(url) == {:ok, icon_url}

      assert_called(Cache.get(url))
    end
  end

  describe "finds the site icon when cache is empty" do
    test "link tags present and hold largest icon in favicon" do
      icon_relative_url = "/favicon-1920831098fa0df09sdf8a09sd8f.ico"
      url = "https://www.nytimes.com"
      icon_url = url <> icon_relative_url

      html = """
      <html>
        <head>
          <link rel="shortcut icon" href="#{icon_relative_url}"/>
          <link rel="apple-touch-icon" href="/bad_url.png"/>
          <link rel="apple-touch-icon-precomposed" href="/bad_url_2.png"/>
        </head>
      </html>
      """

      with_mocks([
        {Cache, [], get: fn _url -> nil end, update: fn _url, _icon_url -> nil end},
        {HTMLFetcher, [], fetch_html: fn ^url -> {:ok, html} end},
        {IconUtils, [],
         icon_info_for: fn
           ^icon_url -> %IconInfo{url: icon_url}
           _ -> nil
         end}
      ]) do
        assert FindSiteIcon.find_icon(url) == {:ok, icon_url}
      end
    end

    test "link tags present and hold largest icon in apple-touch-icon" do
      icon_relative_url = "/apple-touch-icon-1920831098fa0df09sdf8a09sd8f.ico"
      url = "https://www.nytimes.com"
      icon_url = url <> icon_relative_url

      html = """
      <html>
        <head>
          <link rel="apple-touch-icon" href="#{icon_relative_url}"/>
          <link rel="shortcut icon" href="/bad_url.png"/>
          <link rel="apple-touch-icon-precomposed" href="/bad_url_2.png"/>
        </head>
      </html>
      """

      with_mocks([
        {Cache, [], get: fn _url -> nil end, update: fn _url, _icon_url -> nil end},
        {HTMLFetcher, [], fetch_html: fn ^url -> {:ok, html} end},
        {IconUtils, [],
         icon_info_for: fn
           ^icon_url -> %IconInfo{url: icon_url}
           _ -> nil
         end}
      ]) do
        assert FindSiteIcon.find_icon(url) == {:ok, icon_url}
      end
    end

    test "link tags present and hold largest icon in apple-touch-icon-precomposed" do
      icon_relative_url = "/apple-touch-icon-precomposed-1920831098fa0df09sdf8a09sd8f.ico"
      url = "https://www.nytimes.com"
      icon_url = url <> icon_relative_url

      html = """
      <html>
        <head>
          <link rel="shortcut icon" href="/bad_url.png"/>
          <link rel="apple-touch-icon" href="/bad_url_2.png"/>
          <link rel="apple-touch-icon-precomposed" href="#{icon_relative_url}"/>
        </head>
      </html>
      """

      with_mocks([
        {Cache, [], get: fn _url -> nil end, update: fn _url, _icon_url -> nil end},
        {HTMLFetcher, [], fetch_html: fn ^url -> {:ok, html} end},
        {IconUtils, [],
         icon_info_for: fn
           ^icon_url -> %IconInfo{url: icon_url}
           _ -> nil
         end}
      ]) do
        assert FindSiteIcon.find_icon(url) == {:ok, icon_url}
      end
    end

    test "link tags present but all invalid and yet icon present in undefined favicon.ico" do
      icon_relative_url = "/favicon.ico"
      url = "https://www.nytimes.com"
      icon_url = url <> icon_relative_url

      html = """
      <html>
        <head>
          <link rel="shortcut icon" href="#{icon_relative_url}-123234234j22342.ico"/>
          <link rel="apple-touch-icon" href="/bad_url.png"/>
          <link rel="apple-touch-icon-precomposed" href="/bad_url_2.png"/>
        </head>
      </html>
      """

      with_mocks([
        {Cache, [], get: fn _url -> nil end, update: fn _url, _icon_url -> nil end},
        {HTMLFetcher, [], fetch_html: fn ^url -> {:ok, html} end},
        {IconUtils, [],
         icon_info_for: fn
           ^icon_url -> %IconInfo{url: icon_url}
           _ -> nil
         end}
      ]) do
        assert FindSiteIcon.find_icon(url) == {:ok, icon_url}
      end
    end

    test "link tags present but all invalid and yet icon present in undefined apple-touch-icon.png" do
      icon_relative_url = "/apple-touch-icon.png"
      url = "https://www.nytimes.com"
      icon_url = url <> icon_relative_url

      html = """
      <html>
        <head>
          <link rel="shortcut icon" href="/bad_url_3.png"/>
          <link rel="apple-touch-icon" href="/bad_url.png"/>
          <link rel="apple-touch-icon-precomposed" href="/bad_url_2.png"/>
        </head>
      </html>
      """

      with_mocks([
        {Cache, [], get: fn _url -> nil end, update: fn _url, _icon_url -> nil end},
        {HTMLFetcher, [], fetch_html: fn ^url -> {:ok, html} end},
        {IconUtils, [],
         icon_info_for: fn
           ^icon_url -> %IconInfo{url: icon_url}
           _ -> nil
         end}
      ]) do
        assert FindSiteIcon.find_icon(url) == {:ok, icon_url}
      end
    end

    test "link tags absent and yet icon present in undefined favicon.ico" do
      icon_relative_url = "/favicon.ico"
      url = "https://www.nytimes.com"
      icon_url = url <> icon_relative_url

      html = """
      <html>
        <head>
        </head>
      </html>
      """

      with_mocks([
        {Cache, [], get: fn _url -> nil end, update: fn _url, _icon_url -> nil end},
        {HTMLFetcher, [], fetch_html: fn ^url -> {:ok, html} end},
        {IconUtils, [],
         icon_info_for: fn
           ^icon_url -> %IconInfo{url: icon_url}
           _ -> nil
         end}
      ]) do
        assert FindSiteIcon.find_icon(url) == {:ok, icon_url}
      end
    end

    test "link tags absent and yet icon present in undefined apple-touch-icon.png" do
      icon_relative_url = "/apple-touch-icon.png"
      url = "https://www.nytimes.com"
      icon_url = url <> icon_relative_url

      html = """
      <html>
        <head>
        </head>
      </html>
      """

      with_mocks([
        {Cache, [], get: fn _url -> nil end, update: fn _url, _icon_url -> nil end},
        {HTMLFetcher, [], fetch_html: fn ^url -> {:ok, html} end},
        {IconUtils, [],
         icon_info_for: fn
           ^icon_url -> %IconInfo{url: icon_url}
           _ -> nil
         end}
      ]) do
        assert FindSiteIcon.find_icon(url) == {:ok, icon_url}
      end
    end

    test "link tags absent and nothing exists in any of the predefined locations either" do
      url = "https://www.nytimes.com"

      html = """
      <html>
        <head>
        </head>
      </html>
      """

      with_mocks([
        {Cache, [], get: fn _url -> nil end, update: fn _url, _icon_url -> nil end},
        {HTMLFetcher, [], fetch_html: fn ^url -> {:ok, html} end},
        {IconUtils, [],
         icon_info_for: fn
           _ -> nil
         end}
      ]) do
        assert {:error, _msg} = FindSiteIcon.find_icon(url)
      end
    end

    test "link tags present but invalid and nothing exists in any of the predefined locations either" do
      url = "https://www.nytimes.com"

      html = """
      <html>
        <head>
          <link rel="shortcut icon" href="/bad_url_3.png"/>
          <link rel="apple-touch-icon" href="/bad_url.png"/>
          <link rel="apple-touch-icon-precomposed" href="/bad_url_2.png"/>
        </head>
      </html>
      """

      with_mocks([
        {Cache, [], get: fn _url -> nil end, update: fn _url, _icon_url -> nil end},
        {HTMLFetcher, [], fetch_html: fn ^url -> {:ok, html} end},
        {IconUtils, [],
         icon_info_for: fn
           _ -> nil
         end}
      ]) do
        assert {:error, _msg} = FindSiteIcon.find_icon(url)
      end
    end
  end
end
