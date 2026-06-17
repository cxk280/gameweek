extends Node2D
class_name Level
## Builds a level from a Levels.* data dictionary: neon platforms (with rooftop props),
## unmistakable checkpoint gates, pit hazards, and a finish gate. Emits when the local
## player crosses a checkpoint or the finish so Main drives timing/respawn/race logic.

signal checkpoint_reached(index: int, pos: Vector2)
signal finish_reached()

# Collision layers: 1 = players, 2 = solid world.
const L_PLAYER := 1
const L_SOLID := 2

const NEON := [
	Color(0.0, 0.95, 1.0),   # cyan
	Color(1.0, 0.15, 0.7),   # magenta
	Color(0.55, 0.4, 1.0),   # violet
	Color(0.2, 1.0, 0.6),    # green
]
const FILL := Color(0.06, 0.07, 0.14)
const FILL2 := Color(0.09, 0.10, 0.18)
const CHECK_COLOR := Color(0.3, 1.0, 0.45)
const CHECK_GOLD := Color(1.0, 0.85, 0.2)
const FINISH_COLOR := Color(1.0, 0.85, 0.1)
const HAZARD_COLOR := Color(1.0, 0.25, 0.35)

# Per-theme platform look: dark body fills + bright top-edge accent colours that read against
# each stage's backdrop. Keyed by the level's "backdrop" theme; falls back to city.
const PLATFORM_STYLES := {
	"city":       {"fill": Color8(15, 18, 36), "fill2": Color8(23, 26, 46), "edges": NEON},
	"town":       {"fill": Color8(26, 18, 12), "fill2": Color8(38, 27, 18), "edges": [Color8(255, 180, 90), Color8(255, 140, 70)]},
	"lake":       {"fill": Color8(16, 26, 30), "fill2": Color8(22, 34, 40), "edges": [Color8(120, 230, 240), Color8(255, 200, 110)]},
	"terracotta": {"fill": Color8(34, 22, 16), "fill2": Color8(46, 30, 22), "edges": [Color8(240, 140, 80), Color8(245, 225, 190)]},
	"brick":      {"fill": Color8(28, 18, 18), "fill2": Color8(40, 26, 24), "edges": [Color8(255, 180, 90), Color8(220, 90, 70)]},
	"tower":      {"fill": Color8(14, 12, 16), "fill2": Color8(22, 18, 24), "edges": [Color8(255, 70, 70), Color8(150, 130, 110)]},
	"lunar":      {"fill": Color8(16, 18, 30), "fill2": Color8(24, 26, 40), "edges": [Color8(80, 240, 255), Color8(235, 235, 245)]},
	"highland":   {"fill": Color8(30, 26, 20), "fill2": Color8(42, 36, 28), "edges": [Color8(245, 230, 200), Color8(220, 90, 60)]},
	"bay":        {"fill": Color8(16, 24, 30), "fill2": Color8(22, 32, 40), "edges": [Color8(90, 220, 230), Color8(255, 225, 140)]},
	"library":    {"fill": Color8(26, 18, 12), "fill2": Color8(36, 26, 16), "edges": [Color8(245, 205, 110), Color8(255, 235, 180)]},
}

var _pfill := FILL
var _pfill2 := FILL2
var _edges: Array = NEON

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
	var style: Dictionary = PLATFORM_STYLES.get(str(data.get("backdrop", "city")), PLATFORM_STYLES["city"])
	_pfill = style["fill"]
	_pfill2 = style["fill2"]
	_edges = style["edges"]
	var i := 0
	for r in data["platforms"]:
		_add_platform(r, _edges[i % _edges.size()], i)
		i += 1
	for h in data.get("hazards", []):
		_add_hazard(h)
	i = 0
	for cp in data["checkpoints"]:
		_add_checkpoint(cp, i)
		i += 1
	_add_finish(finish_pos)


# ----------------------------------------------------------------------------- platforms
func _add_platform(r: Rect2, edge: Color, idx: int) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = L_SOLID
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = r.size
	shape.shape = rs
	shape.position = r.position + r.size * 0.5
	body.add_child(shape)

	_rect(body, r.position, r.size, _pfill)
	_rect(body, r.position + Vector2(0, r.size.y * 0.5), Vector2(r.size.x, r.size.y * 0.5), _pfill2)
	_rect(body, r.position - Vector2(0, 6), Vector2(r.size.x, 8), Color(edge.r, edge.g, edge.b, 0.22))
	_rect(body, r.position, Vector2(r.size.x, 3), edge)
	_add_props(body, r, edge, idx)
	add_child(body)


func _add_props(body: Node2D, r: Rect2, edge: Color, idx: int) -> void:
	# Deterministic rooftop clutter for detail: antennas, vents, neon signs.
	var n := 1 + (idx % 3)
	for k in range(n):
		var px := r.position.x + 24 + float((idx * 53 + k * 130) % int(maxf(r.size.x - 48, 1)))
		var kind := (idx + k) % 3
		if kind == 0:
			# antenna with a blinking red tip
			_rect(body, Vector2(px, r.position.y - 30), Vector2(3, 30), Color(0.4, 0.42, 0.55))
			_rect(body, Vector2(px - 1, r.position.y - 34), Vector2(5, 5), Color(1.0, 0.3, 0.3))
		elif kind == 1:
			# AC vent box
			_rect(body, Vector2(px, r.position.y - 16), Vector2(26, 16), Color(0.12, 0.13, 0.2))
			_rect(body, Vector2(px, r.position.y - 16), Vector2(26, 3), Color(0.2, 0.22, 0.3))
		else:
			# small neon sign
			_rect(body, Vector2(px, r.position.y - 40), Vector2(4, 26), Color(0.3, 0.32, 0.4))
			_rect(body, Vector2(px - 8, r.position.y - 46), Vector2(20, 12), Color(edge.r, edge.g, edge.b, 0.85))


