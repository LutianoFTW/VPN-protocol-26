#!/usr/bin/env bash
# Validate Linux XTLS-REALITY no-log server packaging.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

pass() {
  echo "PASS: $*"
}

[[ -f server/templates/xray-server-nolog.json.tpl ]] || fail "missing server template"
[[ -f server/templates/xray-client.json.tpl ]] || fail "missing client template"
[[ -f server/systemd/xray-reality.service ]] || fail "missing systemd unit"
[[ -x scripts/install-linux-server.sh ]] || fail "install script not executable"
[[ -x scripts/generate-reality-keys.sh ]] || fail "keygen script not executable"
[[ -x scripts/render-server-config.sh ]] || fail "render script not executable"

python3 tools/xray_nolog.py validate-template \
  --template server/templates/xray-server-nolog.json.tpl
pass "template no-log + reality structure"

# Render with a temporary env that uses non-example secrets.
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

cat >"$tmpdir/server.env" <<'EOF'
SERVER_LISTEN=0.0.0.0
SERVER_LISTEN_PORT=443
SERVER_ADDRESS=203.0.113.10
SERVER_PORT=443
VLESS_UUID=11111111-1111-4111-8111-111111111111
REALITY_PRIVATE_KEY=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
REALITY_PUBLIC_KEY=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB
REALITY_SHORT_ID=0123456789abcdef
REALITY_SERVER_NAME=www.cloudflare.com
REALITY_DEST=www.cloudflare.com:443
REALITY_FINGERPRINT=chrome
CLIENT_SOCKS_PORT=10808
CLIENT_HTTP_PORT=10809
EOF

python3 tools/xray_nolog.py render \
  --env "$tmpdir/server.env" \
  --template server/templates/xray-server-nolog.json.tpl \
  --output "$tmpdir/config.json" \
  --require-nolog
pass "render server config"

python3 - "$tmpdir/config.json" <<'PY'
import json, sys
cfg = json.load(open(sys.argv[1], encoding="utf-8"))
assert cfg["log"]["loglevel"] == "none"
assert cfg["log"]["access"] == "none"
assert cfg["log"]["error"] == "none"
assert "stats" not in cfg
inbound = cfg["inbounds"][0]
assert inbound["protocol"] == "vless"
assert inbound["streamSettings"]["security"] == "reality"
assert inbound["settings"]["clients"][0]["flow"] == "xtls-rprx-vision"
assert inbound["streamSettings"]["realitySettings"]["show"] is False
assert cfg["policy"]["system"]["statsInboundUplink"] is False
print("runtime assertions ok")
PY
pass "rendered JSON asserts"

# Example env must remain placeholders (installer/keygen fill them).
if grep -q 'replace_with_reality_private_key' examples/server.env; then
  pass "example env keeps placeholders"
else
  fail "example env should keep placeholder private key"
fi

# Refuse example UUID through shell renderer.
if scripts/render-server-config.sh \
  --env examples/server.env \
  --template server/templates/xray-server-nolog.json.tpl \
  --output "$tmpdir/should-fail.json" 2>"$tmpdir/err.txt"; then
  fail "renderer should reject example UUID"
else
  pass "renderer rejects example UUID"
fi

# Unit file should launch xray with the no-log config path.
grep -q 'xray run -config /usr/local/etc/xray/config.json' \
  server/systemd/xray-reality.service || fail "systemd ExecStart mismatch"
grep -q 'Xray XTLS-REALITY Server (no-log)' \
  server/systemd/xray-reality.service || fail "systemd description mismatch"
pass "systemd unit checks"

echo
echo "All validation checks passed."
