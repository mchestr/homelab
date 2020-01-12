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
             "INFLUXDB_TELEGRAF_PASSWORD" "MQTT_USERNAME" "MQTT_PASSWORD" "SUBDOMAIN")
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
TRAEFIK_SERVICES=("PROXY" "PROMETHEUS")
for service in "${TRAEFIK_SERVICES[@]}"; do
  env_var="TRAEFIK_${service}_CREDENTIALS"
  if [[ -z "${!env_var}" ]]; then
    echo "TRAEFIK_${service}_USERNAME=";
    read -r user;
    echo "TRAEFIK_${service}_PASSWORD=";
    read -r password;
    declare "TRAEFIK_${service}_CREDENTIALS"="$(htpasswd -nb ${user} ${password})";
  else
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

export TRAEFIK_PROXY_CREDENTIALS='$TRAEFIK_PROXY_CREDENTIALS'
export TRAEFIK_PROMETHEUS_CREDENTIALS='$TRAEFIK_PROMETHEUS_CREDENTIALS'

export SMTP_EMAIL=$SMTP_EMAIL
export SUBDOMAIN=$SUBDOMAIN
export LOGGING_DRIVER=journald

EOF

echo "Generate Mosquitto Config..."
cat << EOF > ${SECRET_DIR}/mosquitto.conf
# Place your local configuration in /mqtt/config/conf.d/

pid_file /var/run/mosquitto.pid

persistence false
password_file /run/secrets/passwd
allow_anonymous false

user mosquitto

# Port to use for the default listener.
listener 1883

log_dest stdout

#connection bridge-1
#address $MQTT_BRIDGE_HOST
#bridge_cafile /etc/ssl/cert.pem
#remote_username $MQTT_BRIDGE_USER
#remote_password $MQTT_BRIDGE_PASSWORD
#topic # in 0

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

echo "Generate Home Assistant Secrets..."
ENV_SECRETS=("AUGUST_USERNAME" "AUGUST_PASSWORD" "GOOGLE_ASSISTANT_PROJECT_ID")
for secret in "${ENV_SECRETS[@]}"; do
  if [[ -z "${!secret}" ]]; then
    echo "$secret=";
    read -r value;
    declare "$secret"="$value"
  else
    echo "${secret}=$(printf '%s\n' "${!secret}")"
  fi;
done;

if [[ ! -d "${SECRET_DIR}/homeassistant" ]]; then
  mkdir "${SECRET_DIR}"/homeassistant
fi;

cat << EOF > ${SECRET_DIR}/homeassistant/secrets.yaml
---
august_username: "${AUGUST_USERNAME}"
august_password: "${AUGUST_PASSWORD}"
google_assistant_project_id: "${GOOGLE_ASSISTANT_PROJECT_ID}"
EOF
