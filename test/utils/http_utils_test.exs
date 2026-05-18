defmodule FindSiteIcon.Util.HTTPUtilsTest do
  use ExUnit.Case, async: true

  import Plug.Conn

  alias FindSiteIcon.HTMLFetcher
  alias FindSiteIcon.IconInfo
  alias FindSiteIcon.Util.{HTTPUtils, IconUtils}

  test "new/1 defaults pool_max_idle_time to 30_000 so idle connections release file descriptors" do
    # Regression test for issue #15: without this option, Req's Finch pools
    # default to :infinity max idle time, so probing many distinct hosts
    # leaks file descriptors until the OS limit is hit.
    request = HTTPUtils.new()

    assert request.options[:pool_max_idle_time] == 30_000
  end

  test "new/1 allows callers to override pool_max_idle_time with an integer" do
    request = HTTPUtils.new(pool_max_idle_time: 5_000)

    assert request.options[:pool_max_idle_time] == 5_000
  end

  test "new/1 allows callers to override pool_max_idle_time with :infinity" do
    request = HTTPUtils.new(pool_max_idle_time: :infinity)

    assert request.options[:pool_max_idle_time] == :infinity
  end

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

  test "icon_info_for/2 falls back to GET when HEAD reports zero content length" do
    bypass = Bypass.open()

    Bypass.expect_once(bypass, "HEAD", "/icon.png", fn conn ->
      conn
      |> put_resp_header("content-type", "image/png")
      |> resp(200, "")
    end)

    Bypass.expect_once(bypass, "GET", "/icon.png", fn conn ->
      conn
      |> put_resp_header("content-type", "image/png")
      |> resp(200, String.duplicate("x", 512))
    end)

    icon_url = "http://localhost:#{bypass.port}/icon.png"

    assert %IconInfo{url: ^icon_url} = IconUtils.icon_info_for(icon_url, timeout: 1_000)
  end
end
