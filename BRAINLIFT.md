# Brainlift — Game Week learning log

The living record of ramping on a brand-new stack (Godot + GDScript) with AI as the learning engine: daily progress, the prompts that actually accelerated learning, challenges, and pivots.

**Project:** Rooftop Rush — real-time multiplayer 2D platformer race
**Stack (never touched before):** Godot 4.6 · GDScript · WebSocket multiplayer · Railway
**Clock:** Jun 8 → Jun 14, 2026

---

## Day 1 — Jun 8 · Setup, research, transport spike

### Goal
Pick the stack, prove the *learning approach* works, and de-risk the single scariest unknown on paper before writing any game code.

### What happened
- **Stack decision.** Chose Godot + GDScript for maximum novelty (strongest Learning-Velocity story), a 2D PvP platformer-race for the game, and Railway for an authoritative-server deploy.
- **Critical research win (before writing code).** Used AI to interrogate primary docs and surfaced the decision the whole week hinges on: Godot's default multiplayer is **ENet/UDP**, which **browsers can't use and Railway won't route**. The fix is `WebSocketMultiplayerPeer` as a drop-in transport for the high-level multiplayer API. Also confirmed: single-threaded web export needs **no COOP/COEP headers** (huge deploy simplification), and headless dedicated-server export runs in Docker on a glibc base. → Captured in [DECISIONS.md](./docs/DECISIONS.md) D2/D4/D5.
- Installed Godot 4.6.3 (Homebrew cask) + Web & Linux export templates (`web_nothreads_release.zip` for the single-threaded client, `linux_release.x86_64` for the headless server).
- **Built the networking POC as real spine code (not throwaway)** — `project/scripts/Main.gd`: role-switched (server vs client) WebSocket bootstrap + an `@rpc` ping/pong roundtrip.
- **PROVED the scariest unknown, headlessly, on Day 1:** ran server + client both `--headless` and confirmed an RPC roundtrip over `WebSocketMultiplayerPeer`:
  ```
  [client] connected (my id=424995361) — sending ping
  [server] ping from 424995361: hello-from-424995361
  [client] got 'pong:hello-from-424995361' — ROUNDTRIP OK
  ```
  Full high-level multiplayer (peer lifecycle + targeted `rpc_id`) works over WebSocket. The entire architecture rested on this assumption — now it's empirical, not hoped-for.

### AI prompts that worked
- _"Verify from primary sources (docs.godotengine.org): can Godot's high-level multiplayer run over WebSocketMultiplayerPeer instead of ENet, for a browser client? What's the exact pattern, and what changed recently re: web-export threading headers?"_ — turned a vague worry into a concrete, cited architecture. **Lesson: make the AI cite primary docs and flag what changed recently — game-dev answers online are full of stale pre-4.3 advice.**
- Methodology that paid off: **read the one primary doc → immediately build the smallest headless POC that exercises it.** The WebSocket-RPC roundtrip took minutes to validate and removed the single biggest project risk before any game code existed.

### Challenges / pivots
- **`--headless` has no display**, so visual "game feel" POCs can't be auto-judged here — but the *networking* POC is fully headless-testable (assert the roundtrip in stdout), which is exactly the risk worth front-loading. Player-feel (POC-1) is deferred to Day 3 where it's built + judged in the editor.
- No pivots needed — the planned transport held up.

### Tomorrow
- Build the deployed two-browser-tab spine (the make-or-break POC). Don't touch real game code until it passes.

---

## Day 2 — Jun 8 · Deployed multiplayer spine (the make-or-break gate) ✅

### Goal
Get the riskiest thing — a real-time multiplayer slice — **deployed and reachable on the public internet** before writing a line of actual game code.

### What happened (gate PASSED, same day as Day 1)
- Grew the POC into a real **authoritative-relay spine** (`Net.gd` autoload): clients submit position at 20 Hz, server broadcasts snapshots, remote players interpolate; live **RTT/ping** readout; connect/disconnect handled.
- Verified the whole sync path **headlessly** first: server + two `--bot` clients, each logging the *other's changing position*. No browser needed to prove correctness.
- **Exported** a Linux dedicated-server binary + a single-threaded Web client (`export_presets.cfg`), wrapped the server in Docker, and **deployed both to Railway** as two services.
- **End-to-end proof over the public internet:** pointed two local clients at `wss://rooftop-server-production.up.railway.app` → they connected through Railway's TLS edge and synced each other's movement. Web client serves over HTTPS (wasm/js/pck all 200).
- **Human-verified in-browser:** two real browser tabs each rendered both players' squares moving live. Gate passed by eye, not just by logs. (UX note for Day 6: one connected client correctly shows one square — worth a "waiting for players / share this link" hint so it doesn't read as "broken".)

### AI prompts / techniques that worked
- _"Railway gives no UDP and terminates TLS at the edge — what exactly does my Godot WS server bind, and how does the browser reach it?"_ → the `wss://` (client) vs plain `ws://`+`$PORT` (server) split, which made the deploy work first try on the networking layer.
- **Verify headlessly, then deploy.** Bots that auto-move + log what they see turned "does multiplayer work?" into a one-command assertion — caught nothing broken because the design was sound, but would have caught regressions instantly.

### Challenges / fixes
- **Silent server on Railway:** stdout is block-buffered off a TTY → no logs. Fix: `application/run/flush_stdout_on_print=true`.
- **`railway up` skipped the exported binary** (it's under gitignored `build/`) → Docker `COPY` failed. Fix: `--no-gitignore`.
- **Web deploy 504** pulling the Caddy base image — transient Docker Hub hiccup; a re-run succeeded.
- Benign `ready_state != STATE_OPEN` when a snapshot races a disconnecting peer — harmless, will guard the broadcast on Day 4.

### Note
Two phases (Day 1 + Day 2) done in one sitting. The hardest, highest-risk work — multiplayer transport + deploy — is behind us and **live**, which is exactly the point of front-loading it.

### Next
Day 3: real player controller (run/jump/coyote/dash, *feels good*) + Level 1 (TileMap, checkpoints, finish), judged visually in the editor.

---

<!-- New day entries go above this line, newest at top of the day list or appended in order — keep daily. -->
