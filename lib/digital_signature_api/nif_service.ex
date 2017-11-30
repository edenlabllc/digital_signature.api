defmodule DigitalSignature.NifService do
  @moduledoc false
  use GenServer
  alias DigitalSignature.Cert.API, as: CertAPI

  # Callbacks
  def init(ttl_seconds) do
    certs = CertAPI.get_certs_map()
    {:ok, {certs, NaiveDateTime.add(NaiveDateTime.utc_now(), ttl_seconds, :seconds)}}
  end

  def handle_call({:process, signed_data, check}, _from, {certs, ttl}) do
    signed_data_list = :binary.bin_to_list(signed_data)
    certs = if NaiveDateTime.compare(ttl, NaiveDateTime.utc_now()) != :gt, do: certs, else: CertAPI.get_certs_map()
    check =
      case check do
        false -> 0
        _ -> 1
      end

    result = DigitalSignatureLib.processPKCS7Data(signed_data_list, certs, check)

    {:reply, result, :hibernate}
  end

  # Client
  def start_link(ttl_seconds) do
    GenServer.start_link(__MODULE__, ttl_seconds, name: __MODULE__)
  end

  def process_signed_data(signed_data, check) do
    GenServer.call(__MODULE__, {:process, signed_data, check})
  end
end
