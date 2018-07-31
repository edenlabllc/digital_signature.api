defmodule DigitalSignature.CrlApi do
  @moduledoc false
  import Ecto.{Query, Changeset}, warn: false
  alias DigitalSignature.Crl
  alias DigitalSignature.Repo
  alias DigitalSignature.RevokedSN

  def list_urls do
    Repo.all(Crl)
  end

  def get_serial(url, serialNumber) do
    Repo.get_by(RevokedSN, url: url, serial_number: Integer.to_string(serialNumber))
  end

  def get_url(url) do
    Repo.get_by(Crl, url: url)
  end

  def write_url(url, nextUpdate) do
    case get_url(url) do
      nil ->
        %Crl{}
        |> crl_changeset(%{url: url, next_update: nextUpdate})
        |> Repo.insert()

      %Crl{} = crl ->
        crl
        |> crl_changeset(%{url: url, next_update: nextUpdate})
        |> Repo.update()
    end
  end

  def write_serials(url, serialNumbers) do
    RevokedSN
    |> where([r], r.url == ^url)
    |> Repo.delete_all()

    NewRevokedSNs =
      Enum.reduce(serialNumbers, [], fn number, revoked_sns ->
        [sn_changeset(%RevokedSN{}, %{url: url, serial_number: Integer.to_string(number)}) | revoked_sns]
      end)

    Repo.insert_all(RevokedSN, NewRevokedSNs, [])
  end

  def update_serials(url, nextUpdate, serialNumbers) do
    Repo.transaction(
      fn ->
        write_url(url, nextUpdate)
        write_serials(url, serialNumbers)
      end,
      []
    )
  end

  def crl_changeset(%Crl{} = crl, attrs) do
    crl
    |> cast(attrs, [:url, :next_update])
    |> unique_constraint(:url, name: "crl_url_index")
  end

  def sn_changeset(%RevokedSN{} = sn, attrs) do
    sn
    |> cast(attrs, [:url, :serial_number])
  end
end
