# HomeLab Stacks

## Secrets

Create a directory called `./secrets` and inside that directory create a file `.secrets`, add the 
following contents to the file and modify them to suit your deployment.

```bash
#!/bin/bash

# InfluxDB Settings
export INFLUXDB_ADMIN_USER=''
export INFLUXDB_ADMIN_PASSWORD=''
export INFLUXDB_TELEGRAF_USER=''
export INFLUXDB_TELEGRAF_PASSWORD=''

export SMTP_HOST=''
export SMTP_USER=''
export SMTP_PASSWORD=''
export SMTP_FROM=''

# Generate with http://www.htaccesstools.com/htpasswd-generator/
export TRAEFIK_DASHBOARD_CREDENTIALS=''
```

Create a `certs` directory inside `./secrets`. Generate a self-signed rootCA.
```bash
openssl genrsa -des3 -out rootCA.key 4096
openssl req -x509 -new -nodes -key rootCA.key -sha256 -days 1024 -out rootCA.crt
```

Create an `ingress` directory under `./secrets/certs` and create a new certificate and key for the ingress gateway (Traefik).
Since Ingress will be hosting many services, We can sign the cert using SAN (Subject Alternate Names) extension.

Create a file called san.cnf and add the following to it, modifying the values to suit your needs.
```text
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = CA
ST = BC
L = Vancouver
O = 
OU = 
CN = 

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
[alt_names]
DNS.1   = mqtt.lan  <-- list of domains ingress will be hosting
DNS.2   = mqtt.lan  <-- list of domains ingress will be hosting
```

Then run the following to create a `server-cert.pem` and `server-key.pem` file and put them in `./secrets/certs/ingress` folder.
```bash
#!/bin/sh
set +x trace

openssl genrsa -out server.key 2048
openssl req -new -key server-key.pem -out server.csr -config san.cnf
openssl req -in server.csr -noout -text
openssl x509 -req -in server.csr -CA rootCA.crt -CAkey rootCA.key -CAcreateserial -out server-cert.pem -days 1000 -sha256 -extfile san.cnf -extensions v3_req
openssl x509 -in server-cert.pem -text -noout
rm server.csr
```


## Base Stack

This stack is used to deploy the basic services (Traefik and Portainer) that can be used to deploy
the rest of the stacks.

`./base/init.sh && ./base/deploy.sh`

- Access Traefik at `<dockerhost>/traefik/`
    - Use password set in `./secrets/.secret` file.
- Access Portainer at `<dockerhost>/portainer/`
    - Set password on first login

## Other Stacks

Use Portainer to deploy the other stacks (or manually deploy them).

