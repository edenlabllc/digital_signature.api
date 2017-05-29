defmodule DigitalSignature.Web.DigitalSignaturesController do
  @moduledoc false
  use DigitalSignature.Web, :controller
  use JValid
  alias DigitalSignature.Cert.API, as: CertAPI
  require Logger

  action_fallback DigitalSignature.Web.FallbackController

  use_schema :digital_signatures, "specs/json_schemas/digital_signatures_request.json"

  def index(conn, params) do
    with :ok <- validate_schema(:digital_signatures, params) do
      params
      |> Map.get("signed_content")
      |> Base.decode64()
      |> process_signed_data(conn, params)
    end
  end

  defp process_signed_data(:error, _conn, _params) do
    {:error, [{%{description: "not a base64 string", params: ["signed_content"], rule: :invalid}, "$.signed_content"}]}
  end
  defp process_signed_data({:ok, signed_content}, conn, params) do
    digital_signature_info =
      signed_content
      |> :erlang.binary_to_list()
      |> :digital_signature_lib.processPKCS7Data(CertAPI.get_certs_map())
      |> process_result()
      |> Map.merge(params)
    render(conn, "digital_signature.json", digital_signature_info: digital_signature_info)
  end

  defp process_result({:error, error}), do: Logger.error(error)
  defp process_result({:ok, result}) do
    result
    |> Map.update!(:content, &process_content/1)
    |> Map.update!(:is_valid, &process_is_valid/1)
  end

  defp process_is_valid(1), do: true
  defp process_is_valid(0), do: false

  defp process_content(content) do
    content
    |> String.replace("\u007f", "") # TODO: fix this bug in a normal way
    |> Poison.decode()
    |> return_content(content)
  end

  defp return_content({:ok, decoded_content}, _content), do: decoded_content
  defp return_content({:error, _error, _pos}, content), do: content
end
