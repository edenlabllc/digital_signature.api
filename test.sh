#!/bin/bash

echo "Create Docker network"
docker network create ds_test_db

echo "Run Postgres container"
POSTGRES_USER=postgres POSTGRES_PASSWORD=postgres docker run -d --name ds_test_db --net ds_test_db postgres:9.6

echo "Build App test image"
IMAGE=$(docker build -f Dockerfile.test . | tail -1 | awk '{ print $NF }')

echo "Run App test image"
docker run --rm -it --net ds_test_db $IMAGE /bin/bash -c 'cd /home/digital_signature.api; DB_HOST=ds_test_db mix test test/web/controllers/digital_signatures_controller_test.exs:186'

# cleanup
echo "Cleanup..."
docker stop ds_test_db
docker rm ds_test_db

docker rmi $IMAGE

docker network rm ds_test_db
