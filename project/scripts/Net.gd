extends Node
## Autoload "Net" — the networking spine.
##
## Authoritative-relay multiplayer over WebSocketMultiplayerPeer (browsers + Railway
## can't do ENet/UDP — see docs/DECISIONS.md D2). At ~20 Hz the server broadcasts a
## snapshot of every player's state; each client submits its own position. Lives at the
## stable path /root/Net so @rpc routing matches across server and clients.
##
## Roles:  server = `--server` user arg OR the dedicated_server export feature.
##         client = default (browser).

signal players_updated(states: Dictionary)  # peer_id -> {pos:Vector2, name:String, color:Color}
signal race_event(phase: String, payload: Dictionary)  # client-side race phase changes

const DEFAULT_PORT := 8915
const TICK := 1.0 / 20.0
const COUNTDOWN := 3
const FINISH_GRACE := 20.0   # seconds the race continues after the first finisher
const RESULTS_TIME := 9.0     # results screen duration before returning to lobby

# --- Race state (server-authoritative) ---
var phase := "lobby"          # lobby · countdown · racing · results
var readies := {}               # id -> bool
var finishers := []           # ordered [{id,name,char,ms}]
var _names := {}              # id -> String
var _chars := {}              # id -> String
var _cd := 0.0
var _cd_last := -1
var _grace := -1.0
var _results_t := 0.0

# --- Progression (server-authoritative, persisted) ---
var current_level := 0
var board := {}               # str(level_index) -> [{name, ms}] sorted ascending (top 10)
var wins := {}                # name -> int
## Filled after the server is deployed. The browser can't read server env at runtime,
## so the web client's server URL is baked here (overridable at runtime via ?server=wss://…).
const WEB_SERVER_URL := "wss://rooftop-server-production.up.railway.app"

var is_server := false
var is_connected := false
var my_id := 0
var rtt_ms := 0

# Client link state for the UI + reliable reconnect. "connecting" while (re)dialing,
# "online" once connected, "offline" after we give up (falls back to solo). Emitted only
# on a real transition so callers can `await` it to learn the outcome.
signal link_state_changed(state: String)
var link_state := "connecting"
var peer_count := 0           # live count of registered players (from the latest snapshot)
const MAX_RETRIES := 5
const RETRY_DELAY := 1.5
var _retries := 0


## True once we're connected AND another player is present (for "race a friend" affordances).
func others_online() -> int:
	return maxi(0, peer_count - 1) if is_connected else 0

# Server-authoritative store (server only): peer_id -> state dict.
var states := {}

# Local player identity/state (client only).
var local_pos := Vector2(640, 360)
var local_name := "player"
var local_color := Color.WHITE
var local_char := "vex"

var _accum := 0.0
var _ping_accum := 0.0
var _ping_sent_ms := 0


func _ready() -> void:
	_setup_input()
	var args := OS.get_cmdline_user_args()
	if args.has("--server") or OS.has_feature("dedicated_server"):
		_start_server()
	else:
		local_name = "p%03d" % (randi() % 1000)
		local_color = Color.from_hsv(randf(), 0.65, 0.98)
		local_pos = Vector2(randf_range(220, 1060), randf_range(160, 560))
		_start_client()


func _setup_input() -> void:
	# Define controls in code so we don't hand-author InputEventKey blobs in project.godot.
	_add_action("move_left", [KEY_A, KEY_LEFT])
	_add_action("move_right", [KEY_D, KEY_RIGHT])
	_add_action("jump", [KEY_SPACE, KEY_W, KEY_UP])
	_add_action("dash", [KEY_SHIFT])
	# gamepad: left stick / d-pad to move, A to jump, X to dash
	_add_joy_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_joy_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_joy_button("move_left", JOY_BUTTON_DPAD_LEFT)
	_add_joy_button("move_right", JOY_BUTTON_DPAD_RIGHT)
	_add_joy_button("jump", JOY_BUTTON_A)
	_add_joy_button("dash", JOY_BUTTON_X)


