defmodule DigitalSignature.Repo.Migrations.AddCrlTable do
  use Ecto.Migration

  def up do
    create table(:crl, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:url, :string, null: false)
      add(:data, :binary, null: false)

      timestamps()
    end

    unique_index(:crl, [:url])
  end

  def down do
    drop(table(:crl))
  end
end
