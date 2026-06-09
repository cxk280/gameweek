# Demo Video Scripts — Rooftop Rush

Ready-to-record scripts for the three Game Week video deliverables. **You record these**
(Claude can't). Each lists setup, on-screen actions, and narration beats with timings.

**Live:** https://rooftop-web-production.up.railway.app
**Recording tip:** Chrome + a screen recorder (QuickTime/OBS/Loom). Have the repo open in your
editor in a second window for the docs walkthrough portions.

---

## 1. MVP video — **DUE TUE 11:59 PM CT** ⏰ (~2–3 min)
**Required content:** docs/architecture overview + single-player core loop.

### Setup
- Tab 1: the live URL. Tab 2 / editor: the repo (`README.md`, `docs/ARCHITECTURE.md`, `docs/DECISIONS.md`, `docs/CURRICULUM.md`).

### Beats
**(0:00–0:20) Intro.** "This is Rooftop Rush — a real-time multiplayer 2D platformer race I built this week in **Godot 4.6 + GDScript**, a stack I'd never touched. The game's the vehicle; the point was ramping fast with AI."

**(0:20–1:00) Docs & architecture.** Screen-share the editor:
- `README.md` — what it is, tech-stack table, how to play.
- `docs/DECISIONS.md` — call out **D2**: "Godot's default multiplayer is ENet/UDP, which browsers can't use and Railway won't route — so the whole thing rides on `WebSocketMultiplayerPeer` instead. Verified against the Godot docs before committing." Mention **D1** (why Godot) and **D4** (single-threaded web export = no header pain).
- `docs/ARCHITECTURE.md` — show the topology diagram: browser HTML5 client ⇄ wss ⇄ headless Godot dedicated server on Railway.
- `docs/CURRICULUM.md` — "the AI-generated learning path I used to go zero-to-shipping."

**(1:00–2:30) Single-player loop.** On the live URL:
- Title → pick a runner (show the roster).
- In the lobby, **ready up solo** → 3-2-1-GO countdown.
- Run the course: show **run, variable jump, dash** (with trail), crossing **checkpoints** (call out the light-beam gates), the **race timer**, falling/respawn, and crossing the **FINISH**.
- Land on the results screen with your time.
- "That's the core loop — and it's already deployed and publicly accessible."

**(2:30) Close.** "Multiplayer, progression, and a leaderboard are already in too — but for the MVP gate, that's the single-player core running live."

---

## 2. Early video — **DUE THU 11:59 PM CT** (~2–3 min)
**Required content:** real-time multiplayer (2+ players) + progression.

### Setup
- **Two browser windows side by side** (or two devices), both on the live URL. (Two windows = two players; open as separate windows so you can see both.)

### Beats
**(0:00–0:20)** "Same game — now the multiplayer race. Two clients, one authoritative headless Godot server on Railway, talking over WebSocket."

**(0:20–1:10) The race.** Both windows: pick different runners → both **READY UP** (point out the lobby shows both players + ready state) → synced **countdown** fires in both → race. Show both squares/runners moving live in each window, the **live ping/standings**, and crossing the finish → **results with finish order + medals**.

**(1:10–2:00) Progression.** After results, show the lobby flip to the **next course** (Neon Rooftops → Spire Climb — "courses rotate"). Show the **BEST TIMES leaderboard** filling in, and the **★ win badge** by your name. Mention the leaderboard is **persisted server-side** (survives redeploys).

**(2:00–2:40) Networking + perf.** Briefly: "connect/disconnect is handled — a player leaving mid-race is cleaned up, late joiners spectate and join the next race." Mention the **measured latency** from the stress test (see `docs/PERFORMANCE.md`) — low-latency with multiple concurrent players.

---

## 3. Final video — **DUE SUN 11:59 AM CT** (~5 min)
**Required content:** gameplay + technical walkthrough + reflection on AI-augmented dev.

### Beats
**(0:00–0:30) Hook — gameplay.** Cold-open on a 2-player race, juice on (dash trails, particles, screen shake, SFX). "Rooftop Rush — real-time multiplayer rooftop racing."

**(0:30–1:30) Gameplay tour.** Roster select; a full race with both players; checkpoints/finish; results + medals; course rotation; leaderboard + win unlocks (gold trail at 3 wins). Show it's all on a **public URL**.

**(1:30–3:30) Technical walkthrough.**
- The **WebSocket-not-ENet** decision (D2) and why it's the linchpin (browsers + Railway = no UDP).
- Architecture: headless Godot **dedicated-server export** in Docker on Railway + single-threaded HTML5 client; **server-authoritative race state machine** (lobby→countdown→racing→results); 20 Hz snapshot relay + client interpolation.
- Progression persistence on a **Railway volume**.
- The **autopilot/racebot harness** — how I validated physics, level completability, and the entire multiplayer race loop **headlessly** (no display), and even live over wss.
- Original **pixel art via palette grids** + a render-to-PNG loop to author art without seeing the game.

**(3:30–4:45) Reflection on AI-augmented development.**
- Zero Godot/GDScript experience → shipped a deployed multiplayer game in a week.
- What AI accelerated: the curriculum, the cited architecture call (ENet→WebSocket) that avoided a dead end, debugging unfamiliar GDScript, and building test harnesses.
- Pull 2–3 concrete moments from `BRAINLIFT.md` (e.g., catching the ready-storm bug, the stale-binary deploy catch, the autopilot-as-level-oracle).

**(4:45–5:00) Close.** "Shipped, deployed, and play it yourself at the link."

> Keep it ≤ 5:00. Practice once; the technical section tends to run long.
