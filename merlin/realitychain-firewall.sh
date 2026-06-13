#!/bin/sh
set -eu

ROOT="${REALITYCHAIN_ROOT:-/jffs/vpn-realitychain}"
ENV_FILE="$ROOT/realitychain.env"

if [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  . "$ENV_FILE"
fi

ENABLE_TRANSPARENT="${ENABLE_TRANSPARENT:-0}"
LAN_IFACE="${LAN_IFACE:-br0}"
DOKODEMO_PORT="${DOKODEMO_PORT:-12345}"
CHAIN_NAME="${CHAIN_NAME:-REALITYCHAIN}"
REALITYCHAIN_SERVER_IP="${REALITYCHAIN_SERVER_IP:-}"

log() {
  logger -t realitychain-firewall "$*"
}

need_iptables() {
  command -v iptables >/dev/null 2>&1 || {
    log "iptables not found"
    exit 1
  }
}

chain_exists() {
  iptables -t nat -L "$CHAIN_NAME" >/dev/null 2>&1
}

delete_jump_if_present() {
  while iptables -t nat -C PREROUTING -i "$LAN_IFACE" -p tcp -j "$CHAIN_NAME" >/dev/null 2>&1; do
    iptables -t nat -D PREROUTING -i "$LAN_IFACE" -p tcp -j "$CHAIN_NAME" || break
  done
}

stop_rules() {
  need_iptables
  delete_jump_if_present
  if chain_exists; then
    iptables -t nat -F "$CHAIN_NAME" || true
    iptables -t nat -X "$CHAIN_NAME" || true
  fi
}

add_bypass() {
  iptables -t nat -A "$CHAIN_NAME" -d "$1" -j RETURN
}

start_rules() {
  need_iptables

  if [ "$ENABLE_TRANSPARENT" != "1" ]; then
    log "transparent mode disabled"
    stop_rules
    exit 0
  fi

  stop_rules
  iptables -t nat -N "$CHAIN_NAME"

  # Avoid redirecting local, private, multicast, and reserved destinations.
  add_bypass 0.0.0.0/8
  add_bypass 10.0.0.0/8
  add_bypass 127.0.0.0/8
  add_bypass 169.254.0.0/16
  add_bypass 172.16.0.0/12
  add_bypass 192.168.0.0/16
  add_bypass 224.0.0.0/4
  add_bypass 240.0.0.0/4

  if [ -n "$REALITYCHAIN_SERVER_IP" ]; then
    add_bypass "$REALITYCHAIN_SERVER_IP"
  else
    log "REALITYCHAIN_SERVER_IP is unset; set it to avoid redirect loops"
  fi

  iptables -t nat -A "$CHAIN_NAME" -p tcp -j REDIRECT --to-ports "$DOKODEMO_PORT"
  iptables -t nat -A PREROUTING -i "$LAN_IFACE" -p tcp -j "$CHAIN_NAME"
  log "transparent redirect enabled on $LAN_IFACE tcp -> $DOKODEMO_PORT"
}

case "${1:-start}" in
  start)
    start_rules
    ;;
  stop)
    stop_rules
    ;;
  restart)
    stop_rules
    start_rules
    ;;
  *)
    echo "Usage: $0 {start|stop|restart}" >&2
    exit 2
    ;;
esac
