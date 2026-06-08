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
- Installed Godot 4.6.3.

### AI prompts that worked
- _"Verify from primary sources (docs.godotengine.org): can Godot's high-level multiplayer run over WebSocketMultiplayerPeer instead of ENet, for a browser client? What's the exact pattern, and what changed recently re: web-export threading headers?"_ — turned a vague worry into a concrete, cited architecture. **Lesson: make the AI cite primary docs and flag what changed recently — game-dev answers online are full of stale pre-4.3 advice.**

### Challenges / pivots
- _(running log — fill in as the day progresses)_

### Tomorrow
- Build the deployed two-browser-tab spine (the make-or-break POC). Don't touch real game code until it passes.

---

<!-- New day entries go above this line, newest at top of the day list or appended in order — keep daily. -->
