#!/bin/bash
# This script starts a local Docker container with created image.

# Find mix.exs inside project tree.
# This allows to call bash scripts within any folder inside project.
PROJECT_DIR=$(git rev-parse --show-toplevel)
if [ ! -f "${PROJECT_DIR}/mix.exs" ]; then
    echo "[E] Can't find '${PROJECT_DIR}/mix.exs'."
    echo "    Check that you run this script inside git repo or init a new one in project root."
fi

# Extract project name and version from mix.exs
PROJECT_NAME=$(sed -n 's/.*app: :\([^, ]*\).*/\1/pg' "${PROJECT_DIR}/mix.exs")
PROJECT_VERSION=$(sed -n 's/.*@version "\([^"]*\)".*/\1/pg' "${PROJECT_DIR}/mix.exs")

echo "[I] Starting a Docker container '${PROJECT_NAME}' (version '${PROJECT_VERSION}') from path '${PROJECT_DIR}'.."

docker run -p 4000:4000 \
       --env-file .env \
       -d \
       --net ${DOCKER_NET} \
       --name ${PROJECT_NAME} \
       "${PROJECT_NAME}:${PROJECT_VERSION}"
sleep 5

# Check if a local Docker container with created image started succesfully.
docker logs ${PROJECT_NAME} --details --since 5h;

IS_RUNNING=$(docker inspect --format='{{ .State.Running }}' ${PROJECT_NAME});

if [ -z "$IS_RUNNING" ] || [ $IS_RUNNING != "true" ]; then
  echo "[E] Container is not started.";
  exit 1;
else
  docker stop ${PROJECT_NAME}
  docker rm ${PROJECT_NAME}
fi;
