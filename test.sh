#!/bin/bash

mix do deps.clean --all, clean

docker build -t mixtest -f Dockerfile.test .

docker run --rm \
-it \
--mount type=bind,source="$(pwd)",target=/home/DIGITAL_SIGNATURE.API \
mixtest:latest \
/bin/bash -c \
"service postgresql start; \
cd /home/DIGITAL_SIGNATURE.API; \
MIX_ENV=test mix do local.hex --force, local.rebar --force, deps.get, deps.compile; \
mix test; \
bash"
