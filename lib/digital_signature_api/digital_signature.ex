defmodule DigitalSignature.API do
  @moduledoc false

  alias DigitalSignature.NifService
  require Logger

  @invalid_content_error_message "Malformed encoded content. Probably, you have encoded corrupted JSON."

  def process_signed_content(signed_content, check) do
    with {:ok, result} <- NifService.process_signed_content(signed_content, check),
         {:ok, content} <- decode_content(result.content) do
      result = Map.put(result, :content, content)
      {:ok, result}
    end
  end

  defp decode_content(""), do: {:ok, ""}

  defp decode_content(content) do
    content =
      content
      |> String.replace_leading("\uFEFF", "")
      |> String.replace_trailing(<<0>>, "")

    case Jason.decode(content) do
      {:ok, decoded_content} ->
        {:ok, decoded_content}

      {:error, reason} ->
        Logger.error("Content cannot be decoded from Json, error: #{inspect(reason)}, content: #{content}")
        {:error, {:invalid_content, @invalid_content_error_message <> " Error: #{inspect(reason)}", inspect(content)}}
    end
  end
end
