#!/usr/bin/env python3
"""Validate and optionally render Linux XTLS-REALITY no-log server configs."""

from __future__ import annotations

import argparse
import json
import re
import sys
import uuid
from pathlib import Path
from typing import Dict, Mapping


PLACEHOLDER_RE = re.compile(r"\{\{([A-Z0-9_]+)\}\}")


def load_env(path: Path) -> Dict[str, str]:
    env: Dict[str, str] = {}
    for line_no, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            raise ValueError(f"{path}:{line_no}: expected KEY=VALUE")
        key, value = line.split("=", 1)
        env[key.strip()] = value.strip()
    return env


def render_template(template: str, values: Mapping[str, str]) -> str:
    def repl(match: re.Match[str]) -> str:
        key = match.group(1)
        if key not in values:
            raise KeyError(f"missing template value: {key}")
        return values[key]

    rendered = PLACEHOLDER_RE.sub(repl, template)
    leftover = PLACEHOLDER_RE.findall(rendered)
    if leftover:
        raise ValueError(f"unresolved placeholders: {sorted(set(leftover))}")
    return rendered


def assert_nolog(config: Mapping[object, object]) -> None:
    log = config.get("log")
    if not isinstance(log, dict):
        raise AssertionError("log section missing")
    if log.get("loglevel") != "none":
        raise AssertionError(f"expected loglevel none, got {log.get('loglevel')!r}")
    if log.get("access") != "none":
        raise AssertionError(f"expected access none, got {log.get('access')!r}")
    if log.get("error") != "none":
        raise AssertionError(f"expected error none, got {log.get('error')!r}")
    # Any stats object (even empty) enables the stats module — omit it entirely.
    if "stats" in config:
        raise AssertionError("stats section must be omitted for no-log builds")

    policy = config.get("policy")
    if isinstance(policy, dict):
        system = policy.get("system", {})
        if isinstance(system, dict):
            for key in (
                "statsInboundUplink",
                "statsInboundDownlink",
                "statsOutboundUplink",
                "statsOutboundDownlink",
            ):
                if system.get(key) is True:
                    raise AssertionError(f"policy.system.{key} must be false")


def assert_reality_inbound(config: Mapping[object, object]) -> None:
    inbounds = config.get("inbounds")
    if not isinstance(inbounds, list) or not inbounds:
        raise AssertionError("inbounds missing")
    inbound = inbounds[0]
    if inbound.get("protocol") != "vless":
        raise AssertionError("expected vless inbound")
    settings = inbound.get("settings") or {}
    clients = settings.get("clients") or []
    if not clients:
        raise AssertionError("no vless clients configured")
    for client in clients:
        if client.get("flow") != "xtls-rprx-vision":
            raise AssertionError("expected xtls-rprx-vision flow")
        uuid.UUID(str(client.get("id")))
    stream = inbound.get("streamSettings") or {}
    if stream.get("security") != "reality":
        raise AssertionError("expected reality security")
    reality = stream.get("realitySettings") or {}
    for key in ("dest", "serverNames", "privateKey", "shortIds"):
        if key not in reality:
            raise AssertionError(f"realitySettings.{key} missing")
    if reality.get("show") is not False:
        raise AssertionError("realitySettings.show must be false")


def validate_template_file(path: Path) -> None:
    text = path.read_text(encoding="utf-8")
    # Ensure the checked-in no-log template hard-codes the no-log policy.
    if '"loglevel": "none"' not in text:
        raise AssertionError(f"{path}: loglevel none missing")
    if '"access": "none"' not in text:
        raise AssertionError(f"{path}: access none missing")
    if '"error": "none"' not in text:
        raise AssertionError(f"{path}: error none missing")
    if re.search(r'"stats"\s*:', text):
        raise AssertionError(f"{path}: stats section must not be present")
    # Structural sanity with placeholder-safe dummy values.
    values = {
        "SERVER_LISTEN": "0.0.0.0",
        "SERVER_LISTEN_PORT": "443",
        "VLESS_UUID": "11111111-1111-4111-8111-111111111111",
        "REALITY_DEST": "www.cloudflare.com:443",
        "REALITY_SERVER_NAME": "www.cloudflare.com",
        "REALITY_PRIVATE_KEY": "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
        "REALITY_SHORT_ID": "0123456789abcdef",
    }
    config = json.loads(render_template(text, values))
    assert_nolog(config)
    assert_reality_inbound(config)


def cmd_validate_template(args: argparse.Namespace) -> int:
    validate_template_file(Path(args.template))
    print(f"ok: {args.template}")
    return 0


def cmd_render(args: argparse.Namespace) -> int:
    env = load_env(Path(args.env))
    defaults = {
        "SERVER_LISTEN": "0.0.0.0",
        "SERVER_LISTEN_PORT": env.get("SERVER_PORT", "443"),
        "SERVER_PORT": "443",
        "CLIENT_SOCKS_PORT": "10808",
        "CLIENT_HTTP_PORT": "10809",
        "REALITY_FINGERPRINT": "chrome",
    }
    merged = {**defaults, **env}
    text = Path(args.template).read_text(encoding="utf-8")
    rendered = render_template(text, merged)
    config = json.loads(rendered)
    if args.require_nolog:
        assert_nolog(config)
        assert_reality_inbound(config)
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(config, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {output}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    validate = sub.add_parser("validate-template", help="Validate a no-log server template")
    validate.add_argument(
        "--template",
        default="server/templates/xray-server-nolog.json.tpl",
    )
    validate.set_defaults(func=cmd_validate_template)

    render = sub.add_parser("render", help="Render template with env file")
    render.add_argument("--env", required=True)
    render.add_argument("--template", required=True)
    render.add_argument("--output", required=True)
    render.add_argument("--require-nolog", action="store_true")
    render.set_defaults(func=cmd_render)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        return args.func(args)
    except Exception as exc:  # noqa: BLE001 - CLI boundary
        print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
