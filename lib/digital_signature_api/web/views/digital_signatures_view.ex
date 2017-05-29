defmodule DigitalSignature.Web.DigitalSignaturesView do
  @moduledoc false
  use DigitalSignature.Web, :view

  def render("digital_signature.json", %{digital_signature_info: digital_signature_info}), do: digital_signature_info
end
