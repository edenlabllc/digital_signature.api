defmodule DigitalSignature.Web.DigitalSignaturesView do
  @moduledoc false
  use DigitalSignature.Web, :view

  def render("show.json", %{digital_signature_info: digital_signature_info}) do
    render_one(digital_signature_info, DigitalSignaturesView, "digital_signature.json")
  end

  def render("digital_signature.json", %{digital_signature_info: digital_signature_info}) do
    Map.drop(digital_signature_info, :__meta__)
  end
end
