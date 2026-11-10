#!/usr/bin/env bash
# Creates an isolated logical PostgreSQL database and dedicated least-privilege role for a tenant app
# on a shared Linode Managed PostgreSQL cluster.
# Usage: ./scripts/create-tenant-db.sh "<ADMIN_POSTGRES_URI>" <app_slug>
set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 \"postgres://linpostgres:<pass>@<host>:5432/defaultdb?sslmode=require\" <app_slug>"
  exit 1
fi

ADMIN_URI="$1"
APP_SLUG="$2"
DB_NAME="${APP_SLUG//-/_}"
DB_USER="${DB_NAME}_app"
DB_PASS="$(openssl rand -hex 24)"

HOST_PORT="$(echo "${ADMIN_URI}" | sed -E 's|^postgres(ql)?://[^@]+@([^/]+)/.*|\2|')"

psql "${ADMIN_URI}" -v ON_ERROR_STOP=1 <<SQL
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${DB_USER}') THEN
    CREATE ROLE ${DB_USER} WITH LOGIN PASSWORD '${DB_PASS}';
  ELSE
    ALTER ROLE ${DB_USER} WITH PASSWORD '${DB_PASS}';
  END IF;
END
\$\$;
SQL

psql "${ADMIN_URI}" -tc "SELECT 1 FROM pg_database WHERE datname = '${DB_NAME}'" | grep -q 1 || \
  psql "${ADMIN_URI}" -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};"

psql "${ADMIN_URI}" -c "REVOKE ALL ON DATABASE ${DB_NAME} FROM PUBLIC; GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};"

echo ""
echo "Isolated tenant database provisioned on shared Managed PostgreSQL:"
echo "  Database : ${DB_NAME}"
echo "  Role     : ${DB_USER}"
echo "  URI      : postgres://${DB_USER}:${DB_PASS}@${HOST_PORT}/${DB_NAME}?sslmode=require"
