#!/bin/bash

docker build -t digital_signature_api_test -f Dockerfile.test .

docker run --rm -i -t digital_signature_api_test:latest

