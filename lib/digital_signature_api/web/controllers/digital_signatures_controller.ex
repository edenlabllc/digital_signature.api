defmodule DigitalSignature.Web.DigitalSignaturesController do
  @moduledoc false
  use DigitalSignature.Web, :controller
  use JValid
  alias DigitalSignature.NifService
  require Logger

  action_fallback DigitalSignature.Web.FallbackController

  use_schema :digital_signatures, "specs/json_schemas/digital_signatures_request.json"

  def index(conn, %{signed_content: signed_content} = params) do
    with :ok <- validate_schema(:digital_signatures, params),
         {:ok, signed_data} = Base.decode64(signed_content),
         check = Map.get(params, "check")
    do
        signed_data
        |> NifService.process_signed_data(check)
        |> process_result()
        |> render_response(params, conn)
    else
        {:error, reason} -> {:error, reason}
        :error -> {:error, [{%{description: "Not a base64 string", params: [], rule: :invalid}, "$.signed_content"}]}
    end
  end

  defp process_result({:error, error}), do: {:error, error}
  defp process_result({:ok, %{content: content} = result}) do
    content
    |> process_content()
    |> update_content(result)
    |> process_is_valid()
  end

  defp process_content(content) do
    content
    |> Poison.decode()
    |> return_content(content)
  end

  defp update_content({:ok, content}, result), do: {:ok, Map.put(result, :content, content)}
  defp update_content({:error, error}, _result), do: {:error, error}

  defp process_is_valid({:ok, %{is_valid: 1} = result}), do: {:ok, Map.put(result, :is_valid, true)}
  defp process_is_valid({:ok, %{is_valid: 0} = result}), do: {:ok, Map.put(result, :is_valid, false)}
  defp process_is_valid({:ok, result}), do: {:ok, result}
  defp process_is_valid({:error, error}), do: {:error, error}

  defp return_content({:ok, decoded_content}, _content), do: {:ok, decoded_content}
  defp return_content(_error, content) do
    case String.valid?(content) do
      true -> {:ok, content}
      _ -> {:error, [{%{description: "not a valid utf8 string", params: [], rule: :invalid}, "$.content"}]}
    end
  end

  defp render_response({:error, error}, _params, _conn) when is_list(error), do: {:error, error}
  defp render_response({:error, error}, _params, _conn), do: Logger.error(error)
  defp render_response({:ok, result}, params, conn) do
    render(conn, "show.json", digital_signature_info: Map.merge(result, params))
  end
end
