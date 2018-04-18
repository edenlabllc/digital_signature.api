defmodule DigitalSignature.Poolboy do
  def pool_name, do: :nif_pool

  def poolboy_config do
    [
      {:name, {:local, pool_name()}},
      {:worker_module, DigitalSignature.NifWorker},
      {:size, Confex.fetch_env!(:digital_signature_api, DigitalSignature.Poolboy)[:nif_workers]},
      {:max_overflow, 2}
    ]
  end
end
