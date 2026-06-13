# Security model

RealityChain has two distinct security layers:

1. **Tunnel security:** Xray-core VLESS + REALITY provides the encrypted tunnel,
   REALITY public-key validation, short ID matching, and optional XTLS Vision
   flow.
2. **Control-plane integrity:** `tools/realitychain.py` stores tunnel records in
   a hash-chained JSONL ledger. Each block includes the previous block hash, the
   payload hash, and the block hash. When `--hmac-key-env` is used, every block is
   also authenticated with HMAC-SHA256.

The ledger is intentionally simple and auditable. It is a local/private
blockchain-style append-only log, not a consensus network. If decentralized
notarization is required, anchor a trusted block hash into a public blockchain or
another external notary and keep the transaction ID with deployment records.

## What the ledger protects

- Silent edits to router peer records before rendering an Xray client config.
- Accidental replacement of REALITY public keys, short IDs, UUIDs, or server
  addresses in the operator workflow.
- Rollback or deletion attempts when operators compare the current head hash
  with an externally anchored head hash.

## What the ledger does not protect

- Compromise of the router after `client.json` has been installed.
- Compromise of the Xray server private key or client UUID.
- Weak REALITY parameters, reused UUIDs, exposed proxy ports, or unsafe firewall
  rules.
- Traffic analysis risks inherent to any network tunnel.

## Recommended operating practice

1. Generate REALITY key material on the server with `xray x25519`.
2. Keep `REALITYCHAIN_LEDGER_KEY` in a password manager or secrets vault.
3. Initialize and update the ledger on an admin workstation, not on the router.
4. Run `tools/realitychain.py verify` before rendering any router config.
5. Copy only the rendered Xray config to the router.
6. Keep `/jffs/vpn-realitychain/realitychain.env` restricted to router admins.
7. If transparent gateway mode is enabled, set `REALITYCHAIN_SERVER_IP` so the
   firewall hook avoids redirecting the tunnel connection into itself.

## Merlin-specific hardening

- Enable Merlin custom scripts in the web UI or allow the installer to set
  `jffs2_scripts=1` with `nvram`.
- Use Entware storage that survives reboot and is not exposed over SMB/FTP.
- Bind SOCKS/HTTP listeners to `127.0.0.1` unless LAN clients explicitly need
  proxy access.
- Prefer transparent mode for trusted LAN segments only; do not bridge guest or
  untrusted Wi-Fi networks into the transparent redirect chain.
