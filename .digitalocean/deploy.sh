#!/bin/bash

curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

git clone https://github.com/Sylius/SyliusSalesDemo.git

cd SyliusSalesDemo || exit

#docker compose -f docker-compose.prod.yml up -d
docker compose up -d
