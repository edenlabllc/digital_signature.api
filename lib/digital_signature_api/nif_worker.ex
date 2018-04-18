defmodule DigitalSignature.NifWorker do
  @moduledoc false
  use GenServer
  alias DigitalSignature.CertCache

  # Callbacks
  def init(_) do
    {:ok, nil}
  end

  def handle_call({:process_signed_data, signed_data, check}, _from, nil) do
    check = unless is_boolean(check), do: true
    {:ok, certs} = CertCache.get_certs()

    result = DigitalSignatureLib.processPKCS7Data(signed_data, certs, check)

    {:reply, result, nil, :hibernate}
  end

  # Client
  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, [])
  end
end
