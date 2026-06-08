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

<!-- New day entries go above this line, newest at top of the day list or appended in order — keep daily. -->
