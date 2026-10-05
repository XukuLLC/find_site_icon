defmodule FindSiteIcon.Util.HTTPUtilsTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO
  import Plug.Conn

  alias FindSiteIcon.HTMLFetcher
  alias FindSiteIcon.IconInfo
  alias FindSiteIcon.Util.{HTTPUtils, IconUtils}

  test "new/1 defaults pool_max_idle_time to 30_000 so idle connections release file descriptors" do
    # Regression test for issue #15: without this option, Req's Finch pools
    # default to :infinity max idle time, so probing many distinct hosts
    # leaks file descriptors until the OS limit is hit.
    request = HTTPUtils.new()

    assert request.options[:finch][:pool_max_idle_time] == 30_000
  end

  test "new/1 passes the connect timeout through :finch rather than :connect_options" do
    # Req 0.7 raises when :finch and :connect_options are both set, so the
    # connect timeout has to travel inside the :finch pool options.
    request = HTTPUtils.new(timeout: 1_234)

    refute Map.has_key?(request.options, :connect_options)
    assert request.options[:finch][:conn_opts][:transport_opts][:timeout] == 1_234
    assert request.options[:receive_timeout] == 1_234
  end

  test "new/1 still honours a caller-supplied :connect_options" do
    request = HTTPUtils.new(connect_options: [timeout: 2_000, hostname: "example.com"])

    assert request.options[:finch][:conn_opts][:transport_opts][:timeout] == 2_000
    assert request.options[:finch][:conn_opts][:hostname] == "example.com"
  end

  test "new/1 lets callers add Finch options without losing the defaults" do
    request = HTTPUtils.new(finch: [pool_timeout: 500])

    assert request.options[:finch][:pool_timeout] == 500
    assert request.options[:finch][:pool_max_idle_time] == 30_000
  end

  test "new/1 emits no Req deprecation warning" do
    # Regression test: Req 0.7 deprecated top-level :pool_max_idle_time and
    # IO.warn/1 attaches a stacktrace to every occurrence, so a single icon
    # lookup used to flood stderr with dozens of multi-line warnings.
    stderr = capture_io(:stderr, fn -> HTTPUtils.new() end)

    refute stderr =~ "deprecated"
  end

  test "do_get/3 emits no Req deprecation warning" do
    bypass = Bypass.open()

    Bypass.expect_once(bypass, "GET", "/", fn conn -> resp(conn, 200, "ok") end)

    stderr =
      capture_io(:stderr, fn ->
        assert {:ok, %Req.Response{status: 200}} =
                 HTTPUtils.do_get("http://localhost:#{bypass.port}/")
      end)

    refute stderr =~ "deprecated"
  end

  test "new/1 defaults compressed to true so Req decompresses encoded responses" do
    # Regression test for issue #17: Req 0.6 no longer decompresses response
    # bodies unless :compressed is enabled.
    request = HTTPUtils.new()

    assert request.options[:compressed] == true
  end

  test "new/1 allows callers to override compressed" do
    request = HTTPUtils.new(compressed: false)

    assert request.options[:compressed] == false
  end

  test "new/1 allows callers to override pool_max_idle_time with an integer" do
    request = HTTPUtils.new(pool_max_idle_time: 5_000)

    assert request.options[:finch][:pool_max_idle_time] == 5_000
  end

  test "new/1 allows callers to override pool_max_idle_time with :infinity" do
    request = HTTPUtils.new(pool_max_idle_time: :infinity)

    assert request.options[:finch][:pool_max_idle_time] == :infinity
  end

  test "do_get/3 keeps the pool settings of a prebuilt request" do
    # Regression test: request/3 merges the per-call options over the request,
    # and Req.merge/2 replaces :finch wholesale. Translating only the options
    # actually passed keeps whatever the request already carries.
    request = capturing_request(pool_max_idle_time: :infinity, finch: [pool_timeout: 250])

    assert {:ok, %Req.Response{status: 200}} = HTTPUtils.do_get(request)

    assert_received {:request_options, options}
    assert options[:finch][:pool_max_idle_time] == :infinity
    assert options[:finch][:pool_timeout] == 250
    assert options[:finch][:conn_opts][:transport_opts][:timeout] == 30_000
  end

  test "do_head/3 keeps the pool settings of a prebuilt request" do
    request = capturing_request(pool_max_idle_time: :infinity)

    assert {:ok, %Req.Response{status: 200}} = HTTPUtils.do_head(request)

    assert_received {:request_options, options}
    assert options[:finch][:pool_max_idle_time] == :infinity
  end

  test "do_get/3 applies per-call options without resetting the rest of the pool" do
    request = capturing_request(pool_max_idle_time: :infinity)

    assert {:ok, %Req.Response{status: 200}} = HTTPUtils.do_get(request, [], timeout: 1_500)

    assert_received {:request_options, options}
    assert options[:finch][:conn_opts][:transport_opts][:timeout] == 1_500
    assert options[:receive_timeout] == 1_500
    assert options[:finch][:pool_max_idle_time] == :infinity
  end

  test "new/1 accepts a Finch pool name without raising on pool options" do
    # Req raises `cannot set Finch pool options together with :name in :finch`,
    # so a caller-supplied name has to suppress the library's pool defaults.
    request = HTTPUtils.new(finch: [name: FindSiteIcon.TestFinch])

    assert request.options[:finch] == [name: FindSiteIcon.TestFinch]
  end

  test "do_get/3 accepts per-call options on a request that uses a named Finch pool" do
    # Regression test: the per-call timeout used to add pool options next to
    # the request's `:name`, and Req raised `cannot set Finch pool options
    # together with :name in :finch` instead of returning a result.
    request = capturing_request(finch: [name: FindSiteIcon.TestFinch])

    assert {:ok, %Req.Response{status: 200}} = HTTPUtils.do_get(request, [], timeout: 1_500)

    assert_received {:request_options, options}
    assert options[:finch] == [name: FindSiteIcon.TestFinch]
    assert options[:receive_timeout] == 1_500
  end

  test "do_get/3 keeps nested connect options when a per-call timeout changes" do
    # Regression test: Req's translation always emits :protocols and a fresh
    # :conn_opts, so merging translated options let a per-call timeout drop
    # the request's hostname and fall back to HTTP/1.
    request =
      capturing_request(
        connect_options: [hostname: "h.example", protocols: [:http2], transport_opts: [verify: :verify_none]]
      )

    assert {:ok, %Req.Response{status: 200}} = HTTPUtils.do_get(request, [], timeout: 1_500)

    assert_received {:request_options, options}
    assert options[:finch][:conn_opts][:hostname] == "h.example"
    assert options[:finch][:protocols] == [:http2]
    assert options[:finch][:conn_opts][:transport_opts][:verify] == :verify_none
    assert options[:finch][:conn_opts][:transport_opts][:timeout] == 1_500
    assert options[:finch][:pool_max_idle_time] == 30_000
  end

  test "do_get/3 folds :connect_options of a request not built by new/1" do
    request =
      [url: "http://example.com/", adapter: FindSiteIcon.CaptureAdapter, connect_options: [hostname: "h.example"]]
      |> Req.new()
      |> Req.Request.put_private(:test_pid, self())

    assert {:ok, %Req.Response{status: 200}} = HTTPUtils.do_get(request, [], timeout: 1_500)

    assert_received {:request_options, options}
    refute Map.has_key?(options, :connect_options)
    assert options[:finch][:conn_opts][:hostname] == "h.example"
    assert options[:finch][:conn_opts][:transport_opts][:timeout] == 1_500
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

  defp capturing_request(opts) do
    HTTPUtils.new(Keyword.merge([url: "http://example.com/", adapter: FindSiteIcon.CaptureAdapter], opts))
    |> Req.Request.put_private(:test_pid, self())
  end
end
