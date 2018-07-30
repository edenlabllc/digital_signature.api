defmodule DigitalSignature.CrlService do
  @moduledoc false
  use GenServer
  require Logger
  require :public_key

  alias DigitalSignature.Crl
  alias DigitalSignature.Repo

  # Callbacks

  @impl true
  def init([]) do
    state = Enum.reduce(get_existing_crls(), %{}, fn crl, acc -> update_state(crl, acc) end)

    {:ok, state}
  end

  @impl true
  def handle_call({:check_revoked, serialNumber, urls}, _from, state) do
    {:reply, :ok, state}
  end

  @impl true
  def handle_info({:reload, :crl}, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info({:reload, :delta_crl}, state) do
    {:noreply, state}
  end

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def update_state(%Crl{url: url, data: data} = crl, state) do
    with {CertificateList, {TBSCertList, _, _, _, thisUpdate, nexUpdate, revokedCertificates, _}, _, _} <-
           :public_key.der_decode(:CertificateList, data) do
      revokedSerialNumbers =
        Enum.reduce(revokedCertificates, %{}, fn {TBSCertList_revokedCertificates_SEQOF, userCertificate, _, _}, acc ->
          # Maps wokrs much more faster that list, so for list with a lot of data find much more slower, that for maps
          Map.put(acc, userCertificate, nil)
        end)

      Map.put(state, url, revokedSerialNumbers)
    else
      error ->
        Logger.info("Error processig crl: #{url} :: #{error}")
        state
    end
  end

  def get_existing_crls do
    Repo.all(Crl)
  end
end
