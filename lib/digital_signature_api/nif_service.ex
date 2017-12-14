defmodule DigitalSignature.NifService do
  @moduledoc false
  use GenServer
  alias DigitalSignature.Cert.API, as: CertAPI

  @max_response_time 60_000

  # Callbacks
  def init(ttl_seconds) do
    {:ok, {CertAPI.get_certs_map(), NaiveDateTime.utc_now(), ttl_seconds}}
  end

  def handle_call({:process, signed_data, check}, _from, {certs, certs_time, ttl_seconds}) do
    {certs, certs_time} =
      if NaiveDateTime.compare(certs_time, NaiveDateTime.utc_now()) != :lt do
        {certs, certs_time}
      else
        {CertAPI.get_certs_map(), NaiveDateTime.add(certs_time, ttl_seconds)}
      end

    check =
      case check do
        false -> 0
        _ -> 1
      end

    result = DigitalSignatureLib.processPKCS7Data(signed_data, certs, check)

    {:reply, result, {certs, certs_time, ttl_seconds}, :hibernate}
  end

  # Client
  def start_link(ttl_seconds) do
    GenServer.start_link(__MODULE__, ttl_seconds, name: __MODULE__)
  end

  def process_signed_data(signed_data, check) do
    GenServer.call(__MODULE__, {:process, signed_data, check}, @max_response_time)
  end
end
