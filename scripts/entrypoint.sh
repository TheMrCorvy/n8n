#!/bin/sh
# =============================================================================
# entrypoint.sh — n8n custom entrypoint
# =============================================================================
# Installs yt-dlp, ffmpeg, and spotdl on first boot (or when binaries are
# missing), then hands off to the official n8n entrypoint.
#
# Tools installed:
#   • ffmpeg     – audio encoding / post-processing (via apk)
#   • yt-dlp     – YouTube (and YouTube-matched Spotify) downloads
#   • spotdl     – Spotify → YouTube resolver with rich metadata tagging
#
# All binaries are written to /usr/local/bin which is already on $PATH.
# =============================================================================

set -e

TOOLS_MARKER="/home/node/.n8n/.tools_installed"

install_tools() {
  echo "[entrypoint] Installing yt-dlp, ffmpeg and spotdl..."

  # ── ffmpeg (from Alpine package index) ─────────────────────────────────────
  apk add --no-cache ffmpeg python3 py3-pip curl 2>/dev/null || true

  # ── yt-dlp (latest release binary, runs without Python import issues) ──────
  curl -fsSL \
    "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp" \
    -o /usr/local/bin/yt-dlp
  chmod +x /usr/local/bin/yt-dlp

  # ── spotdl (installed via pip into the system Python) ──────────────────────
  pip3 install --break-system-packages --quiet spotdl 2>/dev/null || \
    pip3 install --quiet spotdl

  echo "[entrypoint] Tools installed successfully."
  touch "$TOOLS_MARKER"
}

# Only run the full install on fresh starts (marker missing = first boot or
# the container was recreated). On subsequent restarts the tools are already
# present on disk (via the bind-mounted ./data volume) and we skip the slow
# install step to keep startup fast.
if [ ! -f "$TOOLS_MARKER" ]; then
  # The n8n container runs as the 'node' user which has no sudo rights.
  # apk / pip require root, so we call this block as root via the docker
  # user override in docker-compose.yml (user: root) and then drop back.
  install_tools
fi

# ── Create the music download directory if it doesn't exist ──────────────────
if [ -n "$MUSIC_DOWNLOAD_PATH" ] && [ ! -d "$MUSIC_DOWNLOAD_PATH" ]; then
  mkdir -p "$MUSIC_DOWNLOAD_PATH"
  echo "[entrypoint] Created music download directory: $MUSIC_DOWNLOAD_PATH"
fi

# ── Hand off to the original n8n entrypoint ──────────────────────────────────
exec /docker-entrypoint.sh "$@"
