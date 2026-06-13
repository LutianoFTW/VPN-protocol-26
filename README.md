# RealityChain VPN for AsusWRT-Merlin

RealityChain is a Merlin-router deployable VPN stack built around
[Xray-core](https://github.com/XTLS/Xray-core) VLESS + REALITY. It includes:

- Xray/REALITY server and AsusWRT-Merlin client configuration templates.
- A Merlin installer that runs Xray from `/opt` and integrates with `/jffs/scripts`.
- An optional transparent LAN gateway mode using Merlin `iptables` hooks.
- A tamper-evident "blockchain" ledger for tunnel policy/configuration records.

## Security model

REALITY is the tunnel security layer. The blockchain component in this repository
does not replace TLS, X25519, or Xray's VLESS/REALITY authentication. Instead,
`tools/realitychain.py` creates a SHA-256 hash chain of tunnel records and can
protect each block with an HMAC signature. Operators can verify that router
configuration inputs were not silently changed before rendering or installing
them, and can anchor block hashes into a public blockchain or other external
notary if required.

## Repository layout

```text
docs/
  SECURITY.md                 Security model and threat boundaries
merlin/
  realitychain-firewall.sh    Optional transparent gateway firewall hook
  templates/                  Client and server Xray config templates
scripts/
  install-merlin.sh           AsusWRT-Merlin installer
tools/
  realitychain.py             Ledger and Xray config generator
tests/
  test_realitychain.py        Unit tests for the ledger/config generator
```

## Quick start

### 1. Generate a router client record

```sh
export REALITYCHAIN_LEDGER_KEY='replace-with-a-long-random-secret'

python3 tools/realitychain.py init \
  --ledger ./tunnels.chain.jsonl \
  --network production \
  --operator admin@example.com

python3 tools/realitychain.py append-peer \
  --ledger ./tunnels.chain.jsonl \
  --peer-id asus-main-router \
  --server-address vpn.example.com \
  --server-port 443 \
  --uuid 00000000-0000-0000-0000-000000000000 \
  --public-key SERVER_REALITY_PUBLIC_KEY \
  --server-name www.microsoft.com \
  --short-id abcdef0123456789 \
  --hmac-key-env REALITYCHAIN_LEDGER_KEY

python3 tools/realitychain.py verify \
  --ledger ./tunnels.chain.jsonl \
  --hmac-key-env REALITYCHAIN_LEDGER_KEY

python3 tools/realitychain.py render-client \
  --ledger ./tunnels.chain.jsonl \
  --peer-id asus-main-router \
  --listen-host 0.0.0.0 \
  --transparent \
  --output ./client.json
```

### 2. Install on AsusWRT-Merlin

Copy this repository and `client.json` to the router, then run:

```sh
chmod +x scripts/install-merlin.sh
./scripts/install-merlin.sh --config ./client.json
```

The installer writes runtime files under `/jffs/vpn-realitychain`, installs an
Entware-style service at `/opt/etc/init.d/S24realitychain-xray`, and adds managed
Merlin hooks to `/jffs/scripts/services-start` and `/jffs/scripts/firewall-start`.

Transparent gateway mode is disabled by default. To enable it after installing:

```sh
vi /jffs/vpn-realitychain/realitychain.env
# Set ENABLE_TRANSPARENT=1 and REALITYCHAIN_SERVER_IP=<server-ip>

/jffs/vpn-realitychain/bin/realitychain-firewall.sh restart
/opt/etc/init.d/S24realitychain-xray restart
```

## Server setup

Generate REALITY keys on the server:

```sh
xray x25519
```

Then render a server config:

```sh
python3 tools/realitychain.py render-server \
  --private-key SERVER_REALITY_PRIVATE_KEY \
  --client 00000000-0000-0000-0000-000000000000 \
  --server-name www.microsoft.com \
  --short-id abcdef0123456789 \
  --output ./server.json
```

Install `server.json` on an Xray-capable VPS and expose the configured TCP port.

## Notes

- Use unique UUIDs, short IDs, and REALITY key pairs for each deployment.
- Keep the ledger HMAC secret off the router when possible; verify and render
  configs on an admin workstation, then copy only the rendered Xray JSON to the
  router.
- Do not expose the local SOCKS/HTTP listener to untrusted networks.
