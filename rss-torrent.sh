#!/usr/bin/env bash
set -euo pipefail

if [ -f ".env" ]; then
  export $(grep -v '^#' .env | xargs)
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.xml"
LOG_FILE="$SCRIPT_DIR/rss-torrent.log"
DISCORD_WEBHOOK="${DISCORD_WEBHOOK:-}"

mkdir -p "$SCRIPT_DIR"
touch "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1

send_discord() {
  local title="$1"
  local message="$2"
  local color="${3:-5763719}"

  if [[ -z "$DISCORD_WEBHOOK" ]]; then
    echo "[Discord] Skipped (no webhook configured)"
    return
  fi

  local payload
  payload=$(jq -n     --arg title "$title"     --arg message "$message"     --argjson color "$color"     --arg now "$(date -u +'%Y-%m-%d %H:%M:%S UTC')"     '{embeds: [{title: $title, description: $message, color: $color, footer: {text: $now}}]}')

  curl -s -H "Content-Type: application/json" -d "$payload" "$DISCORD_WEBHOOK" >/dev/null ||     echo "[Discord] Failed to send webhook"
}

if [[ "${1:-}" == "--test" ]]; then
  send_discord "🧠 TorrentOps Test" "Webhook and logging are operational."
  echo "✅ Test notification sent."
  exit 0
fi

DOWNLOAD_DIR=$(xmllint --xpath "string(//download_dir)" "$CONFIG_FILE")
HISTORY_FILE=$(xmllint --xpath "string(//history_file)" "$CONFIG_FILE")
RSS_FEEDS=$(xmllint --xpath "//feed/url/text()" "$CONFIG_FILE")

mkdir -p "$DOWNLOAD_DIR"
touch "$HISTORY_FILE"

found_any=false

for FEED in $RSS_FEEDS; do
  echo "[Feed] Checking: $FEED"
  FEED_DATA=$(curl -fsSL --compressed -A "Mozilla/5.0" "$FEED" || echo "")
  if [[ ! "$FEED_DATA" =~ \<rss ]]; then
    echo "[Feed] ⚠️ Skipping invalid or rate-limited feed."
    continue
  fi

  LINKS=$(echo "$FEED_DATA" | grep -oP '(?<=<link>).*?(?=</link>)' | grep -v '^$' || true)

  while read -r LINK; do
    [ -z "$LINK" ] && continue
    FILE_HASH=$(echo "$LINK" | md5sum | awk '{print $1}')
    FILE_NAME="$FILE_HASH.torrent"

    if ! grep -q "$FILE_HASH" "$HISTORY_FILE"; then
      echo "🧲 New torrent found: $LINK"
      if curl -fsSL --compressed -A "Mozilla/5.0" "$LINK" -o "$DOWNLOAD_DIR/$FILE_NAME" && [ -s "$DOWNLOAD_DIR/$FILE_NAME" ]; then
        echo "$FILE_HASH" >> "$HISTORY_FILE"
        echo "✅ Saved: $DOWNLOAD_DIR/$FILE_NAME"
        found_any=true
        send_discord "🧲 New Torrent Downloaded" "[$(basename "$FILE_NAME")]($LINK)\nSaved successfully." 5763719
      else
        echo "⚠️ Failed to download $LINK"
        rm -f "$DOWNLOAD_DIR/$FILE_NAME"
      fi
    fi
  done <<< "$LINKS"
done

if ! $found_any; then
  echo "No new torrents found."
  send_discord "📭 TorrentOps Idle" "No new torrents found." 9807270
fi
