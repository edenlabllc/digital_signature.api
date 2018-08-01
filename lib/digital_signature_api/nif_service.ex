defmodule DigitalSignature.NifService do
  @moduledoc false
  use GenServer
  alias DigitalSignature.CrlService
  alias DigitalSignature.SignedData
  alias DigitalSignature.Cert.API, as: CertAPI
  require Logger

  @call_response_threshold 100
  @nif_service Application.get_env(:digital_signature_api, :api_resolvers)[:nif_service]

  # Callbacks
  def init(certs_cache_ttl) do
    certs = CertAPI.get_certs_map()
    Process.send_after(self(), :refresh, certs_cache_ttl)

    {:ok, {certs_cache_ttl, certs}}
  end

  def handle_call(
        {:process_signed_content, signed_content, signed_data, check, message_exp_time},
        _from,
        {certs_cache_ttl, certs}
      ) do
    processing_result =
      if NaiveDateTime.compare(message_exp_time, NaiveDateTime.utc_now()) == :gt do
        check = unless is_boolean(check), do: true
        nif_process_signed_content(signed_content, signed_data, certs, check)
      else
        IO.inspect({message_exp_time, NaiveDateTime.utc_now()})
        Logger.info("NifService message queue timeout")
        {:error, {:nif_service_timeout, "messaqe queue timeout"}}
      end

    {:reply, processing_result, {certs_cache_ttl, certs}}
  end

  defp nif_process_signed_content(signed_content, signed_data, certs, check) do
    case DigitalSignatureLib.checkPKCS7Data(signed_content) do
      {:ok, 1} ->
        DigitalSignatureLib.retrivePKCS7Data(signed_content, certs, check)

      {:ok, n} ->
        {:error, {:n, n}}

      {:error, :signed_data_load} ->
        {:ok, signed_data}
    end
  end

  def provider_cert?(certificates_info, timeout) do
    Enum.all?(certificates_info, fn cert_info ->
      %{delta_crl: deltaCrl, serial_number: serialNumber, crl: crl} = cert_info
      send(CrlService, {:check, deltaCrl})
      send(CrlService, {:check, crl})

      with {:ok, true} <- @nif_service.ocsp_response(cert_info, timeout) do
        true
      else
        {:ok, :timeout} ->
          not (CrlService.revoked?(crl, serialNumber) and CrlService.revoked?(deltaCrl, serialNumber))

        _ ->
          false
      end
    end)
  end

  def ocsp_response(%{access: access, data: data}, timeout) do
    case HTTPoison.post(
           access,
           data,
           [{"Content-Type", "application/ocsp-request"}],
           timeout: timeout
         ) do
      {:ok, %HTTPoison.Response{status_code: 200}} ->
        {:ok, true}

      {:error, %HTTPoison.Error{reason: :connect_timeout}} ->
        {:ok, :timeout}

      _ ->
        {:error, :invalid}
    end
  end

  def handle_info(:refresh, {certs_cache_ttl, _certs}) do
    certs = CertAPI.get_certs_map()
    # GC
    :erlang.garbage_collect(self())

    Process.send_after(self(), :refresh, certs_cache_ttl)
    {:noreply, {certs_cache_ttl, certs}}
  end

  # Handle unexpected messages
  def handle_info(unexpected_message, certs) do
    super(unexpected_message, certs)
  end

  # Client
  def start_link(certs_cache_ttl) do
    GenServer.start_link(__MODULE__, certs_cache_ttl, name: __MODULE__)
  end

  def process_signed_content(signed_content, check) do
    retrive_signed_data(signed_content, SignedData.new(), check)
  end

  defp retrive_signed_data(signed_content, signed_data, check) do
    gen_server_timeout = Confex.fetch_env!(:digital_signature_api, :nif_service_call_timeout)

    message_exp_time =
      NaiveDateTime.add(NaiveDateTime.utc_now(), gen_server_timeout - @call_response_threshold, :millisecond)

    ocsp_call_timeout = Confex.fetch_env!(:digital_signature_api, :ocsp_call_timeout)

    try do
      nif_responce =
        GenServer.call(
          __MODULE__,
          {:process_signed_content, signed_content, signed_data, check, message_exp_time},
          gen_server_timeout
        )

      case nif_responce do
        {:ok, data} ->
          {:ok, SignedData.get_map(data)}

        {:ok, data, certificates_info} ->
          if provider_cert?(certificates_info, ocsp_call_timeout) do
            retrive_signed_data(data.content, SignedData.update(signed_data, data), check)
          else
            data =
              data
              |> Map.put(:is_valid, false)
              |> Map.put(:validation_error_message, "OCSP certificate verificaton failed")

            {:ok, SignedData.update(signed_data, data)}
          end

        {:error, {:n, n}} ->
          signed_data_error = SignedData.add_sign_error(signed_data, "envelope contains #{n} signatures instead of 1")
          {:ok, SignedData.get_map(signed_data_error)}
      end
    catch
      :exit, {:timeout, error} ->
        Logger.info("NifService call timeout")
        {:error, {:nif_service_timeout, error}}
    end
  end
end
