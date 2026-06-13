#!/bin/sh
set -eu

PROGRAM_NAME=${0##*/}
CHAIN=REALITYCHAIN_KILLSWITCH
DEFAULT_ENV=/jffs/addons/realitychain/client.env

die() {
	printf '%s: %s\n' "$PROGRAM_NAME" "$*" >&2
	exit 1
}

load_env() {
	env_file=${1:-$DEFAULT_ENV}
	[ -f "$env_file" ] || die "environment file not found: $env_file"
	# shellcheck disable=SC1090
	. "$env_file"
}

need_cmd() {
	command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

iptables_has_rule() {
	iptables -t filter -C "$@" >/dev/null 2>&1
}

add_private_returns() {
	for cidr in \
		0.0.0.0/8 \
		10.0.0.0/8 \
		100.64.0.0/10 \
		127.0.0.0/8 \
		169.254.0.0/16 \
		172.16.0.0/12 \
		192.168.0.0/16 \
		224.0.0.0/4 \
		240.0.0.0/4
	do
		iptables -t filter -A "$CHAIN" -d "$cidr" -j RETURN
	done
}

engage() {
	need_cmd iptables

	LAN_IFACE=${LAN_IFACE:-br0}
	KILLSWITCH_REJECT_WITH=${KILLSWITCH_REJECT_WITH:-icmp-port-unreachable}

	iptables -t filter -N "$CHAIN" >/dev/null 2>&1 || true
	iptables -t filter -F "$CHAIN"
	add_private_returns
	iptables -t filter -A "$CHAIN" -j REJECT --reject-with "$KILLSWITCH_REJECT_WITH"

	iptables_has_rule FORWARD -i "$LAN_IFACE" -j "$CHAIN" || iptables -t filter -I FORWARD 1 -i "$LAN_IFACE" -j "$CHAIN"
	printf 'killswitch engaged on %s\n' "$LAN_IFACE"
}

clear_rules() {
	LAN_IFACE=${LAN_IFACE:-br0}

	if command -v iptables >/dev/null 2>&1; then
		while iptables_has_rule FORWARD -i "$LAN_IFACE" -j "$CHAIN"; do
			iptables -t filter -D FORWARD -i "$LAN_IFACE" -j "$CHAIN"
		done
		iptables -t filter -F "$CHAIN" >/dev/null 2>&1 || true
		iptables -t filter -X "$CHAIN" >/dev/null 2>&1 || true
	fi
	printf 'killswitch cleared on %s\n' "$LAN_IFACE"
}

status() {
	LAN_IFACE=${LAN_IFACE:-br0}

	if command -v iptables >/dev/null 2>&1 && iptables_has_rule FORWARD -i "$LAN_IFACE" -j "$CHAIN"; then
		printf 'engaged\n'
	else
		printf 'clear\n'
	fi
}

command_name=${1:-}
env_file=${2:-$DEFAULT_ENV}

case "$command_name" in
	engage)
		load_env "$env_file"
		engage
		;;
	clear|disengage)
		load_env "$env_file"
		clear_rules
		;;
	status)
		load_env "$env_file"
		status
		;;
	*)
		printf 'Usage: %s {engage|clear|status} [env-file]\n' "$PROGRAM_NAME" >&2
		exit 2
		;;
esac
