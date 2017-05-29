use Mix.Releases.Config,
  default_release: :default,
  default_environment: :default

cookie = :sha256
|> :crypto.hash(System.get_env("ERLANG_COOKIE") || "6pZjwYjfjQE+rJVD1eWEthCfUlWcpL2fye7VNOt1LQVRhGmmTWe9LjykbbuMXIfB")
|> Base.encode64

environment :default do
  set pre_start_hook: "bin/hooks/pre-start.sh"
  set dev_mode: false
  set include_erts: false
  set include_src: false
  set cookie: cookie
end

release :digital_signature_api do
  set version: current_version(:digital_signature_api)
  set applications: [
    digital_signature_api: :permanent
  ]
end
