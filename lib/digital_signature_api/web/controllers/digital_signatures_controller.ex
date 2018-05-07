defmodule DigitalSignature.Web.DigitalSignaturesController do
  @moduledoc false
  use DigitalSignature.Web, :controller
  use JValid
  alias DigitalSignature.API, as: DigitalSignatureAPI
  require Logger

  action_fallback(DigitalSignature.Web.FallbackController)

  use_schema(:digital_signatures, "specs/json_schemas/digital_signatures_request.json")

  def index(conn, params) do
    with :ok <- validate_schema(:digital_signatures, params),
         {:ok, signed_content} <- Base.decode64(Map.get(params, "signed_content")),
         {:ok, result} <- DigitalSignatureAPI.process_signed_content(signed_content, Map.get(params, "check")) do
      render_response(result, params, conn)
    else
      :error ->
        error = [{%{description: "Not a base64 string", params: [], rule: :invalid}, "$.signed_content"}]
        Logger.error(inspect(error))
        {:error, error}

      {:error, {:multiple_signatures, n}} ->
        error = [
          {%{description: "Envelop contains multiple signatures (#{n})", params: [], rule: :invalid},
           "$.signed_content"}
        ]

        Logger.error(inspect(error))
        {:error, error}

      {:error, errors} when is_list(errors) ->
        Enum.each(errors, &Logger.error(inspect(&1)))
        {:error, errors}

      {:error, error} ->
        Logger.error(inspect(error))
        {:error, error}
    end
  end

  defp render_response(result, params, conn) do
    render(conn, "show.json", digital_signature_info: Map.merge(result, params))
  end
end
