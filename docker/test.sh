#!/bin/sh
set -e

readonly timeout=600
readonly sleep_time=10

i=1
time=$((timeout * sleep_time))

until curl -L --fail http://localhost:80 2>/dev/null
do
    i=$((i+1))

    if [ "${i}" -gt "${timeout}" ]; then

        echo "Sylius Store was never created, aborting due to ${time}s timeout!"
        exit 1
    else
        echo "Sylius Store did not response"
    fi

    sleep $sleep_time
done
