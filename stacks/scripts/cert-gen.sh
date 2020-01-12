#!/bin/bash

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
