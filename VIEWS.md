# VIEWS — Rooftop Rush

Verbal description of every view in the application. Mocks are derived from this file and
must be approved before any UI/visual coding begins.

## 1. Title / Boot
First screen on launch. Game title, a "press to start" / connect prompt, and version/build
info. Sits over a static slice of the night-city skyline (see Race backdrop).

## 2. Character Select
Roster lineup of playable characters (idle/run/jump sprite previews), name + color entry,
and a confirm action. Background is a calm, dimmed skyline so the roster reads clearly.

## 3. Lobby (multiplayer)
Pre-race waiting room: connected players list, ready toggles, and the rotated course name.
Overlaid on the current stage's backdrop.

## 4. Race (gameplay) — primary view
The platformer race itself. Composed of, back-to-front:

- **Backdrop (art-directed, PER STAGE).** A parallax night-city skyline. This is the
  application's signature visual surface and where the distinctive art style is developed.
  Each stage defines its own backdrop *theme* (sky gradient, moon, star field, building-layer
  palettes, lit-window palette, and optional signature focal elements such as a hovering
  craft or a lattice broadcast spire). Backdrops scroll at sub-1.0 parallax behind the play
  field. The art style is a fusion: the layered density and warm-moon mood of a classic
  night-city stage, rendered in our own neon-synthwave palette (cyan / magenta / violet /
  green accents over deep navy fills).
    - **Stage 1 — "Neon Rooftops" (Midnight Metropolis theme):** the reference look for the
      art style. Deep navy sky; large warm cream-gold full moon with soft layered glow;
      dense, height-varied skyscraper silhouettes in two parallax layers; grids of lit
      windows mixing warm amber, cool teal, and occasional neon magenta; antennas with
      blinking red aviation tips on the tallest towers; one teal-lit accent slab and one
      amber-crowned tower; signature focal elements — a hovering craft with an underside
      glow, and a tapering lattice broadcast spire with red beacons.
    - **Stages 2–10:** each will get its own theme as its art direction is defined. Same
      themeable backdrop system; distinct palette, sky, moon/sun, and focal elements per
      stage so stages are visually unmistakable.
- **Play field.** Neon-edged rooftop platforms (dark fills, bright top edges), rooftop props
  (antennas, AC vents, neon signs), pit hazards (spikes), checkpoint light-gates, and a
  checkered finish gate. Defined per stage by level geometry data.
- **Actors.** The local player (full physics) and remote ghosts (interpolated).
- **HUD.** Race timer, player/ping info, banner (countdown / finish), and race standings.

## 5. Results
Post-race standings and times, win tally, and a path back to lobby/next course. Overlaid on
the finishing stage's backdrop.
