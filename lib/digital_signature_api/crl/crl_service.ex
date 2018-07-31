defmodule DigitalSignature.CrlService do
  @moduledoc false
  use GenServer
  use DigitalSignature.DateUtils
  require Logger

  alias DigitalSignature.CrlApi
  alias DigitalSignature.Crl
  alias DigitalSignature.RevokedSN
  #
  #   # Callbacks
  #
  #   @impl true
  #   def init([]) do
  #     {:ok, {%{}, %{}}}
  #   end
  #
  #   @impl true
  #   def handle_call({:revoked?, url}, _from, {urls, _} = state) do
  #     {:reply, Map.get(urls, url), state}
  #   end
  #
  #   @impl true
  #   def handle_info({:update, url}, state) do
  #     newState =
  #       with {:ok, crl} <- update_crl(url) do
  #         update_state(crl, state)
  #       else
  #         state
  #       end
  #
  #     {:noreply, newState}
  #   end
  #
  #   def start_link() do
  #     GenServer.start_link(__MODULE__, [], name: __MODULE__)
  #
  #     Enum.reduce(CrlApi.list(), fn crl, _ -> send(__MODULE__, {:update, crl}) end)
  #   end
  #
  #   def update_state(%Crl{url: url, data: data} = crl, {urls, timers} = state) do
  #     with {CertificateList, {TBSCertList, _, _, _, _, nextUpdateTs, revokedCertificates, _}, _, _} <-
  #            :public_key.der_decode(:CertificateList, data) do
  #       nextUpdate = convert_date(nextUpdateTs)
  #       tref = Process.send_after(pid, :hi, 1000)
  #
  #       revokedSerialNumbers =
  #         Enum.reduce(revokedCertificates, %{}, fn {TBSCertList_revokedCertificates_SEQOF, userCertificate, _, _}, acc ->
  #           Map.put(acc, userCertificate, nil)
  #         end)
  #
  #       newUrls = Map.put(urls, url, {nextUpdate, revokedSerialNumbers})
  #       newTimers = Map.put(timers, url, tref)
  #       {newUrls, newTimers}
  #     else
  #       error ->
  #         Logger.error("Error processig CRL: #{url} :: #{error}")
  #         state
  #     end
  #   end
  #
  #
  #
  #   def get_revoked_status(url, timeout \\ 1000) do
  #     GenServer.call(__MODULE__, {:revoked?, url}, timeout)
  #   end
  #
  #   # API
  #   def revoked?(url, serialNumber) do
  #     serialNumber =
  #       serialNumber
  #       |> String.upcase()
  #       |> Base.decode16!()
  #       |> :binary.decode_unsigned()
  #
  #     with {nextUpdate, revokedList} <- get_revoked_status(url),
  #          :gt <- DateTime.compare(nextUpdate, DateTime.utc_now()) do
  #       case revokedList do
  #         %{^url => %{^serialNumber => _}} ->
  #           true
  #
  #         %{^url => _} ->
  #           false
  #       end
  #     else
  #       error when error in ~w(nil lt eq)a ->
  #         send(__MODULE__, {:update, url})
  #         true
  #
  #       error ->
  #         Logger.error("Error get revoked status for #{url}:#{serialNumber} :: #{error}")
  #         true
  #     end
  #   end

  def parse_crl(data) do
    with {CertificateList, {TBSCertList, _, _, _, _, nextUpdateTs, revokedCertificates, _}, _, _} <-
           :public_key.der_decode(:CertificateList, data) do
      nextUpdate = convert_date(nextUpdateTs)

      revokedSerialNumbers =
        Enum.reduce(revokedCertificates, [], fn {TBSCertList_revokedCertificates_SEQOF, userCertificate, _, _},
                                                serialNumbers ->
          [userCertificate | serialNumbers]
        end)

      {nextUpdate, revokedSerialNumbers}
    end
  end

  def update_crl(url) do
    with {:ok, %HTTPoison.Response{status_code: 200, body: data}} <- HTTPoison.get(url),
         {nextUpdate, serialNumbers} <- parse_crl(data) do
      CrlApi.update_serials(url, nexUpdate, serialNumbers)
    else
      error ->
        Logger.error("Error update crl #{url} in state :: #{error}")
    end
  end

  # API

  def revoked?(url, serialNumber) do
    serialNumber =
      serialNumber
      |> String.upcase()
      |> Base.decode16!()
      |> :binary.decode_unsigned()

    case CrlApi.get_url(url) do
      %Crl{next_update: nextUpdate} ->
        case DateTime.compare(nextUpdate, DateTime.utc_now()) do
          :gt ->
            case CrlApi.get_serial(url, serialNumber) do
              nil -> false
              %RevokedSN{} -> true
            end

          _ ->
            # TODO: add url into db
            true
        end

      _ ->
        # TODO: add url into db
        true
    end
  end
end