# ----------------------------------------------------------------------------- hazards
func _add_hazard(r: Rect2) -> void:
	# Spikes that respawn the player (placed in pits — visual danger, autopilot jumps gaps).
	var area := Area2D.new()
	area.position = r.position
	area.collision_layer = 0
	area.collision_mask = L_PLAYER
	area.monitorable = false
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = r.size
	shape.shape = rs
	shape.position = r.size * 0.5
	area.add_child(shape)
	var spikes := int(r.size.x / 12.0)
	for s in range(spikes):
		var tri := Polygon2D.new()
		var bx := s * 12.0
		tri.polygon = PackedVector2Array([Vector2(bx, r.size.y), Vector2(bx + 6, 0), Vector2(bx + 12, r.size.y)])
		tri.color = HAZARD_COLOR
		area.add_child(tri)
	area.body_entered.connect(_on_hazard_entered)
	add_child(area)


func _on_hazard_entered(body: Node) -> void:
	if body is LocalPlayer:
		(body as LocalPlayer).respawn()


# ----------------------------------------------------------------------------- checkpoints
func _add_checkpoint(pos: Vector2, index: int) -> void:
	var area := Area2D.new()
	area.position = pos
	area.collision_layer = 0
	area.collision_mask = L_PLAYER
	area.monitorable = false
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(60, 260)
	shape.shape = rs
	shape.position = Vector2(0, -120)
	area.add_child(shape)

	# Tall light beam (the unmistakable "checkpoint here" marker).
	var beam := ColorRect.new()
	beam.size = Vector2(20, 270)
	beam.position = Vector2(-10, -270)
	beam.color = Color(CHECK_COLOR.r, CHECK_COLOR.g, CHECK_COLOR.b, 0.22)
	area.add_child(beam)
	# Gate posts + top crossbar.
	_rect(area, Vector2(-30, -250), Vector2(5, 250), CHECK_COLOR)
	_rect(area, Vector2(25, -250), Vector2(5, 250), CHECK_COLOR)
	_rect(area, Vector2(-30, -256), Vector2(60, 8), CHECK_COLOR)
	# Floating label.
	var lbl := Label.new()
	lbl.text = "CHECKPOINT"
	lbl.position = Vector2(-52, -288)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", CHECK_COLOR)
	area.add_child(lbl)

	add_child(area)
	var tw := beam.create_tween().set_loops()
	tw.tween_property(beam, "modulate:a", 0.45, 0.8)
	tw.tween_property(beam, "modulate:a", 1.0, 0.8)
	area.body_entered.connect(_on_checkpoint_entered.bind(index, pos, beam, lbl))


func _on_checkpoint_entered(body: Node, index: int, pos: Vector2, beam: ColorRect, lbl: Label) -> void:
	if body is LocalPlayer:
		beam.color = Color(CHECK_GOLD.r, CHECK_GOLD.g, CHECK_GOLD.b, 0.4)
		lbl.text = "✓ CLEARED"
		lbl.add_theme_color_override("font_color", CHECK_GOLD)
		checkpoint_reached.emit(index, pos)


# ----------------------------------------------------------------------------- finish
func _add_finish(pos: Vector2) -> void:
	var area := Area2D.new()
	area.position = pos
	area.collision_layer = 0
	area.collision_mask = L_PLAYER
	area.monitorable = false
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(60, 280)
	shape.shape = rs
	shape.position = Vector2(0, -120)
	area.add_child(shape)
	# Beam + posts + checkered banner + label.
	var beam := ColorRect.new()
	beam.size = Vector2(26, 300)
	beam.position = Vector2(-13, -300)
	beam.color = Color(FINISH_COLOR.r, FINISH_COLOR.g, FINISH_COLOR.b, 0.22)
	area.add_child(beam)
	_rect(area, Vector2(-34, -280), Vector2(6, 280), FINISH_COLOR)
	_rect(area, Vector2(28, -280), Vector2(6, 280), FINISH_COLOR)
	for n in range(12):
		var c := ColorRect.new()
		c.size = Vector2(11, 11)
		c.position = Vector2(-28 + (n % 2) * 11, -276 + (n / 2) * 11)
		c.color = FINISH_COLOR if (n + n / 2) % 2 == 0 else Color(0.05, 0.05, 0.05)
		area.add_child(c)
	var lbl := Label.new()
	lbl.text = "FINISH"
	lbl.position = Vector2(-30, -300)
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", FINISH_COLOR)
	area.add_child(lbl)
	area.body_entered.connect(_on_finish_entered)
	add_child(area)


func _on_finish_entered(body: Node) -> void:
	if body is LocalPlayer:
		finish_reached.emit()


# ----------------------------------------------------------------------------- helper
func _rect(parent: Node, pos: Vector2, size: Vector2, color: Color) -> void:
	var cr := ColorRect.new()
	cr.position = pos
	cr.size = size
	cr.color = color
	parent.add_child(cr)
