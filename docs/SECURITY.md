# Security notes — Linux XTLS-REALITY no-log server

## What this profile protects

- Xray access and error logs are disabled (`access/error/loglevel = none`).
- The stats module is omitted so Xray does not retain uplink/downlink counters.
- REALITY resists active probing by forwarding unrecognized handshakes to a
  real TLS destination (`dest`).
- Vision flow (`xtls-rprx-vision`) reduces TLS-in-TLS fingerprints versus plain
  VLESS+TLS.

## What this profile does not protect

- Host OS logs (`journalctl`, `auth.log`, cloud provider flow logs, netflow).
- Kernel connection tracking (`conntrack`) while sessions are live.
- Compromise of the VPS root account (private key and UUID live on disk).
- Endpoint fingerprinting of the *client* device beyond the tunnel.

## Secret handling

| Secret | Where it belongs |
| --- | --- |
| `REALITY_PRIVATE_KEY` | Server only (`server.env`, mode `0600`) |
| `VLESS_UUID` | Server + authorized clients |
| `REALITY_PUBLIC_KEY` | Safe to share with clients |
| `REALITY_SHORT_ID` | Safe to share with clients |

Rotate UUID, shortId, and the X25519 keypair if either leaks.

## Operational checklist

1. Generate fresh secrets with `scripts/generate-reality-keys.sh`.
2. Never commit `server.env` (gitignored).
3. Prefer listen port `443` so REALITY blends with HTTPS.
4. Pick a `REALITY_DEST` that is stable, widely used, and reachable from the VPS.
5. Keep the VPS patched; this stack does not replace host hardening.
