#!/bin/sh
set -eu

PROGRAM_NAME=${0##*/}
REALITYCHAIN_HOME=${REALITYCHAIN_HOME:-/jffs/addons/realitychain}
DEFAULT_ENV=$REALITYCHAIN_HOME/client.env
XRAY_PID_FILE=${XRAY_PID_FILE:-/var/run/realitychain-xray.pid}
WATCHDOG_PID_FILE=${WATCHDOG_PID_FILE:-/var/run/realitychain-watchdog.pid}

log() {
	if command -v logger >/dev/null 2>&1; then
		logger -t RealityChain "$*"
	else
		printf '%s\n' "$*" >&2
	fi
}

load_env() {
	env_file=${1:-$DEFAULT_ENV}
	[ -f "$env_file" ] || {
		log "environment file not found: $env_file"
		exit 1
	}
	# shellcheck disable=SC1090
	. "$env_file"
}

tunnel_running() {
	[ -f "$XRAY_PID_FILE" ] || return 1
	pid=$(cat "$XRAY_PID_FILE" 2>/dev/null || true)
	[ -n "$pid" ] || return 1
	kill -0 "$pid" >/dev/null 2>&1
}

update_webui_status() {
	status=$1
	if [ -x "$REALITYCHAIN_HOME/realitychain-webui.sh" ]; then
		"$REALITYCHAIN_HOME/realitychain-webui.sh" status "$status" >/dev/null 2>&1 || true
	fi
}

run_watchdog() {
	env_file=$1
	load_env "$env_file"
	KILLSWITCH_ENABLED=${KILLSWITCH_ENABLED:-1}
	KILLSWITCH_WATCH_INTERVAL=${KILLSWITCH_WATCH_INTERVAL:-10}

	[ "$KILLSWITCH_ENABLED" = "1" ] || exit 0

	while :; do
		if ! tunnel_running; then
			log "tunnel process missing; engaging kill switch"
			"$REALITYCHAIN_HOME/realitychain-killswitch.sh" engage "$env_file" >/dev/null 2>&1 || true
			update_webui_status killswitch_engaged
			exit 0
		fi
		sleep "$KILLSWITCH_WATCH_INTERVAL"
	done
}

start_watchdog() {
	env_file=$1
	if [ -f "$WATCHDOG_PID_FILE" ]; then
		old_pid=$(cat "$WATCHDOG_PID_FILE" 2>/dev/null || true)
		if [ -n "$old_pid" ] && kill -0 "$old_pid" >/dev/null 2>&1; then
			exit 0
		fi
		rm -f "$WATCHDOG_PID_FILE"
	fi

	"$0" run "$env_file" >/tmp/realitychain-watchdog.log 2>&1 &
	echo $! >"$WATCHDOG_PID_FILE"
}

stop_watchdog() {
	if [ -f "$WATCHDOG_PID_FILE" ]; then
		pid=$(cat "$WATCHDOG_PID_FILE" 2>/dev/null || true)
		if [ -n "$pid" ]; then
			kill "$pid" >/dev/null 2>&1 || true
		fi
		rm -f "$WATCHDOG_PID_FILE"
	fi
}

command_name=${1:-}
env_file=${2:-$DEFAULT_ENV}

case "$command_name" in
	start)
		start_watchdog "$env_file"
		;;
	stop)
		stop_watchdog
		;;
	run)
		run_watchdog "$env_file"
		;;
	*)
		printf 'Usage: %s {start|stop|run} [env-file]\n' "$PROGRAM_NAME" >&2
		exit 2
		;;
esac
