#!/usr/bin/env bash
# Install Xray-core as a Linux systemd service with XTLS-REALITY and no-log.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE=""
SKIP_DOWNLOAD=0
BOOTSTRAP_ONLY=0
LISTEN_PORT=""
XRAY_VERSION="${XRAY_VERSION:-}"
INSTALL_DIR="/usr/local"
CONFIG_DIR="/usr/local/etc/xray"
SERVICE_NAME="xray-reality"
TEMPLATE="$REPO_ROOT/server/templates/xray-server-nolog.json.tpl"
UNIT_SRC="$REPO_ROOT/server/systemd/xray-reality.service"

usage() {
  cat <<'EOF'
Usage: install-linux-server.sh --env FILE [options]

Installs Xray-core, renders a no-log VLESS + XTLS-REALITY config, and enables
a hardened systemd unit.

Options:
  --env FILE           Server environment file (required unless --bootstrap-only)
  --template FILE      Override server JSON template
  --skip-download      Reuse an existing /usr/local/bin/xray binary
  --bootstrap-only     Download/install the xray binary only (for keygen)
  --port N             Override SERVER_LISTEN_PORT / firewall hint
  --version TAG        Xray release tag (default: latest)
  -h, --help           Show this help

Example:
  sudo scripts/install-linux-server.sh --bootstrap-only
  ./scripts/generate-reality-keys.sh ./server.env
  sudo scripts/install-linux-server.sh --env ./server.env
EOF
}

need_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo "run as root (sudo)" >&2
    exit 1
  fi
}

detect_arch() {
  local arch
  arch="$(uname -m)"
  case "$arch" in
    x86_64|amd64) echo "64" ;;
    aarch64|arm64) echo "arm64-v8a" ;;
    armv7l) echo "arm32-v7a" ;;
    *)
      echo "unsupported architecture: $arch" >&2
      exit 1
      ;;
  esac
}

latest_xray_tag() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL https://api.github.com/repos/XTLS/Xray-core/releases/latest \
      | python3 -c 'import json,sys; print(json.load(sys.stdin)["tag_name"])'
  else
    wget -qO- https://api.github.com/repos/XTLS/Xray-core/releases/latest \
      | python3 -c 'import json,sys; print(json.load(sys.stdin)["tag_name"])'
  fi
}

download_xray() {
  local tag="$1"
  local arch_suffix="$2"
  local tmp
  tmp="$(mktemp -d)"
  local asset="Xray-linux-${arch_suffix}.zip"
  local url="https://github.com/XTLS/Xray-core/releases/download/${tag}/${asset}"
  echo "downloading $url"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$tmp/$asset"
  else
    wget -qO "$tmp/$asset" "$url"
  fi
  if ! command -v unzip >/dev/null 2>&1; then
    if command -v apt-get >/dev/null 2>&1; then
      apt-get update -y
      apt-get install -y unzip
    else
      echo "unzip is required" >&2
      exit 1
    fi
  fi
  unzip -qo "$tmp/$asset" -d "$tmp/extract"
  install -m 755 "$tmp/extract/xray" "$INSTALL_DIR/bin/xray"
  if [[ -f "$tmp/extract/geoip.dat" ]]; then
    install -m 644 "$tmp/extract/geoip.dat" "$CONFIG_DIR/geoip.dat"
  fi
  if [[ -f "$tmp/extract/geosite.dat" ]]; then
    install -m 644 "$tmp/extract/geosite.dat" "$CONFIG_DIR/geosite.dat"
  fi
  rm -rf "$tmp"
}

open_firewall_port() {
  local port="$1"
  if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -qi "Status: active"; then
    ufw allow "${port}/tcp" || true
    echo "opened ${port}/tcp via ufw"
  elif command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active --quiet firewalld; then
    firewall-cmd --permanent --add-port="${port}/tcp" || true
    firewall-cmd --reload || true
    echo "opened ${port}/tcp via firewalld"
  else
    echo "ensure TCP port ${port} is allowed in your host firewall / security group"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) ENV_FILE="${2:-}"; shift 2 ;;
    --template) TEMPLATE="${2:-}"; shift 2 ;;
    --skip-download) SKIP_DOWNLOAD=1; shift ;;
    --bootstrap-only) BOOTSTRAP_ONLY=1; shift ;;
    --port) LISTEN_PORT="${2:-}"; shift 2 ;;
    --version) XRAY_VERSION="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

need_root
mkdir -p "$INSTALL_DIR/bin" "$CONFIG_DIR" /usr/local/share/xray /etc/systemd/system

if [[ "$SKIP_DOWNLOAD" -eq 1 ]]; then
  if [[ ! -x "$INSTALL_DIR/bin/xray" ]]; then
    echo "no existing xray at $INSTALL_DIR/bin/xray" >&2
    exit 1
  fi
else
  tag="${XRAY_VERSION:-$(latest_xray_tag)}"
  download_xray "$tag" "$(detect_arch)"
fi

