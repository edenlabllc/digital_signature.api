defmodule DigitalSignature.NifService do
  @moduledoc false
  alias DigitalSignature.Poolboy

  def process_signed_data(signed_data, check) do
    :poolboy.transaction(Poolboy.pool_name(), fn worker ->
      GenServer.call(worker, {:process_signed_data, signed_data, check})
    end)
  end
end
