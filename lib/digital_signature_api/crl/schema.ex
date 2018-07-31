defmodule DigitalSignature.Crl do
  @moduledoc false
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "crl" do
    field(:url, :string)
    field(:next_update, :utc_datetime)
  end
end

defmodule DigitalSignature.RevokedSN do
  @moduledoc false
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "revoked" do
    field(:url, :string)
    field(:serial_number, :string)
  end
end
