defmodule DigitalSignature.Web.DigitalSignaturesControllerTest do
  @moduledoc false

  use DigitalSignature.Web.ConnCase, async: false
  alias DigitalSignature.Cert
  alias DigitalSignature.Repo

  describe "With correct certs in db" do
    setup %{conn: conn} do
      insert_dfs_certs()
      insert_justice_certs()
      insert_ucsku_certs()
      insert_privat_certs()

      Supervisor.terminate_child(DigitalSignature.Supervisor, DigitalSignature.NifService)
      Supervisor.restart_child(DigitalSignature.Supervisor, DigitalSignature.NifService)

      {:ok, conn: put_req_header(conn, "accept", "application/json")}
    end

    test "required params validation works", %{conn: conn} do
      conn = post(conn, digital_signatures_path(conn, :index), %{})

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
      conn =
        post(conn, digital_signatures_path(conn, :index), %{
          "signed_content" => "",
          "signed_content_encoding" => "base58"
        })

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
      conn =
        post(conn, digital_signatures_path(conn, :index), %{
          "signed_content" => "111",
          "signed_content_encoding" => "base64"
        })

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

    test "processing signed valid data works", %{conn: conn} do
      data = get_data("test/fixtures/hello.json")
      request = create_request(data)

      resp =
        conn
        |> post(digital_signatures_path(conn, :index), request)
        |> json_response(200)

      [signature] = resp["data"]["signatures"]

      assert signature["is_valid"]
      assert "" == signature["validation_error_message"]
      assert resp["data"]["content"] == %{"hello" => "world"}
    end

    test "processing signed valid data works (uakey)", %{conn: conn} do
      data = get_data("test/fixtures/uakey.json")
      request = create_request(data)

      resp =
        conn
        |> post(digital_signatures_path(conn, :index), request)
        |> json_response(200)

      [signature] = resp["data"]["signatures"]

      assert signature["is_valid"]
      assert "" == signature["validation_error_message"]

      assert resp["data"]["content"] == %{
               "name" => "patient",
               "route" => %{"first" => "Kiev", "second" => "Odessa"},
               "sex" => "male",
               "url" => %{"/api" => %{"target" => "http://api-dev.example.org/"}}
             }
    end

    test "processing double signed valid data works", %{conn: conn} do
      data = get_data("test/fixtures/double_hello.json")
      request = create_request(data)

      resp =
        conn
        |> post(digital_signatures_path(conn, :index), request)
        |> json_response(200)

      assert Enum.count(resp["data"]["signatures"]) == 2
      assert resp["data"]["content"] == %{"double" => "hello world"}
    end

    test "processing envelope with more than one signature returns correct error", %{conn: conn} do
      data = get_data("test/fixtures/tripple_hello.json")
      request = create_request(data)

      resp =
        conn
        |> post(digital_signatures_path(conn, :index), request)
        |> json_response(200)

      [signature] = resp["data"]["signatures"]
      refute signature["is_valid"]
      assert signature["validation_error_message"] == "envelope contains 2 signatures instead of 1"
    end

    @tag :pending
    test "processing valid encoded data 25 times in a row", %{conn: conn} do
      data = get_data("test/fixtures/hello.json")
      request = create_request(data)

      Enum.each(1..25, fn _ ->
        resp =
          conn
          |> post(digital_signatures_path(conn, :index), request)
          |> json_response(200)

        assert List.first(resp["data"]["signatures"])["is_valid"]
      end)
    end

    @tag :pending
    test "processing valid encoded data 25 times in parallel", %{conn: conn} do
      data = get_data("test/fixtures/hello.json")
      request = create_request(data)

      Enum.map(1..25, fn _ ->
        Task.async(fn ->
          conn
          |> post(digital_signatures_path(conn, :index), request)
        end)
      end)
      |> Enum.each(fn task ->
        resp =
          task
          |> Task.await()
          |> json_response(200)

        assert List.first(resp["data"]["signatures"])["is_valid"]
      end)
    end

    @tag :pending
    test "test NIF gen_server call timeout leads to correct response", %{conn: conn} do
      data = get_data("test/fixtures/hello.json")
      request = create_request(data)

      System.put_env("NIF_SERVICE_CALL_TIMEOUT", "10")

      Enum.map(1..10, fn _ ->
        Task.async(fn ->
          post(conn, digital_signatures_path(conn, :index), request)
        end)
      end)
      |> Enum.each(fn task ->
        task
        |> Task.await()
        |> json_response(424)
      end)

      System.delete_env("NIF_SERVICE_CALL_TIMEOUT")
    end

    @tag :pending
    test "test NIF gen_server messages timestamp works", %{conn: conn} do
      data = get_data("test/fixtures/hello.json")
      request = create_request(data)

      System.put_env("NIF_SERVICE_CALL_TIMEOUT", "110")

      Enum.map(1..100, fn _ ->
        Task.async(fn ->
          post(conn, digital_signatures_path(conn, :index), request)
        end)
      end)
      |> Enum.each(fn task ->
        %Plug.Conn{status: code} =
          task
          |> Task.await()
      end)

      assert code in [200, 424]

      System.delete_env("NIF_SERVICE_CALL_TIMEOUT")

      conn
      |> post(digital_signatures_path(conn, :index), request)
      |> json_response(200)
    end

    test "processing invalid encoded data works", %{conn: conn} do
      bad_request = %{
        "signed_content" => "eyJoZWxsbzoid29ybGQ6fQ==",
        "signed_content_encoding" => "base64"
      }

      conn = post(conn, digital_signatures_path(conn, :index), bad_request)
      resp = json_response(conn, 200)

      assert [] == resp["data"]["signatures"]
      assert "" == resp["data"]["content"]
    end

    test "processign valid signed declaration with outdated signature", %{conn: conn} do
      data = get_data("test/fixtures/outdated_cert.json")

      resp =
        conn
        |> post(digital_signatures_path(conn, :index), data)
        |> json_response(200)

      [signature] = resp["data"]["signatures"]

      refute signature["is_valid"]
      assert signature["validation_error_message"] == "certificate timestamp expired"
    end
  end

  describe "Without certs" do
    setup %{conn: conn} do
      Repo.delete_all(Cert)

      Supervisor.terminate_child(DigitalSignature.Supervisor, DigitalSignature.NifService)
      Supervisor.restart_child(DigitalSignature.Supervisor, DigitalSignature.NifService)

      {:ok, conn: put_req_header(conn, "accept", "application/json")}
    end

    test "Can return correct error", %{conn: conn} do
      data = get_data("test/fixtures/hello.json")

      resp =
        conn
        |> post(digital_signatures_path(conn, :index), data)
        |> json_response(200)

      [signature] = resp["data"]["signatures"]

      refute signature["is_valid"]
      assert signature["validation_error_message"] == "matching ROOT certificate not found"
    end

    test "Can process data signed with key where some info fieds are invalid and certificate is absent", %{conn: conn} do
      data = get_data("test/fixtures/no_cert_and_invalid_signer.json")
      conn = post(conn, digital_signatures_path(conn, :index), data)

      resp = json_response(conn, 200)

      [signature] = resp["data"]["signatures"]

      refute signature["is_valid"]
      assert signature["validation_error_message"] == "matching ROOT certificate not found"

      # this field contains invalid (non UTF-8) data inside the signed package - so we are returing an empty string
      assert signature["signer"]["organization_name"] == ""
      # this field contains invalid (non UTF-8) data inside the signed package - so we are returing an empty string
      assert signature["signer"]["organizational_unit_name"] == ""
    end
  end

  defp get_data(json_file) do
    {:ok, file} = File.read(json_file)
    {:ok, json} = Jason.decode(file)

    Map.take(json["data"], ["signed_content", "signed_content_encoding"])
  end

  defp create_request(data) do
    %{
      "signed_content" => data["signed_content"],
      "signed_content_encoding" => data["signed_content_encoding"]
    }
  end

  defp insert_dfs_certs do
    # Original Root with updated OCSP
    {:ok, %{id: dfs_root_id}} =
      Repo.insert(%Cert{
        name: "DFS",
        data: File.read!("test/fixtures/CA-DFS.cer"),
        parent: nil,
        type: "root",
        active: true
      })

    Repo.insert!(%Cert{
      name: "DFS",
      data: File.read!("test/fixtures/OCSP-IDDDFS-080218.cer"),
      parent: dfs_root_id,
      type: "ocsp",
      active: true
    })

    # Original OCSP - disabled
    Repo.insert!(%Cert{
      name: "DFS",
      data: File.read!("test/fixtures/CA-OCSP-DFS.cer"),
      parent: dfs_root_id,
      type: "ocsp",
      active: false
    })

    # Updated Root with updates OCSP
    {:ok, %{id: new_dfs_root_id}} =
      Repo.insert(%Cert{
        name: "DFS_NEW",
        data: File.read!("test/fixtures/CA-IDDDFS-080218.cer"),
        parent: nil,
        type: "root",
        active: true
      })

    Repo.insert!(%Cert{
      name: "DFS_NEW",
      data: File.read!("test/fixtures/OCSP-IDDDFS-080218.cer"),
      parent: new_dfs_root_id,
      type: "ocsp",
      active: true
    })

    # TSP
    Repo.insert!(%Cert{
      name: "DFS",
      data: File.read!("test/fixtures/TSA-IDDDFS-140218.cer"),
      parent: nil,
      type: "tsp",
      active: true
    })

    Repo.insert!(%Cert{
      name: "DFS_OLD",
      data: File.read!("test/fixtures/CA-TSP-DFS.cer"),
      parent: nil,
      type: "tsp",
      active: true
    })
  end

  defp insert_justice_certs do
    {:ok, %{id: j_root_id}} =
      Repo.insert(%Cert{
        name: "Justice",
        data: File.read!("test/fixtures/CA-Justice.cer"),
        parent: nil,
        type: "root",
        active: true
      })

    Repo.insert!(%Cert{
      name: "Justice",
      data: File.read!("test/fixtures/OCSP-Server Justice.cer"),
      parent: j_root_id,
      type: "ocsp",
      active: true
    })

    Repo.insert!(%Cert{
      name: "Justice",
      data: File.read!("test/fixtures/TSP-Server Justice.cer"),
      parent: nil,
      type: "tsp",
      active: true
    })
  end

  defp insert_ucsku_certs do
    {:ok, %{id: ucsk_root_id}} =
      Repo.insert(%Cert{
        name: "ucsku",
        data: File.read!("test/fixtures/cert1599998-root.crt"),
        parent: nil,
        type: "root",
        active: true
      })

    Repo.insert!(%Cert{
      name: "ucsku",
      data: File.read!("test/fixtures/cert14493930-oscp.crt"),
      parent: ucsk_root_id,
      type: "ocsp",
      active: true
    })

    Repo.insert!(%Cert{
      name: "ucsku",
      data: File.read!("test/fixtures/cert14491837-tsp.crt"),
      parent: nil,
      type: "tsp",
      active: true
    })
  end

  defp insert_privat_certs do
    {:ok, %{id: ucsk_root_id}} =
      Repo.insert(%Cert{
        name: "Privat",
        data: File.read!("test/fixtures/CA-3004751DEF2C78AE010000000100000049000000.cer"),
        parent: nil,
        type: "root",
        active: true
      })

    Repo.insert!(%Cert{
      name: "Privat",
      data: File.read!("test/fixtures/CAOCSPServer-D84EDA1BB9381E802000000010000001A000000.cer"),
      parent: ucsk_root_id,
      type: "ocsp",
      active: true
    })

    Repo.insert!(%Cert{
      name: "Privat",
      data: File.read!("test/fixtures/CATSPServer-3004751DEF2C78AE02000000010000004A000000.cer"),
      parent: nil,
      type: "tsp",
      active: true
    })
  end
end
