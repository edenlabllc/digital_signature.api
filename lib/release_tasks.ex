defmodule DigitalSignature.ReleaseTasks do
  @moduledoc """
  Nice way to apply migrations inside a released application.
  Example:
      digital_signature_api/bin/digital_signature_api command Elixir.DigitalSignature.ReleaseTasks migrate!
  """
  alias Ecto.Migrator

  @start_apps [
    :logger,
    :postgrex,
    :ecto
  ]

  @apps [
    :digital_signature_api
  ]

  @repos [
    DigitalSignature.Repo
  ]

  def migrate! do
    IO.puts "Loading digital_signature_api.."
    # Load the code for digital_signature_api, but don't start it
    :ok = Application.load(:digital_signature_api)

    IO.puts "Starting dependencies.."
    # Start apps necessary for executing migrations
    Enum.each(@start_apps, &Application.ensure_all_started/1)

    # Start the Repo(s) for digital_signature_api
    IO.puts "Starting repos.."
    Enum.each(@repos, &(&1.start_link(pool_size: 1)))

    # Run migrations
    Enum.each(@apps, &run_migrations_for/1)

    # Run the seed script if it exists
    seed_script = seed_path(:digital_signature_api)
    if File.exists?(seed_script) do
      IO.puts "Running seed script.."
      Code.eval_file(seed_script)
    end

    # Signal shutdown
    IO.puts "Success!"
    :init.stop()
  end

  def priv_dir(app),
    do: :code.priv_dir(app)

  defp run_migrations_for(app) do
    IO.puts "Running migrations for #{app}"
    Enum.each(@repos, &Migrator.run(&1, migrations_path(app), :up, all: true))
  end

  defp migrations_path(app), do: Path.join([priv_dir(app), "repo", "migrations"])
  defp seed_path(app), do: Path.join([priv_dir(app), "repo", "seeds.exs"])
end
