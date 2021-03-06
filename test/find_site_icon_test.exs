defmodule FindSiteIconTest do
  use ExUnit.Case, async: true

  alias FindSiteIcon.{Cache, HTMLFetcher, IconInfo}
  alias FindSiteIcon.Fixtures.FindSiteIconFixtures
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

    test "error in case of bad url" do
      assert {:error, _msg} = FindSiteIcon.find_icon("bad_url")
    end

    test "error but with default_icon_url returns default_icon_url" do
      default_icon_url = "https://www.nytimes.com/apple-touch-icon.png"

      assert {:ok, ^default_icon_url} =
               FindSiteIcon.find_icon("bad_url", default_icon_url: default_icon_url)
    end

    test "if html provided, we use that instead of making an api call" do
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
        {HTMLFetcher, [], fetch_html: fn ^url -> {:error, "no html provided"} end},
        {IconUtils, [],
         icon_info_for: fn
           # Icon url is not one of the common urls, so it should not match with any
           # automatically merged icon location.
           ^icon_url -> %IconInfo{url: icon_url}
           _ -> nil
         end}
      ]) do
        assert FindSiteIcon.find_icon(url, html: html) == {:ok, icon_url}
      end
    end

    test "if html provided is not valid utf8 string, we try with base url" do
      invalid_html_binary = FindSiteIconFixtures.invalid_html_binary()

      url = "http://paulgraham.com/earnest.html"
      base_url = "http://paulgraham.com"
      icon_url = "http://ycombinator.com/arc/arc.png"

      base_url_html = """
      <!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
      <html>
      <head>
        <title>Paul Graham</title><!-- <META NAME="ROBOTS" CONTENT="NOODP"> -->
        <link rel="shortcut icon" href="#{icon_url}">
      </head>

      </html>
      """

      with_mocks([
        {Cache, [], get: fn _url -> nil end, update: fn _url, _icon_url -> nil end},
        {HTMLFetcher, [], fetch_html: fn ^base_url -> {:ok, base_url_html} end},
        {IconUtils, [],
         icon_info_for: fn
           ^icon_url -> %IconInfo{url: icon_url}
           _ -> nil
         end}
      ]) do
        # We provide a bad html binary.
        # It should then first check if the provided html is valid
        # If not, it should try to fetch the base url
        # Use the link tag from the base url
        # And try that
        assert {:ok, ^icon_url} = FindSiteIcon.find_icon(url, html: invalid_html_binary)
      end
    end

    test "if url and base url both provide invalid utf8 string, we try latin1 encoding" do
      invalid_html_binary = FindSiteIconFixtures.invalid_html_binary()

      url = "http://paulgraham.com/earnest.html"
      icon_url = "http://ycombinator.com/arc/arc.png"

      with_mocks([
        {Cache, [], get: fn _url -> nil end, update: fn _url, _icon_url -> nil end},
        {HTMLFetcher, [], fetch_html: fn _ -> {:ok, invalid_html_binary} end},
        {IconUtils, [],
         icon_info_for: fn
           ^icon_url -> %IconInfo{url: icon_url}
           _ -> nil
         end}
      ]) do
        # We provide a bad html binary.
        # It should then first check if the provided html is valid
        # If not, it should try to fetch the base url
        # Use the link tag from the base url
        # And try that
        assert {:ok, ^icon_url} = FindSiteIcon.find_icon(url)
      end
    end

    test "if image url is relative, it is converted to proper url" do
      icon_relative_url = "../images/apple-touch-icon-1920831098fa0df09sdf8a09sd8f.ico"
      url = "https://www.nytimes.com/news/biden.html"

      icon_url =
        "https://www.nytimes.com/images/apple-touch-icon-1920831098fa0df09sdf8a09sd8f.ico"

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
        {HTMLFetcher, [], fetch_html: fn ^url -> {:error, "no html provided"} end},
        {IconUtils, [],
         icon_info_for: fn
           # Icon url is not one of the common urls, so it should not match with any
           # automatically merged icon location.
           ^icon_url -> %IconInfo{url: icon_url}
           _ -> nil
         end}
      ]) do
        assert FindSiteIcon.find_icon(url, html: html) == {:ok, icon_url}
      end
    end
  end
end
