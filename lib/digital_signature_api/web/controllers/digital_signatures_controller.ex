defmodule DigitalSignature.Web.DigitalSignaturesController do
  @moduledoc false
  use DigitalSignature.Web, :controller
  use JValid
  alias DigitalSignature.NifService
  require Logger

  action_fallback DigitalSignature.Web.FallbackController

  use_schema :digital_signatures, "specs/json_schemas/digital_signatures_request.json"

  def index(conn, params) do
    with :ok <- validate_schema(:digital_signatures, params),
         {:ok, signed_data} <- Base.decode64(Map.get(params, "signed_content")),
         {:ok, result} <- NifService.process_signed_data(signed_data, Map.get(params, "check")),
         {:ok, content} <- Poison.decode(Map.get(result, :content))
    do
        result
        |> Map.put(:content, content)
        |> process_is_valid()
        |> render_response(params, conn)
    else
        {:error, errors} when is_list(errors) ->
          Enum.each(errors, &Logger.error(IO.inspect(&1)))
          {:error, errors}
        {:error, error} ->
          Logger.error(IO.inspect(error))
          {:error, error}
        :error ->
          error = [{%{description: "Not a base64 string", params: [], rule: :invalid}, "$.signed_content"}]
          Logger.error(IO.inspect(error))
          {:error, error}
    end
  end

  defp process_is_valid(%{is_valid: 1} = result), do: Map.put(result, :is_valid, true)
  defp process_is_valid(%{is_valid: 0} = result), do: Map.put(result, :is_valid, false)
  defp process_is_valid(result), do: result

  defp render_response(result, params, conn) do
    render(conn, "show.json", digital_signature_info: Map.merge(result, params))
  end
end
