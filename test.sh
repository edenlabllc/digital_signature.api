#!/bin/bash

echo "Create Docker network"
docker network create ds_test_net

echo "Run Postgres container"
POSTGRES_USER=postgres POSTGRES_PASSWORD=postgres docker run -d --name ds_test_db --net ds_test_net postgres:9.6

echo "Build App test image"
IMAGE=$(docker build -f Dockerfile.test . | tail -1 | awk '{ print $NF }')

echo "Run App test image"
docker run --rm -it --net ds_test_net $IMAGE /bin/bash -c 'cd /home/digital_signature.api; mix test'

# cleanup
echo "Cleanup..."
docker stop ds_test_db
docker rm ds_test_db

docker rmi $IMAGE

docker network rm ds_test_net
