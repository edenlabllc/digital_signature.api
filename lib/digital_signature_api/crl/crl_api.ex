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
    Repo.get_by(RevokedSN, url: url, serial_number: serialNumber)
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

    serialNumbers
    |> Enum.reduce([], fn number, revoked_sns ->
      [%{url: url, serial_number: Integer.to_string(number, 16)} | revoked_sns]
    end)
    |> chunk_records([])
    |> Enum.each(fn revokedSNs ->
      Repo.insert_all(RevokedSN, revokedSNs, [])
    end)
  end

  @doc """
  Insert n of records m times, because postgres ecto has
  limit of input parameters: 65000
  """
  def chunk_records([], acc), do: acc

  def chunk_records(list, acc) do
    chunk_limit = Confex.fetch_env!(:digital_signature_api, __MODULE__)[:sn_chunk_limit]
    {records, rest} = Enum.split(list, chunk_limit)

    chunk_records(rest, [records | acc])
  end

  def update_serials(url, nextUpdate, serialNumbers) do
    write_url(url, nextUpdate)
    write_serials(url, serialNumbers)
  end

  def crl_changeset(%Crl{} = crl, attrs) do
    crl
    |> cast(attrs, [:url, :next_update])
    |> unique_constraint(:url, name: "crl_url_index")
  end
end
