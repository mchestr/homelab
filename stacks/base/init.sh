#!/bin/bash
sudo mkdir /nfs/portainer && sudo chmod 777 /nfs/portainer
echo "/nfs/portainer 172.19.181.0/24(rw,sync)" | sudo tee --append /etc/exports

sudo mkdir /nfs/grafana && sudo chmod 777 /nfs/grafana
echo "/nfs/grafana 172.19.181.0/24(rw,sync)" | sudo tee --append /etc/exports
sudo exportfs -a

docker network create -d overlay --attachable traefik-public
