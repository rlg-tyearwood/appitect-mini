#!/usr/bin/env bash
# Displays host memory/swap/disk health and per-container CPU/RAM consumption across all shared tenants.
set -euo pipefail

echo "=================================================================="
echo " Appitect-Mini Shared Host Health Summary"
echo "=================================================================="
free -h
echo ""
df -h / /opt
echo ""
echo "=================================================================="
echo " Configured Tenant Caddy + Coraza WAF Sites"
echo "=================================================================="
if compgen -G "/opt/appitect-mini/edge/sites/*.caddy" > /dev/null; then
  for site in /opt/appitect-mini/edge/sites/*.caddy; do
    domain=$(grep -E '^[a-zA-Z0-9.-]+\s*\{' "${site}" | awk '{print $1}' || true)
    echo " - $(basename "${site}" .caddy): https://${domain}"
  done
else
  echo " (No tenant site files currently configured)"
fi
echo ""
echo "=================================================================="
echo " Live Container Resource Usage (CPU / Memory / Network I/O)"
echo "=================================================================="
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}"
