defmodule FindSiteIcon.Util.IconUtilsTest do
  use ExUnit.Case, async: true

  alias FindSiteIcon.Util.{HTTPUtils, IconUtils}

  import Mock

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

  test "extract_header/2" do
    assert IconUtils.extract_header([], "content-length") == nil
    assert IconUtils.extract_header(["Varies"], "content-length") == nil
    assert IconUtils.extract_header([{"Cache-Control", "max=0"}], "content-length") == nil
    assert IconUtils.extract_header([{"content-length", "123"}], "content-length") == "123"
    assert IconUtils.extract_header([{"Content-Length", "123"}], "content-length") == "123"
  end

  test "reject_bad_content_type/1" do
    # Good responses
    response = {:ok, %Tesla.Env{status: 200, headers: []}}
    assert IconUtils.reject_bad_content_type(response) == response
    response = {:ok, %Tesla.Env{status: 200, headers: [{"content-type", "image/png"}]}}
    assert IconUtils.reject_bad_content_type(response) == response
    response = {:ok, %Tesla.Env{status: 200, headers: [{"content-type", "image/jpeg"}]}}
    assert IconUtils.reject_bad_content_type(response) == response
    response = {:ok, %Tesla.Env{status: 200, headers: [{"content-type", "image/jpg"}]}}
    assert IconUtils.reject_bad_content_type(response) == response
    response = {:ok, %Tesla.Env{status: 200, headers: [{"content-type", "image/*"}]}}
    assert IconUtils.reject_bad_content_type(response) == response

    # Bad responses
    assert IconUtils.reject_bad_content_type({:error, %Tesla.Env{status: 200, headers: []}}) ==
             nil

    assert IconUtils.reject_bad_content_type({:ok, %Tesla.Env{status: 400, headers: []}}) == nil

    assert IconUtils.reject_bad_content_type(
             {:ok, %Tesla.Env{status: 200, headers: [{"content-type", "text/html"}]}}
           ) == nil

    assert IconUtils.reject_bad_content_type(
             {:ok, %Tesla.Env{status: 200, headers: [{"content-type", "text/*"}]}}
           ) == nil

    assert IconUtils.reject_bad_content_type(
             {:ok, %Tesla.Env{status: 200, headers: [{"content-type", "*/*"}]}}
           ) == nil

    assert IconUtils.reject_bad_content_type(
             {:ok, %Tesla.Env{status: 200, headers: [{"content-type", "application/json"}]}}
           ) ==
             nil
  end

  describe "icon_info_for/1" do
    test "error response" do
      with_mock HTTPUtils, do_get: fn _url -> {:error, %Tesla.Env{}} end do
        assert IconUtils.icon_info_for("random_url") == nil

        assert_called(HTTPUtils.do_get("random_url"))
      end
    end

    test "non 200 response" do
      with_mock HTTPUtils, do_get: fn _url -> {:ok, %Tesla.Env{status: 404}} end do
        assert IconUtils.icon_info_for("random_url") == nil

        assert_called(HTTPUtils.do_get("random_url"))
      end
    end

    test "valid response" do
      with_mock HTTPUtils, do_get: fn _url -> {:ok, %Tesla.Env{status: 200}} end do
        assert %FindSiteIcon.IconInfo{} = IconUtils.icon_info_for("random_url")

        assert_called(HTTPUtils.do_get("random_url"))
      end
    end
  end
end
