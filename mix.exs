defmodule DigitalSignature.Mixfile do
  use Mix.Project

  @version "1.56.0"

  def project do
    [
      app: :digital_signature_api,
      description: "This api allows to validate pkcs7 data and get unpacked data with signer information from it.",
      package: package(),
      version: @version,
      elixir: "~> 1.5",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix] ++ Mix.compilers(),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [coveralls: :test],
      docs: [source_ref: "v#\{@version\}", main: "readme", extras: ["README.md"]]
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [
      extra_applications: [
        :logger,
        :confex,
        :runtime_tools,
        :jason,
        :cowboy,
        :httpoison,
        :ecto,
        :postgrex,
        :phoenix,
        :phoenix_pubsub,
        :eview,
        :runtime_tools
      ],
      mod: {DigitalSignature, []}
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # To depend on another app inside the umbrella:
  #
  #   {:myapp, in_umbrella: true}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:distillery, "~> 1.5", runtime: false},
      {:confex, "~> 3.3"},
      {:ecto, "~> 2.2"},
      {:cowboy, "~> 1.1"},
      {:httpoison, "~> 0.13.0"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix, "~> 1.3"},
      {:eview, "~> 0.12.0"},
      {:plug_logger_json, "~> 0.5"},
      {:ecto_logger_json, "~> 0.1"},
      {:excoveralls, ">= 0.5.0", only: [:dev, :test]},
      {:jvalid, "~> 0.6.0"},
      {:digital_signature_lib,
       git: "https://github.com/edenlabllc/digital_signature.lib.git", branch: "link_shared_uacrypto_library"},
      {:credo, "~> 0.9.1", only: [:dev, :test]},
      {:jason, "~> 1.0"},
      {:poolboy, "~> 1.5"}
    ]
  end

  # Settings for publishing in Hex package manager:
  defp package do
    [
      contributors: ["edenlab"],
      maintainers: ["edenlab"],
      licenses: ["LISENSE.md"],
      links: %{github: "https://github.com/edenlabllc/digital_signature.api"},
      files: ~w(lib LICENSE.md mix.exs README.md)
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to create, migrate and run the seeds file at once:m
  #
  #     $ mix ecto.setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate", "test"]
    ]
  end
end
