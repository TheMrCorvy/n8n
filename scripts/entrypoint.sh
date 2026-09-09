#!/bin/sh
# =============================================================================
# entrypoint.sh — n8n custom entrypoint
# =============================================================================
# All tools (yt-dlp, ffmpeg, spotdl) are baked into the image at build time.
# This script only handles runtime directory setup and then hands off to n8n.
# =============================================================================

set -e

# ── Ensure n8n data directory exists and is owned correctly ──────────────────
mkdir -p /home/node/.n8n/logs

# ── Create the music download directory if it doesn't exist ──────────────────
if [ -n "$MUSIC_DOWNLOAD_PATH" ] && [ ! -d "$MUSIC_DOWNLOAD_PATH" ]; then
  mkdir -p "$MUSIC_DOWNLOAD_PATH" 2>/dev/null || true
fi

# ── Hand off to n8n ──────────────────────────────────────────────────────────
exec "$@"
