defmodule DigitalSignature.CrlApi do
  @moduledoc false
  import Ecto.{Query, Changeset}, warn: false
  alias DigitalSignature.Crl
  alias DigitalSignature.Repo

  def insert_or_update(url, data) do
    case get_crl_by_url(url) do
      nil ->
        insert_crl(%{url: url, data: data})

      %Crl{} = crl ->
        update_crl(crl, %{url: url, data: data})
    end
  end

  def list do
    Repo.all(Crl)
  end

  def get_crl_by_url(url) do
    Repo.get_by(Crl, url: url)
  end

  def insert_crl(%{url: _url, data: _data} = attrs) do
    %Crl{}
    |> crl_changeset(attrs)
    |> Repo.insert()
  end

  def update_crl(crl, %{url: _url, data: _data} = attrs) do
    crl
    |> crl_changeset(attrs)
    |> Repo.update()
  end

  def crl_changeset(%Crl{} = crl, %{url: _url, data: _data} = attrs) do
    crl
    |> cast(attrs, [:url, :data])
    |> unique_constraint(:url, name: "crl_url_index")
  end
end
