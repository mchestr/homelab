#!/bin/bash

set -o xtrace

sudo apt install nfs-kernel-server apache2-utils

if [[ ! -f "./secrets/.secrets" ]]; then
  echo "./secrets/.secrets not found, run gen-secrets.sh first..."
  exit 1;
fi;
source ./secrets/.secrets

STACKS=${STACKS:-$(ls ./*stack.yaml)}
#declare -a NFS_DIRS=("${PORTAINTER_NFS_DIR}" "${HOMEASSISTANT_NFS_DIR}")
#declare -a NFS_DIRS_NRS=("${INFLUXDB_NFS_DIR}" "${POSTGRESQL_NFS_DIR}")
declare -a DOCKER_OVERLAY_NETWORKS=("proxy" "database" "portainer_agent")


poll_stack_status() {
  stack="${1}"
  delay="${2:-15}"
  end="$(($(date +%s) + delay))"

  while [ "$(date +%s)" -lt $end ]; do
    docker stack services "${stack}"
    sleep 1;
  done
}


create_nfs_directory() {
  dir="${1}"
  extra="${2}"

  options="rw,sync,no_subtree_check"
  if [[ "${extra}" != "" ]]; then
    options="${options},${extra}"
  fi

  sudo mkdir -p "${dir}" && sudo chmod 777 "${dir}"
  echo "${dir} 192.168.1.*(${options})" | sudo tee --append /etc/exports
  sudo exportfs -ra
}


create_docker_network() {
  name="${1}"
  docker network create -d overlay --attachable "${name}"
}


for dir in "${NFS_DIRS[@]}"; do
  if [[ ! -d "${dir}" ]]; then
    create_nfs_directory "${dir}"
  fi
done

for dir in "${NFS_DIRS_NRS[@]}"; do
  if [[ ! -d "${dir}" ]]; then
    create_nfs_directory "${dir}" "no_root_squash"
  fi
done

for network in "${DOCKER_OVERLAY_NETWORKS[@]}"; do
  if [[ "$(docker network list -f name="${network}" --format "{{ .Name }}" | wc -l)" -eq 0 ]]; then
    create_docker_network "${network}"
  fi
done

for stack in $STACKS; do
  # shellcheck disable=SC2116
  name="$(echo "${stack}" | cut -d- -f2)"

  echo "Deploying $name from $stack..."
  docker stack deploy --compose-file "${stack}" "${name}"
  poll_stack_status "${name}"
done
