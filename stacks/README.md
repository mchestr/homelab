# HomeLab Stacks

## Scripts

### init.sh

This script will createh the initial Docker overlay networks and NFS directories.

### gen-secrets.sh

This script will generate the secrets directory which is used to provision the stacks secret values that are not committed.


## Configs

### postgres_init.sh

This script will generate the grafana user in postgres used to save grafana settings.

### telegraf.conf

This is the telegraf configuration file used to provision the telegraf Docker container


## Stacks

### database-stack.yaml

#### Services

- [InfluxDB](https://hub.docker.com/_/influxdb)
    - Must be on Manager (Pi3) since no image exists for arm32v6
    - NFS mount on Manager used for data
- [Postgres](https://hub.docker.com/r/arm32v6/postgres/) 
    - Can be deployed on any Pi
    - NFS mount on Manager for data
    
### grafana-stack.yaml

#### Services

- [Grafana](https://hub.docker.com/r/grafana/grafana/)
    - Must be on Manager (Pi3) since no image exists for arm32v6
    - Postgres used for data
    - `https` Access at `https://192.168.1.30/grafana`

### ingress-stack.yaml

#### Services

- [Docker Flow Proxy](https://hub.docker.com/r/dockerflow/docker-flow-proxy/)
    - Uses custom built arm32v6 image in `../dockerfiles/docker-flow-proxy` directory
    - Based on HAProxy and acts as an ingress gateway and will terminate TLS for services in the stack
    - Allows dynamic registration of services based on Docker Swarm service labels
- [Docker Flow Swarm Listener](https://hub.docker.com/r/dockerflow/docker-flow-swarm-listener)
    - Must be on Manager (Pi3) since it requires the docker.sock
    - Dynamically registers services on the ingress proxy
    
### mqtt-stack.yaml

#### Services

- [Mosquitto](https://hub.docker.com/_/eclipse-mosquitto)
    - provides MQTT
    - `mqtt` Access at `https://192.168.1.30:1883`
    - `mqtts` Access at `https://192.168.1.30:8883`
    
### portainer-stack.yaml

#### Services

- [Portainer](https://hub.docker.com/r/portainer/portainer/)
    - Must be on Manager (Pi3) since no image exists for arm32v6
    - Provides nice management GUI for Docker Swarm
    - `https` Access at `https://192.168.1.30/portainer`
    
    
### telegraf-stack.yaml

#### Services

- [Telegraf](https://hub.docker.com/_/telegraf)
    - Must be on Manager (Pi3) since no image exists for arm32v6
    - Configured to listen on MQTT and write data to influxDB

