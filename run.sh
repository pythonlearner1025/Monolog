#!/bin/bash

# Navigate to the directory
cd /home/ubuntu/Monolog/backend

# Build the Docker image
docker build -t api .

# Kill the 'api' container if it's running
container_id=$(docker ps -aqf "name=api")
if [ ! -z "$container_id" ]; then
    # If the container is running, kill it
    docker ps -qf "name=api" | xargs -r docker kill

    # Remove the container
    docker rm $container_id
fi

# Run the new container
docker run --env-file=/home/ubuntu/Monolog/backend/.env -p 3000:3000 -d --name api api

