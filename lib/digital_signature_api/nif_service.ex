defmodule DigitalSignature.NifService do
  @moduledoc false
  use GenServer
  alias DigitalSignature.CertCache

  # Callbacks
  def init(_) do
    {:ok, nil}
  end

  def handle_call({:process_signed_content, signed_content, check}, _from, nil) do
    check = unless is_boolean(check), do: true
    {:ok, certs} = CertCache.get_certs()

    result = DigitalSignatureLib.processPKCS7Data(signed_content, certs, check)

    {:reply, result, nil, :hibernate}
  end

  # Client
  def start_link do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def process_signed_content(signed_content, check) do
    GenServer.call(__MODULE__, {:process_signed_content, signed_content, check})
  end
end
