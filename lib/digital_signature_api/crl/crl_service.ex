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
  def handle_info({:update, url}, state) do
    newState = update_url_state(url, state)

    {:noreply, newState}
  end

  @impl true
  def handle_call({:update, url}, _from, state) do
    newState = update_url_state(url, state)

    {:reply, Map.has_key?(newState, url), newState}
  end

  def update_url_state(url, state) do
    clean_timer(url, state)

    newState =
      with {:ok, nextUpdate} <- update_crl(url) do
        tref = Process.send_after(__MODULE__, {:update, url}, next_update_time(nextUpdate))
        Map.put(state, url, tref)
      else
        _ -> state
      end
  end

  def start_link() do
    started = GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
    Enum.each(CrlApi.list_urls(), fn %Crl{url: url} -> send(__MODULE__, {:update, url}) end)
    started
  end

  def clean_timer(url, state) do
    case state do
      %{^url => nil} -> :ok
      %{^url => tref} -> Process.cancel_timer(tref)
      _ -> :ok
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
        Logger.error(fn -> :io_lib.format("~nError update crl ~s :: ~p~n", [url, error]) end)
        {:error, url}
    end
  end

  def check_revoked?(url, serialNumber) do
    case CrlApi.get_url(url) do
      %Crl{next_update: nextUpdate} ->
        case DateTime.compare(nextUpdate, DateTime.utc_now()) do
          :gt ->
            case CrlApi.get_serial(url, serialNumber) do
              nil -> {:ok, false}
              %RevokedSN{} -> {:ok, true}
            end

          _ ->
            {:error, :outdated}
        end

      _ ->
        {:error, :not_found}
    end
  end

  # API

  def revoked(url, serialNumber) do
    serialNumber =
      serialNumber
      |> String.upcase()
      |> Base.decode16!()
      |> :binary.decode_unsigned()

    case check_revoked?(url, serialNumber) do
      {:ok, _} = response ->
        response

      {:error, reason} ->
        # if url not found in db, we make update synchroniously only once
        # if it is not succesfull, we count certificate as revoked
        case GenServer.call(__MODULE__, {:update, url}) do
          true ->
            check_revoked?(url, serialNumber)

          _ ->
            send(__MODULE__, {:update, url})
            {:error, reason}
        end
    end
  end
end
