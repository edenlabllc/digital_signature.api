defmodule DigitalSignature.CrlService do
  @moduledoc false
  use GenServer
  use DigitalSignature.DateUtils
  require Logger

  alias DigitalSignature.CrlApi
  alias DigitalSignature.Crl
  alias DigitalSignature.RevokedSN

  # Callbacks

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_info({:check, url}, state) do
    case state do
      %{^url => _} ->
        :ok

      _ ->
        send(__MODULE__, {:update, url})
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:update, url}, state) do
    clean_timer(url, state)

    newState =
      with {:ok, nextUpdate} <- update_crl(url) do
        tref = Process.send_after(__MODULE__, {:update, url}, next_update_time(nextUpdate))
        Map.put(state, url, tref)
      else
        _ -> state
      end

    {:noreply, newState}
  end

  def start_link() do
    started = GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

    Enum.reduce(CrlApi.list_urls(), fn %Crl{url: url} -> send(__MODULE__, {:update, url}) end)
    started
  end

  def clean_timer(url, state) do
    with %{^url => tref} <- state do
      Process.cancel_timer(tref)
    end
  end

  def next_update_time(nextUpdate) do
    case DateTime.diff(nextUpdate, DateTime.utc_now(), :second) do
      n when n < 0 -> 0
      n -> n
    end
  end

  def parse_crl(data) do
    with {:CertificateList, {:TBSCertList, _, _, _, _, {:utcTime, nextUpdateTs}, revokedCertificates, _}, _, _} <-
           :public_key.der_decode(:CertificateList, data),
         {:ok, nextUpdate} <- convert_date(nextUpdateTs) do
      revokedSerialNumbers =
        Enum.reduce(revokedCertificates, [], fn {:TBSCertList_revokedCertificates_SEQOF, userCertificate, _, _},
                                                serialNumbers ->
          [userCertificate | serialNumbers]
        end)

      {nextUpdate, revokedSerialNumbers}
    end
  end

  def update_crl(url) do
    with {:ok, %HTTPoison.Response{status_code: 200, body: data}} <- HTTPoison.get(url),
         {nextUpdate, serialNumbers} <- parse_crl(data) do
      CrlApi.update_serials(url, nextUpdate, serialNumbers)
      {:ok, nextUpdate}
    else
      error ->
        IO.inspect(error)
        Logger.error(fn -> :io_lib.format("~nError update crl ~s :: ~p~n", [error]) end)
        {:error, url}
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
            send(__MODULE__, {:update, url})
            true
        end

      _ ->
        send(__MODULE__, {:update, url})
        true
    end
  end
end
