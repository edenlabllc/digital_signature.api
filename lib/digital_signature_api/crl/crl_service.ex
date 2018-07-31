defmodule DigitalSignature.CrlService do
  @moduledoc false
  use GenServer
  use DigitalSignature.DateUtils
  require Logger

  alias DigitalSignature.Crl
  alias DigitalSignature.CrlApi

  # Callbacks

  @impl true
  def init([]) do
    state = Enum.reduce(CrlApi.list(), %{}, fn crl, acc -> update_state(crl, acc) end)
    {:ok, state}
  end

  @impl true
  def handle_call({:revoked?, url}, _from, state) do
    {:reply, Map.get(state, url), state}
  end

  @impl true
  def handle_cast({:reload, crl}, state) do
    {:noreply, update_state(crl, state)}
  end

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def update_state(%Crl{url: url, data: data} = crl, state) do
    with {CertificateList, {TBSCertList, _, _, _, _, nextUpdateTs, revokedCertificates, _}, _, _} <-
           :public_key.der_decode(:CertificateList, data) do
      nextUpdate = convert_date(nextUpdateTs)

      revokedSerialNumbers =
        Enum.reduce(revokedCertificates, %{}, fn {TBSCertList_revokedCertificates_SEQOF, userCertificate, _, _}, acc ->
          Map.put(acc, userCertificate, nil)
        end)

      Map.put(state, url, {nextUpdate, revokedSerialNumbers})
    else
      error ->
        Logger.error("Error processig CRL: #{url} :: #{error}")
        state
    end
  end

  def update_crl(url) do
    with {:ok, %HTTPoison.Response{status_code: 200, body: data}} <- HTTPoison.get(url),
         {:ok, crl} <- CrlApi.insert_or_update(url, data) do
      GenServer.cast(__MODULE__, {:reload, crl})
    else
      error ->
        Logger.error("Error update crl #{url} in state :: #{error}")
    end
  end

  def get_revoked_status(url, timeout \\ 1000) do
    GenServer.call(__MODULE__, {:revoked?, url}, timeout)
  end

  # API
  def revoked?(url, serialNumber) do
    serialNumber =
      serialNumber
      |> String.upcase()
      |> Base.decode16!()
      |> :binary.decode_unsigned()

    with {nextUpdate, revokedList} <- get_revoked_status(url),
         :gt <- DateTime.compare(nextUpdate, DateTime.utc_now()) do
      case revokedList do
        %{^url => %{^serialNumber => _}} ->
          true

        %{^url => _} ->
          false
      end
    else
      error when error in ~w(nil lt eq)a ->
        update_crl(url)
        true

      error ->
        Logger.error("Error get revoked status for #{url}:#{serialNumber} :: #{error}")
        true
    end
  end
end
