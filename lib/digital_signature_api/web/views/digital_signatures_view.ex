defmodule DigitalSignatureApi.Web.DigitalSignaturesView do
  @moduledoc false
  use DigitalSignatureApi.Web, :view

  def render("digital_signature.json", %{digital_signature_info: digital_signature_info}), do: digital_signature_info
end
