#!/bin/bash

# Runs the app in Docker container.

docker run --rm -e TZ="Europe/Helsinki" -v $PWD:/code sheet-to-cal
if [ $? -ne 0 ]; then
  echo "Make sure you have built Docker image:"
  echo "docker build -t sheet-to-cal ."
fi
