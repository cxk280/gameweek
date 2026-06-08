extends Node2D
## Arena scene controller (spine vertical slice).
##
## Renders one square per connected peer from Net's snapshots, drives the local
## player's movement from input, interpolates remote players, and shows a HUD with
## live player count + RTT. `--bot` synthesizes movement + logs what it sees so the
## whole sync path is verifiable headlessly before deploy.

const PlayerScene := preload("res://scenes/Player.tscn")
const SPEED := 320.0
const ARENA := Rect2(16, 16, 1248, 688)

var _nodes := {}  # peer_id -> Player node
var _bot := false
var _log_accum := 0.0

@onready var players: Node2D = $Players
@onready var info: Label = $HUD/Info


func _ready() -> void:
	_bot = OS.get_cmdline_user_args().has("--bot")
	Net.players_updated.connect(_on_players_updated)


func _physics_process(delta: float) -> void:
	if Net.is_server:
		info.text = "SERVER  ·  players=%d" % Net.states.size()
		return
	if not Net.is_connected:
		info.text = "connecting…"
		return

	var input := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if _bot:
		var t := Time.get_ticks_msec() / 1000.0
		input = Vector2(sin(t + Net.my_id), cos(t * 1.3 + Net.my_id))

	Net.local_pos += input * SPEED * delta
	Net.local_pos.x = clampf(Net.local_pos.x, ARENA.position.x, ARENA.end.x)
	Net.local_pos.y = clampf(Net.local_pos.y, ARENA.position.y, ARENA.end.y)
	if _nodes.has(Net.my_id):
		_nodes[Net.my_id].position = Net.local_pos

	info.text = "id=%d  ·  players=%d  ·  ping=%dms" % [Net.my_id, _nodes.size(), Net.rtt_ms]

	if _bot:
		_log_accum += delta
		if _log_accum >= 1.0:
			_log_accum = 0.0
			var others := 0
			var sample := ""
			for id in _nodes:
				if id != Net.my_id:
					others += 1
					sample = "peer %d @ %v" % [id, _nodes[id].target.round()]
			print("[bot %d] sees %d other(s)  %s" % [Net.my_id, others, sample])


func _process(delta: float) -> void:
	# Interpolate remote players toward their last snapshot position.
	for id in _nodes:
		if id != Net.my_id:
			var n: Player = _nodes[id]
			n.position = n.position.lerp(n.target, clampf(delta * 12.0, 0.0, 1.0))


func _on_players_updated(states: Dictionary) -> void:
	for id in states:
		var s: Dictionary = states[id]
		if not _nodes.has(id):
			var p := PlayerScene.instantiate()
			players.add_child(p)
			p.setup(str(s["name"]), s["color"], id == Net.my_id)
			p.position = s["pos"]
			p.target = s["pos"]
			_nodes[id] = p
		else:
			_nodes[id].target = s["pos"]
	for id in _nodes.keys():
		if not states.has(id):
			_nodes[id].queue_free()
			_nodes.erase(id)
