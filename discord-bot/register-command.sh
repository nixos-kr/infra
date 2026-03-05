#!/usr/bin/env bash
set -euo pipefail

# Register the /archive slash command with Discord.
# Usage: ./register-command.sh <APPLICATION_ID> <BOT_TOKEN>

APP_ID="${1:?Usage: $0 <APPLICATION_ID> <BOT_TOKEN>}"
BOT_TOKEN="${2:?Usage: $0 <APPLICATION_ID> <BOT_TOKEN>}"

curl -s -X POST \
  "https://discord.com/api/v10/applications/${APP_ID}/commands" \
  -H "Authorization: Bot ${BOT_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "archive",
    "description": "Discord 대화를 FAQ 항목으로 아카이브합니다",
    "default_member_permissions": "8192",
    "options": [
      {
        "name": "link",
        "description": "아카이브할 메시지 링크",
        "type": 3,
        "required": true
      }
    ]
  }' | jq .

echo ""
echo "Slash command registered successfully."
