# Key Decisions & Rationale

ADR-style log of the load-bearing technical decisions. Newest context at top of each entry.

---

## D1 — Engine: Godot 4.6.3 + GDScript

**Decision.** Build in Godot 4.6.3 (current stable, mid-2026) using GDScript.

**Why.** Game Week requires a stack the author has *never touched*. Prior work (AgentForge, ShipShape, FleetGraph, Plugforge) is all AI/web/TypeScript — so a dedicated game engine + GDScript is maximally unfamiliar, which is exactly what the "Learning Velocity" grading lens rewards. Godot also has exceptional first-party docs and a built-in high-level multiplayer API, lowering the ramp.

**Version pin.** Godot **4.6.3** (Homebrew cask `godot`). Web + multiplayer APIs are stable across 4.3→4.6.

---

## D2 — Networking transport: WebSocket, NOT ENet/UDP

**Decision.** Use `WebSocketMultiplayerPeer` as the transport for Godot's high-level multiplayer API (RPCs, `MultiplayerSpawner`, `MultiplayerSynchronizer`).

**Why.** This is the single most important decision of the week. Godot's *default* multiplayer transport is ENet over **UDP**, which:
- **does not work in browsers** (no raw UDP in the browser sandbox), and
- **is not routable on Railway** (Railway public networking is HTTP/TCP only — no UDP).

`WebSocketMultiplayerPeer` is a drop-in `MultiplayerPeer`, so the entire high-level multiplayer stack works unchanged over WebSocket. Pattern: `peer.create_server(port)` / `peer.create_client(url)`, then `multiplayer.multiplayer_peer = peer`.

**Trade-off.** WebSocket is TCP → head-of-line blocking / higher jitter than UDP. Mitigated by (a) choosing a **race** game where positions interpolate gracefully, (b) interpolating remote players, (c) keeping authoritative state at a modest tick rate. Verified against `docs.godotengine.org` (WebSocket tutorial + `WebSocketMultiplayerPeer` class ref).

---

## D3 — Deployment: Railway, two services

**Decision.** One Railway project, two services:
- `game-server` — headless Godot dedicated-server export in a Docker container.
- `web-client` — Godot HTML5 export served as static files.

**Why.** Public URL + real concurrency, Railway tooling already wired. Verified facts:
- Railway terminates TLS at the edge → clients connect `wss://`, the Godot server speaks plain `ws://` internally on `0.0.0.0:$PORT`.
- WebSockets over HTTP/1.1 are supported; 10k conns/service cap; 60s keep-alive → add app-level ping.
- Container must bind `0.0.0.0` and read `OS.get_environment("PORT")`; Dockerfile uses **shell-form** `CMD` so `$PORT` expands.
- Client references the server URL via build-time reference variable `wss://${{game-server.RAILWAY_PUBLIC_DOMAIN}}` (web exports bake env at build time — the browser can't read server env at runtime).

**Fallback.** If the web+WS spine fails, pivot to a desktop client over Railway **TCP Proxy** (still a hosted authoritative server) — keeps all five non-negotiables, loses "open a URL".

---

## D4 — Web export: single-threaded (no COOP/COEP headers)

**Decision.** Export the HTML5 client **single-threaded** (threads OFF).

**Why.** Single-threaded web export has been the default since Godot 4.3 and requires **no** `Cross-Origin-Opener-Policy` / `Cross-Origin-Embedder-Policy` headers and no `SharedArrayBuffer`. This removes a whole class of static-hosting pain — a plain static server works. (Only threaded exports need the cross-origin-isolation headers, which would otherwise force a custom Caddy config.)

---

## D5 — Headless server build

**Decision.** Export the server as a **Linux dedicated-server export** (export preset "Export as dedicated server"), run with `--headless`. Docker base = glibc (Ubuntu/Debian), **not** Alpine.

**Why.** Since Godot 4.0 the standard Linux export template runs headless — no separate server binary, no GPU/X11. The dedicated-server preset adds the `dedicated_server` feature tag (detect via `OS.has_feature("dedicated_server")`) and strips client-only assets. Official Godot binaries link glibc, so Alpine/musl can fail — use a glibc base image.

---

## D6 — Game design: 2D PvP platformer-race ("Rooftop Rush")

**Decision.** A 2D side-scrolling platformer race: 2–8 players race through obstacle-course levels to a finish line.

**Why.** Satisfies the spec two ways — discrete tracks = "levels", unlock chain + best-times + cosmetics = "character progression". A **race** is the most forgiving multiplayer genre over a TCP transport (sync positions, not twitch hit-detection physics), and "first to the finish" is instantly readable and fun to demo. Art via Kenney.nl CC0 packs to stay polished without an art time-sink.
