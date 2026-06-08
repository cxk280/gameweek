extends Node2D
## Game scene: builds the level, spawns the local player (full physics) + remote ghosts
## (interpolated), follows with the camera, and runs the single-player race timer/respawn.
## Multiplayer race logic (finish order, server-authoritative checkpoints) lands Day 4.

const GhostScene := preload("res://scenes/Player.tscn")
const LocalScene := preload("res://scenes/player/LocalPlayer.tscn")
const SelectScene := preload("res://scenes/CharacterSelect.tscn")

var _ghosts := {}            # peer_id -> ghost Node2D (remotes only)
var _local: LocalPlayer = null
var _race_time := 0.0
var _timing := false
var _finished := false
var _auto := false
var _log_accum := 0.0

@onready var level: Level = $Level
@onready var players: Node2D = $Players
@onready var info: Label = $HUD/Info
@onready var timer_label: Label = $HUD/Timer
@onready var banner: Label = $HUD/Banner


func _ready() -> void:
	_auto = OS.get_cmdline_user_args().has("--auto")
	Net.players_updated.connect(_on_players_updated)
	if Net.is_server:
		return
	level.load_level(Levels.LEVEL_1)
	level.checkpoint_reached.connect(_on_checkpoint)
	level.finish_reached.connect(_on_finish)
	Net.local_pos = level.start_pos
	_build_skyline()
	banner.text = ""
	if _auto:
		Net.local_char = CharacterArt.ids()[0]
		_spawn_local()
	else:
		var select := SelectScene.instantiate()
		add_child(select)
		select.chosen.connect(_on_character_chosen)


func _on_character_chosen(char_id: String) -> void:
	Net.local_char = char_id
	if Net.is_connected:
		Net.register.rpc_id(1, Net.local_name, Net.local_color, char_id)
	_spawn_local()


func _spawn_local() -> void:
	_local = LocalScene.instantiate()
	players.add_child(_local)
	_local.global_position = level.start_pos
	_local.setup(Net.local_name, Net.local_color, level, Net.local_char)


func _physics_process(delta: float) -> void:
	if Net.is_server:
		info.text = "SERVER · players=%d" % Net.states.size()
		return
	if _local:
		Net.local_pos = _local.global_position
		if not _timing and not _finished and absf(_local.velocity.x) > 1.0:
			_timing = true
		if _timing and not _finished:
			_race_time += delta
		if _auto:
			_log_accum += delta
			if _log_accum >= 1.0:
				_log_accum = 0.0
				print("[auto] pos=%v on_floor=%s t=%.1f" % [
					_local.global_position.round(), _local.is_on_floor(), _race_time])
	timer_label.text = _format_time(_race_time)
	info.text = "%s · players=%d · ping=%dms" % [Net.local_name, 1 + _ghosts.size(), Net.rtt_ms]


func _on_players_updated(states: Dictionary) -> void:
	for id in states:
		if id == Net.my_id:
			continue
		var s: Dictionary = states[id]
		if not _ghosts.has(id):
			var g := GhostScene.instantiate()
			players.add_child(g)
			g.setup(str(s["name"]), s["color"], str(s.get("char", "vex")))
			g.position = s["pos"]
			g.target = s["pos"]
			_ghosts[id] = g
		else:
			_ghosts[id].target = s["pos"]
	for id in _ghosts.keys():
		if not states.has(id):
			_ghosts[id].queue_free()
			_ghosts.erase(id)


func _on_checkpoint(index: int, pos: Vector2) -> void:
	if _local:
		_local.respawn_pos = pos
	print("[cp %d] reached @ %v" % [index, pos])


func _on_finish() -> void:
	if _finished:
		return
	_finished = true
	if _local:
		_local.finished = true
	banner.text = "FINISH!  " + _format_time(_race_time)
	print("[FINISH] time=%s" % _format_time(_race_time))


func _format_time(t: float) -> String:
	var total_ms := int(t * 1000.0)
	return "%d:%02d.%03d" % [total_ms / 60000, (total_ms / 1000) % 60, total_ms % 1000]


func _build_skyline() -> void:
	var pb := ParallaxBackground.new()
	add_child(pb)
	move_child(pb, 0)
	_add_stars(pb)
	_add_moon(pb)
	_add_sky_layer(pb, 0.2, Color(0.05, 0.05, 0.13), 70, 7)
	_add_sky_layer(pb, 0.45, Color(0.08, 0.06, 0.18), 130, 11)


func _add_stars(pb: ParallaxBackground) -> void:
	var layer := ParallaxLayer.new()
	layer.motion_scale = Vector2(0.08, 0.08)
	pb.add_child(layer)
	for i in range(180):
		var sx := float((i * 167) % int(bounds_w()))
		var sy := float((i * 89) % 380)
		var s := ColorRect.new()
		var b := 0.5 + float(i % 5) * 0.1
		s.size = Vector2(2, 2)
		s.position = Vector2(sx, sy)
		s.color = Color(b, b, b * 1.1, 0.9)
		layer.add_child(s)


func _add_moon(pb: ParallaxBackground) -> void:
	var layer := ParallaxLayer.new()
	layer.motion_scale = Vector2(0.04, 0.04)
	pb.add_child(layer)
	var glow := _disc(70.0, Color(0.7, 0.8, 1.0, 0.10))
	glow.position = Vector2(960, 150)
	layer.add_child(glow)
	var moon := _disc(46.0, Color(0.86, 0.9, 0.98, 1.0))
	moon.position = Vector2(960, 150)
	layer.add_child(moon)
	var crater := _disc(40.0, Color(0.80, 0.85, 0.95, 1.0))
	crater.position = Vector2(972, 142)
	layer.add_child(crater)


func _disc(radius: float, color: Color) -> Polygon2D:
	var poly := PackedVector2Array()
	for a in range(20):
		var ang := TAU * float(a) / 20.0
		poly.append(Vector2(cos(ang), sin(ang)) * radius)
	var p := Polygon2D.new()
	p.polygon = poly
	p.color = color
	return p


func bounds_w() -> float:
	return maxf(level.bounds.size.x, 1.0)


func _add_sky_layer(pb: ParallaxBackground, scale: float, color: Color, seedn: int, count: int) -> void:
	var layer := ParallaxLayer.new()
	layer.motion_scale = Vector2(scale, scale)
	pb.add_child(layer)
	var base_y := 820.0
	var x := -200.0
	for i in range(count * 6):
		var w := 70.0 + float((i * seedn + 13) % 140)
		var h := 140.0 + float((i * 53 + seedn * 7) % 360)
		var b := ColorRect.new()
		b.position = Vector2(x, base_y - h)
		b.size = Vector2(w, h)
		b.color = color
		layer.add_child(b)
		# a couple of lit neon windows
		var win_color := Color(0.0, 0.95, 1.0, 0.5) if i % 2 == 0 else Color(1.0, 0.3, 0.7, 0.5)
		for k in range(3):
			var win := ColorRect.new()
			win.size = Vector2(6, 6)
			win.position = Vector2(x + 14 + (k * 18 % int(maxf(w - 20, 10))), base_y - h + 20 + k * 26)
			win.color = win_color
			layer.add_child(win)
		x += w + 30.0


func _input(event: InputEvent) -> void:
	# R restarts the run locally (handy while iterating; full race reset is Day 4).
	if event is InputEventKey and event.pressed and event.keycode == KEY_R and _local:
		_local.respawn_pos = level.start_pos
		_local.global_position = level.start_pos
		_local.respawn()
		_local.finished = false
		_race_time = 0.0
		_timing = false
		_finished = false
		banner.text = ""
