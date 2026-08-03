# Linux Xray XTLS-REALITY server (no-log)

This document describes the Linux VPS side of VPN-protocol-26: an
[Xray-core](https://github.com/XTLS/Xray-core) **VLESS + REALITY + Vision
(XTLS)** inbound with logging and traffic stats disabled.

## Threat / privacy goals

| Control | Setting |
| --- | --- |
| Access log | `"access": "none"` |
| Error log | `"error": "none"` |
| Log level | `"loglevel": "none"` |
| Stats module | omitted entirely |
| Per-user counters | `statsUserUplink/Downlink: false` |
| System counters | all `statsInbound*` / `statsOutbound*` false |

No connection metadata is written by Xray itself under this profile. Host
`journalctl` may still record systemd start/stop events for the service unit;
that is process supervision, not proxy access logging.

## Protocol profile

- Inbound: `vless` on TCP
- Security: `reality`
- Flow: `xtls-rprx-vision`
- Camouflage: operator-chosen `serverNames` + `dest` (must speak real TLS)
- Private destinations and BitTorrent are blackholed by default

## Files

```text
examples/server.env
server/templates/xray-server-nolog.json.tpl
server/templates/xray-client.json.tpl
server/systemd/xray-reality.service
scripts/generate-reality-keys.sh
scripts/render-server-config.sh
scripts/install-linux-server.sh
tools/xray_nolog.py
tests/validate-server-nolog.sh
```

## Install on a Linux VPS

Requirements: root shell, systemd, `curl` or `wget`, `unzip`, Python 3.

```sh
cd /path/to/VPN-protocol-26
chmod +x scripts/*.sh tests/*.sh

# 1. Bootstrap the xray binary (needed for key generation)
sudo ./scripts/install-linux-server.sh --bootstrap-only

# 2. Generate UUID + REALITY keys
./scripts/generate-reality-keys.sh ./server.env

# 3. Set the public address clients will dial; tune camouflage if needed
vi ./server.env
# SERVER_ADDRESS=your.vps.ip.or.hostname
# optional: REALITY_SERVER_NAME / REALITY_DEST

# 4. Install no-log config + enable systemd unit
sudo ./scripts/install-linux-server.sh --env ./server.env --skip-download
```

## Verify

```sh
sudo systemctl status xray-reality
sudo /usr/local/bin/xray run -test -config /usr/local/etc/xray/config.json
python3 tools/xray_nolog.py validate-template
./tests/validate-server-nolog.sh
```

Confirm no-log landed:

```sh
python3 - <<'PY'
import json
cfg=json.load(open("/usr/local/etc/xray/config.json"))
print(cfg["log"])
assert cfg["log"]["loglevel"]=="none"
assert "stats" not in cfg
print("no-log ok")
PY
```

## Client share values

Give clients only the public fields:

- `SERVER_ADDRESS` / `SERVER_PORT`
- `VLESS_UUID`
- `REALITY_PUBLIC_KEY`
- `REALITY_SHORT_ID`
- `REALITY_SERVER_NAME`
- `REALITY_FINGERPRINT` (usually `chrome`)
- flow `xtls-rprx-vision`

Never share `REALITY_PRIVATE_KEY`. A companion client JSON is written to
`/usr/local/etc/xray/client.json` when `SERVER_ADDRESS` is set to a non-example
value.

## Choosing REALITY dest

`REALITY_DEST` must be a host:port that:

1. Is reachable from your VPS on TCP
2. Speaks normal TLS
3. Presents a certificate covering `REALITY_SERVER_NAME`

Common choices: large CDN / content frontends such as `www.cloudflare.com:443`,
`www.microsoft.com:443`, or a region-appropriate site. For Russian-network
camouflage profiles used elsewhere in this repository, `vk.com:443` is the
documented example.

## Firewall

The installer opens the listen port via `ufw` or `firewalld` when those are
active. Otherwise open TCP `SERVER_LISTEN_PORT` in your cloud security group.

## Uninstall

```sh
sudo systemctl disable --now xray-reality
sudo rm -f /etc/systemd/system/xray-reality.service
sudo systemctl daemon-reload
sudo rm -rf /usr/local/etc/xray
# optional: sudo rm -f /usr/local/bin/xray
```
