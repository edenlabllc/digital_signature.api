defmodule DigitalSignature.CertCache do
  @moduledoc false
  use GenServer
  alias DigitalSignature.Cert.API, as: CertAPI

  # Callbacks
  def init(cache_ttl) do
    certs = CertAPI.get_certs_map()
    Process.send_after(self(), {:reload_cache, cache_ttl}, cache_ttl)
    {:ok, certs}
  end

  def handle_call(:get_certs, _from, certs) do
    {:reply, certs, certs}
  end

  def handle_info({:reload_cache, cache_ttl}, _certs) do
    certs = CertAPI.get_certs_map()
    Process.send_after(self(), {:reload_cache, cache_ttl}, cache_ttl)
    {:noreply, certs}
  end

  # Handle unexpected messages
  def handle_info(unexpected_message, certs) do
    super(unexpected_message, certs)
  end

  # Client
  def start_link(cache_ttl) do
    GenServer.start_link(__MODULE__, cache_ttl, name: __MODULE__)
  end

  def get_certs do
    certs = GenServer.call(__MODULE__, :get_certs)
    {:ok, certs}
  end
end
