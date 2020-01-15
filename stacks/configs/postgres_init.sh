#!/bin/bash
set -e

GRAFANA_USER=$(cat /run/secrets/postgresql_grafana_user)
GRAFANA_PASSWORD=$(cat /run/secrets/postgresql_grafana_password)
POSTGRES_USER=$(cat /run/secrets/db_user)
POSTGRES_DB=$(cat /run/secrets/db)
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE USER ${GRAFANA_USER} WITH encrypted password '${GRAFANA_PASSWORD}';
    GRANT CONNECT ON DATABASE ${POSTGRES_DB} TO ${GRAFANA_USER};
    GRANT SELECT ON ALL TABLES IN SCHEMA public TO ${GRAFANA_USER};
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO ${GRAFANA_USER};
EOSQL
