#!/bin/bash

docker stack rm core
docker stack rm ingress

docker container prune
docker network prune
docker volume prune
