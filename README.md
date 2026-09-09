# n8n – Self-Hosted

> [!NOTE]
> Self-hosted [n8n](https://n8n.io) running in Docker with a **SQLite** backend.
> All persistent data lives in `./data/` (git-ignored) and can be backed up with a simple script.

---

## Table of Contents

1. [Project Structure](#1-project-structure)
2. [Prerequisites](#2-prerequisites)
   - [Windows 11 – Docker Desktop](#21-windows-11--docker-desktop)
   - [macOS (Intel) – OrbStack](#22-macos-intel--orbstack)
   - [Ubuntu Server 24.04 – Docker Engine](#23-ubuntu-server-2404--docker-engine)
3. [Initializing the Project](#3-initializing-the-project)
   - [Step 1 – Get the code](#step-1--get-the-code)
   - [Step 2 – Create the `.env` file](#step-2--create-the-env-file)
   - [Step 3 – Generate the encryption key](#step-3--generate-the-encryption-key)
   - [Step 4 – Configure your timezone](#step-4--configure-your-timezone)
   - [Step 5 – Fix data directory permissions (Linux only)](#step-5--fix-data-directory-permissions-linux-only)
   - [Step 6 – Verify Docker is ready](#step-6--verify-docker-is-ready)
   - [Step 7 – Pull the n8n image](#step-7--pull-the-n8n-image)
   - [Step 8 – Start the container](#step-8--start-the-container)
   - [Step 9 – Verify the container is healthy](#step-9--verify-the-container-is-healthy)
   - [Step 10 – First login & owner account setup](#step-10--first-login--owner-account-setup)
4. [Music Downloads (yt-dlp & spotdl)](#4-music-downloads-yt-dlp--spotdl)
5. [Day-to-Day Operations](#5-day-to-day-operations)
6. [Stopping & Removing](#6-stopping--removing)
7. [Data & Backups](#7-data--backups)
8. [Environment Variables Reference](#8-environment-variables-reference)
9. [Kubernetes (Getting Started)](#9-kubernetes-getting-started)
10. [Upgrading n8n](#10-upgrading-n8n)
11. [Troubleshooting](#11-troubleshooting)

---

## 1. Project Structure

```
n8n/
├── docker-compose.yml      ← Main compose file
├── .env.example            ← Template – copy to .env and fill in values
├── .env                    ← Your local secrets (git-ignored, never committed)
├── .gitignore
├── README.md
├── scripts/                ← Helper scripts
│   └── entrypoint.sh       ← Custom entrypoint: installs yt-dlp, ffmpeg, spotdl on first boot
├── data/                   ← ALL persistent n8n data lives here (git-ignored)
│   ├── .gitkeep            ← Placeholder so git tracks the empty folder
│   ├── database.sqlite     ← SQLite database (auto-created on first run)
│   ├── config              ← n8n runtime config (auto-created on first run)
│   └── ...                 ← Additional runtime files
└── k8s/                    ← Kubernetes manifests (starter pack)
    ├── kustomization.yaml  ← Apply everything: kubectl apply -k k8s/
    ├── namespace.yaml
    ├── secret.yaml
    ├── pvc.yaml
    ├── deployment.yaml
    └── service.yaml
```

---

## 2. Prerequisites

Install and verify the required tooling for your operating system before proceeding.

---

### 2.1 Windows 11 – Docker Desktop

#### Install

1. Download **Docker Desktop** from https://www.docker.com/products/docker-desktop/
2. Run the installer and follow the wizard. When asked, choose **"Use WSL 2 instead of Hyper-V"**.
3. After installation, launch Docker Desktop and wait for the whale icon in the system tray to stop animating (engine is ready).

#### Enable WSL 2 backend (required)

Open Docker Desktop → **Settings** → **General** and confirm **"Use the WSL 2 based engine"** is checked. If it was not already on, toggle it, click **Apply & Restart**, and wait for the engine to restart.

> [!IMPORTANT]
> Running on the WSL 2 backend is mandatory for bind-mount performance and Linux container compatibility. Without it, volume permissions may behave unexpectedly.

#### Install Git for Windows (if not present)

Download from https://git-scm.com/download/win and install with default options. After installation, open a new **PowerShell** or **Git Bash** window.

#### Verify

Open **PowerShell** and run:

```powershell
docker --version
# Expected: Docker version 26.x.x or newer

docker compose version
# Expected: Docker Compose version v2.x.x

git --version
# Expected: git version 2.x.x
```

> [!TIP]
> For best bind-mount performance on Windows, keep the project folder **inside the WSL 2 filesystem**, not on your Windows drive (`C:\`). See the [Troubleshooting](#10-troubleshooting) section for details.

---

### 2.2 macOS (Intel) – OrbStack

#### Install

1. Download **OrbStack** from https://orbstack.dev
2. Open the `.dmg`, drag OrbStack to Applications, and launch it.
3. On first launch, OrbStack will set up the Docker engine automatically. Grant any requested system permissions.
4. Wait for the OrbStack menu bar icon to show a green status.

> [!NOTE]
> OrbStack is a drop-in, high-performance replacement for Docker Desktop. It bundles a full Docker Engine + Compose v2 and does **not** require Rosetta or any extra configuration on Intel Macs.

#### Install Git (if not present)

Git ships with Xcode Command Line Tools:

```bash
xcode-select --install
```

Or install via Homebrew:

```bash
brew install git
```

#### Verify

Open **Terminal** and run:

```bash
docker --version
# Expected: Docker version 26.x.x or newer

docker compose version
# Expected: Docker Compose version v2.x.x

git --version
# Expected: git version 2.x.x
```

---

### 2.3 Ubuntu Server 24.04 – Docker Engine

> [!NOTE]
> Install **Docker Engine** (the server-side daemon), not Docker Desktop. Docker Desktop is a GUI app for workstations and is not suitable for headless servers.

#### Install Docker Engine

Run the following commands as a user with `sudo` privileges:

```bash
# 1. Remove any old/conflicting packages
for pkg in docker.io docker-doc docker-compose docker-compose-v2 \
           podman-docker containerd runc; do
  sudo apt-get remove -y $pkg 2>/dev/null || true
done

# 2. Install prerequisites
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release

# 3. Add Docker's official GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# 4. Add the Docker stable repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 5. Install Docker Engine and the Compose plugin
sudo apt-get update
sudo apt-get install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

# 6. Enable Docker to start on boot and start it now
sudo systemctl enable --now docker
```

#### Allow running Docker without sudo (recommended)

```bash
sudo usermod -aG docker $USER

# Apply the new group without logging out
newgrp docker
```

> [!IMPORTANT]
> The `newgrp docker` command applies the group change for the current shell session only. For it to apply to all new sessions, log out and log back in (or reboot the server).

#### Install Git

```bash
sudo apt-get install -y git
```

#### Verify

```bash
docker --version
# Expected: Docker version 26.x.x or newer

docker compose version
# Expected: Docker Compose version v2.x.x

git --version
# Expected: git version 2.x.x

# Confirm Docker daemon is running
sudo systemctl status docker | grep "Active:"
# Expected: Active: active (running)
```

---

## 3. Initializing the Project

The following steps are written to be **platform-agnostic**. Commands that differ per OS are clearly labelled.

---

### Step 1 – Get the code

Clone the repository to your machine:

```bash
# Using SSH (recommended if you have an SSH key configured)
git clone git@github.com:YOUR_ORG/n8n.git

# Using HTTPS
git clone https://github.com/YOUR_ORG/n8n.git
```

Enter the project directory:

```bash
cd n8n
```

Confirm the contents:

```bash
# Linux / macOS
ls -la

# Windows PowerShell
Get-ChildItem -Force
```

You should see `docker-compose.yml`, `.env.example`, `.gitignore`, `data/`, and `k8s/`.

---

### Step 2 – Create the `.env` file

The `.env` file holds your local configuration and secrets. It is **git-ignored** and must never be committed.

```bash
# Linux / macOS
cp .env.example .env

# Windows PowerShell
Copy-Item .env.example .env
```

Open `.env` in your preferred editor:

```bash
# Linux / macOS
nano .env          # or: vim .env / code .env

# Windows PowerShell
notepad .env       # or: code .env
```

At minimum you **must** set:
- `N8N_ENCRYPTION_KEY` (see Step 3)
- `GENERIC_TIMEZONE` (see Step 4)

All other values have sensible defaults for local development.

---

### Step 3 – Generate the encryption key

> [!CAUTION]
> **Set this value once and never change it.** n8n uses this key to encrypt all saved credentials (API keys, passwords, tokens). If you change or lose it, every stored credential will be permanently unreadable and will need to be re-entered.

Generate a cryptographically random 32-byte (64-character hex) key:

```bash
# Linux / macOS
openssl rand -hex 32
```

```powershell
# Windows PowerShell (no openssl required)
-join ((1..32) | ForEach-Object { '{0:x2}' -f (Get-Random -Maximum 256) })
```

Copy the output (it will look like `a3f8c2...`) and paste it into `.env`:

```dotenv
N8N_ENCRYPTION_KEY=paste-your-64-character-hex-string-here
```

**Double-check:** the value should be exactly 64 hexadecimal characters with no spaces or quotes.

---

### Step 4 – Configure your timezone

Edit `.env` and set `GENERIC_TIMEZONE` to your local timezone identifier. This ensures that scheduled workflows run at the correct times.

```dotenv
# Examples
GENERIC_TIMEZONE=America/Argentina/Buenos_Aires
GENERIC_TIMEZONE=America/New_York
GENERIC_TIMEZONE=Europe/London
GENERIC_TIMEZONE=Europe/Madrid
GENERIC_TIMEZONE=Asia/Tokyo
GENERIC_TIMEZONE=Australia/Sydney
```

Full list of valid identifiers: https://en.wikipedia.org/wiki/List_of_tz_database_time_zones (use the value in the **TZ identifier** column).

---

### Step 5 – Fix data directory permissions (Linux only)

> [!NOTE]
> This step is **only required on Linux (Ubuntu Server)**. Docker Desktop on Windows and OrbStack on macOS handle bind-mount permissions automatically.

Inside the container n8n runs as the `node` user (UID `1000`, GID `1000`). The `data/` folder on the host must be owned by the same UID/GID so the container can read and write to it:

```bash
# Check the current owner
ls -la | grep data

# Fix ownership (run from the project root)
sudo chown -R 1000:1000 data/

# Verify
ls -la | grep data
# Expected output: drwxr-xr-x ... 1000 1000 ... data
```

---

### Step 6 – Verify Docker is ready

Before starting the container, confirm the Docker daemon is reachable:

```bash
docker info
```

The output should show server information (OS, kernel version, containers count). If you get a `permission denied` or `Cannot connect` error:

- **Windows**: Make sure Docker Desktop is running (whale icon in system tray is stable).
- **macOS**: Make sure OrbStack is running (menu bar icon is green).
- **Linux**: Run `sudo systemctl start docker` then retry. If you added yourself to the `docker` group, log out and back in.

---

### Step 7 – Pull the n8n image

Pre-pulling the image separates the download step from the startup step, making it easier to diagnose network issues:

```bash
docker compose pull
```

You will see Docker pulling layers for `n8nio/n8n:latest`. This may take a few minutes on a first pull depending on your connection speed. Subsequent runs will only download changed layers.

Verify the image was pulled:

```bash
docker images | grep n8n
# Expected: n8nio/n8n   latest   <image-id>   <date>   <size>
```

---

### Step 8 – Start the container

```bash
docker compose up -d
```

The `-d` flag runs the container in detached (background) mode. Docker will:

1. Read your `.env` file automatically.
2. Create the `n8n` container.
3. Bind-mount `./data/` into the container at `/home/node/.n8n`.
4. Start the n8n process inside the container.

**Expected output:**

```
[+] Running 1/1
 ✔ Container n8n  Started
```

---

### Step 9 – Verify the container is healthy

#### Check container status

```bash
docker compose ps
```

The `STATUS` column should show `Up X seconds (healthy)` after the `start_period` of 30 seconds has elapsed. If it shows `Up X seconds (health: starting)`, wait a moment and re-run the command.

#### Check logs for errors

```bash
docker compose logs n8n
```

On a successful first start you should see lines similar to:

```
n8n ready on 0.0.0.0, port 5678
Editor is now accessible via: http://localhost:5678
```

If you see errors, consult the [Troubleshooting](#10-troubleshooting) section.

#### Check the health endpoint directly

```bash
# Linux / macOS
curl -s http://localhost:5678/healthz

# Windows PowerShell
Invoke-WebRequest -Uri http://localhost:5678/healthz -UseBasicParsing | Select-Object -ExpandProperty Content
```

Expected response: `{"status":"ok"}`

#### Confirm data files were created

```bash
# Linux / macOS
ls -lh data/

# Windows PowerShell
Get-ChildItem data\
```

You should see `database.sqlite` and `config` (among others) — these were created automatically by n8n on first startup.

---

### Step 10 – First login & owner account setup

Open your browser and navigate to:

**http://localhost:5678**

n8n will display the **Setup** screen (this only appears once). Follow these steps:

1. **Enter your email address** – this will be your owner account login.
2. **Set a strong password** – use a password manager.
3. **Fill in your first and last name** (used for display purposes only).
4. Click **"Next"**.
5. n8n may ask whether you want to receive product updates by email – choose your preference.
6. Click **"Get started"** to enter the n8n editor.

> [!IMPORTANT]
> The owner account has **full administrative access** to all workflows, credentials, and settings. Store the credentials in a password manager immediately.

> [!TIP]
> After the owner account is created, n8n's built-in user management is fully active. You can invite additional users from **Settings → Users**.

---

## 4. Music Downloads (yt-dlp & spotdl)

> [!NOTE]
> This feature installs **yt-dlp**, **ffmpeg**, and **spotdl** inside the n8n container at first boot via a custom entrypoint script (`scripts/entrypoint.sh`). No Dockerfile is required.

### How it works

| Tool | Purpose |
|---|---|
| `ffmpeg` | Audio encoding and post-processing (remux, normalize, embed artwork) |
| `yt-dlp` | Download audio from YouTube URLs in the best available quality |
| `spotdl` | Resolve a Spotify track/album/playlist URL, find the best YouTube match, download and embed full ID3 metadata (title, artist, album, cover art) |

On first `docker compose up`, the entrypoint script runs `apk add ffmpeg`, downloads the latest `yt-dlp` binary, and runs `pip3 install spotdl`. A marker file (`/home/node/.n8n/.tools_installed`) is written so subsequent restarts skip the install and start instantly.

Downloaded files land in the container at `/music`, which is bind-mounted from `MUSIC_DOWNLOAD_PATH` on the host — the same folder Navidrome (shockwave) points its `MUSIC_PATH` at. Navidrome's scanner (configured with `SCANNER_SCHEDULE=1m` by default) will detect and index new tracks automatically.

### Setup

1. Set `MUSIC_DOWNLOAD_PATH` in `.env` to the absolute host path of your music library:

   ```dotenv
   MUSIC_DOWNLOAD_PATH=/mnt/storage/music
   ```

2. Ensure the n8n container can write to that directory:

   ```bash
   # Linux only – the container runs as root, so this should already work.
   # If Navidrome also needs write access, keep PUID/PGID consistent.
   ls -la /mnt/storage/music
   ```

3. (Re)start n8n:

   ```bash
   docker compose up -d
   ```

4. Watch the install on first boot:

   ```bash
   docker compose logs -f n8n
   # You should see: [entrypoint] Installing yt-dlp, ffmpeg and spotdl...
   # followed by:    [entrypoint] Tools installed successfully.
   ```

### Building the n8n workflow

Create a new **Webhook** workflow in n8n with the following structure:

```
Webhook (POST /download)
  └── Switch (route by "source" field)
        ├── youtube → Execute Command (yt-dlp)
        └── spotify → Execute Command (spotdl)
```

#### Webhook trigger

- Method: `POST`
- Path: `download`
- Response mode: `When last node finishes`

Expected JSON body:

```json
{ "url": "https://...", "source": "youtube" }
{ "url": "https://open.spotify.com/track/...", "source": "spotify" }
```

#### Switch node

- Mode: `Rules`
- Rule 1 → value `{{ $json.body.source }}` equals `youtube`
- Rule 2 → value `{{ $json.body.source }}` equals `spotify`

#### Execute Command – YouTube branch

```bash
yt-dlp \
  --extract-audio \
  --audio-format mp3 \
  --audio-quality 0 \
  --embed-thumbnail \
  --add-metadata \
  -o "/music/%(artist)s/%(album)s/%(title)s.%(ext)s" \
  "{{ $json.body.url }}"
```

#### Execute Command – Spotify branch

```bash
spotdl \
  --output "/music/{artists}/{album}/{title}.{output-ext}" \
  --format mp3 \
  "{{ $json.body.url }}"
```

> [!TIP]
> Both commands use sub-folder templates (`artist/album/title`) so the music library stays organized and Navidrome can parse metadata from the directory structure as a fallback.

> [!IMPORTANT]
> spotdl resolves Spotify URLs to YouTube and downloads from there — no Spotify Premium account or API key is required.

### Testing from the command line

```bash
# YouTube single track
curl -X POST http://localhost:5678/webhook/download \
  -H "Content-Type: application/json" \
  -d '{"url":"https://www.youtube.com/watch?v=dQw4w9WgXcQ","source":"youtube"}'

# Spotify single track
curl -X POST http://localhost:5678/webhook/download \
  -H "Content-Type: application/json" \
  -d '{"url":"https://open.spotify.com/track/4uLU6hMCjMI75M1A2tKUQC","source":"spotify"}'
```

### Verify tools inside the container

```bash
docker compose exec n8n yt-dlp --version
docker compose exec n8n spotdl --version
docker compose exec n8n ffmpeg -version | head -1
```

---

## 5. Day-to-Day Operations

```bash
# Start (if not already running)
docker compose up -d

# Stop (data is preserved)
docker compose down

# Restart the container
docker compose restart n8n

# View live logs (Ctrl+C to exit)
docker compose logs -f n8n

# View the last 100 log lines
docker compose logs --tail=100 n8n

# Check container resource usage (CPU, memory)
docker stats n8n

# Open a shell inside the container (for debugging)
docker compose exec n8n sh
```

---

## 6. Stopping & Removing

```bash
# Stop containers only (data is preserved in ./data/)
docker compose down

# Stop and remove the container + network (data still preserved in ./data/)
docker compose down --remove-orphans

# ⚠️  Nuclear option: stop + remove EVERYTHING including data
docker compose down
rm -rf data/*               # Linux / macOS
Remove-Item data\* -Recurse # Windows PowerShell
```

---

## 7. Data & Backups

All n8n data is stored in the `./data/` directory on the host:

| Path | Contents |
|---|---|
| `data/database.sqlite` | Workflows, credentials, executions, settings |
| `data/config` | n8n instance configuration (encryption salt, etc.) |
| `data/binaryData/` | Binary files attached to workflow executions |
| `data/.n8n/` | Internal runtime files |

### Backing up

Since everything is in a single directory, a backup is as simple as archiving it:

```bash
# Linux / macOS – timestamped tar archive
tar -czf "n8n-backup-$(date +%Y%m%d-%H%M%S).tar.gz" data/

# Windows PowerShell – timestamped zip archive
$ts = Get-Date -Format "yyyyMMdd-HHmmss"
Compress-Archive -Path data\ -DestinationPath "n8n-backup-$ts.zip"
```

> [!TIP]
> For live backups without stopping the container, use SQLite's `.backup` command:
> ```bash
> docker compose exec n8n sqlite3 /home/node/.n8n/database.sqlite ".backup '/home/node/.n8n/backup.sqlite'"
> ```
> Then copy `data/backup.sqlite` to your backup destination.

> [!TIP]
> Automate backups with a cron job (Linux/macOS) or Windows Task Scheduler and ship archives to a cloud provider (S3, Backblaze B2, Cloudflare R2, etc.).

### Restoring a backup

```bash
# 1. Stop the container
docker compose down

# 2. Remove current data (be sure you have a backup!)
rm -rf data/*               # Linux / macOS
Remove-Item data\* -Recurse # Windows PowerShell (keep .gitkeep if present)

# 3. Extract the backup
tar -xzf n8n-backup-YYYYMMDD-HHMMSS.tar.gz  # restores ./data/

# 4. Fix permissions if on Linux
sudo chown -R 1000:1000 data/

# 5. Restart
docker compose up -d
```

---

## 8. Environment Variables Reference

| Variable | Default | Required | Description |
|---|---|---|---|
| `N8N_HOST` | `localhost` | No | Hostname n8n binds to |
| `N8N_PORT` | `5678` | No | Port exposed on the host |
| `N8N_PROTOCOL` | `http` | No | `http` or `https` |
| `WEBHOOK_URL` | `http://localhost:5678/` | No | Full base URL used for webhooks (must be publicly reachable for external triggers) |
| `N8N_ENCRYPTION_KEY` | – | **Yes** | 32-byte hex key for credential encryption – set once, never change |
| `GENERIC_TIMEZONE` | `America/New_York` | No | Timezone for scheduled workflows |
| `N8N_DIAGNOSTICS_ENABLED` | `false` | No | Send anonymous usage statistics to n8n |
| `N8N_VERSION_NOTIFICATIONS_ENABLED` | `true` | No | Show in-app banner when a new version is available |
| `EXECUTIONS_DATA_SAVE_ON_ERROR` | `all` | No | Save execution data for failed runs (`all` or `none`) |
| `EXECUTIONS_DATA_SAVE_ON_SUCCESS` | `all` | No | Save execution data for successful runs (`all` or `none`) |
| `EXECUTIONS_DATA_SAVE_ON_PROGRESS` | `false` | No | Save node-level progress data during execution |
| `EXECUTIONS_DATA_SAVE_MANUAL_EXECUTIONS` | `true` | No | Save executions triggered manually from the editor |
| `EXECUTIONS_DATA_PRUNE` | `true` | No | Automatically delete old execution data |
| `EXECUTIONS_DATA_MAX_AGE` | `336` | No | Max age (hours) of execution data before pruning – `336` = 14 days |
| `MUSIC_DOWNLOAD_PATH` | – | **Yes** | Absolute host path bind-mounted at `/music` inside the container; yt-dlp and spotdl write downloaded tracks here |

See `.env.example` for additional commentary and `docker-compose.yml` for how each variable maps to n8n's internal configuration.

---

## 9. Kubernetes (Getting Started)

> [!NOTE]
> The `k8s/` directory contains a **starter pack** of Kubernetes manifests. They mirror the Docker Compose configuration exactly and are designed to be extended as your infrastructure matures.

### What's included

| File | Purpose |
|---|---|
| `namespace.yaml` | Creates the `n8n` namespace |
| `secret.yaml` | Holds the encryption key (must be populated before applying) |
| `pvc.yaml` | 5 Gi PersistentVolumeClaim for SQLite data |
| `deployment.yaml` | Single-replica Deployment with health probes and resource limits |
| `service.yaml` | ClusterIP Service mapping port 80 → container port 5678 |
| `kustomization.yaml` | Applies all manifests with a single command |

### Steps to deploy

```bash
# 1. Generate the encryption key and base64-encode it
openssl rand -hex 32 | base64    # Linux / macOS

# PowerShell equivalent
$key = -join ((1..32) | ForEach-Object { '{0:x2}' -f (Get-Random -Maximum 256) })
[Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($key))
```

Open `k8s/secret.yaml` and replace `REPLACE_WITH_BASE64_ENCODED_KEY` with the output above.

```bash
# 2. (Optional) Update the timezone in k8s/deployment.yaml
#    Look for: value: "America/New_York"

# 3. Apply all manifests
kubectl apply -k k8s/

# 4. Watch the pod come up
kubectl -n n8n get pods -w
# Expected: n8n-... 1/1 Running after ~30 seconds

# 5. Check logs
kubectl -n n8n logs -l app.kubernetes.io/name=n8n --tail=50

# 6. Access the UI locally via port-forward
kubectl -n n8n port-forward svc/n8n 5678:80
# Then open http://localhost:5678
```

### Important limitations with SQLite

> [!WARNING]
> SQLite supports only **one writer at a time**. The Deployment is pinned to `replicas: 1` with `strategy: Recreate`, which prevents two pods from writing simultaneously. Do **not** increase replicas while using SQLite.
>
> To scale horizontally, migrate to PostgreSQL and set `DB_TYPE=postgresdb` along with the relevant `DB_POSTGRESDB_*` environment variables.

### Next steps for a production Kubernetes cluster

When you're ready to harden the deployment, consider adding:

- **Ingress** + **cert-manager** for automatic TLS certificates
- **NetworkPolicy** to restrict pod-to-pod traffic
- **HorizontalPodAutoscaler** (after migrating to PostgreSQL)
- **PodDisruptionBudget** for controlled node drains
- **ExternalSecrets** or **Sealed Secrets** for GitOps-safe secret management

---

## 10. Upgrading n8n

Since the image tag is `latest`, pulling the newest release is straightforward.

> [!TIP]
> Always **back up `./data/`** before upgrading, especially across major version bumps. n8n automatically runs database migrations on startup, which are not reversible.

```bash
# 1. Back up current data
tar -czf "n8n-backup-pre-upgrade-$(date +%Y%m%d).tar.gz" data/

# 2. Pull the latest image
docker compose pull

# 3. Recreate the container with the new image
docker compose up -d --force-recreate

# 4. Verify the new version
docker compose logs n8n | grep "n8n@"
```

---

## 11. Troubleshooting

### Container exits immediately after starting

```bash
docker compose logs n8n
```

| Symptom in logs | Cause | Fix |
|---|---|---|
| `N8N_ENCRYPTION_KEY is not set` | Missing env variable | Set `N8N_ENCRYPTION_KEY` in `.env` |
| `EACCES: permission denied ... /home/node/.n8n` | Wrong ownership on `./data/` | Run `sudo chown -R 1000:1000 data/` (Linux only) |
| `Error: SQLITE_CANTOPEN` | SQLite cannot open or create the database | Fix permissions on `./data/` or delete `data/database.sqlite` to reset |
| `MUSIC_DOWNLOAD_PATH must be set in .env` | Missing required env variable | Add `MUSIC_DOWNLOAD_PATH=/your/music/path` to `.env` |

---

### Port 5678 is already in use

Find what is using it:

```bash
# Linux / macOS
lsof -i :5678

# Windows PowerShell
Get-NetTCPConnection -LocalPort 5678 | Select-Object -Property LocalPort, OwningProcess
```

Then either stop the conflicting process, or change the exposed port in `.env`:

```dotenv
N8N_PORT=5679
```

And update the `ports` section of `docker-compose.yml` accordingly:

```yaml
ports:
  - "${N8N_PORT:-5678}:5678"
```

---

### Webhooks not receiving external traffic

n8n uses `WEBHOOK_URL` to build the webhook URLs it displays in the editor. If this does not match the address external services reach, webhooks will fail silently.

Set the correct public URL in `.env`:

```dotenv
WEBHOOK_URL=https://n8n.yourdomain.com/
N8N_PROTOCOL=https
N8N_HOST=n8n.yourdomain.com
```

Then restart: `docker compose restart n8n`

---

### Health check stuck on "starting"

The container needs up to 30 seconds to become healthy. Wait and re-check:

```bash
watch docker compose ps          # Linux / macOS (updates every 2s)
docker compose ps                # Windows (run repeatedly)
```

If it stays on `health: starting` beyond 2 minutes, check the logs for startup errors:

```bash
docker compose logs n8n
```

---

### macOS (OrbStack) – volume performance

OrbStack uses VirtioFS for bind mounts, which delivers near-native filesystem performance. No extra configuration is needed.

---

### Windows (Docker Desktop) – slow filesystem performance

Bind mounts from the Windows (`C:\`) filesystem into WSL 2 containers are inherently slower than native Linux paths. For best performance, keep the project inside the WSL 2 filesystem:

```bash
# Open a WSL terminal and clone there
cd ~
git clone https://github.com/YOUR_ORG/n8n.git
cd n8n
docker compose up -d
```

You can browse the WSL filesystem from Windows Explorer by navigating to:
`\\wsl$\Ubuntu\home\<your-wsl-username>\n8n`

---

### Reset the owner account

If you are locked out of the owner account:

```bash
# Reset all user accounts (you will need to re-create the owner on next login)
docker compose exec n8n n8n user-management:reset

# Restart to apply
docker compose restart n8n
```

Then open http://localhost:5678 and complete the setup wizard again.

---

### Inspect the SQLite database directly

```bash
# Open an interactive SQLite shell inside the container
docker compose exec n8n sqlite3 /home/node/.n8n/database.sqlite

# Useful queries
.tables                       -- list all tables
SELECT * FROM workflow_entity LIMIT 5;
SELECT * FROM credentials_entity LIMIT 5;
.quit
```

---

### yt-dlp / spotdl not found after first boot

If the tools were not installed (e.g. the container had no internet access on first boot), delete the marker file and restart:

```bash
# Remove the marker so the install runs again on next start
docker compose exec n8n rm /home/node/.n8n/.tools_installed

docker compose restart n8n
docker compose logs -f n8n   # watch the install
```

---

### Downloaded files don't appear in Navidrome

1. Confirm the file landed in `MUSIC_DOWNLOAD_PATH` on the host:

   ```bash
   ls -lh /your/music/path/
   ```

2. Trigger a manual rescan in Navidrome's web UI (**Settings → Library → Scan Now**), or wait for the automatic scan (default: every 1 minute).

3. Confirm the file has a valid audio extension (`.mp3`, `.flac`, `.ogg`, etc.) — Navidrome ignores unknown extensions.
