#!/bin/bash

# Build the Docker image for FreeSWITCH
docker build -t freeswitch:latest ./docker

# Tag the image for the Docker repository
docker tag freeswitch:latest 176.9.65.80/freeswitch:latest

# Push the image to the Docker repository
docker push 176.9.65.80/freeswitch:latest