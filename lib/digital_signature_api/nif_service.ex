defmodule DigitalSignature.NifService do
  @moduledoc """
  Process signed data via NIF functions
  """

  def process_signed_data(signed_data, check, certs) do
    check = unless is_boolean(check), do: true
    DigitalSignatureLib.processPKCS7Data(signed_data, certs, check)
  end
end
