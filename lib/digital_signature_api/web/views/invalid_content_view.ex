defmodule DigitalSignature.Web.InvalidContentView do
  @moduledoc """
  This view will render 422 Error in a case of invalid content (malformed Json) inside a correct signed request
  """

  use DigitalSignature.Web, :view

  def render("invalid.json", assigns) do
    %{
      "type" => "request_malformed",
      "message" => assigns.error_message,
      "invalid" => [
          %{
              "rules" => [
                  %{
                      "rule" => "json",
                      "params" =>
                      %{
                        "content" => assigns.content
                      }
                  }
              ],
              "entry_type" => "content"
          }
      ],
  }
  end
end
