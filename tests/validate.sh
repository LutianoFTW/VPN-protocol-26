#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP_DIR=${TMPDIR:-/tmp}/realitychain-validate.$$

cleanup() {
	rm -rf "$TMP_DIR"
}
trap cleanup EXIT INT TERM

fail() {
	printf 'validate: %s\n' "$*" >&2
	exit 1
}

check_shell_syntax() {
	for script in "$ROOT_DIR"/scripts/*.sh "$ROOT_DIR"/scripts/realitychainctl; do
		sh -n "$script" || fail "shell syntax failed for $script"
	done
}

check_template_variables_documented() {
	vars=$(sed -n 's/.*{{\([A-Z0-9_][A-Z0-9_]*\)}}.*/\1/p' "$ROOT_DIR"/templates/*.tpl | sort -u)
	for var_name in $vars; do
		grep -q "^$var_name=" "$ROOT_DIR/examples/client.env" || fail "template variable $var_name missing from examples/client.env"
	done
}

check_rendered_json() {
	mkdir -p "$TMP_DIR"
	REALITYCHAIN_TEMPLATE_DIR="$ROOT_DIR/templates" \
		"$ROOT_DIR/scripts/realitychainctl" render-client "$ROOT_DIR/examples/client.env" "$TMP_DIR/client.json" >/dev/null
	REALITYCHAIN_TEMPLATE_DIR="$ROOT_DIR/templates" \
		"$ROOT_DIR/scripts/realitychainctl" render-server "$ROOT_DIR/examples/client.env" "$TMP_DIR/server.json" >/dev/null

	if command -v python3 >/dev/null 2>&1; then
		python3 -m json.tool "$TMP_DIR/client.json" >/dev/null
		python3 -m json.tool "$TMP_DIR/server.json" >/dev/null
	elif command -v jq >/dev/null 2>&1; then
		jq . "$TMP_DIR/client.json" >/dev/null
		jq . "$TMP_DIR/server.json" >/dev/null
	else
		printf 'validate: skipping JSON parser check; python3 or jq not found\n' >&2
	fi

	if grep -q 'geoip:' "$TMP_DIR/client.json"; then
		fail "rendered client config depends on external geoip assets"
	fi
}

check_policy_hash() {
	hash=$("$ROOT_DIR/scripts/realitychainctl" policy-hash "$ROOT_DIR/examples/policy.json")
	printf '%s' "$hash" | grep -Eq '^0x[0-9a-f]{64}$' || fail "invalid policy hash format: $hash"
}

check_webui_settings() {
	[ -f "$ROOT_DIR/webui/RealityChain.asp" ] || fail "missing Merlin WebUI page"

	keys=$(
		{
			sed -n 's/.*custom_settings\.\([A-Za-z0-9_-][A-Za-z0-9_-]*\).*/\1/p' "$ROOT_DIR/webui/RealityChain.asp"
			sed -n 's/.*am_settings_[gs]et \([A-Za-z0-9_-][A-Za-z0-9_-]*\).*/\1/p' "$ROOT_DIR/scripts/realitychain-webui.sh"
			sed -n 's/.*setting_[a-z_]* \([A-Za-z0-9_-][A-Za-z0-9_-]*\).*/\1/p' "$ROOT_DIR/scripts/realitychain-webui.sh"
		} | sort -u
	)

	for key in $keys; do
		case "$key" in
			rch_*)
				[ "${#key}" -le 29 ] || fail "Merlin custom setting key too long: $key"
				;;
		esac
	done

	ids=$(sed -n 's/.*id="\([^"]*\)".*/\1/p' "$ROOT_DIR/webui/RealityChain.asp" | sort)
	duplicates=$(printf '%s\n' "$ids" | uniq -d)
	[ -z "$duplicates" ] || fail "duplicate WebUI element id(s): $duplicates"

	grep -q 'Client setup - router outbound tunnel' "$ROOT_DIR/webui/RealityChain.asp" || fail "WebUI missing client setup section"
	grep -q 'Server setup - Xray VLESS REALITY inbound' "$ROOT_DIR/webui/RealityChain.asp" || fail "WebUI missing server setup section"
	grep -q "restart_realitychainsrv" "$ROOT_DIR/webui/RealityChain.asp" || fail "WebUI missing server render action"
	grep -q "realitychainsrv:restart" "$ROOT_DIR/scripts/realitychain-webui.sh" || fail "backend missing server render event handler"
}

check_xray_arch_mapping() {
	grep -q "arm64-v8a" "$ROOT_DIR/scripts/install-merlin.sh" || fail "installer missing Xray ARM64 asset mapping"
	grep -q "arm64-v8a" "$ROOT_DIR/scripts/check-merlin-386-compat.sh" || fail "compat checker missing Xray ARM64 asset mapping"
}

check_shell_syntax
check_template_variables_documented
check_rendered_json
check_policy_hash
check_webui_settings
check_xray_arch_mapping

printf 'validation passed\n'