func _add_action(action: String, physical_keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for k in physical_keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func _add_joy_button(action: String, button: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _add_joy_axis(action: String, axis: int, dir: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = dir
	InputMap.action_add_event(action, ev)


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
	is_server = true
	_load_progress()
	print("[server] WebSocket server listening on port %d" % _port())


func _resolve_server_url() -> String:
	var env := OS.get_environment("SERVER_URL")
	if env != "":
		return env
	if OS.has_feature("web"):
		var q := _web_query_param("server")
		return q if q != "" else WEB_SERVER_URL
	return "ws://127.0.0.1:%d" % _port()


func _web_query_param(key: String) -> String:
	if not OS.has_feature("web"):
		return ""
	var v: Variant = JavaScriptBridge.eval(
		"new URLSearchParams(window.location.search).get('%s') || ''" % key, true)
	return str(v) if v != null else ""


func _start_client() -> void:
	# Signals live on the MultiplayerAPI (not the peer), so connect them once even though we
	# may rebuild the peer on every reconnect attempt.
	if not multiplayer.connected_to_server.is_connected(_on_connected):
		multiplayer.connected_to_server.connect(_on_connected)
		multiplayer.connection_failed.connect(_on_connection_failed)
		multiplayer.server_disconnected.connect(_on_server_disconnected)
	var url := _resolve_server_url()
	var peer := WebSocketMultiplayerPeer.new()
	var err := peer.create_client(url)
	if err != OK:
		printerr("[client] create_client failed: %d" % err)
		_schedule_retry()
		return
	multiplayer.multiplayer_peer = peer
	print("[client] connecting to %s ... (attempt %d)" % [url, _retries + 1])


func _schedule_retry() -> void:
	# Reconnect with a short delay instead of silently falling to solo, so a flaky/cold-start
	# WebSocket dial doesn't strand the player offline. After MAX_RETRIES we give up to "offline".
	multiplayer.multiplayer_peer = null
	if _retries >= MAX_RETRIES:
		_set_link("offline")
		push_warning("[client] could not reach server — playing solo")
		return
	_retries += 1
	_set_link("connecting")
	get_tree().create_timer(RETRY_DELAY).timeout.connect(_start_client, CONNECT_ONE_SHOT)


func _set_link(state: String) -> void:
	if link_state == state:
		return
	link_state = state
	link_state_changed.emit(state)


func _process(delta: float) -> void:
	if not (is_server or is_connected):
		return
	_accum += delta
	if _accum >= TICK:
		_accum = 0.0
		if is_server:
			receive_snapshot.rpc(states)
		else:
			submit_state.rpc_id(1, local_pos)
	if is_server:
		_server_race_tick(delta)
	if not is_server:
		_ping_accum += delta
		if _ping_accum >= 1.0:
			_ping_accum = 0.0
			_ping_sent_ms = Time.get_ticks_msec()
			ping_req.rpc_id(1)


# --- Server peer lifecycle ---

func _on_peer_connected(id: int) -> void:
	print("[server] peer connected: %d" % id)


func _on_peer_disconnected(id: int) -> void:
	print("[server] peer disconnected: %d" % id)
	states.erase(id)
	readies.erase(id)
	_names.erase(id)
	_chars.erase(id)
	if phase == "lobby":
		_broadcast_lobby()
	elif phase == "racing" and finishers.size() >= readies.size() and readies.size() > 0:
		_end_race()


# --- Client connection lifecycle ---

func _on_connected() -> void:
	is_connected = true
	_retries = 0
	_set_link("online")
	my_id = multiplayer.get_unique_id()
	print("[client] connected id=%d" % my_id)
	register.rpc_id(1, local_name, local_color, local_char)


func _on_connection_failed() -> void:
	is_connected = false
	push_warning("[client] connection failed — retrying")
	_schedule_retry()


func _on_server_disconnected() -> void:
	printerr("[client] server disconnected — reconnecting")
	is_connected = false
	_retries = 0
	_schedule_retry()


# --- RPCs (defined on both ends; routed by the /root/Net path) ---

@rpc("any_peer", "reliable")
func register(pname: String, color: Color, char_id: String) -> void:
	var id := multiplayer.get_remote_sender_id()
	states[id] = {"pos": Vector2.ZERO, "name": pname, "color": color, "char": char_id}
	_names[id] = pname
	_chars[id] = char_id
	if not readies.has(id):
		readies[id] = false
	# Newcomers always land in the lobby — never dumped mid-race into a confusing running
	# course. If a race is underway they wait there for the next one.
	var payload := _lobby_payload()
	payload["race_in_progress"] = phase != "lobby"
	srv_phase.rpc_id(id, "lobby", payload)
	if phase == "lobby":
		_broadcast_lobby()


@rpc("any_peer", "unreliable_ordered")
func submit_state(pos: Vector2) -> void:
	var id := multiplayer.get_remote_sender_id()
	if states.has(id):
		states[id]["pos"] = pos
	else:
		states[id] = {"pos": pos, "name": "p%d" % id, "color": Color.WHITE, "char": "vex"}


@rpc("authority", "unreliable_ordered")
func receive_snapshot(snap: Dictionary) -> void:
	peer_count = snap.size()
	players_updated.emit(snap)


@rpc("any_peer", "reliable")
func ping_req() -> void:
	pong_resp.rpc_id(multiplayer.get_remote_sender_id())


@rpc("authority", "reliable")
func pong_resp() -> void:
	rtt_ms = Time.get_ticks_msec() - _ping_sent_ms


# ============================================================ Race loop (server-authoritative)

func _server_race_tick(delta: float) -> void:
	match phase:
		"countdown":
			_cd -= delta
			var n := int(ceil(_cd))
			if n != _cd_last:
				_cd_last = n
				if n <= 0:
					_start_race()
				else:
					srv_phase.rpc("countdown", {"n": n, "level": current_level})
		"racing":
			if _grace >= 0.0:
				_grace -= delta
				if _grace <= 0.0:
					_end_race()
		"results":
			_results_t -= delta
			if _results_t <= 0.0:
				_reset_lobby()


func _lobby_payload() -> Dictionary:
	return {
		"readies": readies.duplicate(), "names": _names.duplicate(), "chars": _chars.duplicate(),
		"level": current_level, "level_name": _level_name(current_level),
		"board": board.get(str(current_level), []), "wins": wins,
	}


func _level_name(idx: int) -> String:
	return Levels.ALL[idx % Levels.ALL.size()]["name"]


func _broadcast_lobby() -> void:
	srv_phase.rpc("lobby", _lobby_payload())


func _maybe_start() -> void:
	if phase != "lobby" or readies.is_empty():
		return
	for id in readies:
		if not readies[id]:
			return
	phase = "countdown"
	_cd = float(COUNTDOWN) + 0.99
	_cd_last = -1
	print("[server] all readies (%d) → countdown" % readies.size())


func _start_race() -> void:
	phase = "racing"
	finishers = []
	_grace = -1.0
	srv_phase.rpc("racing", {"level": current_level})
	print("[server] GO — race started (level %d: %s)" % [current_level, _level_name(current_level)])


func _end_race() -> void:
	phase = "results"
	_results_t = RESULTS_TIME
	# Winner gets a win; best times already recorded per-finish.
	if not finishers.is_empty():
		var winner: String = finishers[0]["name"]
		wins[winner] = int(wins.get(winner, 0)) + 1
	_save_progress()
	srv_phase.rpc("results", {
		"order": finishers, "level_name": _level_name(current_level),
		"board": board.get(str(current_level), []), "wins": wins,
	})
	var order := ""
	for f in finishers:
		order += " %s(%dms)" % [f["name"], f["ms"]]
	print("[server] race over → results:%s" % order)


func _reset_lobby() -> void:
	phase = "lobby"
	finishers = []
	for id in readies:
		readies[id] = false
	current_level = (current_level + 1) % Levels.ALL.size()  # rotate course
	_broadcast_lobby()
	print("[server] back to lobby — next course: %s" % _level_name(current_level))


# --- Client API ---

func send_ready(r: bool) -> void:
	if is_connected:
		set_ready.rpc_id(1, r)


func report_finish(ms: int) -> void:
	if is_connected:
		submit_finish.rpc_id(1, ms)


# --- Race RPCs ---

@rpc("any_peer", "reliable")
func set_ready(r: bool) -> void:
	if not is_server:
		return
	var id := multiplayer.get_remote_sender_id()
	if readies.get(id, false) == r:
		return  # no change — avoid rebroadcast storms
	readies[id] = r
	_broadcast_lobby()
	_maybe_start()


@rpc("any_peer", "reliable")
func submit_finish(ms: int) -> void:
	if not is_server or phase != "racing":
		return
	var id := multiplayer.get_remote_sender_id()
	for f in finishers:
		if f["id"] == id:
			return
	var pname: String = _names.get(id, "p%d" % id)
	finishers.append({"id": id, "name": pname, "char": _chars.get(id, "vex"), "ms": ms})
	_record_time(pname, ms)
	srv_phase.rpc("standings", {"order": finishers})
	if _grace < 0.0:
		_grace = FINISH_GRACE
	if finishers.size() >= readies.size():
		_end_race()


func _record_time(pname: String, ms: int) -> void:
	var key := str(current_level)
	var arr: Array = board.get(key, [])
	arr.append({"name": pname, "ms": ms})
	arr.sort_custom(func(a, b): return int(a["ms"]) < int(b["ms"]))
	if arr.size() > 10:
		arr = arr.slice(0, 10)
	board[key] = arr


func _data_path() -> String:
	var d := OS.get_environment("DATA_DIR")
	return d.path_join("leaderboard.json") if d != "" else "user://leaderboard.json"


func _load_progress() -> void:
	var p := _data_path()
	if not FileAccess.file_exists(p):
		return
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		board = data.get("board", {})
		wins = data.get("wins", {})
		print("[server] loaded leaderboard (%d courses, %d winners)" % [board.size(), wins.size()])


func _save_progress() -> void:
	var f := FileAccess.open(_data_path(), FileAccess.WRITE)
	if f == null:
		printerr("[server] could not write leaderboard to %s" % _data_path())
		return
	f.store_string(JSON.stringify({"board": board, "wins": wins}))
	f.close()


@rpc("authority", "reliable")
func srv_phase(phase_name: String, payload: Dictionary) -> void:
	phase = phase_name
	race_event.emit(phase_name, payload)
