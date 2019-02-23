#!/bin/bash

declare -a dirs=("portainer")
for dir in "${dirs[@]}"; do
    sudo mkdir -p /nfs/${dir} && sudo chmod 777 /nfs/${dir}
    echo "/nfs/${dir} *(rw,sync,no_subtree_check)" | sudo tee --append /etc/exports
done;

declare -a dirs=("influxdb" "postgresql")
for dir in "${dirs[@]}"; do
    sudo mkdir -p /nfs/${dir} && sudo chmod 777 /nfs/${dir}
    echo "/nfs/${dir} *(rw,sync,no_subtree_check,no_root_squash)" | sudo tee --append /etc/exports
done;
sudo exportfs -ra

docker network create -d overlay --attachable proxy
docker network create -d overlay --attachable database
