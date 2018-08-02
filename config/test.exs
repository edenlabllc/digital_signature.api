use Mix.Config

# General application configuration
config :digital_signature_api, api_resolvers: [nif_service: NifServiceMock]

# Configuration for test environment
config :ex_unit, capture_log: true

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :digital_signature_api, DigitalSignature.Web.Endpoint,
  http: [port: 4001],
  server: true

# Print only warnings and errors during test
config :logger, level: :warn

# Run acceptance test in concurrent mode
config :digital_signature_api, sql_sandbox: true

# Configure your database
config :digital_signature_api, DigitalSignature.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "digital_signature_api_test",
  hostname: System.get_env("DB_HOST"),
  pool: Ecto.Adapters.SQL.Sandbox,
  ownership_timeout: 120_000_000

# Configure crl scheduler
# config :digital_signature_api, DigitalSignature.CrlService, preload_crl: ~w(
#     http://uakey.com.ua/list.crl
#     http://uakey.com.ua/list-delta.crl
#
#     http://acsk.privatbank.ua/crldelta/PB-Delta-S9.crl
#     http://acsk.privatbank.ua/crl/PB-S9.crl
#
#     http://acskidd.gov.ua/download/crls/CA-20B4E4ED-Full.crl
#     http://acskidd.gov.ua/download/crls/CA-20B4E4ED-Delta.crl
#     )
