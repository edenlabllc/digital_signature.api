#!/bin/bash

docker build -t mixtest -f Dockerfile.test .

docker run -it -v "$(pwd)":/home/DIGITAL_SIGNATURE.API mixtest:latest /bin/bash -c  \
"service postgresql start; cd /home/DIGITAL_SIGNATURE.API; mix do local.hex --force, local.rebar --force, deps.get; mix test; bash"
