# Digital Signature API
[![Build Status](https://api.travis-ci.org/Nebo15/digital_signature.api.svg?branch=master)](https://travis-ci.org/Nebo15/digital_signature.api) [![Coverage Status](https://coveralls.io/repos/github/Nebo15/digital_signature.api/badge.svg?branch=master)](https://coveralls.io/github/Nebo15/digital_signature.api?branch=master)

This api allows to validate pkcs7 data and get unpacked data with signer information from it.

## Specification

- [API docs](http://docs.ehealthapi1.apiary.io/#reference/internal.-digital-signature/verification/digital-signature)

## Installation

You can use official Docker container to deploy this service, it can be found on [nebo15/digital_signature_api](https://hub.docker.com/r/nebo15/digital_signature_api/) Docker Hub.

### Dependencies

- PostgreSQL 9.6 is used as storage back-end.
- Elixir 1.4
- Erlang/OTP 19.2
- [Digital Signature LIB](https://github.com/Nebo15/digital_signature.lib) is used for processing pkcs7 data.

## Configuration

See [ENVIRONMENT.md](docs/ENVIRONMENT.md).

## License

See [LICENSE.md](LICENSE.md).
