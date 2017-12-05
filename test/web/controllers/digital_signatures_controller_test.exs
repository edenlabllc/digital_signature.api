defmodule DigitalSignature.Web.DigitalSignaturesControllerTest do
  use DigitalSignature.Web.ConnCase

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
    assert "Not a base64 string" == rule["description"]
  end

  test "processing empty data works", %{conn: conn} do
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

  test "processing valid encoded data works", %{conn: conn} do
    data = %{
      "signed_content" =>
      "MIIYEwYJKoZIhvcNAQcCoIIYBDCCGAACAQExDjAMBgoqhiQCAQEBAQIBMIIIHwYJKoZIhvcNAQcBoIIIEASCCAx7Im5hbWUiOiLQmtCe0JzQo9Cd0JDQm9Cs0J3QmNCZINCX0JDQmtCb0JDQlCBcItCh0KPQlNCe0JLQntCS0JjQqNCd0K/QndCh0KzQmtCQINCa0J7QnNCj0J3QkNCb0KzQndCQINCc0IbQodCs0JrQkCDQm9CG0JrQkNCg0J3Qr1wiINCh0KPQlNCe0JLQntCS0JjQqNCd0K/QndCh0KzQmtCe0Icg0JzQhtCh0KzQmtCe0Icg0KDQkNCU0Jgg0JvQrNCS0IbQktCh0KzQmtCe0Icg0J7QkdCb0JDQodCi0IYiLCJzaG9ydF9uYW1lIjoi0KHQo9CU0J7QktCe0JLQmNCo0J3Qr9Cd0KHQrNCa0JAg0JrQnNCbIiwidHlwZSI6Ik1TUCIsIm93bmVyX3Byb3BlcnR5X3R5cGUiOiJTVEFURSIsImxlZ2FsX2Zvcm0iOiIxNTAiLCJlZHJwb3UiOiI0MTE1MTUxNCIsImt2ZWRzIjpbIjg2LjEwIl0sImFkZHJlc3NlcyI6W3sidHlwZSI6IlJFR0lTVFJBVElPTiIsImNvdW50cnkiOiJVQSIsImFyZWEiOiLQm9Cs0JLQhtCS0KHQrNCa0JAiLCJyZWdpb24iOiLQnNCe0KHQotCY0KHQrNCa0JjQmSIsInNldHRsZW1lbnRfdHlwZSI6IkNJVFkiLCJzZXR0bGVtZW50X2lkIjoiNTQ5YTdhOWYtY2E0Ni00ZmU3LWE4ODAtZDcxM2I5ZTUxYzJlIiwic3RyZWV0X3R5cGUiOiJTVFJFRVQiLCJzdHJlZXQiOiLQodCQ0JPQkNCZ0JTQkNCn0J3QntCT0J4iLCJidWlsZGluZyI6IjUiLCJ6aXAiOiI4MTM0MCIsInNldHRsZW1lbnQiOiLQodCj0JTQntCS0JAg0JLQmNCo0J3QryJ9XSwicGhvbmVzIjpbeyJ0eXBlIjoiTU9CSUxFIiwibnVtYmVyIjoiKzM4MDkzNTIzODkzMiJ9XSwiZW1haWwiOiJ5YXJvc2xhdmIxOTg5QGdtYWlsLmNvbSIsIm93bmVyIjp7ImZpcnN0X25hbWUiOiLQr9GA0L7RgdC70LDQsiIsImxhc3RfbmFtZSI6ItCa0L7QvdC40LoiLCJzZWNvbmRfbmFtZSI6ItCh0YLQtdC/0LDQvdC+0LLQuNGHIiwidGF4X2lkIjoiMTUyMDgxMjE1NCIsImJpcnRoX2RhdGUiOiIxOTQxLTA4LTIxIiwiYmlydGhfY291bnRyeSI6ItCj0LrRgNCw0ZfQvdCwIiwiYmlydGhfc2V0dGxlbWVudCI6ItCh0YPQtNC+0LLQsCDQktC40YjQvdGPIiwiZ2VuZGVyIjoiTUFMRSIsImVtYWlsIjoieWFyb3NsYXZiMTk4OUBnbWFpbC5jb20iLCJkb2N1bWVudHMiOlt7InR5cGUiOiJQQVNTUE9SVCIsIm51bWJlciI6ItCa0JAzMzA4MDMifV0sInBob25lcyI6W3sidHlwZSI6Ik1PQklMRSIsIm51bWJlciI6IiszODA5MzUyMzg5MzIifV0sInBvc2l0aW9uIjoiUDMifSwibWVkaWNhbF9zZXJ2aWNlX3Byb3ZpZGVyIjp7ImxpY2Vuc2VzIjpbeyJpc3N1ZWRfYnkiOiLQnNCe0Jcg0KPQutGA0LDRl9C90LgiLCJpc3N1ZWRfZGF0ZSI6IjIwMTctMDktMjEiLCJhY3RpdmVfZnJvbV9kYXRlIjoiMjAxNy0wOS0yMSIsIm9yZGVyX25vIjoiMjEwOS8wMS3QnCJ9XSwiYWNjcmVkaXRhdGlvbiI6eyJjYXRlZ29yeSI6IlNFQ09ORCIsImlzc3VlZF9kYXRlIjoiMjAxNy0wOS0yMSIsIm9yZGVyX25vIjoiMjEwOS8wMS3QnCIsIm9yZGVyX2RhdGUiOiIyMDE3LTA5LTIxIn19LCJzZWN1cml0eSI6eyJyZWRpcmVjdF91cmkiOiJodHRwczovL21lZGljcy5jb20udWEifSwicHVibGljX29mZmVyIjp7ImNvbnNlbnQiOnRydWUsImNvbnNlbnRfdGV4dCI6ItCX0L7QsdC+0LIn0Y/Qt9GD0Y7RgdGMINC00L7RgtGA0LjQvNGD0LLQsNGC0LjRgdGMINCg0LXQs9C70LDQvNC10L3RgtGDINGE0YPQvdC60YbRltC+0L3Rg9Cy0LDQvdC90Y8g0YHQuNGB0YLQtdC80LggZUhlYWx0aC4g0J/RltC00YLQstC10YDQtNC20YPRjiDQtNC+0YHRgtC+0LLRltGA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",
      "signed_content_encoding" => "base64"
    }

    conn = post conn, digital_signatures_path(conn, :index), data
    resp = json_response(conn, 200)

    IO.inspect(resp["data"])

    assert true
  end
end
