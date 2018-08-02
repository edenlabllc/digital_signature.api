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

    with {:ok, nextUpdate} <- update_crl(url) do
      tref = Process.send_after(__MODULE__, {:update, url}, next_update_time(nextUpdate))
      Map.put(state, url, tref)
    else
      _ -> state
    end
  end

  def start_link() do
    started = GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

    crl_urls()
    |> Enum.each(fn url ->
      try do
        GenServer.call(__MODULE__, {:update, url}, 60000)
        Logger.info("CRL #{url} successfully stored in database")
      catch
        _, reason ->
          IO.inspect(reason, label: 'reason call fail')
          send(__MODULE__, {:update, url})
          {:skip, url}
      end
    end)

    started
  end

  def crl_urls do
    config_urls =
      :ordsets.from_list(Confex.fetch_env!(:digital_signature_api, DigitalSignature.CrlService)[:preload_crl] || [])

    active_crls =
      CrlApi.list_urls()
      |> Enum.map(fn %Crl{url: url} -> url end)
      |> :ordsets.from_list()

    :ordsets.union([config_urls, active_crls])
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
    parsed =
      try do
        :public_key.der_decode(:CertificateList, data)
      catch
        error, reason ->
          {error, reason}
      end

    with {:CertificateList, {:TBSCertList, _, _, _, _, {:utcTime, nextUpdateTs}, revokedCertificates, _}, _, _} <-
           parsed,
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
        # fil this url for feature requests, with outdated nextUpdate
        CrlApi.write_url(url, Date.add(Date.utc_today(), -1))
        send(__MODULE__, {:update, url})
        {:error, reason}
    end
  end
end
