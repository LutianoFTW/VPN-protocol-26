#!/usr/bin/env python3
"""RealityChain ledger and Xray/REALITY config generator."""

from __future__ import annotations

import argparse
import hmac
import hashlib
import json
import os
import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional

ZERO_HASH = "0" * 64
DEFAULT_FLOW = "xtls-rprx-vision"


JsonObject = Dict[str, Any]


def canonical_json(value: Any) -> bytes:
    return json.dumps(
        value,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=True,
    ).encode("utf-8")


def sha256_hex(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


def payload_hash(payload: JsonObject) -> str:
    return sha256_hex(canonical_json(payload))


def block_hash(block: JsonObject) -> str:
    material = {
        "index": block["index"],
        "timestamp": block["timestamp"],
        "prev_hash": block["prev_hash"],
        "payload_hash": block["payload_hash"],
        "payload": block["payload"],
    }
    return sha256_hex(canonical_json(material))


def hmac_signature(block_hash_value: str, key: str) -> str:
    return hmac.new(
        key.encode("utf-8"),
        block_hash_value.encode("ascii"),
        hashlib.sha256,
    ).hexdigest()


def read_hmac_key(env_name: Optional[str]) -> Optional[str]:
    if not env_name:
        return None
    key = os.environ.get(env_name)
    if not key:
        raise ValueError(f"environment variable {env_name!r} is not set")
    return key


def load_blocks(path: Path) -> List[JsonObject]:
    if not path.exists():
        return []

    blocks: List[JsonObject] = []
    with path.open("r", encoding="utf-8") as ledger:
        for line_number, line in enumerate(ledger, start=1):
            line = line.strip()
            if not line:
                continue
            try:
                block = json.loads(line)
            except json.JSONDecodeError as exc:
                raise ValueError(f"{path}:{line_number}: invalid JSON: {exc}") from exc
            if not isinstance(block, dict):
                raise ValueError(f"{path}:{line_number}: block must be a JSON object")
            blocks.append(block)
    return blocks


def verify_blocks(blocks: Iterable[JsonObject], hmac_key: Optional[str] = None) -> List[JsonObject]:
    verified: List[JsonObject] = []
    prev_hash = ZERO_HASH

    for expected_index, block in enumerate(blocks):
        required = {"index", "timestamp", "prev_hash", "payload_hash", "payload", "block_hash"}
        missing = required - set(block)
        if missing:
            raise ValueError(f"block {expected_index}: missing keys: {sorted(missing)}")

        if block["index"] != expected_index:
            raise ValueError(f"block {expected_index}: expected index {expected_index}, got {block['index']}")
        if block["prev_hash"] != prev_hash:
            raise ValueError(f"block {expected_index}: previous hash mismatch")
        if payload_hash(block["payload"]) != block["payload_hash"]:
            raise ValueError(f"block {expected_index}: payload hash mismatch")

        calculated_hash = block_hash(block)
        if calculated_hash != block["block_hash"]:
            raise ValueError(f"block {expected_index}: block hash mismatch")

        if hmac_key is not None:
            expected_signature = hmac_signature(calculated_hash, hmac_key)
            if block.get("hmac_sha256") != expected_signature:
                raise ValueError(f"block {expected_index}: HMAC signature mismatch")

        prev_hash = calculated_hash
        verified.append(block)

    return verified


def verify_ledger(path: Path, hmac_key: Optional[str] = None) -> List[JsonObject]:
    return verify_blocks(load_blocks(path), hmac_key=hmac_key)


def append_block(path: Path, payload: JsonObject, hmac_key: Optional[str] = None) -> JsonObject:
    blocks = verify_ledger(path, hmac_key=hmac_key)
    block = {
        "index": len(blocks),
        "timestamp": utc_now(),
        "prev_hash": blocks[-1]["block_hash"] if blocks else ZERO_HASH,
        "payload_hash": payload_hash(payload),
        "payload": payload,
    }
    calculated_hash = block_hash(block)
    block["block_hash"] = calculated_hash
    if hmac_key is not None:
        block["hmac_sha256"] = hmac_signature(calculated_hash, hmac_key)

    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as ledger:
        ledger.write(json.dumps(block, sort_keys=True, separators=(",", ":")) + "\n")
    return block


def require_uuid(value: str) -> str:
    try:
        return str(uuid.UUID(value))
    except ValueError as exc:
        raise argparse.ArgumentTypeError(f"invalid UUID: {value}") from exc


def parse_csv(value: str) -> List[str]:
    return [part.strip() for part in value.split(",") if part.strip()]


def latest_peer_payload(blocks: Iterable[JsonObject], peer_id: str) -> JsonObject:
    for block in reversed(list(blocks)):
        payload = block["payload"]
        if payload.get("type") == "peer" and payload.get("peer_id") == peer_id:
            if payload.get("status", "active") != "active":
                raise ValueError(f"peer {peer_id!r} is not active")
            return payload
    raise ValueError(f"peer {peer_id!r} not found in ledger")


def vless_reality_outbound(peer: JsonObject) -> JsonObject:
    xray = peer["xray"]
    return {
        "tag": "reality-out",
        "protocol": "vless",
        "settings": {
            "vnext": [
                {
                    "address": xray["server_address"],
                    "port": xray["server_port"],
                    "users": [
                        {
                            "id": xray["uuid"],
                            "encryption": "none",
                            "flow": xray.get("flow", DEFAULT_FLOW),
                        }
                    ],
                }
            ]
        },
        "streamSettings": {
            "network": "tcp",
            "security": "reality",
            "realitySettings": {
                "show": False,
                "fingerprint": xray.get("fingerprint", "chrome"),
                "serverName": xray["server_name"],
                "publicKey": xray["public_key"],
                "shortId": xray["short_id"],
                "spiderX": xray.get("spider_x", "/"),
            },
        },
    }


def client_config(peer: JsonObject, args: argparse.Namespace) -> JsonObject:
    inbounds: List[JsonObject] = [
        {
            "tag": "socks-in",
            "listen": args.listen_host,
            "port": args.socks_port,
            "protocol": "socks",
            "settings": {"auth": "noauth", "udp": True},
        },
        {
            "tag": "http-in",
            "listen": args.listen_host,
            "port": args.http_port,
            "protocol": "http",
            "settings": {},
        },
    ]

    if args.transparent:
        inbounds.append(
            {
                "tag": "transparent-in",
                "listen": "127.0.0.1",
                "port": args.transparent_port,
                "protocol": "dokodemo-door",
                "settings": {"network": "tcp", "followRedirect": True},
                "sniffing": {"enabled": True, "destOverride": ["http", "tls"]},
            }
        )

    return {
        "log": {"loglevel": args.loglevel},
        "inbounds": inbounds,
        "outbounds": [
            vless_reality_outbound(peer),
            {"tag": "direct", "protocol": "freedom", "settings": {}},
            {"tag": "block", "protocol": "blackhole", "settings": {}},
        ],
        "routing": {
            "domainStrategy": "IPIfNonMatch",
            "rules": [{"type": "field", "outboundTag": "reality-out", "network": "tcp"}],
        },
    }


def server_config(args: argparse.Namespace) -> JsonObject:
    clients = [
        {"id": client_uuid, "flow": args.flow, "email": f"client-{index + 1}"}
        for index, client_uuid in enumerate(args.client)
    ]
    return {
        "log": {"loglevel": args.loglevel},
        "inbounds": [
            {
                "tag": "vless-reality-in",
                "listen": args.listen,
                "port": args.port,
                "protocol": "vless",
                "settings": {"clients": clients, "decryption": "none"},
                "streamSettings": {
                    "network": "tcp",
                    "security": "reality",
                    "realitySettings": {
                        "show": False,
                        "dest": args.dest,
                        "xver": 0,
                        "serverNames": args.server_name,
                        "privateKey": args.private_key,
                        "shortIds": args.short_id,
                    },
                },
                "sniffing": {"enabled": True, "destOverride": ["http", "tls"]},
            }
        ],
        "outbounds": [
            {"tag": "direct", "protocol": "freedom", "settings": {}},
            {"tag": "block", "protocol": "blackhole", "settings": {}},
        ],
    }


def write_json_output(config: JsonObject, output: str) -> None:
    rendered = json.dumps(config, indent=2, sort_keys=False) + "\n"
    if output == "-":
        sys.stdout.write(rendered)
    else:
        Path(output).write_text(rendered, encoding="utf-8")


def cmd_init(args: argparse.Namespace) -> int:
    hmac_key = read_hmac_key(args.hmac_key_env)
    payload = {
        "type": "genesis",
        "network": args.network,
        "operator": args.operator,
        "created_by": "realitychain.py",
        "schema": 1,
    }
    block = append_block(Path(args.ledger), payload, hmac_key=hmac_key)
    print(block["block_hash"])
    return 0


def cmd_append_peer(args: argparse.Namespace) -> int:
    hmac_key = read_hmac_key(args.hmac_key_env)
    client_uuid = args.uuid or str(uuid.uuid4())
    payload = {
        "type": "peer",
        "peer_id": args.peer_id,
        "status": "active",
        "tag": args.tag,
        "xray": {
            "server_address": args.server_address,
            "server_port": args.server_port,
            "uuid": require_uuid(client_uuid),
            "public_key": args.public_key,
            "server_name": args.server_name,
            "short_id": args.short_id,
            "fingerprint": args.fingerprint,
            "spider_x": args.spider_x,
            "flow": args.flow,
        },
    }
    block = append_block(Path(args.ledger), payload, hmac_key=hmac_key)
    print(block["block_hash"])
    return 0


def cmd_verify(args: argparse.Namespace) -> int:
    hmac_key = read_hmac_key(args.hmac_key_env)
    blocks = verify_ledger(Path(args.ledger), hmac_key=hmac_key)
    head = blocks[-1]["block_hash"] if blocks else ZERO_HASH
    print(f"verified_blocks={len(blocks)}")
    print(f"head_hash={head}")
    return 0


def cmd_render_client(args: argparse.Namespace) -> int:
    hmac_key = read_hmac_key(args.hmac_key_env)
    blocks = verify_ledger(Path(args.ledger), hmac_key=hmac_key)
    peer = latest_peer_payload(blocks, args.peer_id)
    write_json_output(client_config(peer, args), args.output)
    return 0


def cmd_render_server(args: argparse.Namespace) -> int:
    write_json_output(server_config(args), args.output)
    return 0


def cmd_uuid(_: argparse.Namespace) -> int:
    print(uuid.uuid4())
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subcommands = parser.add_subparsers(dest="command", required=True)

    init = subcommands.add_parser("init", help="initialize a new ledger")
    init.add_argument("--ledger", required=True)
    init.add_argument("--network", required=True)
    init.add_argument("--operator", required=True)
    init.add_argument("--hmac-key-env")
    init.set_defaults(func=cmd_init)

    append_peer = subcommands.add_parser("append-peer", help="append an active router peer")
    append_peer.add_argument("--ledger", required=True)
    append_peer.add_argument("--peer-id", required=True)
    append_peer.add_argument("--tag", default="asus-merlin")
    append_peer.add_argument("--server-address", required=True)
    append_peer.add_argument("--server-port", type=int, default=443)
    append_peer.add_argument("--uuid", type=require_uuid)
    append_peer.add_argument("--public-key", required=True)
    append_peer.add_argument("--server-name", required=True)
    append_peer.add_argument("--short-id", required=True)
    append_peer.add_argument("--fingerprint", default="chrome")
    append_peer.add_argument("--spider-x", default="/")
    append_peer.add_argument("--flow", default=DEFAULT_FLOW)
    append_peer.add_argument("--hmac-key-env")
    append_peer.set_defaults(func=cmd_append_peer)

    verify = subcommands.add_parser("verify", help="verify the ledger hash chain")
    verify.add_argument("--ledger", required=True)
    verify.add_argument("--hmac-key-env")
    verify.set_defaults(func=cmd_verify)

    render_client = subcommands.add_parser("render-client", help="render an Xray client config")
    render_client.add_argument("--ledger", required=True)
    render_client.add_argument("--peer-id", required=True)
    render_client.add_argument("--output", default="-")
    render_client.add_argument("--listen-host", default="127.0.0.1")
    render_client.add_argument("--socks-port", type=int, default=10808)
    render_client.add_argument("--http-port", type=int, default=10809)
    render_client.add_argument("--transparent-port", type=int, default=12345)
    render_client.add_argument("--transparent", action="store_true")
    render_client.add_argument("--loglevel", default="warning")
    render_client.add_argument("--hmac-key-env")
    render_client.set_defaults(func=cmd_render_client)

    render_server = subcommands.add_parser("render-server", help="render an Xray server config")
    render_server.add_argument("--output", default="-")
    render_server.add_argument("--listen", default="0.0.0.0")
    render_server.add_argument("--port", type=int, default=443)
    render_server.add_argument("--private-key", required=True)
    render_server.add_argument("--dest", default="www.microsoft.com:443")
    render_server.add_argument("--server-name", type=parse_csv, default=["www.microsoft.com"])
    render_server.add_argument("--short-id", type=parse_csv, required=True)
    render_server.add_argument("--client", action="append", type=require_uuid, required=True)
    render_server.add_argument("--flow", default=DEFAULT_FLOW)
    render_server.add_argument("--loglevel", default="warning")
    render_server.set_defaults(func=cmd_render_server)

    generate_uuid = subcommands.add_parser("uuid", help="generate a UUID for a VLESS client")
    generate_uuid.set_defaults(func=cmd_uuid)

    return parser


def main(argv: Optional[List[str]] = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        return args.func(args)
    except (OSError, ValueError, argparse.ArgumentTypeError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
