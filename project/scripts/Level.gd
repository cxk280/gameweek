extends Node2D
class_name Level
## Builds a level's geometry from a Levels.* data dictionary: solid platforms with neon
## top edges, checkpoint pylons, and a finish gate. Emits when the local player crosses a
## checkpoint or the finish so Main can drive timing/respawn/race logic.

signal checkpoint_reached(index: int, pos: Vector2)
signal finish_reached()

# Collision layers: 1 = players, 2 = solid world.
const L_PLAYER := 1
const L_SOLID := 2

const NEON := [
	Color(0.0, 0.95, 1.0),   # cyan
	Color(1.0, 0.15, 0.7),   # magenta
	Color(0.55, 0.4, 1.0),   # violet
]
const FILL := Color(0.06, 0.07, 0.14)
const CHECK_COLOR := Color(0.6, 1.0, 0.25)
const FINISH_COLOR := Color(1.0, 0.85, 0.1)

var start_pos := Vector2.ZERO
var finish_pos := Vector2.ZERO
var kill_y := 9999.0
var bounds := Rect2()


func load_level(data: Dictionary) -> void:
	for c in get_children():
		c.queue_free()
	start_pos = data["start"]
	finish_pos = data["finish"]
	bounds = data["bounds"]
	kill_y = bounds.end.y - 30.0
	var i := 0
	for r in data["platforms"]:
		_add_platform(r, NEON[i % NEON.size()])
		i += 1
	i = 0
	for cp in data["checkpoints"]:
		_add_checkpoint(cp, i)
		i += 1
	_add_finish(finish_pos)


func _add_platform(r: Rect2, edge: Color) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = L_SOLID
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = r.size
	shape.shape = rs
	shape.position = r.position + r.size * 0.5
	body.add_child(shape)
	# Visuals: dark fill + a glowing neon top edge.
	var fill := ColorRect.new()
	fill.position = r.position
	fill.size = r.size
	fill.color = FILL
	body.add_child(fill)
	var glow := ColorRect.new()
	glow.position = r.position - Vector2(0, 6)
	glow.size = Vector2(r.size.x, 10)
	glow.color = Color(edge.r, edge.g, edge.b, 0.25)
	body.add_child(glow)
	var top := ColorRect.new()
	top.position = r.position
	top.size = Vector2(r.size.x, 4)
	top.color = edge
	body.add_child(top)
	add_child(body)


func _add_checkpoint(pos: Vector2, index: int) -> void:
	var area := Area2D.new()
	area.position = pos
	area.collision_layer = 0
	area.collision_mask = L_PLAYER
	area.monitorable = false
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(48, 220)
	shape.shape = rs
	shape.position = Vector2(0, -90)
	area.add_child(shape)
	var bar := ColorRect.new()
	bar.position = Vector2(-3, -200)
	bar.size = Vector2(6, 200)
	bar.color = Color(CHECK_COLOR.r, CHECK_COLOR.g, CHECK_COLOR.b, 0.5)
	area.add_child(bar)
	area.body_entered.connect(_on_checkpoint_entered.bind(index, pos, bar))
	add_child(area)


func _on_checkpoint_entered(body: Node, index: int, pos: Vector2, bar: ColorRect) -> void:
	if body is LocalPlayer:
		bar.color = CHECK_COLOR
		checkpoint_reached.emit(index, pos)


func _add_finish(pos: Vector2) -> void:
	var area := Area2D.new()
	area.position = pos
	area.collision_layer = 0
	area.collision_mask = L_PLAYER
	area.monitorable = false
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(60, 240)
	shape.shape = rs
	shape.position = Vector2(0, -100)
	area.add_child(shape)
	for n in range(10):
		var c := ColorRect.new()
		c.size = Vector2(20, 20)
		c.position = Vector2(-20 if n % 2 == 0 else 0, -200 + n * 20)
		c.color = FINISH_COLOR if n % 2 == 0 else Color(0.05, 0.05, 0.05)
		area.add_child(c)
	area.body_entered.connect(_on_finish_entered)
	add_child(area)


func _on_finish_entered(body: Node) -> void:
	if body is LocalPlayer:
		finish_reached.emit()
