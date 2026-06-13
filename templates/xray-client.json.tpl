{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "tag": "lan-tproxy",
      "listen": "0.0.0.0",
      "port": {{LOCAL_TPROXY_PORT}},
      "protocol": "dokodemo-door",
      "settings": {
        "network": "tcp,udp",
        "followRedirect": true
      },
      "streamSettings": {
        "sockopt": {
          "tproxy": "tproxy"
        }
      }
    }
  ],
  "outbounds": [
    {
      "tag": "reality",
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
          "spiderX": ""
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
        "ip": [
          "geoip:private"
        ],
        "outboundTag": "direct"
      },
      {
        "type": "field",
        "network": "tcp,udp",
        "outboundTag": "reality"
      }
    ]
  }
}
