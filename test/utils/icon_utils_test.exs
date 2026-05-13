defmodule FindSiteIcon.Util.IconUtilsTest do
  use ExUnit.Case, async: true

  import Mock

  alias FindSiteIcon.Util.{HTTPUtils, IconUtils}

  test "expired?/1" do
    assert IconUtils.expired?(nil) == true
    assert IconUtils.expired?("") == true

    timestamp = DateTime.utc_now() |> DateTime.add(-3600, :second)
    assert IconUtils.expired?(timestamp) == true

    timestamp = DateTime.utc_now() |> DateTime.add(3600, :second)
    assert IconUtils.expired?(timestamp) == false
  end

  test "generate_expiration_timestamp/1" do
    # Always returns a date 14 days from now
    timestamp_1 = IconUtils.generate_expiration_timestamp("") |> DateTime.to_date()
    timestamp_2 = IconUtils.generate_expiration_timestamp(nil) |> DateTime.to_date()
    timestamp_3 = IconUtils.generate_expiration_timestamp("max=2342") |> DateTime.to_date()

    assert timestamp_1 == timestamp_2 and timestamp_2 == timestamp_3
  end

  test "generate_size/1" do
    assert IconUtils.generate_size(nil) == nil
    assert IconUtils.generate_size("") == 0
    assert IconUtils.generate_size(123) == nil
    assert IconUtils.generate_size("1234") == 1234
  end

  test "generate_expiration_timestamp/1 honors cache-control max-age" do
    now = DateTime.utc_now()

    timestamp = IconUtils.generate_expiration_timestamp("public, max-age=60")

    assert DateTime.diff(timestamp, now) in 59..61
  end

  test "extract_header/2" do
    assert IconUtils.extract_header([], "content-length") == nil
    assert IconUtils.extract_header(["Varies"], "content-length") == nil
    assert IconUtils.extract_header([{"Cache-Control", "max=0"}], "content-length") == nil
    assert IconUtils.extract_header([{"content-length", "123"}], "content-length") == "123"
    assert IconUtils.extract_header([{"Content-Length", "123"}], "content-length") == "123"
  end

  test "reject_bad_content_type/1" do
    # Good responses
    response = {:ok, %Req.Response{headers: [], status: 200}}
    assert IconUtils.reject_bad_content_type(response) == response
    response = {:ok, %Req.Response{headers: [{"content-type", "image/png"}], status: 200}}
    assert IconUtils.reject_bad_content_type(response) == response
    response = {:ok, %Req.Response{headers: [{"content-type", "image/jpeg"}], status: 200}}
    assert IconUtils.reject_bad_content_type(response) == response
    response = {:ok, %Req.Response{headers: [{"content-type", "image/jpg"}], status: 200}}
    assert IconUtils.reject_bad_content_type(response) == response
    response = {:ok, %Req.Response{headers: [{"content-type", "image/*"}], status: 200}}
    assert IconUtils.reject_bad_content_type(response) == response

    # Bad responses
    assert IconUtils.reject_bad_content_type({:error, %Req.Response{headers: [], status: 200}}) ==
             nil

    assert IconUtils.reject_bad_content_type({:ok, %Req.Response{headers: [], status: 400}}) == nil

    assert IconUtils.reject_bad_content_type(
             {:ok, %Req.Response{headers: [{"content-type", "text/html"}], status: 200}}
           ) == nil

    assert IconUtils.reject_bad_content_type({:ok, %Req.Response{headers: [{"content-type", "text/*"}], status: 200}}) ==
             nil

    assert IconUtils.reject_bad_content_type({:ok, %Req.Response{headers: [{"content-type", "*/*"}], status: 200}}) ==
             nil

    assert IconUtils.reject_bad_content_type(
             {:ok, %Req.Response{headers: [{"content-type", "application/json"}], status: 200}}
           ) ==
             nil
  end

  describe "icon_info_for/1" do
    test "error response" do
      with_mock HTTPUtils,
        do_head: fn _url, _headers, _opts -> {:error, %Req.Response{}} end,
        do_get: fn _url, _headers, _opts -> {:error, %Req.Response{}} end do
        assert IconUtils.icon_info_for("random_url") == nil

        assert_called(HTTPUtils.do_head("random_url", [], []))
        assert_called(HTTPUtils.do_get("random_url", [], []))
      end
    end

    test "non 200 response" do
      with_mock HTTPUtils,
        do_head: fn _url, _headers, _opts -> {:ok, %Req.Response{status: 404}} end,
        do_get: fn _url, _headers, _opts -> {:ok, %Req.Response{status: 404}} end do
        assert IconUtils.icon_info_for("random_url") == nil

        assert_called(HTTPUtils.do_head("random_url", [], []))
        assert_called(HTTPUtils.do_get("random_url", [], []))
      end
    end

    test "valid response" do
      with_mock HTTPUtils,
        do_head: fn _url, _headers, _opts -> {:ok, %Req.Response{status: 200}} end do
        assert %FindSiteIcon.IconInfo{} = IconUtils.icon_info_for("random_url")

        assert_called(HTTPUtils.do_head("random_url", [], []))
      end
    end
  end
end
