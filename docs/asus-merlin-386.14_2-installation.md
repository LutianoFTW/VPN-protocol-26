# Asuswrt-Merlin 386.14_2 full installation file

Use this file from the repository root on the router:

```sh
sh INSTALL-ASUS-MERLIN-386.14_2.sh
```

It calls:

```sh
scripts/install-asus-merlin-386.14_2-full.sh
```

## Firmware basics applied

The full installer applies the basic Merlin settings needed by RealityChain:

- verifies that the firmware appears to be Asuswrt-Merlin 386.14_2,
- enables custom scripts with:

  ```sh
  nvram set jffs2_scripts=1
  nvram commit
  ```

- creates `/jffs/scripts`,
- creates `/jffs/addons`,
- verifies Entware `/opt`,
- verifies Merlin Addons API support when available,
- verifies the router architecture maps to an Xray release asset,
- verifies required tools such as `curl`, `unzip`, `ip`, and `iptables`,
- checks TPROXY support with `xt_TPROXY`, `xt_socket`, and the iptables
  `TPROXY` target.

It does not install or flash Asuswrt-Merlin firmware itself. Flash
Asuswrt-Merlin 386.14_2 through the normal Asus/Merlin firmware upgrade flow
before running this project installer.

## RealityChain functions installed

The installer adds the project to `/jffs/addons/realitychain` and installs:

- `realitychainctl` for rendering client/server configs and verifying policy
  hashes,
- Xray VLESS/REALITY client template,
- Xray VLESS/REALITY server template,
- Merlin WebUI page under **Tools -> RealityChain**,
- `services-start` autostart hook,
- `service-event` WebUI action hook,
- TPROXY transparent LAN routing helper,
- kill switch firewall helper,
- Xray watchdog that engages the kill switch if the tunnel process exits,
- blockchain policy-anchor verification,
- VK/Russia REALITY camouflage defaults.

## Safe default state

After installation:

- `rch_enabled=0`
- `rch_ks_enabled=1`
- `rch_ks_interval=10`
- `rch_reality_server_name=vk.com`
- `rch_reality_dest=vk.com:443`
- `rch_reality_fingerprint=chrome`
- `rch_srv_listen=0.0.0.0`
- `rch_srv_port=443`

The tunnel is intentionally not started until real client/server credentials
are configured. This avoids boot-time tunnel attempts using placeholder values.

## Installer options

```sh
sh INSTALL-ASUS-MERLIN-386.14_2.sh --dry-run
sh INSTALL-ASUS-MERLIN-386.14_2.sh --force
sh INSTALL-ASUS-MERLIN-386.14_2.sh --start
```

- `--dry-run` prints the actions without changing the router.
- `--force` continues when the firmware is not detected as exactly 386.14_2.
- `--start` starts RealityChain immediately after installation. Use this only
  after real credentials are already present in `client.env` or Merlin custom
  settings.

## After installation

Open:

```text
Tools -> RealityChain
```

Then either:

1. Fill **Client setup** with values from an existing server/router and click
   **Apply and restart**, or
2. Fill **Server setup**, click **Render server config**, copy
   `/jffs/addons/realitychain/xray-server.json` to the Xray server, then fill
   **Client setup**.

The installer writes a report to:

```sh
/jffs/addons/realitychain/install-386.14_2.txt
```
