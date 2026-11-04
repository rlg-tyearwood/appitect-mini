#!/usr/bin/env bash
# Day-2 declarative sync: exports Terraform-rendered Caddyfile and all tenant site files,
# creates any missing tenant directories/Docker networks on the shared VPS, and hot-reloads Caddy.
# Usage: ./scripts/sync-tenants.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${REPO_ROOT}/terraform"
RENDER_DIR="${REPO_ROOT}/.rendered"

rm -rf "${RENDER_DIR}"
mkdir -p "${RENDER_DIR}/sites"

VPS_IP="$(terraform -chdir="${TF_DIR}" output -raw vps_public_ipv4)"
terraform -chdir="${TF_DIR}" output -raw rendered_caddyfile > "${RENDER_DIR}/Caddyfile"

TENANTS_JSON="$(terraform -chdir="${TF_DIR}" output -json rendered_tenant_sites)"

for slug in $(echo "${TENANTS_JSON}" | jq -r 'keys[]'); do
  echo "${TENANTS_JSON}" | jq -r --arg s "${slug}" '.[$s]' > "${RENDER_DIR}/sites/${slug}.caddy"
  net="${slug//-/_}_internal"
  ssh "deploy@${VPS_IP}" "sudo mkdir -p /opt/apps/${slug} && sudo chown -R deploy:deploy /opt/apps/${slug} && (docker network inspect ${net} >/dev/null 2>&1 || docker network create --driver bridge ${net})"
done

scp "${REPO_ROOT}/edge/Dockerfile.caddy" "${REPO_ROOT}/edge/docker-compose.yml" "${RENDER_DIR}/Caddyfile" "deploy@${VPS_IP}:/opt/appitect-mini/edge/"
scp "${RENDER_DIR}/sites/"*.caddy "deploy@${VPS_IP}:/opt/appitect-mini/edge/sites/"

ssh "deploy@${VPS_IP}" <<'EOF'
set -euo pipefail
cd /opt/appitect-mini/edge
docker compose up -d --build
docker exec appitect-mini-caddy caddy validate --config /etc/caddy/Caddyfile
docker exec appitect-mini-caddy caddy reload --config /etc/caddy/Caddyfile
EOF

rm -rf "${RENDER_DIR}"
echo "All tenant networks, Caddy + Coraza WAF rules, and site definitions synced to ${VPS_IP}."
