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
var _dust: CPUParticles2D
var _shake := 0.0
var _shake_mag := 0.0
var _was_on_floor := true

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
	_make_dust()
	_apply_camera_limits()


func _make_dust() -> void:
	_dust = CPUParticles2D.new()
	_dust.emitting = false
	_dust.one_shot = true
	_dust.explosiveness = 0.85
	_dust.amount = 10
	_dust.lifetime = 0.4
	_dust.position = Vector2(0, 20)
	_dust.direction = Vector2(0, -1)
	_dust.spread = 70.0
	_dust.gravity = Vector2(0, 320)
	_dust.initial_velocity_min = 40.0
	_dust.initial_velocity_max = 130.0
	_dust.scale_amount_min = 1.0
	_dust.scale_amount_max = 2.5
	_dust.color = Color(0.75, 0.8, 0.95, 0.7)
	add_child(_dust)


func _burst_dust(amount := 10) -> void:
	_dust.amount = amount
	_dust.restart()
	_dust.emitting = true


func shake(mag: float) -> void:
	_shake = 1.0
	_shake_mag = mag


func _apply_shake(delta: float) -> void:
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 4.0)
		camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_mag * _shake
	elif camera.offset != Vector2.ZERO:
		camera.offset = camera.offset.lerp(Vector2.ZERO, 0.3)


## Cosmetic unlock: brighter trail as you rack up wins.
func set_win_tier(w: int) -> void:
	if w >= 10:
		_trail_accent = Color(1.0, 0.3, 0.85)   # magenta (10+ wins)
	elif w >= 3:
		_trail_accent = Color(1.0, 0.85, 0.2)    # gold (3+ wins)
	# else keep the character's own accent


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
		_apply_shake(delta)
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
		Sfx.play("dash", -7.0)
		shake(5.0)
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
		_apply_shake(delta)
		_was_on_floor = is_on_floor()
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
		Sfx.play("jump", -9.0)
		_burst_dust(8)
	if _wants_jump_released() and velocity.y < 0.0:
		velocity.y *= JUMP_CUT

	var fall := velocity.y
	move_and_slide()
	_post_move()
	_update_anim()
	_apply_shake(delta)
	# Landing: airborne -> grounded with downward speed.
	if not _was_on_floor and is_on_floor() and fall > 120.0:
		Sfx.play("land", -10.0)
		_burst_dust(12)
		shake(clampf(fall / 160.0, 1.0, 6.0))
	_was_on_floor = is_on_floor()


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
