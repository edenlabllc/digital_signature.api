# Environment Variables

This environment variables can be used to configure released docker container at start time.
Also sample `.env` can be used as payload for `docker run` cli.

## General

| VAR_NAME      | Default Value           | Description |
| ------------- | ----------------------- | ----------- |
| ERLANG_COOKIE | `6pZjwYjfjQE`.. | Erlang [distribution cookie](http://erlang.org/doc/reference_manual/distributed.html). **Make sure that default value is changed in production.** |
| LOG_LEVEL     | `info` | Elixir Logger severity level. Possible values: `debug`, `info`, `warn`, `error`. |

## Phoenix HTTP Endpoint

| VAR_NAME          | Default Value | Description |
| ----------------- | ------------- | ----------- |
| APP_PORT          | `4000`        | HTTP host for web app to listen on. |
| APP_HOST          | `localhost`   | HTTP port for web app to listen on. |
| APP_SECRET_KEY    | `WVnVN9Rkn4zY`.. | Phoenix [`:secret_key_base`](https://hexdocs.pm/phoenix/Phoenix.Endpoint.html). **Make sure that default value is changed in production.** |

## Database

| VAR_NAME      | Default Value | Description |
| ------------- | ------------- | ----------- |
| DB_NAME       | `nil`         | Database name. |
| DB_USER       | `nil`         | Database user name. |
| DB_PASSWORD   | `nil`         | Database user password. |
| DB_HOST       | `nil`         | Database host. |
| DB_PORT       | `nil`         | Database port. |
| DB_MIGRATE    | `false`       | Flag to run migration. |

## Digital Signature LIB

| VAR_NAME                | Default Value | Description |
| ----------------------- | ------------- | ----------- |
| UACRYPTO_LIB_PATH       | `nil`         | Path to the libUACrypto.so file that is used by Digital Signature LIB. |
