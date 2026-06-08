extends CharacterBody2D
class_name LocalPlayer
## The player YOU control. Full platformer physics against the level; only the local peer
## simulates this — remote players are interpolated ghosts (see Player.gd). Tuned for a
## tight, fast, forgiving feel: accel/friction, variable jump, coyote time, jump buffer,
## and an air-dash that conserves momentum and leaves a neon afterimage trail.

# --- Feel constants (jump/run/gaps confirmed good in playtest; leave them) ---
const RUN_SPEED := 340.0
const GROUND_ACCEL := 2800.0
const GROUND_FRICTION := 3000.0
const AIR_ACCEL := 2000.0
const AIR_FRICTION := 400.0
const GRAVITY := 1500.0
const MAX_FALL := 1250.0
const JUMP_VELOCITY := -600.0
const JUMP_CUT := 0.45
const COYOTE_TIME := 0.10
const JUMP_BUFFER := 0.10
# Dash, reworked to be a useful movement tech (air-dash to extend jumps / save misses).
const DASH_SPEED := 880.0
const DASH_TIME := 0.16
const DASH_COOLDOWN := 0.45
const DASH_EXIT := 1.15            # keep this × RUN_SPEED when a dash ends (momentum)

var respawn_pos := Vector2.ZERO
var facing := 1.0
var finished := false
var input_enabled := true

var _level: Level = null
var _coyote := 0.0
var _buffer := 0.0
var _dash_time := 0.0
var _dash_cd := 0.0
var _dash_dir := 1.0
var _can_air_dash := true
var _trail_accent := Color(0.0, 0.95, 1.0)
var _auto := false

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var label: Label = $Label
@onready var camera: Camera2D = $Camera2D
@onready var _floor_ahead: RayCast2D = $FloorAhead


func setup(pname: String, _color: Color, level: Level, char_id: String) -> void:
	_level = level
	respawn_pos = level.start_pos
	var cd := CharacterArt.get_char(char_id)
	_trail_accent = cd.get("accent", _trail_accent)
	sprite.sprite_frames = SpriteFactory.make_sprite_frames(cd)
	sprite.play("idle")
	label.text = pname
	collision_layer = Level.L_PLAYER
	collision_mask = Level.L_SOLID
	var args := OS.get_cmdline_user_args()
	_auto = args.has("--auto") or args.has("--racebot")
	_apply_camera_limits()


func _apply_camera_limits() -> void:
	if _level == null:
		return
	camera.limit_left = int(_level.bounds.position.x)
	camera.limit_right = int(_level.bounds.end.x)
	camera.limit_top = -400
	camera.limit_bottom = int(_level.bounds.end.y)


func _physics_process(delta: float) -> void:
	if finished:
		velocity = velocity.move_toward(Vector2.ZERO, GROUND_FRICTION * delta)
		move_and_slide()
		_update_anim()
		return

	var dir := _input_axis()
	if dir != 0.0:
		facing = signf(dir)

	if is_on_floor():
		_can_air_dash = true

	# Dash (overrides normal control while active).
	_dash_cd -= delta
	if _wants_dash() and _dash_cd <= 0.0 and (is_on_floor() or _can_air_dash):
		_dash_time = DASH_TIME
		_dash_cd = DASH_COOLDOWN
		_dash_dir = facing
		if not is_on_floor():
			_can_air_dash = false
	if _dash_time > 0.0:
		_dash_time -= delta
		velocity.x = _dash_dir * DASH_SPEED
		velocity.y = 0.0
		_spawn_afterimage()
		move_and_slide()
		if _dash_time <= 0.0:
			velocity.x = _dash_dir * RUN_SPEED * DASH_EXIT  # exit with momentum, not a screech
		_post_move()
		_update_anim()
		return

	# Horizontal accel / friction.
	if dir != 0.0:
		var accel := GROUND_ACCEL if is_on_floor() else AIR_ACCEL
		velocity.x = move_toward(velocity.x, dir * RUN_SPEED, accel * delta)
	else:
		var fric := GROUND_FRICTION if is_on_floor() else AIR_FRICTION
		velocity.x = move_toward(velocity.x, 0.0, fric * delta)

	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)

	_coyote = COYOTE_TIME if is_on_floor() else _coyote - delta
	_buffer = JUMP_BUFFER if _wants_jump_pressed() else _buffer - delta
	if _buffer > 0.0 and _coyote > 0.0:
		velocity.y = JUMP_VELOCITY
		_buffer = 0.0
		_coyote = 0.0
	if _wants_jump_released() and velocity.y < 0.0:
		velocity.y *= JUMP_CUT

	move_and_slide()
	_post_move()
	_update_anim()


func _update_anim() -> void:
	if _dash_time > 0.0 or not is_on_floor():
		sprite.play("jump")
	elif absf(velocity.x) > 15.0:
		sprite.play("run")
	else:
		sprite.play("idle")
	if absf(velocity.x) > 5.0:
		sprite.flip_h = velocity.x < 0.0
	else:
		sprite.flip_h = facing < 0.0


func _spawn_afterimage() -> void:
	if sprite.sprite_frames == null:
		return
	var tex := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if tex == null:
		return
	var ghost := Sprite2D.new()
	ghost.texture = tex
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ghost.global_position = sprite.global_position
	ghost.scale = sprite.scale
	ghost.flip_h = sprite.flip_h
	ghost.modulate = Color(_trail_accent.r, _trail_accent.g, _trail_accent.b, 0.55)
	ghost.z_index = -1
	get_parent().add_child(ghost)
	var tw := ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, 0.28)
	tw.tween_callback(ghost.queue_free)


func _post_move() -> void:
	if global_position.y > _level.kill_y:
		respawn()


func respawn() -> void:
	global_position = respawn_pos
	velocity = Vector2.ZERO
	_dash_time = 0.0


# --- Input (real or autopilot) ---

func _input_axis() -> float:
	if _auto:
		return 1.0 if input_enabled else 0.0
	return Input.get_axis("move_left", "move_right") if input_enabled else 0.0


func _wants_jump_pressed() -> bool:
	if _auto:
		return input_enabled and is_on_floor() and (not _floor_ahead.is_colliding() or is_on_wall())
	return input_enabled and Input.is_action_just_pressed("jump")


func _wants_jump_released() -> bool:
	return false if _auto else Input.is_action_just_released("jump")


func _wants_dash() -> bool:
	return input_enabled and Input.is_action_just_pressed("dash") if not _auto else false
