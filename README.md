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
service status and policy hash. The page has separate **Client setup** and
**Server setup** sections: client settings drive the router outbound tunnel,
while server settings render an `xray-server.json` file that can be copied to
the VPS/server. The page also includes kill-switch controls for enabling
automatic protection, manually engaging the block, and clearing it after
recovery.

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

## Server setup for usage in Russia

This profile is designed for a Merlin router client connecting to your own
Xray server while using a Russian/VK-oriented REALITY camouflage profile:

```sh
REALITY_SERVER_NAME=vk.com
REALITY_DEST=vk.com:443
REALITY_FINGERPRINT=chrome
```

`vk.com` is not your VPN server. It is the REALITY TLS camouflage destination.
`SERVER_ADDRESS` must be the DNS name or IP address of the VPS/server you
control.

### 1. Prepare the server

Use a Linux VPS that can run Xray and accept inbound TCP/443. For a router
client physically used in Russia, the usual deployment is:

- a VPS outside Russia when the goal is external Internet access,
- a VPS inside or near Russia only when the goal is low-latency access to
  Russian-region services.

Install Xray on the VPS using the official Xray-core release or your operating
system's package method. Then generate a VLESS UUID and REALITY keypair:

```sh
xray uuid
xray x25519
```

Save:

- UUID -> `VLESS_UUID`
- private key -> `REALITY_PRIVATE_KEY` on the server only
- public key -> `REALITY_PUBLIC_KEY` on the Merlin router client

### 2. Create the server environment file

On your workstation, router, or VPS:

```sh
cp examples/client-ru-vk.env server.env
vi server.env
```

Set at least:

```sh
SERVER_ADDRESS=your.vps.example.com
SERVER_PORT=443
SERVER_LISTEN=0.0.0.0
SERVER_LISTEN_PORT=443
VLESS_UUID=<uuid from xray uuid>
REALITY_PRIVATE_KEY=<private key from xray x25519>
REALITY_PUBLIC_KEY=<public key from xray x25519>
REALITY_SHORT_ID=<8 to 16 hex chars, for example 0123456789abcdef>
REALITY_SERVER_NAME=vk.com
REALITY_DEST=vk.com:443
REALITY_FINGERPRINT=chrome
```

Keep `REALITY_PRIVATE_KEY` off the router when possible. The router only needs
the public key.

### 3. Render and install the server config

Render the Xray server config:

```sh
scripts/realitychainctl render-server server.env xray-server.json
```

Copy `xray-server.json` to the VPS and start Xray with it. A simple systemd
unit can use:

```sh
xray run -config /etc/xray/xray-server.json
```

Open TCP/443 on the VPS firewall/security group. REALITY/VLESS Vision in this
profile uses TCP.

### 4. Configure the Merlin client

On the Asuswrt-Merlin router, use the WebUI **Client setup** section or edit:

```sh
vi /jffs/addons/realitychain/client.env
```

Copy these values from `server.env`:

```sh
SERVER_ADDRESS=your.vps.example.com
SERVER_PORT=443
VLESS_UUID=<same UUID>
REALITY_PUBLIC_KEY=<public key>
REALITY_SHORT_ID=<same short ID>
REALITY_SERVER_NAME=vk.com
REALITY_DEST=vk.com:443
REALITY_FINGERPRINT=chrome
```

Do not put `REALITY_PRIVATE_KEY` in the client section. It is only needed by
the server config renderer.

### 5. Optional: render server config from Merlin UI

The Merlin **RealityChain** tab has separate sections:

- **Client setup** configures the router outbound tunnel.
- **Server setup** configures and renders `xray-server.json`.

If you fill the server section, click **Render server config**. The generated
file is written to:

```sh
/jffs/addons/realitychain/xray-server.json
```

Copy that file to the VPS and restart Xray there.

### 6. Smoke test

On the VPS:

```sh
xray run -test -config /etc/xray/xray-server.json
```

On the Merlin router:

```sh
/opt/etc/init.d/S99realitychain restart
ps | grep '[x]ray'
/jffs/addons/realitychain/realitychain-killswitch.sh status /jffs/addons/realitychain/client.env
```

Expected result:

- Xray starts on the VPS without config errors.
- Xray starts on the Merlin router.
- The kill switch reports `clear` while the tunnel process is running.

