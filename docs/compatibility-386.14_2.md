# Asuswrt-Merlin 386.14_2 compatibility

RealityChain is designed to work on Asuswrt-Merlin 386.14_2 when the router
model has enough CPU/RAM for Xray and exposes the required Netfilter modules.

## Compatibility verdict

Expected status for Merlin 386.14_2:

- **Core CLI service:** compatible when Entware is installed at `/opt`.
- **Merlin WebUI page:** compatible. Merlin addon WebUI support has existed
  since 384.15, and 386.14_2 is in the supported generation.
- **TPROXY transparent routing:** model-dependent. Most ARM AC/AX routers on
  Merlin support it, but it must be confirmed with `xt_TPROXY`.
- **Kill switch:** compatible when `iptables` filter rules are available.
- **Automatic Xray install:** compatible on ARMv7 and ARM64 routers supported
  by official Xray release assets.
- **Legacy MIPS models:** not supported by automatic Xray install.

## On-router check

Run this over SSH on the Merlin router:

```sh
sh scripts/check-merlin-386-compat.sh
```

The check verifies:

- firmware `nvram` fields and `am_addons` support,
- `/jffs` custom scripts storage,
- Entware `/opt`,
- Merlin `/usr/sbin/helper.sh`,
- `/www/user` WebUI mount directory,
- CPU architecture to Xray release asset mapping,
- `curl`, `unzip`, `sed`, `awk`, and hashing tools,
- `ip`, `iptables`, `modprobe`,
- `xt_TPROXY`, `xt_socket`, and the iptables TPROXY target.

## Notes for 386.14_2

The installer now maps common Merlin CPU architectures to the correct Xray
release assets:

| `uname -m` | Xray asset |
| --- | --- |
| `aarch64`, `arm64` | `Xray-linux-arm64-v8a.zip` |
| `armv7l`, `armv7*`, `armv8l` | `Xray-linux-arm32-v7a.zip` |
| `armv6l` | `Xray-linux-arm32-v6.zip` |
| `x86_64`, `amd64` | `Xray-linux-64.zip` |

The router client template uses explicit private/reserved CIDR rules rather
than `geoip:private`, so Xray does not need bundled `geoip.dat` just to load the
default config.

## Minimum manual smoke test

After install and configuration:

```sh
/opt/etc/init.d/S99realitychain restart
ps | grep '[x]ray'
/jffs/addons/realitychain/realitychain-killswitch.sh status /jffs/addons/realitychain/client.env
iptables -t mangle -S REALITYCHAIN
iptables -t filter -S REALITYCHAIN_KILLSWITCH
```

Expected:

- `xray` is running,
- kill switch status is `clear` while the tunnel process is alive,
- `REALITYCHAIN` mangle rules exist,
- `REALITYCHAIN_KILLSWITCH` may exist but should not be hooked into `FORWARD`
  unless the tunnel is stopped or interrupted.
