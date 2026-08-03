# VPN-protocol-26

VPN protocol tooling to keep ahead of restrictions in highly restricted areas.

This repository currently ships a **Linux Xray XTLS-REALITY server** with
**no-log** defaults (VLESS + REALITY + Vision).

## Linux server (XTLS-REALITY, no-log)

| Piece | Path |
| --- | --- |
| No-log server template | `server/templates/xray-server-nolog.json.tpl` |
| Companion client template | `server/templates/xray-client.json.tpl` |
| systemd unit | `server/systemd/xray-reality.service` |
| Example env | `examples/server.env` |
| Installer | `scripts/install-linux-server.sh` |
| Key generator | `scripts/generate-reality-keys.sh` |
| Config renderer | `scripts/render-server-config.sh` |
| Validator | `tools/xray_nolog.py` |
| Full guide | [`docs/linux-server.md`](docs/linux-server.md) |

### Quick start

```sh
chmod +x scripts/*.sh

# Bootstrap xray binary, generate secrets, install no-log service
sudo ./scripts/install-linux-server.sh --bootstrap-only
./scripts/generate-reality-keys.sh ./server.env
vi ./server.env   # set SERVER_ADDRESS; tune REALITY_DEST if needed
sudo ./scripts/install-linux-server.sh --env ./server.env --skip-download
```

No-log policy baked into the server template:

```json
"log": {
  "access": "none",
  "error": "none",
  "loglevel": "none"
}
```

Traffic stats are omitted. Policy counters stay disabled.

### Validate without installing

```sh
chmod +x tests/validate-server-nolog.sh scripts/*.sh
./tests/validate-server-nolog.sh
```

## Protocol summary

- **Transport:** TCP
- **Inbound protocol:** VLESS
- **Security:** REALITY
- **Flow:** `xtls-rprx-vision`
- **Default camouflage example:** `www.cloudflare.com:443` (override per region)

See [`docs/linux-server.md`](docs/linux-server.md) for firewall, uninstall, and
client share fields.
