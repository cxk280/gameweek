# AI-Generated Learning Curriculum — Godot 4.6 for a multiplayer platformer-race

The focused path used to go from zero Godot experience to shipping. Scoped to *only* what Rooftop Rush needs — not a general Godot course. Each item links the primary doc and states the one thing to extract.

## Phase A — Godot fundamentals (just enough)
1. **Editor + scene/node model** — nodes, scenes, instancing, the scene tree, `_ready`/`_process`/`_physics_process`. → https://docs.godotengine.org/en/stable/getting_started/
2. **GDScript essentials** — typed vars, signals, `@export`, `@onready`, `@rpc` annotation. → https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/
3. **2D movement** — `CharacterBody2D`, `move_and_slide()`, input handling, gravity/jump. → https://docs.godotengine.org/en/stable/tutorials/physics/using_character_body_2d.html

## Phase B — Multiplayer (the core)
4. **High-Level Multiplayer** — `multiplayer` API, peer IDs, `@rpc` calls, server vs client. → https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html
5. **WebSocket transport** — `WebSocketMultiplayerPeer.create_server/create_client`, assigning it as `multiplayer.multiplayer_peer`. → https://docs.godotengine.org/en/stable/tutorials/networking/websocket.html · class ref: https://docs.godotengine.org/en/stable/classes/class_websocketmultiplayerpeer.html
6. **Scene replication** — `MultiplayerSpawner` (spawn players per peer), `MultiplayerSynchronizer` (sync transforms, set authority per peer), interpolation for remote players. → networking section "Scene replication".

## Phase C — Ship it
7. **Exporting for the Web** — single-threaded HTML5 export (no COOP/COEP). → https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html
8. **Exporting for dedicated servers** — `--headless`, "Export as dedicated server", `OS.has_feature("dedicated_server")`. → https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_dedicated_servers.html

## Validation POCs (prove understanding, not just read)
- **POC-1:** a `CharacterBody2D` that runs + jumps and feels OK.
- **POC-2:** two local Godot instances over `WebSocketMultiplayerPeer`; an `@rpc` moves a square on both.
- **POC-3 (Day 2 gate):** the same, but the server is a headless export in Docker on Railway and the clients are two browser tabs.

> Methodology note: read the primary doc for the *one concept*, then immediately build the smallest POC that exercises it. Don't batch-read — interleave reading and building so misunderstandings surface in minutes, not hours.
