# User Personas — Findings & Remediation

App under test: **Rooftop Rush** (native Godot 4 desktop game). Date: 2026-06-12. Iteration: pass 1.

Run as a **native acceptance pass** (the persona-testing skill is browser-only; this is a desktop
real-time game, so the main thread drove the native build + headless autopilot + live in-engine
screenshots instead of browser sub-agents). Evidence: headless autopilot completes all 10 stages
(`--auto --level=0..9` → `[FINISH]`); live captures of stages via a `--shot` hook
(`build/shots/`); code/flow audit of menus, input map, and HUD.

Several findings are cross-cutting; each is recorded under its primary persona and referenced by
others it affects.

---

## Persona 1 — Dax "Frame-Perfect" (smart-user)
Goal: clean dash-chained run of Neon Rooftops. **Outcome: achieved.**

### Finding 1.1 — Backdrop pop-in at stage start [minor]
- **Pass:** 1 · **Where:** any stage load, first ~2–3s.
- **Expected vs actual:** backdrop present at spawn; actual: flat placeholder sky for a couple
  seconds while the parallax layers build on a worker thread. Under heavy CPU contention (e.g. two
  game instances) this degrades badly — near-blank backdrop + the game running at <25% speed for
  several seconds (observed during automated multi-instance capture).
- **Repro:** start any stage; watch the sky before buildings appear.
- **Remediation:** Declined a deep fix. The placeholder now shows the correct per-theme sky colour
  (committed earlier), pop-in is ~2–3s on the target machine, and the severe stall only reproduced
  under artificial multi-instance CPU contention during testing, not in normal solo play. Noted for
  a future optimisation (mount the cheap sky-bodies layer first, or precompute/bake layers).
- **Status:** open (accepted as minor).

## Persona 2 — Priya (smart-user)
Goal: play all 10 stages back-to-back via finish→next. **Outcome: achieved (after fix).**

### Finding 2.1 — Free-run parked on "FINISH!" with no way to advance [major]
- **Pass:** 1 (user-reported in live play) · **Where:** finish state, free-run.
- **Expected vs actual:** after finishing a stage you should be able to continue to the next.
  Actual: free-run had no progression — it sat on "FINISH! <time>" forever (stage rotation was
  server-only).
- **Repro:** finish any free-run stage; nothing advances.
- **Remediation:** added an Enter/Space → next-stage handler (cycles all 10, swaps backdrop + music)
  with R = retry (`Main.gd`, commit `48f2d79`); the banner now reads
  "FINISH! <time> / ENTER: next stage · R: retry". Lightly tuned the banner area/font (−170, 40px)
  for balance. **Verified** via a finish-state capture (`build/shots/finish.png`): both lines render
  fully and centered. (My initial hypothesis that the banner was clipped was wrong — its anchoring
  makes it a centered near-fullscreen rect, not a bottom strip; corrected here.)
- **Status:** fixed (verified).

## Persona 3 — Marcus (smart-user)
Goal: start a multiplayer race and reach results. **Outcome: blocked.**

### Finding 3.1 — No way to host/join multiplayer from the game [major / by-design]
- **Pass:** 1 · **Where:** boot → character select.
- **Expected vs actual:** expected an in-game host/join. Actual: a race requires a **separately
  launched** server (`godot ... -- --server`, port 8915); the client silently falls back to
  free-run ("connection failed — continuing offline"). No UI affordance to start multiplayer.
- **Repro:** launch the game normally; look for any multiplayer/host option — there is none.
- **Remediation:** Declined for this pass — separate-server is the project's intended architecture
  (documented in `docs/SETUP.md`). Lobby/countdown/standings DO work when a server is running
  (verified earlier via `--racebot`). A future nicety: a one-line "multiplayer: run a server" hint
  or an in-game host button.
- **Status:** declined (by design); documented.

## Persona 4 — Lin Mei (smart-user)
Goal: navigate character select → stage select; expects clean centered menus. **Outcome: achieved.**

### Finding 4.1 — Stage-select menu mis-anchored to lower-right [major]
- **Pass:** 1 (pre-existing, found in live play before this pass) · **Where:** stage-select overlay.
- **Expected vs actual:** centered modal. Actual: the menu box was manually positioned and landed
  off the lower-right with no dim.
