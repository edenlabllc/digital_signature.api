defmodule DigitalSignatureApi.Repo do
  @moduledoc false
  use Ecto.Repo, otp_app: :digital_signature_api
  use Ecto.Pagging.Repo
end
