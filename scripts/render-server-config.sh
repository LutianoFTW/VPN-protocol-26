#!/usr/bin/env bash
# Render an Xray JSON config from a template and env file.
# Usage:
#   render-server-config.sh --env examples/server.env \
#     --template server/templates/xray-server-nolog.json.tpl \
#     --output /usr/local/etc/xray/config.json
set -euo pipefail

ENV_FILE=""
TEMPLATE=""
OUTPUT="-"
ALLOW_EXAMPLE_UUID=0

usage() {
  cat <<'EOF'
Usage: render-server-config.sh --env FILE --template FILE [--output FILE]

Substitutes {{VAR}} placeholders from an env file into an Xray JSON template.
Unknown placeholders are left unchanged and reported as an error.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) ENV_FILE="${2:-}"; shift 2 ;;
    --template) TEMPLATE="${2:-}"; shift 2 ;;
    --output) OUTPUT="${2:-}"; shift 2 ;;
    --allow-example-uuid) ALLOW_EXAMPLE_UUID=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ -z "$ENV_FILE" || -z "$TEMPLATE" ]]; then
  usage >&2
  exit 2
fi
if [[ ! -f "$ENV_FILE" ]]; then
  echo "env file not found: $ENV_FILE" >&2
  exit 1
fi
if [[ ! -f "$TEMPLATE" ]]; then
  echo "template not found: $TEMPLATE" >&2
  exit 1
fi

# shellcheck disable=SC1090
set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a

: "${SERVER_LISTEN:=0.0.0.0}"
: "${SERVER_LISTEN_PORT:=${SERVER_PORT:-443}}"
: "${SERVER_ADDRESS:=}"
: "${SERVER_PORT:=443}"
: "${CLIENT_SOCKS_PORT:=10808}"
: "${CLIENT_HTTP_PORT:=10809}"
: "${REALITY_FINGERPRINT:=chrome}"

required=(
  VLESS_UUID
  REALITY_SHORT_ID
  REALITY_SERVER_NAME
  REALITY_DEST
)

# Server templates need the private key; client templates need the public key.
if grep -q '{{REALITY_PRIVATE_KEY}}' "$TEMPLATE"; then
  required+=(REALITY_PRIVATE_KEY)
fi
if grep -q '{{REALITY_PUBLIC_KEY}}' "$TEMPLATE"; then
  required+=(REALITY_PUBLIC_KEY)
fi
if grep -q '{{SERVER_ADDRESS}}' "$TEMPLATE"; then
  required+=(SERVER_ADDRESS)
fi

for key in "${required[@]}"; do
  value="${!key:-}"
  if [[ -z "$value" || "$value" == replace_with_* ]]; then
    echo "missing or placeholder value for $key in $ENV_FILE" >&2
    exit 1
  fi
done

if [[ "$ALLOW_EXAMPLE_UUID" -eq 0 && "$VLESS_UUID" == "00000000-0000-4000-8000-000000000000" ]]; then
  echo "refusing to render with the example UUID; generate a real one" >&2
  exit 1
fi

# Delegate substitution to Python so base64 REALITY keys (/+=) stay intact.
OUTPUT_PATH="$OUTPUT" TEMPLATE_PATH="$TEMPLATE" python3 - <<'PY'
import json
import os
import pathlib
import re
import sys

template_path = pathlib.Path(os.environ["TEMPLATE_PATH"])
output_path = os.environ["OUTPUT_PATH"]
text = template_path.read_text(encoding="utf-8")
keys = re.findall(r"\{\{([A-Z0-9_]+)\}\}", text)
values = {key: os.environ.get(key, "") for key in sorted(set(keys))}
missing = [k for k, v in values.items() if v == ""]
if missing:
    print(f"missing values for: {', '.join(missing)}", file=sys.stderr)
    sys.exit(1)

def repl(match: re.Match[str]) -> str:
    return values[match.group(1)]

rendered = re.sub(r"\{\{([A-Z0-9_]+)\}\}", repl, text)
try:
    json.loads(rendered)
except json.JSONDecodeError as exc:
    print(f"rendered output is not valid JSON: {exc}", file=sys.stderr)
    sys.exit(1)

if output_path == "-":
    sys.stdout.write(rendered if rendered.endswith("\n") else rendered + "\n")
else:
    out = pathlib.Path(output_path)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(rendered if rendered.endswith("\n") else rendered + "\n", encoding="utf-8")
    out.chmod(0o600)
    print(f"wrote {out}")
PY
