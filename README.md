# Rooftop Rush

> A real-time multiplayer platformer **race**. Sprint across the rooftops, hit every checkpoint, don't fall — first to the finish wins. Built in **Godot 4.6** for **GFA2 Game Week**.

**▶ Play:** https://rooftop-web-production.up.railway.app  ·  Server: `wss://rooftop-server-production.up.railway.app`

---

## What it is

2–8 players drop into the same level and race through a 2D platformer obstacle course in real time. Levels unlock as you clear them; your best times persist on a server-side leaderboard.

- **Real-time multiplayer** over WebSocket (authoritative headless Godot server).
- **Levels & progression** — discrete tracks, unlock chain, per-level best-time leaderboard, cosmetic unlocks.
- **Deployed & accessible** — open a URL in the browser, no install.

## Tech stack

| Layer | Choice |
|---|---|
| Engine / language | Godot 4.6.3 · GDScript |
| Networking | Godot high-level multiplayer over `WebSocketMultiplayerPeer` |
| Server | Headless Godot dedicated-server export, Docker, on Railway |
| Client | Godot HTML5 export (single-threaded), static-hosted on Railway |

This is a **Game Week** project: the point is shipping a polished multiplayer game in a stack the author had never touched, using AI as the learning engine. See [`BRAINLIFT.md`](./BRAINLIFT.md) for the daily learning log.

## How to play

1. Open the live URL.
2. Enter a name, join the lobby, hit **Ready**.
3. When everyone's ready, a countdown starts — then race to the finish.
4. Clear a level to unlock the next; beat the clock to climb the leaderboard.

Controls: **←/→** or **A/D** move · **Space/W/↑** jump · **Shift** dash.

## Features

- 5 selectable runners (animated, original pixel art) with distinct silhouettes
- 2 rotating courses (Neon Rooftops, Spire Climb) — checkpoints, hazards, finish gates
- Tight platformer feel: run, variable jump, coyote time, jump buffer, air-dash with trail
- Server-authoritative race loop: lobby → ready → synced countdown → race → results
- Persistent per-course best-time leaderboard + win-based cosmetic unlocks
- Chiptune SFX, particles, screen shake — all original/procedural

## Repository docs

- [`docs/ARCHITECTURE.md`](./docs/ARCHITECTURE.md) — system architecture & networking model
- [`docs/DECISIONS.md`](./docs/DECISIONS.md) — key technical decisions & rationale (8 ADRs)
- [`docs/SETUP.md`](./docs/SETUP.md) — local setup, build & deployment guide
- [`docs/PERFORMANCE.md`](./docs/PERFORMANCE.md) — perf model + 8-player stress test + latency
- [`docs/CURRICULUM.md`](./docs/CURRICULUM.md) — the AI-generated learning path used to ramp on Godot
- [`docs/DEMO_SCRIPTS.md`](./docs/DEMO_SCRIPTS.md) — recording scripts for the demo videos
- [`BRAINLIFT.md`](./BRAINLIFT.md) — daily progress, AI prompts, challenges & pivots

## Status

**Feature-complete & deployed.** Real-time multiplayer, levels + progression, persistent
leaderboard, polish (juice/SFX), and an 8-player stress test all done and live on Railway.
See [`BRAINLIFT.md`](./BRAINLIFT.md) for the daily build log and [`docs/DEMO_SCRIPTS.md`](./docs/DEMO_SCRIPTS.md) for video scripts.
