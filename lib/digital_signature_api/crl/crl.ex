defmodule DigitalSignature.Crl do
  @moduledoc false
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "crl" do
    field(:url, :string)
    field(:data, :binary)

    timestamps()
  end
end
