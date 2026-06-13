{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "tag": "vless-reality",
      "listen": "{{SERVER_ADDRESS}}",
      "port": {{SERVER_PORT}},
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "{{VLESS_UUID}}",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "{{REALITY_DEST}}",
          "xver": 0,
          "serverNames": [
            "{{REALITY_SERVER_NAME}}"
          ],
          "privateKey": "{{REALITY_PRIVATE_KEY}}",
          "shortIds": [
            "{{REALITY_SHORT_ID}}"
          ]
        }
      }
    }
  ],
  "outbounds": [
    {
      "tag": "direct",
      "protocol": "freedom"
    },
    {
      "tag": "block",
      "protocol": "blackhole"
    }
  ]
}
