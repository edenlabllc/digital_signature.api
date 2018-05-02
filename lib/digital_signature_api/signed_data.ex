defmodule DigitalSignature.SignedData do
  @moduledoc false
  defstruct signatures: [], content: ""

  def new, do: %__MODULE__{}

  def update(%__MODULE__{signatures: signatures}, %{
        signer: signer,
        is_valid: is_valid,
        validation_error_message: validation_error_message,
        content: content
      })
      when is_map(signer) and is_boolean(is_valid) and is_bitstring(validation_error_message) and is_binary(content) do
    signature = %{signer: signer, is_valid: is_valid, validation_error_message: validation_error_message}

    %__MODULE__{signatures: [signature | signatures], content: content}
  end

  def get_map(%__MODULE__{signatures: signatures, content: content}),
    do: %{signatures: Enum.reverse(signatures), content: content}
end
