extends CharacterBody2D
class_name LocalPlayer
## The player YOU control. Full platformer physics against the level; only the local peer
## simulates this — remote players are interpolated ghosts (see Player.gd). Tuned for a
## tight, fast, forgiving feel: accel/friction, variable jump, coyote time, jump buffer, dash.

# --- Feel constants (tuned for tight-and-fast; adjust from playtest feedback) ---
const RUN_SPEED := 340.0
const GROUND_ACCEL := 2800.0
const GROUND_FRICTION := 3000.0
const AIR_ACCEL := 2000.0
const AIR_FRICTION := 400.0
const GRAVITY := 1500.0
const MAX_FALL := 1250.0
const JUMP_VELOCITY := -600.0      # ~120px jump height
const JUMP_CUT := 0.45             # released-early jump cut (variable height)
const COYOTE_TIME := 0.10
const JUMP_BUFFER := 0.10
const DASH_SPEED := 720.0
const DASH_TIME := 0.16
const DASH_COOLDOWN := 0.55

var respawn_pos := Vector2.ZERO
var facing := 1.0
var finished := false

var _level: Level = null
var _coyote := 0.0
var _buffer := 0.0
var _dash_time := 0.0
var _dash_cd := 0.0
var _dash_dir := 1.0
var _auto := false
var _auto_jump := 0.0

@onready var label: Label = $Label
@onready var rect: ColorRect = $Rect
@onready var camera: Camera2D = $Camera2D
@onready var _floor_ahead: RayCast2D = $FloorAhead


func setup(pname: String, color: Color, level: Level) -> void:
	_level = level
	respawn_pos = level.start_pos
	rect.color = color
	label.text = "▶ " + pname
	collision_layer = Level.L_PLAYER
	collision_mask = Level.L_SOLID
	_auto = OS.get_cmdline_user_args().has("--auto")
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
		return

	var dir := _input_axis()
	if dir != 0.0:
		facing = signf(dir)

	# Dash (overrides normal horizontal control while active).
	_dash_cd -= delta
	if _wants_dash() and _dash_cd <= 0.0:
		_dash_time = DASH_TIME
		_dash_cd = DASH_COOLDOWN
		_dash_dir = facing
	if _dash_time > 0.0:
		_dash_time -= delta
		velocity.x = _dash_dir * DASH_SPEED
		velocity.y = 0.0
		move_and_slide()
		_post_move()
		return

	# Horizontal accel / friction.
	if dir != 0.0:
		var accel := GROUND_ACCEL if is_on_floor() else AIR_ACCEL
		velocity.x = move_toward(velocity.x, dir * RUN_SPEED, accel * delta)
	else:
		var fric := GROUND_FRICTION if is_on_floor() else AIR_FRICTION
		velocity.x = move_toward(velocity.x, 0.0, fric * delta)

	# Gravity.
	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)

	# Coyote time + jump buffer.
	_coyote = COYOTE_TIME if is_on_floor() else _coyote - delta
	_buffer = JUMP_BUFFER if _wants_jump_pressed() else _buffer - delta
	if _buffer > 0.0 and _coyote > 0.0:
		velocity.y = JUMP_VELOCITY
		_buffer = 0.0
		_coyote = 0.0
	# Variable jump height: cut the rise if jump released early.
	if _wants_jump_released() and velocity.y < 0.0:
		velocity.y *= JUMP_CUT

	move_and_slide()
	_post_move()


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
		return 1.0  # autopilot runs right
	return Input.get_axis("move_left", "move_right")


func _wants_jump_pressed() -> bool:
	if _auto:
		# Edge-detecting autopilot: jump when grounded and there's a gap ahead or a wall.
		return is_on_floor() and (not _floor_ahead.is_colliding() or is_on_wall())
	return Input.is_action_just_pressed("jump")


func _wants_jump_released() -> bool:
	return false if _auto else Input.is_action_just_released("jump")


func _wants_dash() -> bool:
	return false if _auto else Input.is_action_just_pressed("dash")
