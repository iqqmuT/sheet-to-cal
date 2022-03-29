#!/bin/bash

# Runs the app in Docker container.
# You can start this script by anacron.
# Note that stdout and stderr is redirected into a log file.

LOGFILE="/tmp/sheet-to-cal.log"
docker run --rm -e TZ="Europe/Helsinki" -v $PWD:/code sheet-to-cal > $LOGFILE 2>&1
if [ $? -ne 0 ]; then
  echo "Make sure you have built Docker image:"
  echo "docker build -t sheet-to-cal ."
fi
