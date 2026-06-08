extends Node2D
## Day-1 networking POC + Day-2 spine seed.
##
## Proves Godot's high-level multiplayer (RPCs) runs over WebSocketMultiplayerPeer,
## which is the transport the whole project depends on (browsers + Railway can't do
## ENet/UDP). Role is chosen from `--server` user arg or the dedicated_server feature.
##
## Headless validation:
##   server: godot --headless --path project -- --server
##   client: godot --headless --path project -- --client   (expects "ROUNDTRIP OK")

const DEFAULT_PORT := 8915

var _is_server := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--server") or OS.has_feature("dedicated_server"):
		_is_server = true
		_start_server()
	else:
		_start_client()


func _port() -> int:
	var p := OS.get_environment("PORT")
	return int(p) if p != "" else DEFAULT_PORT


func _start_server() -> void:
	var peer := WebSocketMultiplayerPeer.new()
	var err := peer.create_server(_port(), "*")
	if err != OK:
		printerr("[server] create_server failed: %d" % err)
		get_tree().quit(1)
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	print("[server] WebSocket server listening on port %d" % _port())


func _start_client() -> void:
	var url := OS.get_environment("SERVER_URL")
	if url == "":
		url = "ws://127.0.0.1:%d" % _port()
	var peer := WebSocketMultiplayerPeer.new()
	var err := peer.create_client(url)
	if err != OK:
		printerr("[client] create_client failed: %d" % err)
		get_tree().quit(1)
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	print("[client] connecting to %s ..." % url)
	# Safety net so a headless run can never hang a CI/build.
	get_tree().create_timer(8.0).timeout.connect(_on_timeout)


# --- Server peer lifecycle ---

func _on_peer_connected(id: int) -> void:
	print("[server] peer connected: %d" % id)


func _on_peer_disconnected(id: int) -> void:
	print("[server] peer disconnected: %d" % id)


# --- Client connection lifecycle ---

func _on_connected() -> void:
	print("[client] connected (my id=%d) — sending ping" % multiplayer.get_unique_id())
	ping.rpc_id(1, "hello-from-%d" % multiplayer.get_unique_id())


func _on_connection_failed() -> void:
	printerr("[client] connection FAILED")
	get_tree().quit(1)


func _on_server_disconnected() -> void:
	printerr("[client] server disconnected")
	get_tree().quit(1)


func _on_timeout() -> void:
	printerr("[client] TIMEOUT — no RPC roundtrip within 8s")
	get_tree().quit(1)


# --- The RPC roundtrip under test ---

@rpc("any_peer", "reliable")
func ping(msg: String) -> void:
	# Runs on the server (callable by any client peer).
	var sender := multiplayer.get_remote_sender_id()
	print("[server] ping from %d: %s" % [sender, msg])
	pong.rpc_id(sender, "pong:%s" % msg)


@rpc("authority", "reliable")
func pong(msg: String) -> void:
	# Runs on the client (server is the authority).
	print("[client] got '%s' — ROUNDTRIP OK" % msg)
	get_tree().quit(0)
