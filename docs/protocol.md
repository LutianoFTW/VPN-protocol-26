# RealityChain protocol profile

RealityChain is a control-plane profile for Xray VLESS + REALITY deployments on
Asuswrt-Merlin routers. It combines:

1. **Data plane:** Xray VLESS over TCP with REALITY security and Vision flow.
2. **Router plane:** Linux TPROXY rules on Asuswrt-Merlin to send LAN traffic
   into the local Xray inbound.
3. **Kill-switch plane:** filter rules and a local watchdog that block LAN
   forwarding if the tunnel process is interrupted.
4. **Policy plane:** an EVM-compatible blockchain storage slot containing the
   SHA-256 hash of the approved local policy file.

## Data plane

The router runs Xray with:

- `dokodemo-door` TPROXY inbound on `LOCAL_TPROXY_PORT`.
- VLESS outbound to `SERVER_ADDRESS:SERVER_PORT`.
- REALITY transport settings:
  - `serverName`
  - `publicKey`
  - `shortId`
  - browser `fingerprint`
- `xtls-rprx-vision` flow.

The server runs a matching VLESS inbound with REALITY:

- generated X25519 private key,
- matching `shortIds`,
- a realistic `dest` target such as `www.microsoft.com:443`,
- a VLESS UUID shared with the router.

## Router plane

The Merlin firewall helper creates a dedicated mangle chain and policy routing
table:

- mangle chain: `REALITYCHAIN`
- fwmark: `1` by default
- routing table: `100` by default
- LAN interface: `br0` by default

Reserved, private, multicast, and direct router ranges are returned before
TPROXY redirection. TCP and UDP from LAN clients are then redirected into the
local Xray TPROXY inbound.

## Kill-switch plane

The kill switch uses a dedicated filter chain:

- filter chain: `REALITYCHAIN_KILLSWITCH`
- hook: first matching `FORWARD` rule for `LAN_IFACE`
- default LAN interface: `br0`

When engaged, the chain allows reserved/private/local destinations and rejects
other forwarded LAN traffic. Router-local traffic is not blocked, which lets
the Xray process establish outbound REALITY sessions from the router itself.

The installer-generated init script engages the kill switch before starting
Xray, clears it once the Xray process is confirmed running, and starts
`realitychain-watchdog.sh`. If the watchdog later sees the Xray PID disappear,
it re-engages the kill switch and updates WebUI status.

The watchdog detects process interruption. It does not prove that every remote
site is reachable through the tunnel while Xray remains running.

## Policy plane

The policy plane is intentionally small enough for a consumer router:

1. `realitychainctl policy-hash policy.json` computes:

   ```text
   0x + SHA256(policy.json bytes)
   ```

2. A trusted operator stores that 32-byte value in an EVM contract storage slot.
3. Router config pins:

   - `ANCHOR_RPC_URL`
   - `ANCHOR_CONTRACT`
   - `ANCHOR_STORAGE_SLOT`

4. `realitychainctl verify-anchor` calls:

   ```json
   {
     "jsonrpc": "2.0",
     "id": 1,
     "method": "eth_getStorageAt",
     "params": ["<contract>", "<slot>", "latest"]
   }
   ```

5. Xray starts only when the local policy hash equals the on-chain slot value.

This provides tamper-evident authorization and operational revocation. It does
not make the tunnel payload more encrypted than REALITY already makes it.

## Revocation

To revoke a router policy, update the trusted storage slot to:

- the hash of a new policy, or
- a zero/invalid hash.

The next guarded render or service restart will refuse to start Xray if the
local policy no longer matches the anchor.

## Trust assumptions

- The router trusts the configured RPC endpoint, contract address, and storage
  slot supplied in `client.env`.
- The router must protect `/jffs/addons/realitychain/client.env`, because that
  file defines both tunnel credentials and the trusted blockchain anchor.
- The blockchain gate is a startup and render-time control. For continuous
  enforcement, schedule a Merlin cron job that runs `verify-anchor` and restarts
  or stops the service on mismatch.

## Recommended operating model

1. Generate Xray UUID and REALITY keys on the server.
2. Render and test the server config.
3. Fill in the router `client.env`.
4. Review the policy JSON.
5. Hash the exact policy file and anchor it on-chain.
6. Install on the router and start `S99realitychain`.
