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

  def handle_call({:process_signed_content, signed_content, check, message_exp_time}, _from, {certs_cache_ttl, certs}) do
    processing_result =
      if NaiveDateTime.compare(message_exp_time, NaiveDateTime.utc_now()) == :gt do
        check = unless is_boolean(check), do: true
        do_process_signed_content(signed_content, certs, check, SignedData.new())
      else
        Logger.info("NifService message queue timeout")
        {:error, {:nif_service_timeout, "messaqe queue timeout"}}
      end

    {:reply, processing_result, {certs_cache_ttl, certs}}
  end

  defp do_process_signed_content(signed_content, certs, check, %SignedData{} = signed_data) do
    case DigitalSignatureLib.checkPKCS7Data(signed_content) do
      {:ok, 1} ->
        with {:ok, processing_result} <- retrive_signed_content(signed_content, certs, check) do
          do_process_signed_content(
            processing_result.content,
            certs,
            check,
            SignedData.update(signed_data, processing_result)
          )
        end

      {:ok, n} ->
        signed_data_error = SignedData.add_sign_error(signed_data, "envelope contains #{n} signatures instead of 1")
        {:ok, SignedData.get_map(signed_data_error)}

      {:error, :signed_data_load} ->
        {:ok, SignedData.get_map(signed_data)}
    end
  end

  defp retrive_signed_content(signed_content, certs, check, timeout \\ 0) do
    with {:ok, data, ocsp_checklist} <- DigitalSignatureLib.retrivePKCS7Data(signed_content, certs, check),
         {:ocsp, true, data} <-
           {:ocsp,
            Enum.all?(ocsp_checklist, fn oscp_info ->
              IO.inspect(oscp_info)
              collect_crls(oscp_info)

              with {:ok, true} <- ocsp_response(oscp_info, timeout) do
                true
              else
                {:ok, :timeout} ->
                  crl_sertificate_valid?(oscp_info)

                _ ->
                  false
              end
            end), data} do
      {:ok, data}
    else
      {:ocsp, false, data} ->
        {:ok, %{data | is_valid: false, validation_error_message: "OCSP certificate verificaton failed"}}

      error ->
        error
    end
  end

  def collect_crls(%{delta_crl: delta_crl, crl: crl}) do
    send(CrlService, {:check, delta_crl})
    send(CrlService, {:check, crl})
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

      {:error, %HTTPoison.Error{reason: reason}} when reason in ~w(timeout connect_timeout)a ->
        {:ok, :timeout}

      _ ->
        {:error, :invalid}
    end
  end

  def crl_sertificate_valid?(%{delta_crl: deltaCrl, serial_number: serialNumber, crl: crl}) do
    CrlService.revoked?(crl, serialNumber) and CrlService.revoked?(deltaCrl, serialNumber)
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
    gen_server_timeout = Confex.fetch_env!(:digital_signature_api, :nif_service_call_timeout)

    message_exp_time =
      NaiveDateTime.add(NaiveDateTime.utc_now(), gen_server_timeout - @call_response_threshold, :millisecond)

    try do
      GenServer.call(__MODULE__, {:process_signed_content, signed_content, check, message_exp_time}, gen_server_timeout)
    catch
      :exit, {:timeout, error} ->
        Logger.info("NifService call timeout")
        {:error, {:nif_service_timeout, error}}
    end
  end
end
