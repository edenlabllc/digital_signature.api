defmodule DigitalSignature.NifService do
  @moduledoc false
  use GenServer
  alias DigitalSignature.SignedData
  alias DigitalSignature.Cert.API, as: CertAPI

  # Callbacks
  def init(certs_cache_ttl) do
    certs = CertAPI.get_certs_map()
    Process.send_after(self(), :refresh, certs_cache_ttl)

    {:ok, {certs_cache_ttl, certs}}
  end

  def handle_call({:process_signed_content, signed_content, check}, _from, {certs_cache_ttl, certs}) do
    check = unless is_boolean(check), do: true

    processing_result = do_process_signed_content(signed_content, certs, check, SignedData.new())
    {:reply, processing_result, {certs_cache_ttl, certs}}
  end

  defp do_process_signed_content(signed_content, certs, check, %SignedData{} = signed_data) do
    case DigitalSignatureLib.checkPKCS7Data(signed_content) do
      {:ok, 1} ->
        with {:ok, processing_result} <- DigitalSignatureLib.processPKCS7Data(signed_content, certs, check) do
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
    gen_server_timeout = Confex.fetch_env!(:digital_signature_api, :nif_service_timeout)

    try do
      GenServer.call(__MODULE__, {:process_signed_content, signed_content, check}, gen_server_timeout)
    catch
      :exit, {:timeout, error} ->
        {:error, {:nif_service_timeot, error}}
    end
  end
end
