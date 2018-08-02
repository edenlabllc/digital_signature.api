# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for
# 3rd-party users, it should be done in your "mix.exs" file.

# You can configure for your application as:
#
#     config :digital_signature_api, key: :value
#
# And access this configuration in your application as:
#
#     Application.get_env(:digital_signature_api, :key)
#
# Or configure a 3rd-party app:
#
#     config :logger, level: :info
#
# Or read environment variables in runtime (!) as:
#
#     :var_name, "${ENV_VAR_NAME}"
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
config :digital_signature_api,
  ecto_repos: [DigitalSignature.Repo],
  namespace: DigitalSignature,
  certs_cache_ttl: {:system, :integer, "CERTS_CACHE_TTL", 30 * 60 * 1000},
  service_call_timeout: {:system, :integer, "SERVICE_CALL_TIMEOUT", 5000},
  ocs_timeout: {:system, :integer, "OCS_CALL_TIMEOUT", 1000},
  api_resolvers: [nif_service: DigitalSignature.NifService]

# Configures the endpoint
config :digital_signature_api, DigitalSignature.Web.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "kM4g3grYc77xl0Zglf381h8g6EgOBSH18TbWwMB1UCdWHxFFkIZcF8Ci3w9ZtLCF",
  render_errors: [view: EView.Views.PhoenixError, accepts: ~w(json)]

# Configures Elixir's Logger
config :logger, :console,
  format: "$message\n",
  handle_otp_reports: true,
  level: :info

config :phoenix, :format_encoders, json: Jason

# Configure crl api
config :digital_signature_api, DigitalSignature.CrlApi, sn_chunk_limit: 20000

# Configure crl scheduler
config :digital_signature_api, DigitalSignature.CrlService,
  crl_process_timeout: 6000,
  crl_outdayted_days: 14,
  preload_crl: ~w(
    http://uakey.com.ua/list.crl
    http://uakey.com.ua/list-delta.crl

    http://acsk.privatbank.ua/crldelta/PB-Delta-S9.crl
    http://acsk.privatbank.ua/crl/PB-S9.crl

    http://acskidd.gov.ua/download/crls/CA-20B4E4ED-Full.crl
    http://acskidd.gov.ua/download/crls/CA-20B4E4ED-Delta.crl

    https://ca.informjust.ua/download/crls/CA-E7E53376-Delta.crl
    https://ca.informjust.ua/download/crls/CA-AD24A7C9-Delta.crl
    https://ca.informjust.ua/download/crls/CA-9A15A67B-Delta.crl
    https://ca.informjust.ua/download/crls/CA-5358AA45-Delta.crl
    https://ca.informjust.ua/download/crls/CA-AD24A7C9-Full.crl
    https://ca.informjust.ua/download/crls/CA-5358AA45-Full.crl
    https://ca.informjust.ua/download/crls/CA-9A15A67B-Full.crl
    https://ca.informjust.ua/download/crls/CA-E7E53376-Full.crl

    http://canbu.bank.gov.ua/download/crls/CANBU-RSA-2018-Delta.crl
    http://canbu.bank.gov.ua/download/crls/CANBU-DSTU-2017-Delta.crl
    http://canbu.bank.gov.ua/download/crls/CANBU-RSA-2018-Full.crl
    http://canbu.bank.gov.ua/download/crls/CANBU-DSTU-2017-Full.crl

    https://csk.uss.gov.ua/download/crls/CSKUSS2017-Full.crl
    https://csk.uss.gov.ua/download/crls/CSKUSS2017-Delta.crl
    https://csk.uss.gov.ua/download/crls/CSKUSS-Full.crl
    https://csk.uss.gov.ua/download/crls/CSKUSS-Delta.crl

    https://www.masterkey.ua/ca/crls/CA-4E6929B9-Delta.crl
    https://www.masterkey.ua/ca/crls/CA-4E6929B9-Full.crl
    https://www.masterkey.ua/ca/crls/CA-F3E31D2E-Delta.crl
    https://www.masterkey.ua/ca/crls/CA-F3E31D2E-Full.crl

    http://ca.ksystems.com.ua/download/crls/CA-B4F39E7B-Delta.crl
    http://ca.ksystems.com.ua/download/crls/CA-568D7635-Delta.crl
    http://ca.ksystems.com.ua/download/crls/CA-568D7635-Full.crl
    http://ca.ksystems.com.ua/download/crls/CA-B4F39E7B-Full.crl

    http://csk.uz.gov.ua/download/crls/CA-5FA2C5F8-Delta.crl
    http://csk.uz.gov.ua/download/crls/CA-5FA2C5F8-Full.crl
    http://csk.uz.gov.ua/download/crls/CA-59FB69AB-Delta.crl
    http://csk.uz.gov.ua/download/crls/CA-59FB69AB-Full.crl
    http://csk.uz.gov.ua/download/crls/CA-957791B9-Delta.crl
    http://csk.uz.gov.ua/download/crls/CA-957791B9-Full.crl

    http://www.acsk.er.gov.ua/download/crls/CA-Delta.crl
    http://www.acsk.er.gov.ua/download/crls/CA-Full.crl

    http://csk.ukrsibbank.com/download/crls/CA-22335CCC-Delta.crl
    http://csk.ukrsibbank.com/download/crls/CA-22335CCC-Full.crl
    http://csk.ukrsibbank.com/download/crls/CA-7B092570-Delta.crl
    http://csk.ukrsibbank.com/download/crls/CA-C718722D-Delta.crl
    http://csk.ukrsibbank.com/download/crls/CA-7B092570-Full.crl
    http://csk.ukrsibbank.com/download/crls/CA-C718722D-Full.crl
    http://csk.ukrsibbank.com/download/crls/CA-DC220F4D-Delta.crl
    http://csk.ukrsibbank.com/download/crls/CA-DC220F4D-Full.crl

    http://ca.mvs.gov.ua/download/crls/CA-C1CDBEF7-Delta.crl
    http://ca.mvs.gov.ua/download/crls/CA-C1CDBEF7-Full.crl
)

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#
import_config("#{Mix.env()}.exs")
