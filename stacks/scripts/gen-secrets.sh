#!/bin/bash
SECRET_DIR=../secrets

if [[ -d "${SECRET_DIR}" ]]; then
    echo "secrets directory already exists, nothing to do."
    exit 0;
fi;
mkdir ${SECRET_DIR}

echo "Generate Docker Secrets..."
SECRETS=("grafana_admin_user" "grafana_admin_password" "postgresql_db" "postgresql_user" "postgresql_password" "postgresql_grafana_user" "postgresql_grafana_password" "smtp_host" "smtp_email" "smtp_password");
for secret in "${SECRETS[@]}"; do
    echo "$secret=";
    read -r value;
    echo "$value" >> "${SECRET_DIR}/${secret}";
done;

echo "Generate Environment Secrets..."
ENV_SECRETS=("INFLUXDB_ADMIN_USER" "INFLUXDB_ADMIN_PASSWORD" "INFLUXDB_TELEGRAF_USER" "INFLUXDB_TELEGRAF_PASSWORD" "MQTT_USERNAME" "MQTT_PASSWORD" "MQTT_BRIDGE_HOST" "MQTT_BRIDGE_USER" "MQTT_BRIDGE_PASSWORD" "CERT_COUNTRY" "CERT_STATE" "CERT_LOCATION" "CERT_ORGANIZATION" "CERT_ORGANIZATIONAL_UNIT" "CERT_COMMON_NAME")
for secret in "${ENV_SECRETS[@]}"; do
    echo "$secret=";
    read -r value;
    declare "$secret"="$value"
done;

echo "TRAEFIK_DASHBOARD_USER=";
read -r TRAEFIK_DASHBOARD_USER;
echo "TRAEFIK_DASHBOARD_PASSWORD=";
read -r TRAEFIK_DASHBOARD_PASSWORD;
TRAEFIK_DASHBOARD_CREDS="$(htpasswd -nb "${TRAEFIK_DASHBOARD_USER}" "${TRAEFIK_DASHBOARD_PASSWORD}")"

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

export TRAEFIK_DASHBOARD_CREDS='$TRAEFIK_DASHBOARD_CREDS'

export DOCKER_DOMAIN=$CERT_COMMON_NAME
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

echo "Generating certificates..."
CERT_DIR=${SECRET_DIR}/certs
mkdir ${CERT_DIR}

echo "Generate rootCA..."
openssl genrsa -des3 -out ${CERT_DIR}/rootCA.key 4096
openssl req -x509 -new -nodes -key ${CERT_DIR}/rootCA.key \
  -sha256 -days 1024 -out ${CERT_DIR}/rootCA.crt \
  -subj "/C=${CERT_COUNTRY}/ST=${CERT_STATE}/L=${CERT_LOCATION}/O=${CERT_ORGANIZATION}/OU=${CERT_ORGANIZATIONAL_UNIT}/CN=${CERT_COMMON_NAME}"

echo "Generate MQTT Cert..."
MQTT_CERT_DIR=${CERT_DIR}/mqtt
mkdir ${MQTT_CERT_DIR}
cat << EOF > ${MQTT_CERT_DIR}/san.cnf
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = ${CERT_COUNTRY}
ST = ${CERT_STATE}
L = ${CERT_LOCATION}
O = ${CERT_ORGANIZATION}
OU = ${CERT_ORGANIZATIONAL_UNIT}
CN = ${CERT_COMMON_NAME}

[v3_req]
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
[alt_names]
DNS.1 = mqtt.${CERT_COMMON_NAME}
EOF

openssl genrsa -out ${MQTT_CERT_DIR}/server.key 2048
openssl req -new -key ${MQTT_CERT_DIR}/server.key -out ${MQTT_CERT_DIR}/server.csr -config ${MQTT_CERT_DIR}/san.cnf
openssl req -in ${MQTT_CERT_DIR}/server.csr -noout -text
openssl x509 -req -in ${MQTT_CERT_DIR}/server.csr -CA ${CERT_DIR}/rootCA.crt -CAkey ${CERT_DIR}/rootCA.key -CAcreateserial -out ${MQTT_CERT_DIR}/server.crt -days 1000 -sha256 -extfile ${MQTT_CERT_DIR}/san.cnf -extensions v3_req
openssl x509 -in ${MQTT_CERT_DIR}/server.crt -text -noout
rm ${MQTT_CERT_DIR}/server.csr

echo "Generate Ingress Cert..."
INGRESS_CERT_DIR=${CERT_DIR}/ingress
mkdir ${INGRESS_CERT_DIR}
cat << EOF > ${INGRESS_CERT_DIR}/san.cnf
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = ${CERT_COUNTRY}
ST = ${CERT_STATE}
L = ${CERT_LOCATION}
O = ${CERT_ORGANIZATION}
OU = ${CERT_ORGANIZATIONAL_UNIT}
CN = ${CERT_COMMON_NAME}

[v3_req]
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
[alt_names]
DNS.1 = proxy.${CERT_COMMON_NAME}
DNS.2 = grafana.${CERT_COMMON_NAME}
DNS.3 = portainer.${CERT_COMMON_NAME}
DNS.4 = mqtt.${CERT_COMMON_NAME}
DNS.5 = dns.${CERT_COMMON_NAME}
DNS.6 = hass.${CERT_COMMON_NAME}
EOF

openssl genrsa -out ${INGRESS_CERT_DIR}/server.key 2048
openssl req -new -key ${INGRESS_CERT_DIR}/server.key -out ${INGRESS_CERT_DIR}/server.csr -config ${INGRESS_CERT_DIR}/san.cnf
openssl req -in ${INGRESS_CERT_DIR}/server.csr -noout -text
openssl x509 -req -in ${INGRESS_CERT_DIR}/server.csr -CA ${CERT_DIR}/rootCA.crt -CAkey ${CERT_DIR}/rootCA.key -CAcreateserial -out ${INGRESS_CERT_DIR}/server.crt -days 1000 -sha256 -extfile ${INGRESS_CERT_DIR}/san.cnf -extensions v3_req
openssl x509 -in ${INGRESS_CERT_DIR}/server.crt -text -noout
rm ${INGRESS_CERT_DIR}/server.csr
cat ${INGRESS_CERT_DIR}/server.crt ${INGRESS_CERT_DIR}/server.key >> ${INGRESS_CERT_DIR}/cert.pem
