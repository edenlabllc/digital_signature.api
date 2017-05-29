defmodule DigitalSignatureApi.Repo.Migrations.CreateCertsTable do
  use Ecto.Migration

  def change do
    create table(:certs, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :string, null: false
      add :data, :binary, null: false
      add :parent, :uuid
      add :type, :string, null: false
      add :active, :bool

      timestamps()
    end
  end
end