- **Remediation:** already fixed (`StageSelect.gd` → full-screen dim + `CenterContainer`), commit
  `7bb0c64`. Character select already uses the same centered pattern.
- **Status:** fixed (confirmed).

## Persona 5 — Tomás (smart-user, deuteranopia)
Goal: read platform edges on neon + lunar without confusing hues. **Outcome: achieved.**

### Finding 5.1 — Platform readability relies partly on hue [minor]
- **Pass:** 1 · **Where:** neon/lunar stages.
- **Expected vs actual:** platforms readable by brightness/shape. Actual: platforms ARE readable —
  each has a bright 3px top edge over a dark fill (high luminance contrast), which survives color-
  vision deficiency; but adjacent neon edge colours (e.g. green vs magenta) are distinguished by
  hue, which a CVD player can't use.
- **Remediation:** Declined for now — luminance contrast keeps platforms clearly visible (the
  gameplay-critical signal). A future option: a high-contrast/CVD edge palette toggle.
- **Status:** declined (acceptable); noted.

## Persona 6 — Sasha (smart-user, gamepad)
Goal: play with a controller. **Outcome: blocked → fixed.**

### Finding 6.1 — No gamepad support [major]
- **Pass:** 1 · **Where:** input map.
- **Expected vs actual:** controller works. Actual: input actions were keyboard-only; a gamepad did
  nothing.
- **Remediation:** `project/scripts/Net.gd::_setup_input` — added joypad bindings: left stick X /
  d-pad = move, A = jump, X = dash (via `InputEventJoypadMotion`/`InputEventJoypadButton`). Movement
  goes through `Input.get_axis`, so analog stick works.
- **Status:** fixed.

## Persona 7 — Dr. Helen Cho (smart-user)
Goal: hear each stage's distinct, seamlessly-looping music. **Outcome: achieved.**
- No issues. All 10 stages have their own original track; the loop-seam gap was fixed earlier
  (echo tail folded into the start, commit `48f2d79`). Music swaps per theme on stage change.

## Persona 8 — Bilal (smart-user, adversarial QA)
Goal: find a softlock/crash via input/menu/respawn abuse. **Outcome: no blocker found.**

### Finding 8.1 — Minor jank: R restarts behind an open stage-select [nitpick]
- **Pass:** 1 · **Where:** free-run, stage-select open.
- **Expected vs actual:** with the menu open, R still resets the level behind it (menu stays up).
  Not a softlock — choosing a stage or Esc resumes correctly with input re-enabled.
- **Remediation:** Declined (harmless). Could ignore gameplay keys while the menu is open.
- **Status:** declined.
- Otherwise: all 10 stages complete under autopilot (no softlocks); respawn-on-fall and spike-
  respawn behave; menus open/close cleanly.

## Persona 9 — Grace (smart-user, streamer)
Goal: quickly showcase several visually distinct stages. **Outcome: achieved (after fix).**

