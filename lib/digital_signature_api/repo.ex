defmodule DigitalSignature.Repo do
  @moduledoc false
  use Ecto.Repo, otp_app: :digital_signature_api
  use Ecto.Paging.Repo
end
