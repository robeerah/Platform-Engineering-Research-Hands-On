#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="${1:-}"
MODE="${2:-}"

if [ -z "$CONFIG_FILE" ] || [ ! -f "$CONFIG_FILE" ]; then
  echo "Usage: $0 <config.json> [--dry-run]" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/platform.sh"
require_nomad

json_get() {
  local key="$1"
  if [ -n "$JQ" ]; then
    jqr -r --arg k "$key" '.[$k] // "null"' "$CONFIG_FILE"
  else
    local win_path
    win_path="$(cygpath -w "$CONFIG_FILE")"
    powershell.exe -NoProfile -Command \
      "\$j = Get-Content -Raw -LiteralPath '$win_path' | ConvertFrom-Json; \$v = \$j.'$key'; if (\$null -eq \$v) { 'null' } else { \$v }" \
      | tr -d '\r'
  fi
}

if [ -n "$JQ" ]; then
  echo "🔧 JSON parser: jq ($("$JQ" --version | tr -d '\r'))"
else
  echo "🔧 JSON parser: PowerShell ConvertFrom-Json (jq not found)"
fi

APP_NAME="$(json_get app_name)"
MESSAGE="$(json_get message)"
CPU="$(json_get cpu)"
MEMORY="$(json_get memory)"
COUNT="$(json_get count)"

[[ "$APP_NAME" =~ ^[a-z0-9][a-z0-9-]*$ ]] || fail "app_name must be lowercase letters, digits, dashes (got '$APP_NAME')"
[[ "$CPU"    =~ ^[0-9]+$ ]] || fail "cpu must be an integer (got '$CPU')"
[[ "$MEMORY" =~ ^[0-9]+$ ]] || fail "memory must be an integer (got '$MEMORY')"
[[ "$COUNT"  =~ ^[0-9]+$ ]] || fail "count must be an integer (got '$COUNT')"
[ "$MESSAGE" != "null" ] || MESSAGE="Hello from $APP_NAME"

PS_SERVER=$(cat <<'PS'
$port = [int]$env:NOMAD_PORT_http;
$msg = [Text.Encoding]::UTF8.GetBytes('__MESSAGE__');
$l = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::IPv6Any, $port);
$l.Server.DualMode = $true;
$l.Start();
$n = 0;
Write-Host "Server started on port $port";
while ($true) {
  try {
    $c = $l.AcceptTcpClient(); $c.ReceiveTimeout = 2000;
    $s = $c.GetStream(); $r = New-Object System.IO.StreamReader($s);
    $req = $r.ReadLine(); $line = $req;
    while (-not [string]::IsNullOrEmpty($line)) { $line = $r.ReadLine() };
    $n++;
    $path = "$req".Split(' ')[1];
    if ($path -eq '/metrics') {
      $body = [Text.Encoding]::UTF8.GetBytes("app_requests_total{app=`"__APP__`"} $n`napp_up{app=`"__APP__`"} 1`n");
      $ct = 'text/plain; version=0.0.4'
    } else {
      $body = $msg; $ct = 'text/plain; charset=utf-8'
    };
    $h = [Text.Encoding]::ASCII.GetBytes("HTTP/1.1 200 OK`r`nContent-Type: $ct`r`nContent-Length: $($body.Length)`r`nConnection: close`r`n`r`n");
    $s.Write($h, 0, $h.Length); $s.Write($body, 0, $body.Length); $s.Flush(); $c.Close()
  } catch { Write-Host "request error: $_" }
}
PS
)

PS_MSG="${MESSAGE//\'/\'\'}"
PS_SERVER="${PS_SERVER//__MESSAGE__/$PS_MSG}"
PS_SERVER="${PS_SERVER//__APP__/$APP_NAME}"
PS_SERVER="$(printf '%s' "$PS_SERVER" | tr -d '\r' | tr '\n' ' ' | sed 's/  */ /g')"
HCL_CMD="${PS_SERVER//\\/\\\\}"
HCL_CMD="${HCL_CMD//\"/\\\"}"
HCL_CMD="${HCL_CMD//\$\{/\$\$\{}"
HCL_CMD="${HCL_CMD//%\{/%%\{}"

OUTPUT_DIR="${OUTPUT_DIR:-$SCRIPT_DIR}"
mkdir -p "$OUTPUT_DIR"
OUT_FILE="$(cd "$OUTPUT_DIR" && pwd)/${APP_NAME}.nomad.hcl"
echo "🔨 Generating Nomad job spec for: $APP_NAME (count=$COUNT cpu=$CPU mem=$MEMORY)"

cat > "$OUT_FILE" <<EOF
job "${APP_NAME}" {
  datacenters = ["dc1"]
  type        = "service"

  group "web" {
    count          = ${COUNT}
    shutdown_delay = "5s"

    network {
      port "http" {}
    }

    service {
      name     = "${APP_NAME}"
      port     = "http"
      provider = "consul"
      tags     = ["metrics", "platform-managed"]

      check {
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "server" {
      driver = "raw_exec"

      config {
        command = "powershell.exe"
        args    = [
          "-NoProfile", "-ExecutionPolicy", "Bypass",
          "-Command",
          "${HCL_CMD}"
        ]
      }

      resources {
        cpu    = ${CPU}
        memory = ${MEMORY}
      }
    }
  }
}
EOF

echo " Generated $OUT_FILE"

echo " Validating..."
"$NOMAD" job validate "$OUT_FILE"

if [ "$MODE" = "--dry-run" ]; then
  echo " Dry run - not deploying."
  exit 0
fi

echo " Deploying to Nomad..."
"$NOMAD" job run "$OUT_FILE"
