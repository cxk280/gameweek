extends Node2D
## Game scene: builds the level, spawns the local player (full physics) + remote ghosts
## (interpolated), follows the camera, runs the race timer, and drives the multiplayer race
## loop (lobby/countdown/race/results) off Net's server-authoritative phase events. When not
## connected to a server it falls back to free-run (single-player time trial).

const Backdrop := preload("res://scripts/Backdrop.gd")
const GhostScene := preload("res://scenes/Player.tscn")
const LocalScene := preload("res://scenes/player/LocalPlayer.tscn")
const SelectScene := preload("res://scenes/CharacterSelect.tscn")
const COUNTDOWN_FALLBACK := 3

var _ghosts := {}            # peer_id -> ghost Node2D (remotes only)
var _local: LocalPlayer = null
var _race_time := 0.0
var _timing := false
var _finished := false
var _auto := false
var _log_accum := 0.0
var _race_mode := false      # true when connected to a server (drives lobby/countdown/race)
var _racing := false         # true between GO and results
var _race_hud: RaceHUD = null
var _racebot := false        # headless test: auto-play + auto-ready in the race
var _racebot_readied := false
var _current_level := -1
var _bg: ParallaxBackground = null
var _sky_rect: TextureRect = null
var _backdrop_theme := ""
var _bg_thread: Thread = null
var _bg_want_theme := ""
var _bg_busy := false
var _tower_layer: CanvasLayer = null
var _tower_spin: Sprite2D = null
var _music: AudioStreamPlayer = null
var _music_theme := ""

@onready var level: Level = $Level
@onready var players: Node2D = $Players
@onready var info: Label = $HUD/Info
@onready var timer_label: Label = $HUD/Timer
@onready var banner: Label = $HUD/Banner


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_racebot = args.has("--racebot")
	_auto = args.has("--auto") or _racebot
	Net.players_updated.connect(_on_players_updated)
	if Net.is_server:
		return
	level.checkpoint_reached.connect(_on_checkpoint)
	level.finish_reached.connect(_on_finish)
	_ensure_level(0)
	banner.text = ""
	if _racebot:
		# Headless race participant: drive the race flow, auto-ready on lobby.
		Net.local_char = CharacterArt.ids()[0]
		_race_mode = true
		Net.race_event.connect(_on_race_event)
		_spawn_local()
	elif _auto:
		Net.local_char = CharacterArt.ids()[0]
		# --level=N test hook: free-run a specific course headlessly.
		for a in args:
			if a.begins_with("--level="):
				_ensure_level(int(a.split("=")[1]))
		_spawn_local()
	else:
		var select := SelectScene.instantiate()
		add_child(select)
		select.chosen.connect(_on_character_chosen)


func _on_character_chosen(char_id: String) -> void:
	Net.local_char = char_id
	_race_mode = Net.is_connected
	if _race_mode:
		# Re-register with the chosen character; the server replies with the current phase.
		Net.register.rpc_id(1, Net.local_name, Net.local_color, char_id)
		_race_hud = RaceHUD.new()
		add_child(_race_hud)
		_race_hud.ready_pressed.connect(func(r: bool): Net.send_ready(r))
		Net.race_event.connect(_on_race_event)
	_spawn_local()
	if not _race_mode:
		banner.text = ""


func _on_race_event(phase: String, payload: Dictionary) -> void:
	# Load the rotated course + apply win-based cosmetic trail before phase handling.
	if payload.has("level"):
		_ensure_level(int(payload["level"]))
	if payload.has("wins") and _local:
		_local.set_win_tier(int((payload["wins"] as Dictionary).get(Net.local_name, 0)))
	match phase:
		"lobby":
			_racing = false
			_finished = false
			_timing = false
			_race_time = 0.0
			banner.text = ""
			_reset_to_start()
			if _local:
				_local.input_enabled = true
			if _race_hud:
				_race_hud.show_lobby(payload, Net.my_id)
			if _racebot and not _racebot_readied:
				_racebot_readied = true
				Net.send_ready(true)
		"countdown":
			_racing = false
			_finished = false
			_timing = false
			_race_time = 0.0
			banner.text = ""
			_reset_to_start()
			if _local:
				_local.input_enabled = false
			if _race_hud:
				_race_hud.show_countdown(int(payload.get("n", COUNTDOWN_FALLBACK)))
			Sfx.play("beep")
		"racing":
			_racing = true
			_finished = false
			_timing = true
			_race_time = 0.0
			banner.text = ""
			_reset_to_start()
			if _local:
				_local.input_enabled = true
			if _race_hud:
				_race_hud.start_racing()
			Sfx.play("go", -3.0)
		"standings":
			if _race_hud:
				var place := _race_hud.update_standings(payload.get("order", []), Net.my_id)
				if _finished and place > 0:
					_race_hud.toast("You finished P%d" % place, Color(1.0, 0.85, 0.2))
		"results":
			_racing = false
			_racebot_readied = false  # re-ready for the next race
			if _local:
				_local.input_enabled = false
			if _race_hud:
				_race_hud.show_results(payload, Net.my_id)


