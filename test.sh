#!/bin/bash

IMAGE=$(docker build -f Dockerfile.test . | tail -1 | awk '{ print $NF }')

docker run --rm -it $IMAGE /bin/bash -c 'service postgresql start; cd /home/digital_signature.api; mix test'

#docker rmi $IMAGE
