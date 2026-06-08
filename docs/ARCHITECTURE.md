# Architecture

> Status: **target** architecture (Day 1). Updated with the real deployed topology after the Day-2 spine POC.

## Topology

```
 Browser tab ──┐   Godot 4.6 HTML5 export (single-threaded)
 Browser tab ──┤        │ wss://   (TLS terminated at Railway edge)
 Browser tab ──┘        ▼
                  Railway edge proxy
                        │ plain ws:// on $PORT
                        ▼
              Headless Godot server  (Docker, --headless, dedicated_server)
              WebSocketMultiplayerPeer.create_server($PORT) bound to 0.0.0.0
              ── authoritative: lobby/ready, level load, start countdown,
                 checkpoint + lap validation, finish order, unlock grants,
                 best-time leaderboard persistence
```

**Two Railway services, one project:**
- `game-server` — Dockerfile, headless export binary + `.pck`.
- `web-client` — static Godot HTML5 export; server URL baked at build time via `wss://${{game-server.RAILWAY_PUBLIC_DOMAIN}}`.

## Networking & authority model

Godot's high-level multiplayer (RPCs, `MultiplayerSpawner`, `MultiplayerSynchronizer`) running over `WebSocketMultiplayerPeer` (see [DECISIONS.md](./DECISIONS.md) D2).

**Server authoritative for match flow:**
- lobby membership & ready state
- level selection + synced start countdown
- checkpoint order & lap/segment counting → **finish order** (anti-cheat-lite validation)
- unlock grants & leaderboard persistence

**Client-owned, server-relayed for movement:**
- server spawns one player node per peer via `MultiplayerSpawner`
- each player's `CharacterBody2D` + `MultiplayerSynchronizer` has authority = owning peer (client owns its own position)
- **remote players are interpolated** to hide TCP jitter

**Resilience:** explicit handling of connect / disconnect / late-join (player leaves mid-race → cleanly despawned; new player → spectate, joins next race).

**Latency:** on-screen RTT/ping readout + interpolation; target a sub-~100ms *feel*. App-level ping keeps the connection alive under Railway's 60s keep-alive.

## Scenes / project layout (planned)

```
project/                 # Godot project root
  project.godot
  scenes/
    main.tscn            # entry; routes to menu/lobby/game by role
    player/Player.tscn
    levels/Level1.tscn ...
    ui/Lobby.tscn, Results.tscn, Leaderboard.tscn
  scripts/
    net/                 # NetworkManager (server vs client bootstrap), transport
    game/                # match state machine, checkpoint/finish logic
    player/              # controller, interpolation
  export_presets.cfg     # Web (client) + Linux dedicated server presets
deploy/
  server.Dockerfile
  (web static host config if needed)
```