func _ensure_level(idx: int) -> void:
	if idx == _current_level:
		return
	_current_level = idx
	var data: Dictionary = Levels.ALL[idx % Levels.ALL.size()]
	level.load_level(data)
	_build_backdrop(str(data.get("backdrop", "city")))
	Net.local_pos = level.start_pos
	if _local:
		_reset_to_start()


func _apply_progress(payload: Dictionary) -> void:
	_ensure_level(int(payload.get("level", 0)))
	if _local:
		var w: Dictionary = payload.get("wins", {})
		_local.set_win_tier(int(w.get(Net.local_name, 0)))


func _reset_to_start() -> void:
	if _local == null:
		return
	_local.global_position = level.start_pos
	_local.velocity = Vector2.ZERO
	_local.respawn_pos = level.start_pos
	_local.finished = false
	Net.local_pos = level.start_pos


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
		if _tower_spin != null and _tower_layer.visible:
			var sx := level.start_pos.x
			var fx := level.finish_pos.x
			var p := clampf((_local.global_position.x - sx) / maxf(fx - sx, 1.0), 0.0, 1.0)
			_tower_spin.frame = int(p * 24.0 * 2.0) % 24   # ~2 turns over the climb
		# Free-run mode starts timing on first movement; race mode is gated by the GO event.
		if not _race_mode and not _timing and not _finished and absf(_local.velocity.x) > 1.0:
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
	Sfx.play("checkpoint", -8.0)
	print("[cp %d] reached @ %v" % [index, pos])


func _on_finish() -> void:
	if _finished:
		return
	if _race_mode and not _racing:
		return  # ignore finishes during lobby warm-up
	_finished = true
	_timing = false
	if _local:
		_local.finished = true
	Sfx.play("finish", -3.0)
	if _local:
		_local.shake(7.0)
	if _race_mode and _racing:
		Net.report_finish(int(_race_time * 1000.0))
		banner.text = "FINISHED  " + _format_time(_race_time)
	else:
		banner.text = "FINISH!  %s\nENTER: next stage     R: retry" % _format_time(_race_time)
	print("[FINISH] time=%s" % _format_time(_race_time))


func _format_time(t: float) -> String:
	var total_ms := int(t * 1000.0)
	return "%d:%02d.%03d" % [total_ms / 60000, (total_ms / 1000) % 60, total_ms % 1000]


func _build_backdrop(theme: String) -> void:
	# 2.5D parallax built off the main thread so level transitions don't hitch. The static sky
	# shows immediately; depth layers (distant ones barely move, nearer rows track the camera)
	# are mounted when the worker finishes (~2s). Latest requested theme always wins.
	_bg_want_theme = theme
	_set_tower(theme == "tower")
	_set_music(theme)
	if theme == _backdrop_theme and _bg != null:
		return
	if _bg_busy:
		return
	_start_backdrop_build(theme)


func _set_music(theme: String) -> void:
	# Per-stage looping background music (one original track per theme). Tracks are added over
	# time; a theme with no track plays nothing.
	if theme == _music_theme:
		return
	if _music == null:
		_music = AudioStreamPlayer.new()
		_music.volume_db = -7.0
		add_child(_music)
	var path := "res://audio/music/%s.wav" % theme
	if not ResourceLoader.exists(path):
		_music.stop()
		_music_theme = ""
		return
	var s := load(path)
	if s is AudioStreamWAV:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = int(s.get_length() * float(s.mix_rate))
	_music.stream = s
	_music.play()
	_music_theme = theme


