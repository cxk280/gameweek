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

## Day 3 — Jun 8 · Player controller + Level 1 (Neon Rooftops)

### Goal
Turn "synced squares" into a game that *feels* like something: a real platformer controller and a playable rooftop course, in a neon-night look.

### What happened
- **Player controller** (`LocalPlayer`, `CharacterBody2D`): run with accel/friction, variable-height jump, **coyote time**, **jump buffering**, and a **dash** — the standard "feels good" platformer kit. Only the local peer simulates physics; remotes stay interpolated ghosts (clean split).
- **Data-driven levels**: `Levels.gd` holds level data, `Level.gd` builds platforms (neon-edged), checkpoint pylons, and a finish gate with proper collision layers (1=players, 2=solid). Adding levels later is just more data.
- **Neon-rooftops-at-night** look: deep-navy sky, parallax skyline with lit windows, glowing platform edges.
- Race timer, checkpoint respawn, finish banner, `R` to restart. Redeployed.

### AI prompts / techniques that worked
- **Built an edge-detecting autopilot (`--auto`) to validate gameplay headlessly.** Since "does it play?" normally needs a human + a window, I gave the bot a forward floor-raycast so it jumps *at* gaps — then ran it headless and watched it complete the course (3 checkpoints in order → finish in 12.3s). This is the day's best trick: **a self-driving test that proves the level is completable and the controller/collision/checkpoints/finish all fire, with no display.**
- Set up the InputMap **in code** (`InputMap.add_action`) instead of hand-authoring `InputEventKey` blobs in `project.godot` — far less error-prone when you can't use the editor.

### Challenges / fixes
- **Autopilot kept missing the first gap.** Root cause was a great bug to find headlessly: the autopilot's look-ahead `RayCast2D` used the default `collision_mask=1`, but platforms are on layer 2 — so the ray never saw floor, the bot hopped constantly and never built speed to clear a gap. Set the ray mask to 2 → it ran the course cleanly. (Reminder: ray masks are independent of body masks.)
- Avoided multi-line GDScript lambdas in `Area2D.connect(...)` — used named methods with `.bind()` for checkpoint/finish callbacks.

### Can't self-verify
- **"Feels good to play" is the one graded quality I can't measure headlessly.** Jump weight, run speed, dash, gap spacing — these need a human. Handing to playtest.

### Next
Day 4: real multiplayer race loop — lobby/ready/countdown, server-authoritative finish order, everyone racing the same level live.

---

## Day 3 (cont.) — Jun 8 · Art direction approved → full roster, clearer checkpoints, longer course

### From playtest feedback
- Jump/run/gaps: confirmed good (left untouched). Dash: "pointless" → reworked + now matters. Art direction: approved → built the roster. Checkpoints: "took a while to figure out what they were" → redesigned. Asked for longer, more varied courses → delivered a 2× level + a 2nd course.

### What happened
- **Full roster (5 runners)** via the PNG-preview loop: Vex (courier), Glitch (netrunner, hood+goggles), Echo (android, antenna+amber eyes), Kira (street samurai, topknot+mask), Pax (drone-rider, helmet+scarf). Shared body geometry + unique heads/palettes → distinct silhouettes at low cost. Live select screen shows real sprite previews.
- **Checkpoints made unmistakable**: a tall pulsing light-beam + gate posts + a floating "CHECKPOINT" label, and an activation flash to "✓ CLEARED". (Old version was a thin bar — easy to miss.)
- **Course ~2× longer + varied**: Level 1 is now 9k px, 21 platforms, 5 checkpoints, varying gaps/heights + pit-spike hazards; rooftop props (antennas, vents, neon signs) for detail; stars + a moon in the sky. Added a 2nd course ("Spire Climb") in data for the progression work.
- **Dash now has purpose**: air-dash + momentum + neon afterimage trail; great for speed/recovery (kept the main path jump-fair so it never hard-walls anyone).

### AI prompts / techniques that worked
- **The render-to-PNG-and-Read loop is the unlock for authoring art without a display.** I draw sprites as palette grids, render a sheet, and actually look at it — iterating Vex from "blobby box-replacement" to a detailed runner, then stamping 4 more from a shared body. Authoring blind would've been hopeless; this made it a tight loop.
- **The autopilot doubles as a level-design oracle.** When it looped forever at one checkpoint, that *was* the finding: a gap there required a mechanic (dash) the main path shouldn't demand. I re-spaced the course to be jump-fair and the bot completed it in 25s — proof the longer level is winnable.

### Challenges / fixes
- Teaching the autopilot to dash made it *less* stable (overfitting the test bot). Right call was to fix the *level* (jump-fair spacing), not the bot — keeps dash a bonus, not a wall.
- Hand-placing 21 platforms drifted into unjumpable gaps; recomputed with controlled spacing (gaps ≤170, rises ≤60) and re-validated with the autopilot.

### Next
Day 4: real multiplayer race loop — lobby/ready/countdown, server-authoritative finish order, everyone racing the same course live.

---

<!-- New day entries go above this line, newest at top of the day list or appended in order — keep daily. -->
