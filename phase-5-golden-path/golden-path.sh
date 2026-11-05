#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="${1:-}"
if [ -z "$CONFIG_FILE" ] || [ ! -f "$CONFIG_FILE" ]; then
  echo "Usage: $0 <app-config.json>" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/platform.sh"
require_nomad
require_jq

CONFIG_FILE="$(cd "$(dirname "$CONFIG_FILE")" && pwd)/$(basename "$CONFIG_FILE")"
APP_NAME="$(jqr -r '.app_name // empty' "$CONFIG_FILE")"
ROUTE_PATH="$(jqr -r '.route_path // empty' "$CONFIG_FILE")"
[ -n "$APP_NAME" ] || fail "app_name missing in $CONFIG_FILE"
ROUTE_PATH="${ROUTE_PATH:-/api/v1/$APP_NAME}"

echo "========================================="
echo "🌟 PLATFORM ENGINEERING GOLDEN PATH 🌟"
echo "========================================="

echo "[1/5]  Pre-flight checks"
curl -sf -o /dev/null "$CONSUL_ADDR/v1/status/leader" || fail "Consul not reachable at $CONSUL_ADDR. Start it: ./consul.exe agent -dev -ui"
curl -sf -o /dev/null "$NOMAD_ADDR/v1/status/leader"  || fail "Nomad not reachable at $NOMAD_ADDR. Start it: ./nomad.exe agent -dev -config=nomad-dev.hcl"
curl -sf -o /dev/null -H "X-API-KEY: $APISIX_KEY" "$APISIX_ADMIN/routes" || fail "APISIX not reachable. Run: cd phase-3-apisix && docker compose up -d"
echo "      Consul ✅  Nomad ✅  APISIX ✅"

echo "[2/5]  Generating and deploying Nomad job"
OUTPUT_DIR="$SCRIPT_DIR" bash "$REPO_ROOT/phase-1-nomad-consul/generate-hcl.sh" "$CONFIG_FILE"

echo "[3/5]  Waiting for '$APP_NAME' to pass Consul health checks"
wait_for_healthy "$APP_NAME" 60 || fail "'$APP_NAME' did not become healthy. Check: ./nomad.exe job status $APP_NAME"
echo "       Healthy on port(s): $(healthy_ports "$APP_NAME" | paste -sd, -)"

echo "[4/5]  Publishing route through APISIX"
bash "$REPO_ROOT/phase-3-apisix/setup-routes.sh" "$APP_NAME" "$ROUTE_PATH"

echo "[5/5]  Checking Prometheus discovery"
if curl -sf "http://127.0.0.1:9090/-/ready" >/dev/null 2>&1; then
  curl -sf -X POST "http://127.0.0.1:9090/-/reload" >/dev/null 2>&1 || true
  echo "      Prometheus is up. Targets: http://127.0.0.1:9090/targets"
else
  echo "      ⚠️  Prometheus not running. Start it: cd phase-4-monitoring && docker compose up -d"
fi

echo "========================================="
echo " GOLDEN PATH COMPLETE!"
echo "========================================="
echo " App via gateway : $APISIX_GATEWAY$ROUTE_PATH/test"
echo " App metrics     : $APISIX_GATEWAY$ROUTE_PATH/metrics"
echo " Nomad UI        : $NOMAD_ADDR/ui/jobs/$APP_NAME"
echo " Consul UI       : $CONSUL_ADDR/ui/dc1/services/$APP_NAME"
echo " Prometheus      : http://127.0.0.1:9090/targets"
echo " Grafana         : http://127.0.0.1:3000 (admin/admin)"
