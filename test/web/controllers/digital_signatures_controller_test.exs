defmodule DigitalSignatureApi.Web.DigitalSignaturesControllerTest do
  use DigitalSignatureApi.Web.ConnCase

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  test "required params validation works", %{conn: conn} do
    conn = post conn, digital_signatures_path(conn, :index), %{}

    resp = json_response(conn, 422)
    assert Map.has_key?(resp, "error")
    assert Map.has_key?(resp["error"], "type")
    assert "validation_failed" == resp["error"]["type"]

    assert Map.has_key?(resp["error"], "invalid")
    assert 2 == length(resp["error"]["invalid"])

    first_error = Enum.at(resp["error"]["invalid"], 0)
    assert 1 == length(first_error["rules"])
    rule = Enum.at(first_error["rules"], 0)
    assert "required" == rule["rule"]
    assert "required property signed_content was not present" == rule["description"]

    second_error = Enum.at(resp["error"]["invalid"], 1)
    assert 1 == length(second_error["rules"])
    rule = Enum.at(second_error["rules"], 0)
    assert "required" == rule["rule"]
    assert "required property signed_content_encoding was not present" == rule["description"]
  end

  test "signed_content_encoding validation works", %{conn: conn} do
    conn = post conn, digital_signatures_path(conn, :index), %{
      "signed_content" => "",
      "signed_content_encoding" => "base58"
    }

    resp = json_response(conn, 422)
    assert Map.has_key?(resp, "error")
    assert Map.has_key?(resp["error"], "type")
    assert "validation_failed" == resp["error"]["type"]

    assert Map.has_key?(resp["error"], "invalid")
    assert 1 == length(resp["error"]["invalid"])

    error = Enum.at(resp["error"]["invalid"], 0)
    assert 1 == length(error["rules"])
    assert "$.signed_content_encoding" == error["entry"]
    rule = Enum.at(error["rules"], 0)
    assert "inclusion" == rule["rule"]
    assert "value is not allowed in enum" == rule["description"]
  end

  test "signed_content validation works", %{conn: conn} do
    conn = post conn, digital_signatures_path(conn, :index), %{
      "signed_content" => "111",
      "signed_content_encoding" => "base64"
    }

    resp = json_response(conn, 422)
    assert Map.has_key?(resp, "error")
    assert Map.has_key?(resp["error"], "type")
    assert "validation_failed" == resp["error"]["type"]

    assert Map.has_key?(resp["error"], "invalid")
    assert 1 == length(resp["error"]["invalid"])

    error = Enum.at(resp["error"]["invalid"], 0)
    assert 1 == length(error["rules"])
    assert "$.signed_content" == error["entry"]
    rule = Enum.at(error["rules"], 0)
    assert "invalid" == rule["rule"]
    assert "not a base64 string" == rule["description"]
  end

  test "processing valid data works", %{conn: conn} do
    data = %{
      "signed_content" => "MTEx",
      "signed_content_encoding" => "base64"
    }

    conn = post conn, digital_signatures_path(conn, :index), data

    resp = json_response(conn, 200)
    assert Map.has_key?(resp, "data")
    assert data["signed_content"] == resp["data"]["signed_content"]
    assert data["signed_content_encoding"] == resp["data"]["signed_content_encoding"]
    assert "" == resp["data"]["content"]
    refute resp["data"]["is_valid"]

    assert Map.has_key?(resp["data"], "signer")
    signer = resp["data"]["signer"]
    assert "" == signer["common_name"]
    assert "" == signer["country_name"]
    assert "" == signer["drfo"]
    assert "" == signer["edrpou"]
    assert "" == signer["given_name"]
    assert "" == signer["locality_name"]
    assert "" == signer["organization_name"]
    assert "" == signer["organizational_unit_name"]
    assert "" == signer["state_or_province_name"]
    assert "" == signer["surname"]
    assert "" == signer["title"]
  end
end
