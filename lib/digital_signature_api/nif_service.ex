defmodule DigitalSignature.NifService do
  @moduledoc false
  use GenServer
  alias DigitalSignature.CrlService
  alias DigitalSignature.SignedData
  alias DigitalSignature.Cert.API, as: CertAPI
  require Logger

  @call_response_threshold 100

  # Callbacks
  def init(certs_cache_ttl) do
    certs = CertAPI.get_certs_map()
    Process.send_after(self(), :refresh, certs_cache_ttl)

    {:ok, {certs_cache_ttl, certs}}
  end

  def handle_call(
        {:process_signed_content, signed_content, signed_data, check, expires_at},
        _from,
        {certs_cache_ttl, certs}
      ) do
    processing_result =
      if NaiveDateTime.compare(expires_at, NaiveDateTime.utc_now()) == :gt do
        check = unless is_boolean(check), do: true
        nif_process_signed_content(signed_content, signed_data, certs, check)
      else
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
    IO.inspect(certificates_info)

    Enum.all?(certificates_info, fn cert_info ->
      %{delta_crl: deltaCrl, serial_number: serialNumber, crl: crl} = cert_info

      with {:ok, false} <- CrlService.revoked(crl, serialNumber),
           {:ok, false} <- CrlService.revoked(deltaCrl, serialNumber),
           {:ok, revoked?} <- ocsp_response(cert_info, timeout) do
        revoked?
      else
        {:ok, true} ->
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
      {:ok, %HTTPoison.Response{status_code: 200, body: _body}} ->
        # TODO: asn.1 decode
        # {ok, {_, _, {_,T, R}}} = 'OCSP':decode('OCSPResponse', Data)
        # 'OCSP':decode('OCSPResponse', R)
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
    timeout = Confex.fetch_env!(:digital_signature_api, :nif_service_call_timeout)
    ocs_timeout = Confex.fetch_env!(:digital_signature_api, :ocs_timeout)

    expires_at = NaiveDateTime.add(NaiveDateTime.utc_now(), timeout - @call_response_threshold, :millisecond)
    params = %{check: check, expires_at: expires_at, ocs_timeout: ocs_timeout, timeout: timeout}

    retrive_signed_data(signed_content, SignedData.new(), params)
  end

  defp retrive_signed_data(signed_content, signed_data, params) do
    %{check: check, expires_at: expires_at, ocs_timeout: ocs_timeout, timeout: timeout} = params

    try do
      nif_responce =
        GenServer.call(__MODULE__, {:process_signed_content, signed_content, signed_data, check, expires_at}, timeout)

      case nif_responce do
        {:ok, data} ->
          {:ok, SignedData.get_map(data)}

        {:ok, data, certificates_info} ->
          if provider_cert?(certificates_info, ocs_timeout) do
            retrive_signed_data(data.content, SignedData.update(signed_data, data), params)
          else
            data =
              data
              |> Map.put(:is_valid, false)
              |> Map.put(:validation_error_message, "OCSP certificate verificaton failed")

            {:ok, SignedData.get_map(SignedData.update(signed_data, data))}
          end

        {:error, {:n, n}} ->
          signed_data_error = SignedData.add_sign_error(signed_data, "envelope contains #{n} signatures instead of 1")
          {:ok, SignedData.get_map(signed_data_error)}

        error ->
          error
      end
    catch
      :exit, {:timeout, error} ->
        Logger.info("NifService call timeout")
        {:error, {:nif_service_timeout, error}}
    end
  end
end
