defmodule DigitalSignature.Cert do
  @moduledoc false

  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "certs" do
    field(:name, :string)
    field(:data, :binary)
    field(:parent, Ecto.UUID)
    field(:type, :string)
    field(:active, :boolean)

    timestamps()
  end
end

defmodule DigitalSignature.Crl do
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "crl" do
    field(:url, :string)
    field(:data, :binary)

    timestamps()
  end
end
