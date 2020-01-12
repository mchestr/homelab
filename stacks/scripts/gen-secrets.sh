#!/bin/bash
SECRET_DIR=../secrets

if [[ -d "${SECRET_DIR}" ]]; then
  source "${SECRET_DIR}"/.secrets
else
  mkdir ${SECRET_DIR}
fi;

echo "Generate Docker Secrets..."
SECRETS=("grafana_admin_user" "grafana_admin_password" "postgresql_db" "postgresql_user"
         "postgresql_password" "postgresql_grafana_user" "postgresql_grafana_password" "smtp_host"
         "smtp_email" "smtp_password");
for secret in "${SECRETS[@]}"; do
  if [[ ! -f "${SECRET_DIR}/${secret}" ]]; then
    echo "$secret=";
    read -r value;
    echo "$value" >> "${SECRET_DIR}/${secret}";
  else
    echo "${secret}=$(cat ${SECRET_DIR}/${secret})"
  fi;
done;

echo "Generate Environment Secrets..."
ENV_SECRETS=("INFLUXDB_ADMIN_USER" "INFLUXDB_ADMIN_PASSWORD" "INFLUXDB_TELEGRAF_USER"
             "INFLUXDB_TELEGRAF_PASSWORD" "MQTT_USERNAME" "MQTT_PASSWORD" "MQTT_BRIDGE_HOST"
             "MQTT_BRIDGE_USER" "MQTT_BRIDGE_PASSWORD" "SUBDOMAIN")
for secret in "${ENV_SECRETS[@]}"; do
  if [[ -z "${!secret}" ]]; then
    echo "$secret=";
    read -r value;
    declare "$secret"="$value"
  else
    echo "${secret}=$(printf '%s\n' "${!secret}")"
  fi;
done;

echo "Generate Traefik BasicAuth Credentials for Services..."
TRAEFIK_SERVICES=("PROXY" "PORTAINER" "PROMETHEUS")
for service in "${TRAEFIK_SERVICES[@]}"; do
  if [[ -z "TRAEFIK_${service}_CREDENTIALS" ]]; then
    echo "TRAEFIK_${service}_USERNAME=";
    read -r user;
    echo "TRAEFIK_${service}_PASSWORD=";
    read -r password;
    declare "TRAEFIK_${service}_CREDENTIALS"="$(htpasswd -nb ${user} ${password})";
  else
    env_var="TRAEFIK_${service}_CREDENTIALS";
    echo "${env_var}=$(printf '%s\n' "${!env_var}")"
  fi;
done;

SMTP_EMAIL=$(cat ${SECRET_DIR}/smtp_email)

cat << EOF > ${SECRET_DIR}/.secrets
#!/bin/bash

export INFLUXDB_ADMIN_USER=$INFLUXDB_ADMIN_USER
export INFLUXDB_ADMIN_PASSWORD=$INFLUXDB_ADMIN_PASSWORD
export INFLUXDB_TELEGRAF_USER=$INFLUXDB_TELEGRAF_USER
export INFLUXDB_TELEGRAF_PASSWORD=$INFLUXDB_TELEGRAF_PASSWORD

export MQTT_USERNAME=$MQTT_USERNAME
export MQTT_PASSWORD=$MQTT_PASSWORD
export MQTT_BRIDGE_HOST=$MQTT_BRIDGE_HOST
export MQTT_BRIDGE_USER=$MQTT_BRIDGE_USER
export MQTT_BRIDGE_PASSWORD=$MQTT_BRIDGE_PASSWORD

export TRAEFIK_PROXY_CREDENTIALS='$TRAEFIK_PROXY_CREDENTIALS'
export TRAEFIK_PORTAINER_CREDENTIALS='$TRAEFIK_PORTAINER_CREDENTIALS'
export TRAEFIK_PROMETHEUS_CREDENTIALS='$TRAEFIK_PROMETHEUS_CREDENTIALS'

export SMTP_EMAIL=$SMTP_EMAIL
export SUBDOMAIN=$SUBDOMAIN
export LOGGING_DRIVER=journald
export NFS_DIR=/nfs

export HOMEASSISTANT_NFS_DIR="${NFS_DIR}/homeassistant"
export PORTAINTER_NFS_DIR="${NFS_DIR}/portainer"
export INFLUXDB_NFS_DIR="${NFS_DIR}/influxdb"
export POSTGRESQL_NFS_DIR="${NFS_DIR}/postgresql"
EOF

echo "Generate Mosquitto Config..."
cat << EOF > ${SECRET_DIR}/mosquitto.conf
# Place your local configuration in /mqtt/config/conf.d/

pid_file /var/run/mosquitto.pid

persistence false
password_file /run/secrets/passwd
allow_anonymous false

user mosquitto

listener 8883

cafile /run/secrets/ca-cert.pem
keyfile /run/secrets/server.key
certfile /run/secrets/server.crt
tls_version tlsv1.2

# Port to use for the default listener.
listener 1883

log_dest stdout

connection bridge-1
address $MQTT_BRIDGE_HOST
bridge_cafile /etc/ssl/cert.pem
remote_username $MQTT_BRIDGE_USER
remote_password $MQTT_BRIDGE_PASSWORD
topic # in 0

EOF

if [[ ! -f "${SECRET_DIR}/passwd" ]]; then
  touch "${SECRET_DIR}/passwd"
  echo "Generating Mosquitto Users..."
  while true; do
      echo "Enter MQTT User [n to exit]: "
      read -r username;
      case ${username} in
          [nN]* ) break;;
      esac
      echo "Enter MQTT Password: "
      read -r password;
      echo "Generating passwd contents..."
      docker run -it --rm -v "$(pwd)/${SECRET_DIR}:/data" eclipse-mosquitto:latest mosquitto_passwd -b /data/passwd "${username}" "${password}"
  done
fi;
