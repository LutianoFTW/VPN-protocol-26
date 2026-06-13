import importlib.util
import json
import os
import tempfile
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).resolve().parents[1] / "tools" / "realitychain.py"
SPEC = importlib.util.spec_from_file_location("realitychain", MODULE_PATH)
realitychain = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(realitychain)


class RealityChainTests(unittest.TestCase):
    def test_hmac_ledger_roundtrip_and_client_render(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            ledger = Path(tmpdir) / "tunnels.chain.jsonl"
            key = "test-secret"

            realitychain.append_block(
                ledger,
                {"type": "genesis", "network": "test", "operator": "unit"},
                hmac_key=key,
            )
            realitychain.append_block(
                ledger,
                {
                    "type": "peer",
                    "peer_id": "router-1",
                    "status": "active",
                    "tag": "asus-merlin",
                    "xray": {
                        "server_address": "vpn.example.com",
                        "server_port": 443,
                        "uuid": "00000000-0000-0000-0000-000000000000",
                        "public_key": "PUBLIC_KEY",
                        "server_name": "www.microsoft.com",
                        "short_id": "abcdef0123456789",
                        "fingerprint": "chrome",
                        "spider_x": "/",
                        "flow": "xtls-rprx-vision",
                    },
                },
                hmac_key=key,
            )

            blocks = realitychain.verify_ledger(ledger, hmac_key=key)
            peer = realitychain.latest_peer_payload(blocks, "router-1")
            args = type(
                "Args",
                (),
                {
                    "listen_host": "0.0.0.0",
                    "socks_port": 10808,
                    "http_port": 10809,
                    "transparent": True,
                    "transparent_port": 12345,
                    "loglevel": "warning",
                },
            )()
            config = realitychain.client_config(peer, args)

            self.assertEqual(config["outbounds"][0]["protocol"], "vless")
            self.assertEqual(
                config["outbounds"][0]["streamSettings"]["security"],
                "reality",
            )
            self.assertEqual(len(config["inbounds"]), 3)

    def test_tampered_payload_fails_verification(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            ledger = Path(tmpdir) / "tunnels.chain.jsonl"
            realitychain.append_block(
                ledger,
                {"type": "genesis", "network": "test", "operator": "unit"},
            )

            block = json.loads(ledger.read_text(encoding="utf-8").strip())
            block["payload"]["operator"] = "attacker"
            ledger.write_text(json.dumps(block) + "\n", encoding="utf-8")

            with self.assertRaises(ValueError):
                realitychain.verify_ledger(ledger)

    def test_cli_hmac_key_must_exist(self):
        env_name = "REALITYCHAIN_MISSING_TEST_KEY"
        os.environ.pop(env_name, None)

        with self.assertRaises(ValueError):
            realitychain.read_hmac_key(env_name)


if __name__ == "__main__":
    unittest.main()
