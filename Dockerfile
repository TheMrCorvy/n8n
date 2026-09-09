# =============================================================================
# Dockerfile — n8n with yt-dlp, ffmpeg, and spotdl
# =============================================================================
# The official n8n:latest is a Docker Hardened Image (DHI) that has apk and
# most system tools stripped for security — making runtime installs impossible.
#
# Instead, we build on plain Alpine 3.24 + the same Node.js version the
# official image ships (v24), install n8n via npm, and layer the media tools
# on top. Everything is baked at build time; startup is fast and there are no
# runtime install scripts to fail.
# =============================================================================

FROM node:24-alpine3.21

# ── System packages ───────────────────────────────────────────────────────────
# Install ffmpeg, Python + pip, wget (used to download yt-dlp binary).
RUN apk add --no-cache \
      ffmpeg \
      python3 \
      py3-pip \
      wget \
      su-exec

# ── n8n ───────────────────────────────────────────────────────────────────────
ARG N8N_VERSION=2.36.9
RUN npm install -g n8n@${N8N_VERSION} --omit=dev

# ── yt-dlp ────────────────────────────────────────────────────────────────────
RUN wget -qO /usr/local/bin/yt-dlp \
      "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp" \
 && chmod +x /usr/local/bin/yt-dlp

# ── spotdl ────────────────────────────────────────────────────────────────────
RUN pip3 install --break-system-packages --quiet spotdl

# ── Runtime user & directories ────────────────────────────────────────────────
RUN addgroup -S node 2>/dev/null || true \
 && adduser  -S -G node -h /home/node node 2>/dev/null || true \
 && mkdir -p /home/node/.n8n /music \
 && chown -R node:node /home/node /music

# ── Copy entrypoint from official image (handles certs + delegates to n8n) ───
# We replicate the minimal official entrypoint inline so we don't need to COPY
# from the hardened image at build time.
COPY scripts/entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

WORKDIR /home/node

EXPOSE 5678

USER node

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["n8n"]
