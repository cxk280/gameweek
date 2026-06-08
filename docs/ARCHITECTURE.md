# Architecture

> Status: **deployed & verified (Day 2).** The spine below is live on Railway and was
> confirmed end-to-end over the public internet (two clients synced through `wss://`).
>
> **Live:** client https://rooftop-web-production.up.railway.app · server `wss://rooftop-server-production.up.railway.app`
> Railway injects `PORT` (observed `8080`); the server binds `0.0.0.0:$PORT` and Railway
> terminates TLS at the edge, so the server speaks plain `ws://` while browsers use `wss://`.

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

**Server authoritative for match flow** (state machine in `Net.gd`, lives only on the server):
`lobby → countdown → racing → results → lobby`.
- lobby membership & ready state (`set_ready` RPC); countdown begins when all ready
- synced countdown broadcast (`srv_phase` RPC) → simultaneous GO
- **finish order**: clients report finish time (`submit_finish`); the server orders by receipt and is the single source of truth (ignores duplicates, holds a post-first-finisher grace window, DNFs the rest)
- results broadcast, then auto-return to lobby
- late-join → spectate current race, joins next lobby; disconnect mid-race handled
- (planned) checkpoint validation + unlock grants & leaderboard persistence

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
