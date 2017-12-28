defmodule DigitalSignature.Web.DigitalSignaturesController do
  @moduledoc false
  use DigitalSignature.Web, :controller
  use JValid
  alias DigitalSignature.NifService
  require Logger

  action_fallback DigitalSignature.Web.FallbackController

  use_schema :digital_signatures, "specs/json_schemas/digital_signatures_request.json"

  @invalid_content_error_message "Malformed encoded content. Probably, you have encoded corrupted JSON."

  def index(conn, params) do
    with :ok <- validate_schema(:digital_signatures, params),
         {:ok, signed_data} <- Base.decode64(Map.get(params, "signed_content")),
         {:ok, result} <- NifService.process_signed_data(signed_data, Map.get(params, "check")),
         {:ok, content} <- decode_content(result)
    do
        result
        |> Map.put(:content, content)
        |> render_response(params, conn)
    else
        {:error, errors} when is_list(errors) ->
          Enum.each(errors, &Logger.error(inspect &1))
          {:error, errors}
        {:error, error} ->
          Logger.error(inspect error)
          {:error, error}
        :error ->
          error = [{%{description: "Not a base64 string", params: [], rule: :invalid}, "$.signed_content"}]
          Logger.error(inspect error)
          {:error, error}
    end
  end

  defp decode_content(%{content: ""}), do: {:ok, ""}
  defp decode_content(%{content: content}) do
    case Poison.decode(content) do
      {:ok, decoded_content} ->
        {:ok, decoded_content}

      {:error, :invalid} ->
        {:error, {:invalid_content, @invalid_content_error_message, content}}

      {:error, reason} ->
        message = "Malformed encoded content. #{inspect reason}"
        {:error, {:invalid_content, @invalid_content_error_message <> " Error: #{inspect reason}", content}}
      end
  end

  defp render_response(result, params, conn) do
    render(conn, "show.json", digital_signature_info: Map.merge(result, params))
  end
end
