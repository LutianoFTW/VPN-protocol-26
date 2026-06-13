#!/bin/sh
set -eu

ROOT="/jffs/vpn-realitychain"
CONFIG_SOURCE=""
INSTALL_XRAY=1
ENABLE_TRANSPARENT_FLAG=0
XRAY_VERSION="${XRAY_VERSION:-latest}"

usage() {
  cat <<'USAGE'
Usage: install-merlin.sh [options]

Options:
  --config PATH             Xray client config to install as client.json
  --root PATH               Install root (default: /jffs/vpn-realitychain)
  --xray-version VERSION    Xray-core version tag, for example v25.1.1
  --skip-xray               Do not install or update the xray binary
  --enable-transparent      Set ENABLE_TRANSPARENT=1 in realitychain.env
  -h, --help                Show this help

Environment:
  XRAY_VERSION              Same as --xray-version; defaults to latest release
USAGE
}

log() {
  printf '%s\n' "realitychain-install: $*"
}

die() {
  printf '%s\n' "realitychain-install: $*" >&2
  exit 1
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --config)
      [ "$#" -ge 2 ] || die "--config requires a path"
      CONFIG_SOURCE="$2"
      shift 2
      ;;
    --root)
      [ "$#" -ge 2 ] || die "--root requires a path"
      ROOT="$2"
      shift 2
      ;;
    --xray-version)
      [ "$#" -ge 2 ] || die "--xray-version requires a version tag"
      XRAY_VERSION="$2"
      shift 2
      ;;
    --skip-xray)
      INSTALL_XRAY=0
      shift
      ;;
    --enable-transparent)
      ENABLE_TRANSPARENT_FLAG=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
done

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
FIREWALL_SOURCE="$REPO_ROOT/merlin/realitychain-firewall.sh"
DEFAULT_CONFIG="$REPO_ROOT/merlin/templates/client-transparent.json"

[ -d /jffs ] || die "this installer is intended for AsusWRT-Merlin with /jffs"
[ -f "$FIREWALL_SOURCE" ] || die "missing firewall hook: $FIREWALL_SOURCE"
[ -f "$DEFAULT_CONFIG" ] || die "missing default config template: $DEFAULT_CONFIG"

if [ -n "$CONFIG_SOURCE" ] && [ ! -f "$CONFIG_SOURCE" ]; then
  die "config file not found: $CONFIG_SOURCE"
fi

ensure_jffs_scripts_enabled() {
  if command -v nvram >/dev/null 2>&1; then
    if [ "$(nvram get jffs2_scripts 2>/dev/null || echo 0)" != "1" ]; then
      log "enabling Merlin custom scripts (jffs2_scripts=1)"
      nvram set jffs2_scripts=1
      nvram commit
    fi
  fi
}

ensure_opkg_package() {
  cmd="$1"
  pkg="$2"
  if command -v "$cmd" >/dev/null 2>&1; then
    return 0
  fi
  if [ -x /opt/bin/opkg ]; then
    log "installing $pkg via Entware"
    /opt/bin/opkg update
    /opt/bin/opkg install "$pkg"
  fi
  command -v "$cmd" >/dev/null 2>&1 || die "$cmd is required; install Entware package $pkg"
}

xray_asset_for_arch() {
  arch=$(uname -m)
  case "$arch" in
    x86_64|amd64)
      printf '%s\n' "Xray-linux-64.zip"
      ;;
    aarch64|arm64)
      printf '%s\n' "Xray-linux-arm64-v8a.zip"
      ;;
    armv7l|armv7*)
      printf '%s\n' "Xray-linux-arm32-v7a.zip"
      ;;
    armv6l|armv6*)
      printf '%s\n' "Xray-linux-arm32-v6.zip"
      ;;
    mipsel|mipsle)
      printf '%s\n' "Xray-linux-mips32le.zip"
      ;;
    *)
      die "unsupported router architecture: $arch"
      ;;
  esac
}

