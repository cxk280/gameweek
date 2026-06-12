# Rooftop Rush — User Personas

20 personas for acceptance testing of **Rooftop Rush**, a real-time 2D platformer race:
character select → stage select → run/jump/dash left→right across one of 10 themed stages to
the finish (free-run single-player; server-driven lobby/countdown/race/standings in multiplayer),
each stage with its own backdrop, platform palette, and original 16-bit-style music.

Controls: move A/D or ←/→, jump Space/W/↑ (variable height, coyote-time, jump-buffer),
dash Shift, restart R, after finishing ENTER/SPACE = next stage, Tab = stage select.

Roster balance: ~10 intelligent/experienced (→ `smart-user`) and ~10 naive/careless
(→ `dumb-user`). Device/connection/patience/accessibility varied. Each persona has ONE goal.
(Acceptance is run as a **native** pass — this is a desktop Godot game, not a web app — so the
agent-type column reflects the persona's mindset, not a browser driver.)

---

## Intelligent / experienced (smart-user)

### P1 — Dax "Frame-Perfect" Okonkwo — speedrunner
- **Device/conn:** desktop, wired, 144 Hz. **Patience:** high for retries, zero for jank.
- **Mindset:** optimizes movement; expects dash to conserve momentum and inputs to be precise.
- **Goal:** beat **Neon Rooftops** with a clean dash-chained run and a time he's happy with.

### P2 — Priya Venkataraman — completionist
- **Device/conn:** laptop, wifi. **Patience:** high.
- **Mindset:** wants to see everything the game offers, in order.
- **Goal:** play **all 10 stages back-to-back** via the finish→next-stage flow without quitting.

### P3 — Marcus Hale — competitive multiplayer host
- **Device/conn:** desktop, wired. **Patience:** medium.
- **Mindset:** expects to host/join a race with others; cares about lobby/ready/countdown/standings.
- **Goal:** start a **multiplayer race** and reach the results screen.

### P4 — Lin Mei — UI/UX-literate designer
- **Device/conn:** MacBook, retina. **Patience:** medium; notices misalignment instantly.
- **Mindset:** judges menus, layout, contrast, affordances.
- **Goal:** navigate **character select → stage select**, expecting clear, centered, legible menus.

### P5 — Tomás Reyes — accessibility (color-vision deficient)
- **Device/conn:** desktop. **Patience:** medium. **A11y:** deuteranopia.
- **Mindset:** relies on brightness/shape, not hue, to read platforms vs. background.
- **Goal:** clear the **neon** and **lunar** stages reading platform edges without confusing them.

### P6 — Sasha Ivanova — gamepad gamer
- **Device/conn:** desktop + Xbox controller plugged in. **Patience:** low for kbd-only.
- **Mindset:** expects a platformer to support a controller.
- **Goal:** play a stage **with the gamepad** (or learn quickly that it's keyboard-only).

### P7 — Dr. Helen Cho — audio-focused musician
- **Device/conn:** desktop, good headphones. **Patience:** high.
- **Mindset:** listens for loop seams, mix balance, per-stage variety.
- **Goal:** hear **each stage's music**, confirming distinct tracks that loop seamlessly.

### P8 — Bilal Haddad — QA engineer (adversarial)
- **Device/conn:** desktop. **Patience:** high; tries to break things.
- **Mindset:** spams keys, mashes restart, opens menus mid-air, falls in pits repeatedly.
- **Goal:** **stress** the input/menu/respawn paths and find a softlock or crash.

### P9 — Grace Wójcik — streamer / content creator
- **Device/conn:** desktop, capture software. **Patience:** medium.
- **Mindset:** wants visual variety and "moments" for an audience.
- **Goal:** quickly **showcase 4–5 visually distinct stages** (e.g., spire, library, bay) via stage select.

### P10 — Kenji Tanaka — returning platformer veteran
- **Device/conn:** laptop. **Patience:** medium.
- **Mindset:** expects coyote-time, jump-buffer, variable jump to "feel right."
- **Goal:** judge whether the **movement feel** is tight across a couple of stages.

---

## Naive / careless / first-time (dumb-user)

### P11 — Auntie Rosa — total non-gamer
- **Device/conn:** old laptop, trackpad. **Patience:** very low.
- **Mindset:** doesn't know WASD; looks for "Play". Reads nothing.
- **Goal:** somehow **start playing** and move the character at all.

### P12 — Liam (age 8) — button masher
- **Device/conn:** family desktop. **Patience:** near-zero.
- **Mindset:** mashes every key, picks the "coolest" character, doesn't read.
- **Goal:** **pick a character and jump around** — fun in 10 seconds or he's gone.

### P13 — Brenda Pock — impatient skimmer
- **Device/conn:** work laptop. **Patience:** very low.
- **Mindset:** hates menus; presses Enter/Space to skip everything.
- **Goal:** get **into a stage in as few clicks as possible**.

### P14 — Chad Mobley — wrong-platform expectation
- **Device/conn:** thinks it's a phone game; tries to tap/click the player.
- **Patience:** low.
- **Mindset:** clicks the screen expecting touch controls.
- **Goal:** move the character by **clicking** — and discover how it actually works.

### P15 — Gita Patel — keyboard-shy
- **Device/conn:** laptop. **Patience:** low. **A11y:** small hands, avoids reaching keys.
- **Mindset:** uses only arrow keys; never finds Shift/Tab.
- **Goal:** complete a stage using **arrows + Space only**.

### P16 — "xX_Destroyer_Xx" — chaos tester
- **Device/conn:** desktop. **Patience:** low; wants to grief.
- **Mindset:** holds keys, jumps into pits on purpose, mashes R and Tab repeatedly.
- **Goal:** **break the respawn / stage-select / next-stage** flow.

### P17 — Walter Brueggemann — slow, deliberate senior
- **Device/conn:** desktop, large monitor, reduced reflexes. **Patience:** high but easily lost.
- **Mindset:** needs on-screen guidance; doesn't memorize keys.
- **Goal:** understand **what to do and which keys** without outside help.

### P18 — Mona Davies — lapsed casual, distracted
- **Device/conn:** laptop, music playing elsewhere. **Patience:** low.
- **Mindset:** alt-tabs, comes back, expects the game to still be sensible.
- **Goal:** **leave and return** mid-run and still know what's happening.

### P19 — Tariq Nasser — expects a tutorial
- **Device/conn:** desktop. **Patience:** medium.
- **Mindset:** first thing he looks for is "how to play".
- **Goal:** find **any controls/help** before playing; if none, infer them.

### P20 — Bex Carter — rage-quitter at unfairness
- **Device/conn:** laptop. **Patience:** low; blames the game.
- **Mindset:** if a jump feels impossible or a death feels cheap, rage-quits.
- **Goal:** reach a finish **without feeling a death was unfair** (unclearable gap, hidden spike).
