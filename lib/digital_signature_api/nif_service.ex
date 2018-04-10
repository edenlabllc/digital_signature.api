defmodule DigitalSignature.NifService do
  def process_signed_data(signed_data, check, certs) do
    check = unless is_boolean(check), do: true
    DigitalSignatureLib.processPKCS7Data(signed_data, certs, check)
  end
end
