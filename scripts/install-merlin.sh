#!/bin/sh
set -eu

PROGRAM_NAME=${0##*/}
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

INSTALL_DIR=${REALITYCHAIN_HOME:-/jffs/addons/realitychain}
INIT_SCRIPT=${REALITYCHAIN_INIT_SCRIPT:-/opt/etc/init.d/S99realitychain}
MERLIN_SERVICES_START=${MERLIN_SERVICES_START:-/jffs/scripts/services-start}
XRAY_BIN=${XRAY_BIN:-/opt/bin/xray}
XRAY_VERSION=${XRAY_VERSION:-latest}
DRY_RUN=0

usage() {
	cat <<EOF
Usage: $PROGRAM_NAME [--dry-run]

Install RealityChain for Asuswrt-Merlin routers with Entware.

Environment overrides:
  REALITYCHAIN_HOME       Default: /jffs/addons/realitychain
  REALITYCHAIN_INIT_SCRIPT Default: /opt/etc/init.d/S99realitychain
  XRAY_BIN                Default: /opt/bin/xray
  XRAY_VERSION            Default: latest
EOF
}

log() {
	printf '%s\n' "$*"
}

die() {
	printf '%s: %s\n' "$PROGRAM_NAME" "$*" >&2
	exit 1
}

run() {
	if [ "$DRY_RUN" -eq 1 ]; then
		printf '[dry-run] %s\n' "$*"
	else
		"$@"
	fi
}

need_cmd() {
	command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

detect_xray_asset_arch() {
	case "$(uname -m)" in
		aarch64|arm64)
			printf '64'
			;;
		armv7l|armv7*|armv8l)
			printf 'arm32-v7a'
			;;
		armv6l)
			printf 'arm32-v6'
			;;
		*)
			die "unsupported router architecture for automatic Xray install: $(uname -m)"
			;;
	esac
}

install_xray_if_needed() {
	if [ -x "$XRAY_BIN" ]; then
		log "Xray already installed at $XRAY_BIN"
		return
	fi

	need_cmd curl
	need_cmd unzip

	arch=$(detect_xray_asset_arch)
	tmp_dir=${TMPDIR:-/tmp}/realitychain-xray.$$
	asset="Xray-linux-$arch.zip"

	if [ "$XRAY_VERSION" = "latest" ]; then
		url="https://github.com/XTLS/Xray-core/releases/latest/download/$asset"
	else
		url="https://github.com/XTLS/Xray-core/releases/download/$XRAY_VERSION/$asset"
	fi

	log "Installing Xray from $url"
	run mkdir -p "$tmp_dir" /opt/bin
	if [ "$DRY_RUN" -eq 0 ]; then
		curl -fL "$url" -o "$tmp_dir/xray.zip"
		unzip -o "$tmp_dir/xray.zip" xray -d "$tmp_dir"
		install -m 0755 "$tmp_dir/xray" "$XRAY_BIN"
		rm -rf "$tmp_dir"
	else
		log "[dry-run] would download and install $asset"
	fi
}

install_files() {
	run mkdir -p "$INSTALL_DIR" "$INSTALL_DIR/templates"
	run cp "$REPO_DIR/scripts/realitychainctl" "$INSTALL_DIR/realitychainctl"
	run cp "$REPO_DIR/scripts/realitychain-tproxy.sh" "$INSTALL_DIR/realitychain-tproxy.sh"
	run cp "$REPO_DIR/templates/xray-client.json.tpl" "$INSTALL_DIR/templates/xray-client.json.tpl"
	run cp "$REPO_DIR/templates/xray-server.json.tpl" "$INSTALL_DIR/templates/xray-server.json.tpl"
	run chmod 0755 "$INSTALL_DIR/realitychainctl" "$INSTALL_DIR/realitychain-tproxy.sh"

	if [ ! -f "$INSTALL_DIR/client.env" ]; then
		run cp "$REPO_DIR/examples/client.env" "$INSTALL_DIR/client.env"
	fi

	if [ ! -f "$INSTALL_DIR/policy.json" ]; then
		run cp "$REPO_DIR/examples/policy.json" "$INSTALL_DIR/policy.json"
	fi
}

write_init_script() {
	init_dir=$(dirname -- "$INIT_SCRIPT")
	run mkdir -p "$init_dir"

	if [ "$DRY_RUN" -eq 1 ]; then
		log "[dry-run] would write $INIT_SCRIPT"
		return
	fi

	cat >"$INIT_SCRIPT" <<EOF
#!/bin/sh
set -eu

REALITYCHAIN_HOME=$INSTALL_DIR
XRAY_BIN=$XRAY_BIN
ENV_FILE=\$REALITYCHAIN_HOME/client.env
POLICY_FILE=\$REALITYCHAIN_HOME/policy.json
CONFIG_FILE=\$REALITYCHAIN_HOME/xray-client.json
PID_FILE=/var/run/realitychain-xray.pid

export REALITYCHAIN_HOME
export REALITYCHAIN_TEMPLATE_DIR=\$REALITYCHAIN_HOME/templates

start() {
	"\$REALITYCHAIN_HOME/realitychainctl" guarded-render "\$POLICY_FILE" "\$ENV_FILE" "\$CONFIG_FILE"
	"\$REALITYCHAIN_HOME/realitychain-tproxy.sh" start "\$ENV_FILE"
	"\$XRAY_BIN" run -config "\$CONFIG_FILE" >/tmp/realitychain-xray.log 2>&1 &
	echo \$! >"\$PID_FILE"
}

stop() {
	"\$REALITYCHAIN_HOME/realitychain-tproxy.sh" stop "\$ENV_FILE" || true
	if [ -f "\$PID_FILE" ]; then
		kill "\$(cat "\$PID_FILE")" 2>/dev/null || true
		rm -f "\$PID_FILE"
	fi
}

case "\${1:-}" in
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
	*)
		echo "Usage: \$0 {start|stop|restart}" >&2
		exit 2
		;;
esac
EOF
	chmod 0755 "$INIT_SCRIPT"
}

install_merlin_hook() {
	hook_dir=$(dirname -- "$MERLIN_SERVICES_START")
	run mkdir -p "$hook_dir"

	if [ "$DRY_RUN" -eq 1 ]; then
		log "[dry-run] would update $MERLIN_SERVICES_START"
		return
	fi

	if [ ! -f "$MERLIN_SERVICES_START" ]; then
		touch "$MERLIN_SERVICES_START"
		chmod 0755 "$MERLIN_SERVICES_START"
	fi

	if ! grep -q 'RealityChain autostart' "$MERLIN_SERVICES_START"; then
		cat >>"$MERLIN_SERVICES_START" <<EOF

# RealityChain autostart
if [ -x "$INIT_SCRIPT" ]; then
	"$INIT_SCRIPT" start
fi
EOF
	fi
}

while [ $# -gt 0 ]; do
	case "$1" in
		--dry-run)
			DRY_RUN=1
			;;
		-h|--help)
			usage
			exit 0
			;;
		*)
			usage >&2
			exit 2
			;;
	esac
	shift
done

[ -d /jffs ] || die "this installer must run on Asuswrt-Merlin with /jffs enabled"
[ -d /opt ] || die "Entware /opt not found; install Entware before running this script"

need_cmd uname
need_cmd grep

install_xray_if_needed
install_files
write_init_script
install_merlin_hook

log "RealityChain installed in $INSTALL_DIR"
log "Edit $INSTALL_DIR/client.env, then run: $INIT_SCRIPT start"
