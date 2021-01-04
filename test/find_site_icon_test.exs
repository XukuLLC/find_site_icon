defmodule FindSiteIconTest do
  use ExUnit.Case, async: true

  import Mock

  @nytimes_html """
    <html>
      <head>
        <link data-rh="true" rel="alternate" hrefLang="en" href="https://www.nytimes.com/live/2021/01/03/us/joe-biden-trump"/>
        <link data-rh="true" rel="canonical" href="https://www.nytimes.com/live/2021/01/03/us/joe-biden-trump"/>
        <link data-rh="true" rel="amphtml" href="https://www.nytimes.com/live/2021/01/03/us/joe-biden-trump.amp.html"/>
        <link data-rh="true" rel="shortcut icon" href="/vi-assets/static-assets/favicon-d2483f10ef688e6f89e23806b9700298.ico"/>
        <link data-rh="true" rel="apple-touch-icon" href="/vi-assets/static-assets/apple-touch-icon-28865b72953380a40aa43318108876cb.png"/>
        <link data-rh="true" rel="apple-touch-icon-precomposed" sizes="144×144" href="/vi-assets/static-assets/ios-ipad-144x144-28865b72953380a40aa43318108876cb.png"/>
        <link data-rh="true" rel="apple-touch-icon-precomposed" sizes="114×114" href="/vi-assets/static-assets/ios-iphone-114x144-080e7ec6514fdc62bcbb7966d9b257d2.png"/>
        <link data-rh="true" rel="apple-touch-icon-precomposed" href="/vi-assets/static-assets/ios-default-homescreen-57x57-43808a4cd5333b648057a01624d84960.png"/>
        <link href="https://g1.nyt.com/fonts/css/web-fonts.5810def60210a2fa7d0848f37e3fa048bb6147b1.css" rel="stylesheet" type="text/css"/>
        <link rel="stylesheet" href="/vi-assets/static-assets/global-69acc7c8fb6a313ed7e8641e4a88bf30.css"/>
      </head>
      <body></body>
    </html>
  """

  @nytimes_html_no_precomposed """
    <html>
      <head>
        <link data-rh="true" rel="alternate" hrefLang="en" href="https://www.nytimes.com/live/2021/01/03/us/joe-biden-trump"/>
        <link data-rh="true" rel="canonical" href="https://www.nytimes.com/live/2021/01/03/us/joe-biden-trump"/>
        <link data-rh="true" rel="amphtml" href="https://www.nytimes.com/live/2021/01/03/us/joe-biden-trump.amp.html"/>
        <link data-rh="true" rel="shortcut icon" href="/vi-assets/static-assets/favicon-d2483f10ef688e6f89e23806b9700298.ico"/>
        <link data-rh="true" rel="apple-touch-icon" href="/vi-assets/static-assets/apple-touch-icon-28865b72953380a40aa43318108876cb.png"/>
        <link href="https://g1.nyt.com/fonts/css/web-fonts.5810def60210a2fa7d0848f37e3fa048bb6147b1.css" rel="stylesheet" type="text/css"/>
        <link rel="stylesheet" href="/vi-assets/static-assets/global-69acc7c8fb6a313ed7e8641e4a88bf30.css"/>
      </head>
      <body></body>
    </html>
  """

  @zombocom_html """
  <html>
    <head>
      <title>ZOMBO</title>
    </head>
    <body>
      Anything is possible at Zombocom
    </body>
  </html>
  """

  test "finds the site icon" do
    with_mock FindSiteIcon.HTMLFetcher, fetch_html: fn _url -> {:ok, @nytimes_html} end do
      assert FindSiteIcon.find_icon("https://www.nytimes.com/live/2021/01/03/us/joe-biden-trump") ==
               "https://www.nytimes.com/vi-assets/static-assets/ios-ipad-144x144-28865b72953380a40aa43318108876cb.png"

      assert_called(
        FindSiteIcon.HTMLFetcher.fetch_html(
          "https://www.nytimes.com/live/2021/01/03/us/joe-biden-trump"
        )
      )
    end
  end

  test "finds the site icon when precomposed isn't present" do
    with_mock FindSiteIcon.HTMLFetcher,
      fetch_html: fn _url -> {:ok, @nytimes_html_no_precomposed} end do
      assert FindSiteIcon.find_icon("https://www.nytimes.com/live/2021/01/03/us/joe-biden-trump") ==
               "https://www.nytimes.com/vi-assets/static-assets/apple-touch-icon-28865b72953380a40aa43318108876cb.png"

      assert_called(
        FindSiteIcon.HTMLFetcher.fetch_html(
          "https://www.nytimes.com/live/2021/01/03/us/joe-biden-trump"
        )
      )
    end
  end

  test "returns nil when no icon found" do
    with_mock FindSiteIcon.HTMLFetcher, fetch_html: fn _url -> {:ok, @zombocom_html} end do
      assert FindSiteIcon.find_icon("https://html5zombo.com") == nil

      assert_called(FindSiteIcon.HTMLFetcher.fetch_html("https://html5zombo.com"))
    end
  end

  test "returns nil when fetching page errors out" do
    with_mock FindSiteIcon.HTMLFetcher,
      fetch_html: fn _url ->
        {:error,
         %Meeseeks.Error{
           metadata: %{
             description: "invalid tuple tree node",
             input:
               {:error,
                {:tls_alert,
                 {:bad_certificate,
                  'TLS client: In state certify at ssl_handshake.erl:1885 generated CLIENT ALERT: Fatal - Bad Certificate\n'}}}
           },
           reason: :invalid_input,
           type: :parser
         }}
      end do
      assert FindSiteIcon.find_icon("https://zombo.com") == nil

      assert_called(FindSiteIcon.HTMLFetcher.fetch_html("https://zombo.com"))
    end
  end
end
