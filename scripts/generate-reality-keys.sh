#!/usr/bin/env bash
# Generate VLESS UUID, REALITY X25519 keys, and shortId for a Linux server.
# Writes secrets to an env file (default: ./server.env) with mode 0600.
set -euo pipefail

OUTPUT="${1:-./server.env}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXAMPLE_ENV="$REPO_ROOT/examples/server.env"

usage() {
  cat <<'EOF'
Usage: generate-reality-keys.sh [output.env]

Generates:
  - VLESS_UUID
  - REALITY_PRIVATE_KEY / REALITY_PUBLIC_KEY (via xray x25519)
  - REALITY_SHORT_ID (16 hex chars)

Requires xray on PATH (installed by scripts/install-linux-server.sh).
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if ! command -v xray >/dev/null 2>&1; then
  echo "xray not found on PATH; install it first (scripts/install-linux-server.sh)" >&2
  exit 1
fi

if [[ -f "$OUTPUT" ]]; then
  echo "refusing to overwrite existing file: $OUTPUT" >&2
  echo "move it aside or choose another path" >&2
  exit 1
fi

uuid=""
if command -v xray >/dev/null 2>&1 && xray help 2>&1 | grep -q uuid; then
  uuid="$(xray uuid 2>/dev/null || true)"
fi
if [[ -z "$uuid" ]]; then
  if command -v uuidgen >/dev/null 2>&1; then
    uuid="$(uuidgen | tr '[:upper:]' '[:lower:]')"
  else
    uuid="$(python3 -c 'import uuid; print(uuid.uuid4())')"
  fi
fi

# Prefer the modern "Password:" / "PublicKey:" output from recent Xray builds.
# Xray >= ~1.8+ prints PrivateKey / Password (PublicKey) / Hash32.
key_out="$(xray x25519)"
private_key="$(printf '%s\n' "$key_out" | awk -F': ' '/^Private(Key| key):/{print $2; exit}')"
public_key="$(printf '%s\n' "$key_out" | awk -F': ' '/^(PublicKey|Public key|Password \(PublicKey\)|Password):/{print $2; exit}')"

if [[ -z "$private_key" || -z "$public_key" ]]; then
  echo "failed to parse xray x25519 output:" >&2
  printf '%s\n' "$key_out" >&2
  exit 1
fi

if command -v openssl >/dev/null 2>&1; then
  short_id="$(openssl rand -hex 8)"
else
  short_id="$(python3 -c 'import secrets; print(secrets.token_hex(8))')"
fi

umask 077
if [[ -f "$EXAMPLE_ENV" ]]; then
  cp "$EXAMPLE_ENV" "$OUTPUT"
else
  cat >"$OUTPUT" <<'EOF'
SERVER_LISTEN=0.0.0.0
SERVER_LISTEN_PORT=443
SERVER_ADDRESS=vpn.example.net
SERVER_PORT=443
VLESS_UUID=
REALITY_PRIVATE_KEY=
REALITY_PUBLIC_KEY=
REALITY_SHORT_ID=
REALITY_SERVER_NAME=www.cloudflare.com
REALITY_DEST=www.cloudflare.com:443
REALITY_FINGERPRINT=chrome
CLIENT_SOCKS_PORT=10808
CLIENT_HTTP_PORT=10809
EOF
fi

python3 - "$OUTPUT" "$uuid" "$private_key" "$public_key" "$short_id" <<'PY'
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
uuid, private_key, public_key, short_id = sys.argv[2:6]
text = path.read_text(encoding="utf-8")

def set_key(text: str, key: str, value: str) -> str:
    pattern = re.compile(rf"^{re.escape(key)}=.*$", re.MULTILINE)
    replacement = f"{key}={value}"
    if pattern.search(text):
        return pattern.sub(replacement, text, count=1)
    return text.rstrip() + "\n" + replacement + "\n"

text = set_key(text, "VLESS_UUID", uuid)
text = set_key(text, "REALITY_PRIVATE_KEY", private_key)
text = set_key(text, "REALITY_PUBLIC_KEY", public_key)
text = set_key(text, "REALITY_SHORT_ID", short_id)
path.write_text(text, encoding="utf-8")
PY

chmod 600 "$OUTPUT"

cat <<EOF
Generated credentials written to: $OUTPUT

VLESS_UUID=$uuid
REALITY_PUBLIC_KEY=$public_key
REALITY_SHORT_ID=$short_id

Private key is in $OUTPUT only. Edit SERVER_ADDRESS / REALITY_DEST as needed,
then render and install:
  sudo scripts/install-linux-server.sh --env $OUTPUT
EOF
