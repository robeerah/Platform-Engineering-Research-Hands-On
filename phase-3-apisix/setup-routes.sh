#!/usr/bin/env bash
set -euo pipefail

APP_NAME="${1:-my-webapp}"
ROUTE_PATH="${2:-/api/v1/$APP_NAME}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/platform.sh"
require_jq

[[ "$APP_NAME" =~ ^[a-z0-9][a-z0-9-]*$ ]] || fail "invalid app name '$APP_NAME'"
ROUTE_PATH="/${ROUTE_PATH#/}"
ROUTE_PATH="${ROUTE_PATH%/}"

echo " Checking APISIX Admin API at $APISIX_ADMIN ..."
curl -sf -o /dev/null -H "X-API-KEY: $APISIX_KEY" "$APISIX_ADMIN/routes" \
  || fail "APISIX Admin API not reachable. Run: cd phase-3-apisix && docker compose up -d"

echo " Looking up healthy '$APP_NAME' instances in Consul ..."
PORTS="$(healthy_ports "$APP_NAME" || true)"
[ -n "$PORTS" ] || fail "no passing instances of '$APP_NAME' in Consul. Deploy it first with phase-1-nomad-consul/generate-hcl.sh"

NODES="$(printf '%s\n' "$PORTS" | jqr -R -s --arg h "$UPSTREAM_HOST" \
  'split("\n") | map(select(length > 0)) | map({key: "\($h):\(.)", value: 1}) | from_entries')"
echo " Upstream nodes: $(printf '%s' "$NODES" | jqr -c .)"

ROUTE_FILE="$SCRIPT_DIR/routes/$APP_NAME.json"
if [ -f "$ROUTE_FILE" ]; then
  BASE="$(jqr . "$ROUTE_FILE")"
else
  BASE='{"plugins":{"limit-count":{"count":100,"time_window":60,"rejected_code":429,"key_type":"var","key":"remote_addr"},"prometheus":{}}}'
fi

ROUTE="$(printf '%s' "$BASE" | jqr --arg uri "$ROUTE_PATH/*" --arg re "^$ROUTE_PATH/(.*)" --arg name "$APP_NAME" --argjson nodes "$NODES" '
  .name = $name
  | .uri = $uri
  | .plugins["proxy-rewrite"] = {regex_uri: [$re, "/$1"]}
  | .upstream = {type: "roundrobin", scheme: "http", nodes: $nodes}')"

echo " Applying route '$APP_NAME' -> $ROUTE_PATH/* ..."
RESP="$(curl -sS -w '\n%{http_code}' -X PUT "$APISIX_ADMIN/routes/$APP_NAME" \
  -H "X-API-KEY: $APISIX_KEY" -H "Content-Type: application/json" -d "$ROUTE")"
CODE="${RESP##*$'\n'}"
[[ "$CODE" =~ ^20[01]$ ]] || fail "APISIX rejected the route (HTTP $CODE): ${RESP%$'\n'*}"
echo " Route configured (HTTP $CODE)"

echo " Testing through the gateway ..."
for _ in $(seq 1 10); do
  if BODY="$(curl -sf "$APISIX_GATEWAY$ROUTE_PATH/test")"; then
    echo " $APISIX_GATEWAY$ROUTE_PATH/test -> $BODY"
    exit 0
  fi
  sleep 1
done
fail "route created but $APISIX_GATEWAY$ROUTE_PATH/test did not answer"