# Put geo assets where Xray expects them.
if [[ -f "$CONFIG_DIR/geoip.dat" ]]; then
  ln -sfn "$CONFIG_DIR/geoip.dat" /usr/local/share/xray/geoip.dat
fi
if [[ -f "$CONFIG_DIR/geosite.dat" ]]; then
  ln -sfn "$CONFIG_DIR/geosite.dat" /usr/local/share/xray/geosite.dat
fi

if [[ "$BOOTSTRAP_ONLY" -eq 1 ]]; then
  echo "bootstrapped xray at $INSTALL_DIR/bin/xray"
  "$INSTALL_DIR/bin/xray" version || true
  echo "next: ./scripts/generate-reality-keys.sh ./server.env"
  exit 0
fi

if [[ -z "$ENV_FILE" ]]; then
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

if [[ -n "$LISTEN_PORT" ]]; then
  SERVER_LISTEN_PORT="$LISTEN_PORT"
fi
: "${SERVER_LISTEN_PORT:=${SERVER_PORT:-443}}"

# Persist env copy for operators (private key included — mode 0600).
install -m 600 "$ENV_FILE" "$CONFIG_DIR/server.env"

"$REPO_ROOT/scripts/render-server-config.sh" \
  --env "$CONFIG_DIR/server.env" \
  --template "$TEMPLATE" \
  --output "$CONFIG_DIR/config.json"

# Service runs as nobody; allow group read of the runtime config only.
chown root:nogroup "$CONFIG_DIR/config.json"
chmod 640 "$CONFIG_DIR/config.json"

# Also emit a companion client config for the operator workstation.
if [[ -n "${SERVER_ADDRESS:-}" && "$SERVER_ADDRESS" != "vpn.example.net" ]]; then
  "$REPO_ROOT/scripts/render-server-config.sh" \
    --env "$CONFIG_DIR/server.env" \
    --template "$REPO_ROOT/server/templates/xray-client.json.tpl" \
    --output "$CONFIG_DIR/client.json" || true
  chown root:root "$CONFIG_DIR/client.json" 2>/dev/null || true
  chmod 600 "$CONFIG_DIR/client.json" 2>/dev/null || true
fi

install -m 644 "$UNIT_SRC" "/etc/systemd/system/${SERVICE_NAME}.service"

systemd_ok=0
if command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]; then
  if systemctl daemon-reload && systemctl enable --now "$SERVICE_NAME"; then
    systemd_ok=1
  else
    echo "warning: systemd unit installed but enable/start failed" >&2
  fi
else
  echo "warning: systemd not available as PID 1; unit written but not started"
  echo "         start manually: /usr/local/bin/xray run -config $CONFIG_DIR/config.json"
fi

# Validate config with xray itself when possible.
if XRAY_LOCATION_ASSET=/usr/local/share/xray \
  "$INSTALL_DIR/bin/xray" run -test -config "$CONFIG_DIR/config.json"; then
  echo "xray config test: ok"
else
  echo "xray config test failed; check $CONFIG_DIR/config.json" >&2
  if [[ "$systemd_ok" -eq 1 ]]; then
    systemctl status "$SERVICE_NAME" --no-pager || true
  fi
  exit 1
fi

open_firewall_port "$SERVER_LISTEN_PORT"

# Confirm no-log settings landed.
python3 - "$CONFIG_DIR/config.json" <<'PY'
import json, sys
cfg = json.load(open(sys.argv[1], encoding="utf-8"))
log = cfg.get("log", {})
assert log.get("loglevel") == "none", log
assert log.get("access") == "none", log
assert log.get("error") == "none", log
assert "stats" not in cfg, "stats must be absent for no-log/no-metrics"
print("no-log policy: ok")
PY

cat <<EOF

Xray XTLS-REALITY server installed.

  binary : $INSTALL_DIR/bin/xray
  config : $CONFIG_DIR/config.json
  env    : $CONFIG_DIR/server.env
  unit   : ${SERVICE_NAME}.service
  listen : ${SERVER_LISTEN:-0.0.0.0}:${SERVER_LISTEN_PORT}
  systemd: $([[ "$systemd_ok" -eq 1 ]] && echo active || echo deferred)

Useful commands:
  systemctl status ${SERVICE_NAME}
  journalctl -u ${SERVICE_NAME} -e
  $INSTALL_DIR/bin/xray run -test -config $CONFIG_DIR/config.json

Client share values (public):
  SERVER_ADDRESS=${SERVER_ADDRESS:-<set me>}
  SERVER_PORT=${SERVER_PORT:-$SERVER_LISTEN_PORT}
  VLESS_UUID=${VLESS_UUID}
  REALITY_PUBLIC_KEY=${REALITY_PUBLIC_KEY}
  REALITY_SHORT_ID=${REALITY_SHORT_ID}
  REALITY_SERVER_NAME=${REALITY_SERVER_NAME}
  REALITY_FINGERPRINT=${REALITY_FINGERPRINT:-chrome}
  flow=xtls-rprx-vision
EOF
