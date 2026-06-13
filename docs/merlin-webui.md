# Merlin WebUI integration

RealityChain includes a custom Asuswrt-Merlin page at
`webui/RealityChain.asp`. The installer deploys it with the firmware Addons
API when the router advertises `am_addons` support in `rc_support`.

## Where it appears

On supported Merlin builds, `scripts/install-merlin.sh`:

1. copies `RealityChain.asp` to `/jffs/addons/realitychain/webui/`,
2. asks `/usr/sbin/helper.sh` for an available `/www/user/userN.asp` slot,
3. copies the page into that slot,
4. adds a `RealityChain` tab under the firmware **Tools** menu,
5. stores the assigned page slot in Merlin custom settings as
   `rch_webui_page`.

The page is mounted during install and again at boot from
`/jffs/scripts/services-start`, because `/www` is recreated by the firmware.

If the router does not support `am_addons`, the VPN service still installs and
runs from the CLI, but the WebUI tab is skipped.

## What the page can do

The page exposes:

- enable/disable at boot,
- server address and port,
- VLESS UUID,
- REALITY public key, short ID, server name, destination, and fingerprint,
- optional blockchain RPC URL, contract address, and storage slot,
- policy file path,
- automatic kill-switch enablement and watchdog interval,
- manual kill-switch engage and clear buttons,
- last known service status,
- last known kill-switch state,
- last known anchor status,
- last calculated policy hash.

Clicking **Apply and restart** submits Merlin custom settings and triggers:

```text
restart_realitychain
```

Clicking **Stop tunnel** triggers:

```text
stop_realitychain
```

Clicking **Engage kill switch** triggers:

```text
start_realitychainks
```

Clicking **Clear kill switch** triggers:

```text
stop_realitychainks
```

The installer appends a small block to `/jffs/scripts/service-event` so those
events are handled by:

```sh
/jffs/addons/realitychain/realitychain-webui.sh service-event "$@"
```

## Settings namespace

Merlin custom setting names are intentionally short because the firmware limits
key length. RealityChain uses the `rch_` namespace:

- `rch_enabled`
- `rch_server_address`
- `rch_server_port`
- `rch_vless_uuid`
- `rch_reality_public_key`
- `rch_reality_short_id`
- `rch_reality_server_name`
- `rch_reality_dest`
- `rch_reality_fingerprint`
- `rch_ks_enabled`
- `rch_ks_interval`
- `rch_ks_state`
- `rch_anchor_rpc_url`
- `rch_anchor_contract`
- `rch_anchor_storage_slot`
- `rch_policy_file`
- `rch_status`
- `rch_anchor_status`
- `rch_policy_hash`
- `rch_updated_at`
- `rch_webui_page`

When settings are applied, `realitychain-webui.sh` rewrites
`/jffs/addons/realitychain/client.env` and calls the Entware init script.
The generated env file is mode `0600`.

## Security notes

- The WebUI only stores client-side tunnel parameters. It does not expose the
  REALITY private key used by the server template.
- Values are newline-stripped before writing `client.env`.
- When the kill switch is engaged, it blocks LAN forwarding to non-private
  destinations while preserving private/local network access.
- The blockchain anchor remains optional; if RPC URL and contract are blank,
  startup is not chain-gated.
