# Setup & Deployment Guide

## Live URLs

- **Play (web client):** https://rooftop-web-production.up.railway.app
- **Game server (WebSocket):** `wss://rooftop-server-production.up.railway.app`
- Append `?server=wss://host` to the client URL to point it at a different server.

## Prerequisites

- **Godot 4.6.3** (`brew install --cask godot`) + Web & Linux **export templates** matching the version (Editor → *Manage Export Templates*, or drop the `.tpz` contents into `~/Library/Application Support/Godot/export_templates/4.6.3.stable/`).
- **Docker** (for building deploy images locally).
- **Railway CLI** (`railway`) logged in (`railway whoami`).

## Run locally

The same project is both client and server; role is chosen at launch.

```bash
# Headless server on :8915
PORT=8915 godot --headless --path project -- --server

# A client (windowed) — connects to ws://127.0.0.1:8915 by default
godot --path project

# A headless "bot" client that auto-moves (handy for testing sync without a window)
PORT=8915 godot --headless --path project -- --bot
```

Role resolution (`project/scripts/Net.gd`): `--server` arg **or** the `dedicated_server` export feature ⇒ server; otherwise client. Server URL: `SERVER_URL` env → `?server=` query param (web) → baked `WEB_SERVER_URL` (web) → `ws://127.0.0.1:$PORT`.

## Build the exports

```bash
mkdir -p build/server build/web
# Linux dedicated server — single embedded-pck binary
godot --headless --path project --export-release "Linux Server" "$PWD/build/server/rooftop_server.x86_64"
# Web client — single-threaded HTML5 (no COOP/COEP headers needed)
godot --headless --path project --export-release "Web" "$PWD/build/web/index.html"
```

> Presets live in `project/export_presets.cfg`: **"Linux Server"** (`dedicated_server=true`, `embed_pck=true`, x86_64) and **"Web"** (`thread_support=false`).
> Before re-exporting the web client, make sure `WEB_SERVER_URL` in `Net.gd` points at the deployed server.

## Deploy to Railway

Two services in one project (`rooftop-rush`), each built from a Dockerfile in `deploy/`.

```bash
railway init -n rooftop-rush                      # once: create + link project

# --- server ---
railway add -s rooftop-server
railway variables --set "RAILWAY_DOCKERFILE_PATH=deploy/server.Dockerfile" -s rooftop-server --skip-deploys
railway up -s rooftop-server --no-gitignore -c    # --no-gitignore so build/ (gitignored) uploads
railway domain -s rooftop-server                  # -> wss URL; put it in Net.gd WEB_SERVER_URL

# --- web client (re-export first, with the server URL baked in) ---
railway add -s rooftop-web
railway variables --set "RAILWAY_DOCKERFILE_PATH=deploy/web.Dockerfile" -s rooftop-web --skip-deploys
railway up -s rooftop-web --no-gitignore -c
railway domain -s rooftop-web                     # -> the public play URL
```

### Gotchas learned (the ones that cost time)

- **`--no-gitignore` is required** on `railway up`: the Dockerfiles `COPY build/…`, but `build/` is gitignored, so a normal upload omits it and the build fails at COPY.
- **stdout is block-buffered** off a TTY → set `application/run/flush_stdout_on_print=true` in `project.godot` or the server prints nothing in `railway logs`.
- **Railway injects `PORT`** (observed `8080`); the server reads it via `OS.get_environment("PORT")` and binds `0.0.0.0`. Railway terminates TLS at the edge, so the server speaks plain `ws://` while clients use `wss://`.
- **glibc base only** for the server image (Ubuntu) — Alpine/musl can fail with official Godot binaries.
- Docker Hub base-image pulls occasionally 504 during build — just re-run `railway up`.
