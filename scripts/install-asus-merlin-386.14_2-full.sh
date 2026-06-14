#!/bin/sh
set -eu

PROGRAM_NAME=${0##*/}
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

REALITYCHAIN_HOME=${REALITYCHAIN_HOME:-/jffs/addons/realitychain}
INIT_SCRIPT=${REALITYCHAIN_INIT_SCRIPT:-/opt/etc/init.d/S99realitychain}
DRY_RUN=0
FORCE=0
START_AFTER_INSTALL=0

usage() {
	cat <<EOF
Usage: $PROGRAM_NAME [--dry-run] [--force] [--start]

Full RealityChain installer for Asuswrt-Merlin 386.14_2.

What it does:
  1. Checks Merlin 386.14_2 compatibility.
  2. Enables Merlin custom scripts in nvram.
  3. Prepares /jffs/scripts and /jffs/addons.
  4. Runs the RealityChain Merlin installer.
  5. Installs all project functions: WebUI, TPROXY, kill switch, watchdog,
     blockchain policy gate, client renderer, and server renderer.
  6. Applies safe default addon settings for Merlin 386.14_2.
  7. Leaves the tunnel disabled until real client/server credentials are set,
     unless --start is provided.

Options:
  --dry-run  Print actions without changing the router.
  --force    Continue even if firmware is not detected as 386.14_2.
  --start    Start RealityChain after installation.
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

have_cmd() {
	command -v "$1" >/dev/null 2>&1
}

firmware_label() {
	if have_cmd nvram; then
		firmver=$(nvram get firmver 2>/dev/null || true)
		buildno=$(nvram get buildno 2>/dev/null || true)
		extendno=$(nvram get extendno 2>/dev/null || true)
		printf '%s %s %s' "$firmver" "$buildno" "$extendno"
	else
		printf 'unknown'
	fi
}

is_merlin_386_14_2() {
	label=$(firmware_label)
	case "$label" in
		*386*14_2*|*386.14_2*|*386*14.2*)
			return 0
			;;
		*)
			return 1
			;;
	esac
}

require_router_paths() {
	[ -d /jffs ] || die "/jffs is not available; enable JFFS on the router first"
	[ -d /opt ] || die "Entware /opt is not available; install Entware with amtm first"
}

run_compatibility_check() {
	if [ "$DRY_RUN" -eq 1 ]; then
		log "[dry-run] would run Merlin 386.14_2 compatibility check"
		return
	fi

	if ! "$REPO_DIR/scripts/check-merlin-386-compat.sh"; then
		[ "$FORCE" -eq 1 ] || die "compatibility check failed; rerun with --force only if you understand the warnings"
	fi
}

enable_merlin_basics() {
	run mkdir -p /jffs/scripts /jffs/addons
	run chmod 0755 /jffs/scripts /jffs/addons

	if have_cmd nvram; then
		current=$(nvram get jffs2_scripts 2>/dev/null || true)
		if [ "$current" != "1" ]; then
			log "Enabling Merlin custom scripts: jffs2_scripts=1"
			if [ "$DRY_RUN" -eq 0 ]; then
				nvram set jffs2_scripts=1
				nvram commit
			else
				log "[dry-run] nvram set jffs2_scripts=1 && nvram commit"
			fi
		else
			log "Merlin custom scripts already enabled"
		fi
	else
		log "nvram not found; skipping custom-script nvram setting"
	fi
}

apply_safe_addon_defaults() {
	if [ ! -f /usr/sbin/helper.sh ]; then
		log "Merlin helper not found; skipping custom Addons settings defaults"
		return
	fi

	if [ "$DRY_RUN" -eq 1 ]; then
		log "[dry-run] would set safe Merlin Addons defaults"
		return
	fi

	# shellcheck disable=SC1091
	. /usr/sbin/helper.sh
	am_settings_set rch_enabled 0
	am_settings_set rch_ks_enabled 1
	am_settings_set rch_ks_interval 10
	am_settings_set rch_reality_server_name vk.com
	am_settings_set rch_reality_dest vk.com:443
	am_settings_set rch_reality_fingerprint chrome
	am_settings_set rch_srv_listen 0.0.0.0
	am_settings_set rch_srv_port 443
	am_settings_set rch_srv_config "$REALITYCHAIN_HOME/xray-server.json"
}

install_realitychain() {
	args=
	if [ "$DRY_RUN" -eq 1 ]; then
		args="--dry-run"
	fi

	# shellcheck disable=SC2086
	"$REPO_DIR/scripts/install-merlin.sh" $args
}

write_install_report() {
	report=$REALITYCHAIN_HOME/install-386.14_2.txt

	if [ "$DRY_RUN" -eq 1 ]; then
		log "[dry-run] would write $report"
		return
	fi

	cat >"$report" <<EOF
RealityChain Asuswrt-Merlin 386.14_2 installation

Firmware detected: $(firmware_label)
Install directory: $REALITYCHAIN_HOME
Init script: $INIT_SCRIPT
WebUI: Tools -> RealityChain, when am_addons is available

Installed functions:
- Xray VLESS/REALITY client renderer
- Xray VLESS/REALITY server renderer
- Merlin WebUI page
- TPROXY transparent LAN routing
- Kill switch and Xray watchdog
- Blockchain policy-hash gate
- VK/Russia REALITY camouflage defaults

Default safety state:
- Tunnel autostart is disabled until Client setup is filled in.
- Kill switch is enabled by default.

Next steps:
1. Open Merlin WebUI: Tools -> RealityChain.
2. Fill Client setup with the real server values.
3. Optionally fill Server setup and click "Render server config".
4. Click "Apply and restart" after credentials are complete.
EOF
}

start_if_requested() {
	if [ "$START_AFTER_INSTALL" -ne 1 ]; then
		log "RealityChain installed but not started. Fill Client setup first, then click Apply and restart."
		return
	fi

	run "$INIT_SCRIPT" restart
}

while [ $# -gt 0 ]; do
	case "$1" in
		--dry-run)
			DRY_RUN=1
			;;
		--force)
			FORCE=1
			;;
		--start)
			START_AFTER_INSTALL=1
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

if ! is_merlin_386_14_2; then
	label=$(firmware_label)
	[ "$FORCE" -eq 1 ] || die "firmware does not look like Asuswrt-Merlin 386.14_2: $label"
	log "Continuing on non-386.14_2 firmware because --force was provided: $label"
fi

require_router_paths
run_compatibility_check
enable_merlin_basics
install_realitychain
apply_safe_addon_defaults
write_install_report
start_if_requested

log "RealityChain full installer for Asuswrt-Merlin 386.14_2 completed"
