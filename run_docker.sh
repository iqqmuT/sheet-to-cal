#!/bin/bash
docker run --rm -it -e TZ="Europe/Helsinki" -v $PWD:/code sheet-to-cal
if [ $? -ne 0 ]; then
  echo "Make sure you have built Docker image:"
  echo "docker build -t sheet-to-cal ."
fi
