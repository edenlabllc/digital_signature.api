defmodule DigitalSignature.CrlService do
  @moduledoc false
  use GenServer
  require Logger

  alias DigitalSignature.Crl
  alias DigitalSignature.Repo

  # Callbacks

  @impl true
  def init([]) do
    state = Enum.reduce(get_existing_crls(), %{}, fn crl, acc -> update_state(crl, acc) end)

    {:ok, state}
  end

  @impl true
  def handle_call({:revoked?, url}, _from, state) do
    {:reply, Map.get(state, url), state}
  end

  @impl true
  def handle_info({:reload, :crl}, state) do
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
          # Maps wokrs much more faster that list, so for map with a lot of keys,
          # key will be found much more faster (x 10-100 times)
          # than for list with a same number of elements
          Map.put(acc, userCertificate, nil)
        end)

      Map.put(state, url, revokedSerialNumbers)
    else
      error ->
        Logger.error("Error processig CRL: #{url} :: #{error}")
        state
    end
  end

  def get_existing_crls do
    Repo.all(Crl)
  end

  def get_revoked_status(url, timeout \\ 1000) do
    GenServer.call(__MODULE__, {:revoked?, url}, timeout)
  end

  # API
  def revoked?(url, serialNumber) do
    case get_revoked_status(url) do
      %{^url => %{^serialNumber => _}} ->
        true

      nil ->
        # TODO: download crl from url

        Logger.error("CRL file not found for #{url}")
        true

      %{^url => _} ->
        false

      error ->
        Logger.error("Unknown error get revoked status for #{url}:#{serialNumber} :: #{error}")
        true
    end
  end
end
