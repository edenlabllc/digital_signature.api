defmodule DigitalSignature do
  @moduledoc """
  This is an entry point of digital_signature application.
  """
  use Application
  alias DigitalSignature.Web.Endpoint
  alias Confex.Resolver
  alias DigitalSignature.CertCache

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    # Define workers and child supervisors to be supervised
    children = [
      # Start the Ecto repository
      supervisor(DigitalSignature.Repo, []),
      # Start the endpoint when the application starts
      supervisor(DigitalSignature.Web.Endpoint, []),
      # Starts a worker by calling: DigitalSignature.Worker.start_link(arg1, arg2, arg3)
      # worker(DigitalSignature.Worker, [arg1, arg2, arg3]),
      worker(DigitalSignature.CertCache, [CertCache.certs_ttl()]),
      worker(DigitalSignature.NifService, [])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: DigitalSignature.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    Endpoint.config_change(changed, removed)
    :ok
  end

  # Loads configuration in `:init` callbacks and replaces `{:system, ..}` tuples via Confex
  @doc false
  def init(_key, config) do
    Resolver.resolve(config)
  end
end
