# Rooftop Rush — Project Instructions

## Stage backdrop art direction
Each stage has its own art-directed backdrop theme (see `VIEWS.md` → Race view). When building
or revising a stage's backdrop, follow these rules:

- **Span the full length of the level.** The backdrop must extend horizontally across the
  entire playable length of the stage, not just one screen. Author/preview it at the level's
  full width, not at the 1280px viewport width.
- **Vary along the length — no repetition.** The skyline (or equivalent scenery) must change
  as the stage progresses: vary building heights, spacing, density, palette, and silhouette so
  no stretch looks like a tiled copy of another. Use a low-frequency height/density envelope
  plus deterministic per-position variation, and place distinct, non-repeating landmarks at
  intervals along the length.
- **Depth, not just width.** Compose the scenery as overlapping front-to-back layers so it
  reads as a real city/place with depth — nearer elements larger, lower, brighter, and
  occluding farther ones; farther elements smaller, higher, hazier, and dimmer (atmospheric
  perspective). Avoid a single flat row of side-by-side shapes.
- **Keep our own art style.** Each stage may draw on a real-world or reference mood, but render
  it in the game's own stylization and palette — never copy a reference directly.
- **Preview and verify pixel-by-pixel.** Render the backdrop offline (see
  `project/tools/render_backdrop.gd`) at full level width and inspect it before wiring it into
  the game. Check contrast (lit elements readable against the sky/fills), no clashing or
  overlapping UI, and balanced composition.

## Workflow
- `VIEWS.md` describes every view; mocks are approved before UI/visual coding (see global rules).
- Offline art previews render into the gitignored `build/` directory.
