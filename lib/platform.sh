#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

CONSUL_ADDR="${CONSUL_ADDR:-http://127.0.0.1:8500}"
NOMAD_ADDR="${NOMAD_ADDR:-http://127.0.0.1:4646}"
APISIX_ADMIN="${APISIX_ADMIN:-http://127.0.0.1:9180/apisix/admin}"
APISIX_GATEWAY="${APISIX_GATEWAY:-http://127.0.0.1:9080}"
APISIX_KEY="${APISIX_KEY:-edd1c9f034335f136f87ad84b625c8f1}"
UPSTREAM_HOST="${UPSTREAM_HOST:-host.docker.internal}"
export NOMAD_ADDR

fail() { echo "ERROR: $*" >&2; exit 1; }

if [ -x "$REPO_ROOT/nomad.exe" ]; then
  NOMAD="$REPO_ROOT/nomad.exe"
elif command -v nomad >/dev/null 2>&1; then
  NOMAD="$(command -v nomad)"
else
  NOMAD=""
fi

JQ=""
if command -v jq >/dev/null 2>&1; then
  JQ="$(command -v jq)"
elif [ -n "${LOCALAPPDATA:-}" ]; then
  _winget_jq="$(cygpath -u "$LOCALAPPDATA" 2>/dev/null)/Microsoft/WinGet/Packages/jqlang.jq_Microsoft.Winget.Source_8wekyb3d8bbwe/jq.exe"
  [ -x "$_winget_jq" ] && JQ="$_winget_jq"
  unset _winget_jq
fi

jqr() { "$JQ" "$@" | tr -d '\r'; return "${PIPESTATUS[0]}"; }

require_nomad() { [ -n "$NOMAD" ] || fail "nomad.exe not found in $REPO_ROOT or on PATH"; }
require_jq() { [ -n "$JQ" ] || fail "jq not found. Open a new Git Bash window, or run in PowerShell: winget install jqlang.jq"; }

wait_for_healthy() {
  local service="$1" tries="${2:-60}" i
  for ((i = 1; i <= tries; i++)); do
    if curl -sf "$CONSUL_ADDR/v1/health/service/$service?passing=true" | jqr -e 'length > 0' >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  return 1
}

healthy_ports() {
  curl -sf "$CONSUL_ADDR/v1/health/service/$1?passing=true" | jqr -r '.[].Service.Port'
}
