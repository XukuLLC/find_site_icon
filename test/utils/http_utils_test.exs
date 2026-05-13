defmodule FindSiteIcon.Util.HTTPUtilsTest do
  use ExUnit.Case, async: true

  import Plug.Conn

  alias FindSiteIcon.HTMLFetcher
  alias FindSiteIcon.IconInfo
  alias FindSiteIcon.Util.{HTTPUtils, IconUtils}

  test "do_get/3 follows redirects and returns response body" do
    bypass = Bypass.open()

    Bypass.expect_once(bypass, "GET", "/", fn conn ->
      conn
      |> put_resp_header("location", "/target")
      |> resp(302, "")
    end)

    Bypass.expect_once(bypass, "GET", "/target", fn conn ->
      resp(conn, 200, "ok")
    end)

    assert {:ok, %Req.Response{body: "ok", status: 200}} =
             HTTPUtils.do_get("http://localhost:#{bypass.port}/")
  end

  test "fetch_html/2 passes timeout options through the Req wrapper" do
    bypass = Bypass.open()

    Bypass.expect_once(bypass, "GET", "/", fn conn ->
      resp(conn, 200, "<html></html>")
    end)

    assert HTMLFetcher.fetch_html("http://localhost:#{bypass.port}/", timeout: 1_000) ==
             {:ok, "<html></html>"}
  end

  test "icon_info_for/2 accepts successful HEAD responses without downloading the body" do
    bypass = Bypass.open()

    Bypass.expect_once(bypass, "HEAD", "/icon.png", fn conn ->
      conn
      |> put_resp_header("content-length", "512")
      |> put_resp_header("content-type", "image/png")
      |> resp(200, "")
    end)

    icon_url = "http://localhost:#{bypass.port}/icon.png"

    assert %IconInfo{size: nil, url: ^icon_url} =
             IconUtils.icon_info_for(icon_url, timeout: 1_000)
  end
end