resolve_xray_version() {
  if [ "$XRAY_VERSION" != "latest" ]; then
    printf '%s\n' "$XRAY_VERSION"
    return 0
  fi
  latest_url=$(curl -fsSL -o /dev/null -w '%{url_effective}' \
    https://github.com/XTLS/Xray-core/releases/latest)
  version="${latest_url##*/}"
  [ -n "$version" ] || die "could not resolve latest Xray-core version"
  printf '%s\n' "$version"
}

install_xray() {
  ensure_opkg_package curl curl
  ensure_opkg_package unzip unzip

  mkdir -p /opt/bin /opt/share/xray "$ROOT/tmp"
  version=$(resolve_xray_version)
  asset=$(xray_asset_for_arch)
  url="https://github.com/XTLS/Xray-core/releases/download/$version/$asset"
  tmp="$ROOT/tmp/xray.zip"
  unpack="$ROOT/tmp/xray-unpack"

  rm -rf "$unpack"
  mkdir -p "$unpack"

  log "downloading $url"
  curl -fL "$url" -o "$tmp"
  unzip -o "$tmp" -d "$unpack" >/dev/null

  [ -f "$unpack/xray" ] || die "xray binary missing from $asset"
  cp "$unpack/xray" /opt/bin/xray
  chmod 0755 /opt/bin/xray

  if [ -f "$unpack/geoip.dat" ]; then
    cp "$unpack/geoip.dat" /opt/share/xray/geoip.dat
  fi
  if [ -f "$unpack/geosite.dat" ]; then
    cp "$unpack/geosite.dat" /opt/share/xray/geosite.dat
  fi

  rm -f "$tmp"
  rm -rf "$unpack"
  log "installed Xray-core $version"
}

write_env_file() {
  env_file="$ROOT/realitychain.env"
  if [ ! -f "$env_file" ]; then
    cat > "$env_file" <<'EOF'
# RealityChain Merlin runtime settings.
ENABLE_TRANSPARENT=0
LAN_IFACE=br0
DOKODEMO_PORT=12345
CHAIN_NAME=REALITYCHAIN

# Set this to the resolved public IP of the REALITY server before enabling
# transparent mode, otherwise the router may redirect the tunnel into itself.
REALITYCHAIN_SERVER_IP=
EOF
  fi

  if [ "$ENABLE_TRANSPARENT_FLAG" = "1" ]; then
    if grep -q '^ENABLE_TRANSPARENT=' "$env_file"; then
      sed -i 's/^ENABLE_TRANSPARENT=.*/ENABLE_TRANSPARENT=1/' "$env_file"
    else
      printf '%s\n' 'ENABLE_TRANSPARENT=1' >> "$env_file"
    fi
  fi
}

write_service() {
  service="/opt/etc/init.d/S24realitychain-xray"
  mkdir -p /opt/etc/init.d
  cat > "$service" <<EOF
#!/bin/sh
set -eu

ROOT="$ROOT"
CONFIG="\$ROOT/config/client.json"
PIDFILE="/var/run/realitychain-xray.pid"
LOGFILE="/tmp/realitychain-xray.log"
XRAY="/opt/bin/xray"

start() {
  [ -x "\$XRAY" ] || {
    echo "xray binary not found at \$XRAY" >&2
    exit 1
  }
  [ -f "\$CONFIG" ] || {
    echo "xray config not found at \$CONFIG" >&2
    exit 1
  }
  if [ -f "\$PIDFILE" ] && kill -0 "\$(cat "\$PIDFILE")" 2>/dev/null; then
    echo "realitychain xray already running"
    return 0
  fi
  "\$XRAY" run -config "\$CONFIG" >> "\$LOGFILE" 2>&1 &
  echo \$! > "\$PIDFILE"
  echo "started realitychain xray"
}

stop() {
  if [ -f "\$PIDFILE" ]; then
    pid=\$(cat "\$PIDFILE")
    if kill -0 "\$pid" 2>/dev/null; then
      kill "\$pid" || true
      sleep 1
    fi
    rm -f "\$PIDFILE"
  fi
  echo "stopped realitychain xray"
}

case "\${1:-start}" in
  start)
    start
    ;;
  stop)
    stop
    ;;
  restart)
    stop
    start
    ;;
  status)
    if [ -f "\$PIDFILE" ] && kill -0 "\$(cat "\$PIDFILE")" 2>/dev/null; then
      echo "running"
    else
      echo "stopped"
      exit 1
    fi
    ;;
  *)
    echo "Usage: \$0 {start|stop|restart|status}" >&2
    exit 2
    ;;
esac
EOF
  chmod 0755 "$service"
}

install_hook() {
  file="$1"
  name="$2"
  command="$3"
  marker_begin="# realitychain-$name begin"
  marker_end="# realitychain-$name end"

  mkdir -p /jffs/scripts
  touch "$file"
  chmod 0755 "$file"

  if ! grep -q "$marker_begin" "$file"; then
    {
      printf '\n%s\n' "$marker_begin"
      printf '%s\n' "$command"
      printf '%s\n' "$marker_end"
    } >> "$file"
  fi
}

install_files() {
  mkdir -p "$ROOT/bin" "$ROOT/config" "$ROOT/tmp"
  cp "$FIREWALL_SOURCE" "$ROOT/bin/realitychain-firewall.sh"
  chmod 0755 "$ROOT/bin/realitychain-firewall.sh"

  if [ -n "$CONFIG_SOURCE" ]; then
    cp "$CONFIG_SOURCE" "$ROOT/config/client.json"
  elif [ ! -f "$ROOT/config/client.json" ]; then
    cp "$DEFAULT_CONFIG" "$ROOT/config/client.json"
  fi
}

ensure_jffs_scripts_enabled
install_files
write_env_file

if [ "$INSTALL_XRAY" = "1" ]; then
  install_xray
fi

write_service
install_hook /jffs/scripts/services-start services-start \
  '[ -x /opt/etc/init.d/S24realitychain-xray ] && /opt/etc/init.d/S24realitychain-xray start'
install_hook /jffs/scripts/firewall-start firewall-start \
  '[ -x /jffs/vpn-realitychain/bin/realitychain-firewall.sh ] && /jffs/vpn-realitychain/bin/realitychain-firewall.sh start'

/opt/etc/init.d/S24realitychain-xray restart || log "service restart failed; check /tmp/realitychain-xray.log"
if [ "$ENABLE_TRANSPARENT_FLAG" = "1" ]; then
  "$ROOT/bin/realitychain-firewall.sh" restart || log "firewall setup failed"
fi

log "installation complete"
log "config: $ROOT/config/client.json"
log "runtime settings: $ROOT/realitychain.env"
