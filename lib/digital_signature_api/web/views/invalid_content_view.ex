defmodule DigitalSignature.Web.InvalidContentView do

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
