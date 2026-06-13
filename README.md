# VPN-protocol-26

VPN-protocol-26 packages a router-installable VPN profile for
Asuswrt-Merlin firmware. It is built on the Xray implementation of
VLESS + REALITY and adds a lightweight blockchain-anchored policy check
called **RealityChain**.

This project does not invent new packet cryptography. REALITY provides the
tunnel transport and active-probing resistance; the blockchain component is
used for tamper-evident tunnel authorization and revocation by anchoring a
policy hash on an EVM-compatible chain.

## What is included

- Asuswrt-Merlin installer for `/jffs` + Entware environments.
- Xray client template for transparent proxy (TPROXY) routing from LAN
  clients through a VLESS/REALITY tunnel.
- Xray server template for the matching VLESS/REALITY endpoint.
- `realitychainctl`, a small POSIX shell control utility that can:
  - render router Xray configs from environment files,
  - hash policy files,
  - verify policy hashes against an EVM storage slot via JSON-RPC,
  - gate tunnel startup when the blockchain anchor no longer matches.
- Firewall helper for Merlin TPROXY rules.
- Merlin WebUI page mounted into the firmware Tools menu through the
  Asuswrt-Merlin Addons API.
- Kill switch and watchdog that can block LAN forwarding automatically if the
  Xray tunnel process is interrupted.
- Russian/VK-oriented REALITY camouflage defaults using `vk.com:443` as the
  TLS destination profile.

## Router requirements

- Asus router running Asuswrt-Merlin with custom scripts enabled.
- JFFS partition enabled.
- Entware installed at `/opt`.
- `curl`, `unzip`, `iproute2`, and `iptables` with TPROXY support.
- A router CPU architecture supported by Xray release artifacts
  (`aarch64` and most ARMv7 Merlin devices are supported).

Legacy MIPS routers are usually too constrained for modern Xray + REALITY and
may not have compatible release artifacts.

## Quick start

On the Asuswrt-Merlin router:

```sh
cd /tmp
# Copy or clone this repository onto the router first.
sh scripts/check-merlin-386-compat.sh
sh scripts/install-merlin.sh
```

Merlin 386.14_2 is expected to work on supported ARM routers with Entware,
Merlin Addons API support, and TPROXY-capable Netfilter modules. See
`docs/compatibility-386.14_2.md` for the detailed compatibility checklist.

Edit the generated environment file:

```sh
vi /jffs/addons/realitychain/client.env
```

At minimum, set:

- `SERVER_ADDRESS`
- `SERVER_PORT`
- `VLESS_UUID`
- `REALITY_PUBLIC_KEY`
- `REALITY_SHORT_ID`
- `REALITY_SERVER_NAME`

By default, the sample config uses a Russian/VK-oriented REALITY camouflage
profile:

```sh
REALITY_SERVER_NAME=vk.com
REALITY_DEST=vk.com:443
REALITY_FINGERPRINT=chrome
```

`SERVER_ADDRESS` still points to your own Xray server. The VK hostname is the
REALITY camouflage destination and must match the server-side template values.

To enable blockchain-gated startup, also set:

- `ANCHOR_RPC_URL`
- `ANCHOR_CONTRACT`
- `ANCHOR_STORAGE_SLOT`
- `POLICY_FILE`

Then start the service:

```sh
/opt/etc/init.d/S99realitychain start
```

On supported Merlin builds, the installer also adds a **RealityChain** tab
under the firmware **Tools** section. Use that page to edit the router tunnel
settings, apply/restart the service, stop the tunnel, and view the last known
service status and policy hash. The page also includes kill-switch controls
for enabling automatic protection, manually engaging the block, and clearing it
after recovery.

## RealityChain anchor model

1. Build and review a local policy file, for example
   `examples/policy.json`.
2. Compute its hash:

   ```sh
   scripts/realitychainctl policy-hash examples/policy.json
   ```

3. Store the resulting 32-byte hash in an EVM smart-contract storage slot that
   the router is configured to trust.
4. On startup, the router fetches that storage slot with `eth_getStorageAt`.
5. If the on-chain hash differs from the local policy hash, Xray is not
   started and existing transparent proxy rules are removed.

The blockchain does not carry tunnel traffic or replace REALITY keys. It adds
an independently auditable control plane for tunnel authorization.

## Server configuration

Render the server template on the VPS or server running Xray:

```sh
cp examples/client.env server.env
vi server.env
scripts/realitychainctl render-server server.env xray-server.json
```

Generate REALITY keys with Xray:

```sh
xray x25519
```

Use the private key in the server config and the public key in the router
client config.

## Development

Run local validation:

```sh
make test
```

The validation suite checks shell syntax and verifies that all template
variables used by the Xray templates are documented in `examples/client.env`.
It also validates that Merlin WebUI custom-setting keys fit firmware limits.
