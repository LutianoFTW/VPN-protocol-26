#!/bin/sh
set -u

PROGRAM_NAME=${0##*/}
FAILURES=0
WARNINGS=0

say() {
	printf '%s\n' "$*"
}

ok() {
	say "OK: $*"
}

warn() {
	WARNINGS=$((WARNINGS + 1))
	say "WARN: $*"
}

fail() {
	FAILURES=$((FAILURES + 1))
	say "FAIL: $*"
}

have_cmd() {
	command -v "$1" >/dev/null 2>&1
}

require_cmd() {
	if have_cmd "$1"; then
		ok "found $1"
	else
		fail "missing $1"
	fi
}

xray_asset_arch() {
	case "$(uname -m)" in
		x86_64|amd64)
			printf '64'
			;;
		aarch64|arm64)
			printf 'arm64-v8a'
			;;
		armv7l|armv7*|armv8l)
			printf 'arm32-v7a'
			;;
		armv6l)
			printf 'arm32-v6'
			;;
		*)
			return 1
			;;
	esac
}

check_firmware() {
	if have_cmd nvram; then
		firmver=$(nvram get firmver 2>/dev/null || true)
		buildno=$(nvram get buildno 2>/dev/null || true)
		extendno=$(nvram get extendno 2>/dev/null || true)
		rc_support=$(nvram get rc_support 2>/dev/null || true)
		say "Detected firmware fields: firmver=${firmver:-unknown} buildno=${buildno:-unknown} extendno=${extendno:-unknown}"

		case "$buildno $extendno $firmver" in
			*386*14_2*|*386.14_2*|*386*14.2*)
				ok "firmware appears to be Asuswrt-Merlin 386.14_2"
				;;
			*386*)
				warn "firmware appears to be Merlin 386.x, but not specifically 386.14_2"
				;;
			*)
				warn "could not confirm Merlin 386.14_2 from nvram fields"
				;;
		esac

		if printf '%s' "$rc_support" | grep -q am_addons; then
			ok "firmware advertises am_addons WebUI support"
		else
			warn "firmware does not advertise am_addons; CLI service may work but WebUI tab will be skipped"
		fi
	else
		warn "nvram command not found; not running on a standard Merlin shell"
	fi
}

check_paths() {
	[ -d /jffs ] && ok "/jffs is available" || fail "/jffs is not available"
	[ -d /opt ] && ok "Entware /opt is available" || fail "Entware /opt is not available"
	[ -d /www/user ] && ok "Merlin /www/user page directory is available" || warn "/www/user not found; WebUI mount can only be checked on the router after httpd starts"
	[ -f /usr/sbin/helper.sh ] && ok "Merlin addon helper exists" || warn "/usr/sbin/helper.sh not found; WebUI integration will be skipped"
}

check_arch() {
	arch=$(uname -m)
	if asset_arch=$(xray_asset_arch); then
		ok "CPU arch $arch maps to Xray-linux-$asset_arch.zip"
	else
		fail "CPU arch $arch is not supported by automatic Xray install"
	fi
}

check_tproxy() {
	require_cmd iptables
	require_cmd ip
	require_cmd modprobe

	if have_cmd modprobe; then
		modprobe xt_TPROXY >/dev/null 2>&1 && ok "xt_TPROXY module loads" || warn "xt_TPROXY did not load; TPROXY may be unavailable on this model"
		modprobe xt_socket >/dev/null 2>&1 && ok "xt_socket module loads" || warn "xt_socket did not load; TPROXY socket matching may be unavailable"
	fi

	if have_cmd iptables && iptables -t mangle -j TPROXY -h >/dev/null 2>&1; then
		ok "iptables exposes the TPROXY target"
	else
		warn "iptables TPROXY target was not confirmed"
	fi
}

check_tools() {
	require_cmd sh
	require_cmd curl
	require_cmd unzip
	require_cmd sed
	require_cmd awk
	if have_cmd sha256sum || have_cmd openssl; then
		ok "found sha256sum or openssl for policy hashing"
	else
		fail "missing sha256sum or openssl for policy hashing"
	fi
}

check_firmware
check_paths
check_arch
check_tools
check_tproxy

say ""
if [ "$FAILURES" -gt 0 ]; then
	say "$PROGRAM_NAME: incompatible or incomplete environment ($FAILURES failure(s), $WARNINGS warning(s))"
	exit 1
fi

if [ "$WARNINGS" -gt 0 ]; then
	say "$PROGRAM_NAME: likely usable with caveats ($WARNINGS warning(s))"
	exit 0
fi

say "$PROGRAM_NAME: compatible with RealityChain requirements"
