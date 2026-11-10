#!/usr/bin/env bash
# Onboards a new low-usage tenant application onto the shared Appitect-Mini VPS with zero downtime.
# Usage: sudo appitect-onboard <app_slug> <domain> <upstream_container> [upstream_port=3000] [waf_mode=On] [max_body_mb=10]
set -euo pipefail

if [ "$#" -lt 3 ]; then
  echo "Usage: $0 <app_slug> <domain> <upstream_container> [upstream_port=3000] [waf_mode=On|DetectionOnly] [max_body_mb=10]"
  exit 1
fi

APP_SLUG="$1"
DOMAIN="$2"
UPSTREAM_CONTAINER="$3"
UPSTREAM_PORT="${4:-3000}"
WAF_MODE="${5:-On}"
MAX_BODY_MB="${6:-10}"

if [[ ! "${APP_SLUG}" =~ ^[a-z][a-z0-9-]{1,19}$ ]]; then
  echo "Error: app_slug must be 2-20 lowercase alphanumeric characters or hyphens."
  exit 1
fi

if [[ "${WAF_MODE}" == "On" ]]; then
  WAF_SNIPPET="coraza_waf_on"
elif [[ "${WAF_MODE}" == "DetectionOnly" ]]; then
  WAF_SNIPPET="coraza_waf_detect"
else
  echo "Error: waf_mode must be 'On' or 'DetectionOnly'."
  exit 1
fi

INTERNAL_NET="${APP_SLUG//-/_}_internal"
APP_DIR="/opt/apps/${APP_SLUG}"
SITE_FILE="/opt/appitect-mini/edge/sites/${APP_SLUG}.caddy"

echo "[1/4] Creating isolated deployment directory ${APP_DIR}..."
mkdir -p "${APP_DIR}"
chown -R deploy:deploy "${APP_DIR}"

echo "[2/4] Ensuring isolated tenant Docker network '${INTERNAL_NET}' exists..."
docker network inspect "${INTERNAL_NET}" >/dev/null 2>&1 || docker network create --driver bridge "${INTERNAL_NET}"

echo "[3/4] Writing Caddy + Coraza OWASP WAF site block to ${SITE_FILE}..."
mkdir -p /opt/appitect-mini/edge/sites
cat > "${SITE_FILE}" <<EOF
# Managed tenant site definition for: ${APP_SLUG}
${DOMAIN} {
	import ${WAF_SNIPPET}

	request_body {
		max_size ${MAX_BODY_MB}MB
	}

	encode zstd gzip

	log {
		output file /var/log/caddy/${APP_SLUG}-access.log {
			roll_size 15MiB
			roll_keep 4
		}
		format json
	}

	reverse_proxy ${UPSTREAM_CONTAINER}:${UPSTREAM_PORT}
}
EOF
chown deploy:deploy "${SITE_FILE}"

echo "[4/4] Validating and hot-reloading Caddy (zero downtime for sibling apps)..."
docker exec appitect-mini-caddy caddy validate --config /etc/caddy/Caddyfile
docker exec appitect-mini-caddy caddy reload --config /etc/caddy/Caddyfile

echo ""
echo "Tenant '${APP_SLUG}' onboarded!"
echo "  - Deploy Path      : ${APP_DIR}"
echo "  - Edge Network     : vps_edge"
echo "  - Private Network  : ${INTERNAL_NET}"
echo "  - Domain           : https://${DOMAIN} -> ${UPSTREAM_CONTAINER}:${UPSTREAM_PORT}"
