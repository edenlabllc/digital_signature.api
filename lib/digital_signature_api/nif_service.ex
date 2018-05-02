defmodule DigitalSignature.NifService do
  @moduledoc false
  use GenServer
  alias DigitalSignature.CertCache
  alias DigitalSignature.SignedData

  # Callbacks
  def init(_) do
    {:ok, nil}
  end

  def handle_call({:process_signed_content, signed_content, check}, _from, nil) do
    check = unless is_boolean(check), do: true
    {:ok, certs} = CertCache.get_certs()

    processing_result = do_process_signed_content(signed_content, certs, check, SignedData.new())
    {:reply, processing_result, nil, :hibernate}
  end

  defp do_process_signed_content(signed_content, certs, check, %SignedData{} = signed_data) do
    case DigitalSignatureLib.checkPKCS7Data(signed_content) do
      {:ok, _} ->
        with {:ok, processing_result} <- DigitalSignatureLib.processPKCS7Data(signed_content, certs, check) do
          do_process_signed_content(
            processing_result.content,
            certs,
            check,
            SignedData.update(signed_data, processing_result)
          )
        end

      {:error, :signed_data_load} ->
        {:ok, SignedData.get_map(signed_data)}
    end
  end

  # Client
  def start_link do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def process_signed_content(signed_content, check) do
    GenServer.call(__MODULE__, {:process_signed_content, signed_content, check})
  end
end