func _set_tower(on: bool) -> void:
	# The spire stage's signature: a colossal tower looming behind the climb that turns as the
	# player ascends (frame advanced from progress in _physics_process). Behind the play field.
	if on and _tower_spin == null:
		var tex := load("res://assets/tower_spin.png") as Texture2D
		if tex == null:
			return
		_tower_layer = CanvasLayer.new()
		_tower_layer.layer = -4
		add_child(_tower_layer)
		_tower_spin = Sprite2D.new()
		_tower_spin.texture = tex
		_tower_spin.hframes = 24
		_tower_spin.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_tower_spin.position = Vector2(640, 360)
		_tower_spin.scale = Vector2(1.25, 1.25)
		_tower_layer.add_child(_tower_spin)
	if _tower_layer != null:
		_tower_layer.visible = on


func _start_backdrop_build(theme: String) -> void:
	_bg_busy = true
	_bg_thread = Thread.new()
	_bg_thread.start(_backdrop_worker.bind(theme, bounds_w()))


func _backdrop_worker(theme: String, level_w: float) -> void:
	# Runs on a background thread: paints the layer Images (no scene-tree access).
	var data := Backdrop.new().build(theme, level_w, 1280, 720)
	call_deferred("_backdrop_ready", theme, data)


func _backdrop_ready(theme: String, data: Dictionary) -> void:
	if _bg_thread != null:
		_bg_thread.wait_to_finish()
		_bg_thread = null
	_bg_busy = false
	_mount_backdrop(data)
	_backdrop_theme = theme
	if _bg_want_theme != theme:
		_start_backdrop_build(_bg_want_theme)   # a newer theme was requested mid-build


func _mount_backdrop(data: Dictionary) -> void:
	# Main thread: turn the painted Images into textures + ParallaxLayers.
	if _bg != null:
		_bg.queue_free()
	if _sky_rect == null:
		var skybg := $Sky.get_node_or_null("SkyBG")
		if skybg:
			skybg.queue_free()
		_sky_rect = TextureRect.new()
		_sky_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_sky_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_sky_rect.stretch_mode = TextureRect.STRETCH_SCALE
		_sky_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		$Sky.add_child(_sky_rect)
	_sky_rect.texture = ImageTexture.create_from_image(data["sky"])
	_bg = ParallaxBackground.new()
	_bg.layer = -5
	add_child(_bg)
	var horizon := level.bounds.end.y
	var left := level.bounds.position.x
	for ld in data["layers"]:
		var layer := ParallaxLayer.new()
		var m: float = ld["motion"]
		layer.motion_scale = Vector2(m, m)
		var spr := Sprite2D.new()
		spr.texture = ImageTexture.create_from_image(ld["image"])
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.centered = false
		var top: float = ld["top"]
		if bool(ld.get("anchor_bottom", false)):
			top = horizon - float((ld["image"] as Image).get_height())
		spr.position = Vector2(left, top)
		layer.add_child(spr)
		_bg.add_child(layer)


func _exit_tree() -> void:
	if _bg_thread != null:
		_bg_thread.wait_to_finish()
		_bg_thread = null


func bounds_w() -> float:
	return maxf(level.bounds.size.x, 1.0)


func _input(event: InputEvent) -> void:
	# Free-run only (race resets are server-driven): R retries the stage; after finishing,
	# ENTER/SPACE advances to the next stage (cycling all courses, swapping backdrop + music).
	if _race_mode or _local == null:
		return
	if not (event is InputEventKey and event.pressed):
		return
	var key: int = (event as InputEventKey).keycode
	if key == KEY_R:
		_local.respawn_pos = level.start_pos
		_local.global_position = level.start_pos
		_local.respawn()
		_local.finished = false
		_race_time = 0.0
		_timing = false
		_finished = false
		banner.text = ""
	elif _finished and (key == KEY_ENTER or key == KEY_KP_ENTER or key == KEY_SPACE):
		_ensure_level((_current_level + 1) % Levels.ALL.size())
		_reset_to_start()
		_local.finished = false
		_race_time = 0.0
		_timing = false
		_finished = false
		banner.text = ""