## Client setup after the server is configured on another router

Use this section when one router or server is already acting as the
RealityChain/Xray server and this Asuswrt-Merlin router only needs to connect
as the client.

### 1. Collect values from the server router

From the router/server that already has the server side configured, collect:

```sh
SERVER_ADDRESS=<server router public IP or DNS/DDNS name>
SERVER_PORT=<server router public listening port>
VLESS_UUID=<server VLESS UUID>
REALITY_PUBLIC_KEY=<public key paired with the server private key>
REALITY_SHORT_ID=<server short ID>
REALITY_SERVER_NAME=vk.com
REALITY_DEST=vk.com:443
REALITY_FINGERPRINT=chrome
```

If the server is another home/office router, make sure its Xray REALITY
listener is reachable from the client router:

- The server router has a public IP address or working DDNS hostname.
- TCP `SERVER_PORT` is open on the server router firewall.
- If Xray is running behind another upstream router, TCP `SERVER_PORT` is
  forwarded to the device running Xray.
- The server-side Xray config uses the same `VLESS_UUID`,
  `REALITY_SHORT_ID`, `REALITY_SERVER_NAME`, and `REALITY_DEST`.

Do not copy the server's `REALITY_PRIVATE_KEY` into the client section. The
client only needs `REALITY_PUBLIC_KEY`.

### 2. Install RealityChain on the client router

On the Merlin router that will act as the client:

```sh
cd /tmp
# Copy or clone this repository onto the client router first.
sh scripts/check-merlin-386-compat.sh
sh scripts/install-merlin.sh
```

Open the Merlin WebUI and go to:

```text
Tools -> RealityChain -> Client setup - router outbound tunnel
```

### 3. Fill in the Client setup section

Use the values from the server router:

| Client setup field | Value |
| --- | --- |
| Enable at boot | checked |
| Remote server address | `SERVER_ADDRESS` from the server router |
| Remote server port | `SERVER_PORT` from the server router |
| VLESS UUID | same `VLESS_UUID` as the server |
| REALITY public key | server keypair public key |
| REALITY short ID | same `REALITY_SHORT_ID` as the server |
| REALITY server name | `vk.com` |
| REALITY fingerprint | `chrome` |

The REALITY destination is shown in the **Server setup** section because it is
used when rendering the server config, but for this profile it must still match
the server:

```sh
REALITY_DEST=vk.com:443
```

If you prefer editing the env file directly on the client router:

```sh
vi /jffs/addons/realitychain/client.env
```

Set:

```sh
SERVER_ADDRESS=<server router public IP or DNS/DDNS name>
SERVER_PORT=<server router public listening port>
VLESS_UUID=<same UUID as the server>
REALITY_PUBLIC_KEY=<server public key>
REALITY_SHORT_ID=<same short ID as the server>
REALITY_SERVER_NAME=vk.com
REALITY_DEST=vk.com:443
REALITY_FINGERPRINT=chrome
KILLSWITCH_ENABLED=1
```

### 4. Apply and test the client router

In the WebUI, click **Apply and restart**. Or from SSH:

```sh
/opt/etc/init.d/S99realitychain restart
```

Check that Xray is running and that the kill switch is clear:

```sh
ps | grep '[x]ray'
/jffs/addons/realitychain/realitychain-killswitch.sh status /jffs/addons/realitychain/client.env
```

Expected:

- The router starts Xray with `xray-client.json`.
- LAN clients are transparently routed through the tunnel.
- The kill switch reports `clear` while the tunnel process is alive.

If the tunnel does not come up, check:

```sh
/tmp/realitychain-xray.log
/tmp/realitychain-webui-action.log
```

Most client-side failures are caused by one of these mismatches:

- wrong server address or port,
- blocked TCP port on the server router,
- different `VLESS_UUID`,
- different `REALITY_SHORT_ID`,
- wrong `REALITY_PUBLIC_KEY`,
- different `REALITY_SERVER_NAME` or `REALITY_DEST`.

## Development

Run local validation:

```sh
make test
```

The validation suite checks shell syntax and verifies that all template
variables used by the Xray templates are documented in `examples/client.env`.
It also validates that Merlin WebUI custom-setting keys fit firmware limits.
