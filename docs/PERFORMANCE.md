# Performance & Stress Test

## Networking model

- **Transport:** Godot high-level multiplayer over `WebSocketMultiplayerPeer` (TCP/WS). See [DECISIONS.md](./DECISIONS.md) D2.
- **Tick rate:** server broadcasts a full player-state snapshot at **20 Hz**; each client submits its own position at 20 Hz.
- **Latency hiding:** remote players are **interpolated** toward their last snapshot; the local player is simulated client-side with zero input latency. An on-screen **RTT/ping readout** reflects live round-trip time.
- **Bandwidth:** snapshot is O(players) per tick; total O(players²) across the room. Negligible at the target scale (≤ ~16 players) — a snapshot for 8 players is a few hundred bytes.

## Measured latency (deployed, Railway US-West)

Network round-trip to the Railway edge (from a US client):

| sample | TCP connect | TTFB |
|---|---|---|
| cold (TLS handshake) | 87 ms | 283 ms |
| warm | ~30 ms | ~210 ms |

In-game application-level latency is shown live in the HUD (`ping=NN ms`) — this is the number that matters for "feel," and remote-player interpolation absorbs the TCP jitter so movement stays smooth.

## Stress test — max concurrent players

**Method:** 8 headless `--racebot` clients launched concurrently against the **live** deployed server (`wss://rooftop-server-production.up.railway.app`), each connecting, readying up, racing the full course, and reporting its finish. (Reproduce: `for i in $(seq 1 8); do SERVER_URL=wss://… godot --headless --path project -- --racebot & done`.)

**Result:**
- ✅ **8 concurrent peers** connected and raced simultaneously.
- ✅ Full 8-player race completed with a correct **server-authoritative finish order** (all 8 recorded).
- ✅ Course **rotated** to the next level for the following race.
- ✅ **0 client errors** across all 8 bots; server stayed responsive (no dropped connections, no socket overflow).

Railway caps a service at 10,000 concurrent connections; the practical ceiling here is gameplay readability, not the transport. The design comfortably exceeds the "multiple concurrent players" requirement.

## Profiling notes

- No hot path identified at target scale: physics is one `CharacterBody2D` per client (local only); remotes are interpolated `Node2D`s; the server does dictionary bookkeeping + a 20 Hz broadcast.
- Headless server CPU is dominated by the 20 Hz broadcast loop — linear in players, flat per tick.
- If scaling to hundreds of players were ever needed: shard into rooms, drop snapshot rate for distant players, and delta-encode snapshots. Not necessary for this game.