### Finding 9.1 — Stage-switching key (Tab) not discoverable in-run [major → fixed]
- **Pass:** 1 · **Where:** in-run.
- **Expected vs actual:** a way to jump between stages. Tab opens stage select, but nothing on
  screen said so (and a streamer skipping the menu wouldn't know).
- **Remediation:** added a persistent faint in-run hint ("Tab: stages · R: restart",
  `Main.gd`) and added Tab/R/Enter to the character-select controls line.
- **Status:** fixed. (Visual variety itself is strong — city/brick/library/tower captures confirm
  distinct, themed backdrops + per-theme platform palettes.)

## Persona 10 — Kenji (smart-user)
Goal: judge movement feel. **Outcome: achieved.**
- No issues. Coyote-time, jump-buffer, variable-height jump, and momentum-preserving air-dash are
  implemented (`LocalPlayer.gd`); autopilot clears every generated course, confirming gaps/steps sit
  inside the jump envelope (gaps ≤200px, up-steps ≤100px by construction).

## Persona 11 — Auntie Rosa (dumb-user, non-gamer)
Goal: just start playing and move at all. **Outcome: achieved.**
- Character select shows the title, "SELECT YOUR RUNNER", clickable cards, and a controls line — a
  non-gamer can click a runner and read move/jump keys. See **9.1** (now the in-run hint persists
  too). No separate finding.

## Persona 12 — Liam, age 8 (dumb-user)
Goal: pick a cool character and jump. **Outcome: achieved.**
- No issues. Cards are clickable; jumping is immediate. Button-mashing surfaced no crash (see 8.1).

## Persona 13 — Brenda (dumb-user, impatient)
Goal: into a stage in as few clicks as possible. **Outcome: achieved.**
- Affected by **2.1** (couldn't see the next-stage prompt) — now fixed. Otherwise: one click on a
  character → stage select → one click/number → playing. Fast enough.

## Persona 14 — Chad (dumb-user, expects touch/click)
Goal: move by clicking. **Outcome: blocked (by design).**

### Finding 14.1 — Clicking the player does nothing, with no feedback [minor]
- **Pass:** 1 · **Where:** in-run.
- **Expected vs actual:** expected click/tap control. Actual: it's keyboard/gamepad only; clicking
  does nothing and gives no nudge toward the real controls.
- **Remediation:** Declined building mouse/touch control. Mitigated by the on-screen controls hint
  (character select + persistent in-run hint) which a confused clicker will eventually read.
- **Status:** declined; mitigated by 9.1.

## Persona 15 — Gita (dumb-user, keyboard-shy)
Goal: complete a stage with arrows + Space only. **Outcome: achieved.**
- No issues. Arrows move, Space jumps; dash (Shift) is optional, not required to finish (autopilot
  finishes without dashing). In-run hint helps. Benefits from **9.1**.

## Persona 16 — "xX_Destroyer_Xx" (dumb-user, chaos)
Goal: break respawn / stage-select / next-stage. **Outcome: no break found.**
- Covered by **8.1**. Mashing R/Tab/Enter and diving into pits did not produce a softlock or crash;
  respawn returns to the last checkpoint; next-stage only fires when finished.

## Persona 17 — Walter (dumb-user, slow senior)
Goal: understand what to do and which keys, unaided. **Outcome: achieved (after fix).**
- Helped by **2.1** (readable finish prompt) and **9.1** (persistent in-run hint + fuller controls
  line on character select). No separate finding.

## Persona 18 — Mona (dumb-user, distracted/alt-tabs)
Goal: leave and return mid-run, still make sense. **Outcome: achieved.**

### Finding 18.1 — No pause; game keeps running when unfocused [nitpick]
- **Pass:** 1 · **Where:** alt-tab during a run.
- **Expected vs actual:** in free-run there's no timer pressure and the player simply stands still
  (no input), so returning is fine; but there's no explicit pause.
- **Remediation:** Declined (free-run has no penalty; adding pause is a future nicety, more relevant
  to multiplayer).
- **Status:** declined.

## Persona 19 — Tariq (dumb-user, wants a tutorial)
Goal: find controls/help before playing. **Outcome: achieved.**
- The character-select screen now lists move/jump/dash/gamepad and Tab/R/Enter (Finding **9.1**),
  acting as a lightweight how-to-play. No dedicated tutorial, but controls are surfaced up front.

## Persona 20 — Bex (dumb-user, rage-quitter)
Goal: finish without a death feeling unfair. **Outcome: achieved.**
- No issues. Courses are generated with gaps ≤200px and up-steps ≤100px — inside the jump envelope
  — and the headless autopilot clears all 10, so there are no unclearable gaps; spikes sit in pits
  you'd fall into anyway (visible danger, not hidden). Deaths are fair.

---

## Pass 1 summary

**Fixed:** finish-banner clip (2.1), gamepad support (6.1), in-run controls discoverability +
fuller controls line (9.1), and (earlier this session) the stage-select layout (4.1) and music
loop seam (7). **Declined/noted with rationale:** backdrop pop-in (1.1), in-UI multiplayer (3.1),
CVD edge palette (5.1), R-behind-menu jank (8.1), click-to-move (14.1), pause-on-alt-tab (18.1).
**No blockers remain.** All 10 stages complete; menus are centered/legible; controls are surfaced;
music + per-theme visuals verified.
