{
  "log": {
    "access": "none",
    "error": "none",
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "tag": "socks-in",
      "listen": "127.0.0.1",
      "port": {{CLIENT_SOCKS_PORT}},
      "protocol": "socks",
      "settings": {
        "auth": "noauth",
        "udp": true
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls", "quic"]
      }
    },
    {
      "tag": "http-in",
      "listen": "127.0.0.1",
      "port": {{CLIENT_HTTP_PORT}},
      "protocol": "http",
      "settings": {}
    }
  ],
  "outbounds": [
    {
      "tag": "vless-reality-out",
      "protocol": "vless",
      "settings": {
        "vnext": [
          {
            "address": "{{SERVER_ADDRESS}}",
            "port": {{SERVER_PORT}},
            "users": [
              {
                "id": "{{VLESS_UUID}}",
                "encryption": "none",
                "flow": "xtls-rprx-vision"
              }
            ]
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "fingerprint": "{{REALITY_FINGERPRINT}}",
          "serverName": "{{REALITY_SERVER_NAME}}",
          "publicKey": "{{REALITY_PUBLIC_KEY}}",
          "shortId": "{{REALITY_SHORT_ID}}",
          "spiderX": "/"
        }
      }
    },
    {
      "tag": "direct",
      "protocol": "freedom"
    },
    {
      "tag": "block",
      "protocol": "blackhole"
    }
  ],
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      {
        "type": "field",
        "ip": ["geoip:private"],
        "outboundTag": "direct"
      },
      {
        "type": "field",
        "network": "tcp,udp",
        "outboundTag": "vless-reality-out"
      }
    ]
  }
}
