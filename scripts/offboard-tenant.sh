#!/usr/bin/env bash
# Cleanly removes a hosted tenant application's edge route, containers, and isolated network.
# Usage: sudo appitect-offboard <app_slug>
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <app_slug>"
  exit 1
fi

APP_SLUG="$1"
INTERNAL_NET="${APP_SLUG//-/_}_internal"
APP_DIR="/opt/apps/${APP_SLUG}"
SITE_FILE="/opt/appitect-mini/edge/sites/${APP_SLUG}.caddy"

if [ -f "${SITE_FILE}" ]; then
  echo "[1/3] Removing Caddy site configuration ${SITE_FILE} and hot-reloading..."
  rm -f "${SITE_FILE}"
  docker exec appitect-mini-caddy caddy validate --config /etc/caddy/Caddyfile
  docker exec appitect-mini-caddy caddy reload --config /etc/caddy/Caddyfile
fi

if [ -d "${APP_DIR}" ]; then
  echo "[2/3] Stopping any Docker Compose projects inside ${APP_DIR}..."
  while IFS= read -r -d '' compose_file; do
    docker compose -f "${compose_file}" down --remove-orphans || true
  done < <(find "${APP_DIR}" -maxdepth 3 -name "docker-compose*.yml" -print0)
fi

if docker network inspect "${INTERNAL_NET}" >/dev/null 2>&1; then
  echo "[3/3] Removing isolated Docker network ${INTERNAL_NET}..."
  docker network rm "${INTERNAL_NET}" || echo "Warning: network ${INTERNAL_NET} still has attached containers."
fi

echo "Tenant '${APP_SLUG}' offboarded. Files in ${APP_DIR} were preserved for backup/archival."
