#!/bin/bash

# Get Sales Demo droplets without the latest one
droplets=$(doctl compute droplet list --tag-name sylius-sales-demo --format ID | sed 1,2d)

for i in $droplets; do

    # Remove droplet
    doctl compute droplet delete "$i" --force

    echo "Removed droplet with id $i"
done
