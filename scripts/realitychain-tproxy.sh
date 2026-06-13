#!/bin/sh
set -eu

PROGRAM_NAME=${0##*/}
CHAIN=REALITYCHAIN
TABLE_ID=${REALITYCHAIN_TABLE_ID:-100}
MARK=${REALITYCHAIN_MARK:-1}
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
	iptables -t mangle -C "$@" >/dev/null 2>&1
}

add_return_routes() {
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
		iptables -t mangle -A "$CHAIN" -d "$cidr" -j RETURN
	done

	if printf '%s' "${SERVER_ADDRESS:-}" | grep -Eq '^[0-9.]+$'; then
		iptables -t mangle -A "$CHAIN" -d "$SERVER_ADDRESS" -j RETURN
	fi
}

start_rules() {
	need_cmd ip
	need_cmd iptables

	LAN_IFACE=${LAN_IFACE:-br0}
	LOCAL_TPROXY_PORT=${LOCAL_TPROXY_PORT:-12345}

	modprobe xt_TPROXY >/dev/null 2>&1 || true
	modprobe xt_socket >/dev/null 2>&1 || true

	ip rule show | grep -q "fwmark $MARK lookup $TABLE_ID" || ip rule add fwmark "$MARK" table "$TABLE_ID"
	ip route show table "$TABLE_ID" | grep -q '^local 0.0.0.0/0' || ip route add local 0.0.0.0/0 dev lo table "$TABLE_ID"

	iptables -t mangle -N "$CHAIN" >/dev/null 2>&1 || true
	iptables -t mangle -F "$CHAIN"
	add_return_routes
	iptables -t mangle -A "$CHAIN" -p tcp -j TPROXY --on-port "$LOCAL_TPROXY_PORT" --tproxy-mark "$MARK"
	iptables -t mangle -A "$CHAIN" -p udp -j TPROXY --on-port "$LOCAL_TPROXY_PORT" --tproxy-mark "$MARK"

	iptables_has_rule PREROUTING -i "$LAN_IFACE" -p tcp -j "$CHAIN" || iptables -t mangle -A PREROUTING -i "$LAN_IFACE" -p tcp -j "$CHAIN"
	iptables_has_rule PREROUTING -i "$LAN_IFACE" -p udp -j "$CHAIN" || iptables -t mangle -A PREROUTING -i "$LAN_IFACE" -p udp -j "$CHAIN"
}

stop_rules() {
	LAN_IFACE=${LAN_IFACE:-br0}

	if command -v iptables >/dev/null 2>&1; then
		while iptables_has_rule PREROUTING -i "$LAN_IFACE" -p tcp -j "$CHAIN"; do
			iptables -t mangle -D PREROUTING -i "$LAN_IFACE" -p tcp -j "$CHAIN"
		done
		while iptables_has_rule PREROUTING -i "$LAN_IFACE" -p udp -j "$CHAIN"; do
			iptables -t mangle -D PREROUTING -i "$LAN_IFACE" -p udp -j "$CHAIN"
		done
		iptables -t mangle -F "$CHAIN" >/dev/null 2>&1 || true
		iptables -t mangle -X "$CHAIN" >/dev/null 2>&1 || true
	fi

	if command -v ip >/dev/null 2>&1; then
		ip rule del fwmark "$MARK" table "$TABLE_ID" >/dev/null 2>&1 || true
		ip route flush table "$TABLE_ID" >/dev/null 2>&1 || true
	fi
}

command_name=${1:-}
env_file=${2:-$DEFAULT_ENV}

case "$command_name" in
	start)
		load_env "$env_file"
		start_rules
		;;
	stop)
		load_env "$env_file"
		stop_rules
		;;
	*)
		printf 'Usage: %s {start|stop} [env-file]\n' "$PROGRAM_NAME" >&2
		exit 2
		;;
esac
