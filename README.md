# Rooftop Rush

> A real-time multiplayer platformer **race**. Sprint across the rooftops, hit every checkpoint, don't fall — first to the finish wins. Built in **Godot 4.6** for **GFA2 Game Week**.

**Live demo:** _(deployed Day 2 — link TBD)_

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

## Repository docs

- [`docs/ARCHITECTURE.md`](./docs/ARCHITECTURE.md) — system architecture & networking model
- [`docs/DECISIONS.md`](./docs/DECISIONS.md) — key technical decisions & rationale
- [`docs/CURRICULUM.md`](./docs/CURRICULUM.md) — the AI-generated learning path used to ramp on Godot
- [`docs/SETUP.md`](./docs/SETUP.md) — local setup & deployment guide _(added during the week)_
- [`BRAINLIFT.md`](./BRAINLIFT.md) — daily progress, AI prompts, challenges & pivots

## Status

Day 1 — scaffolding. See the task list / `BRAINLIFT.md` for current progress.
