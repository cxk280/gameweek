extends Control
class_name OpponentArrows
## Screen-edge markers pointing at off-screen opponents during a race. Each window's camera
## follows its own runner, so once players spread across the long level you'd otherwise never
## see the others — these arrows keep the multiplayer presence visible. Added under $HUD by Main,
## fed the local player + ghost dict each frame via update_for().

const MARGIN := 48.0          # inset from the screen edge where arrows sit
const PX_PER_M := 24.0        # world px -> "meters" for the distance label

var _arrows: Array = []       # [{pos:Vector2, ang:float, label:String, color:Color}]


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func update_for(local: Node2D, ghosts: Dictionary, vp: Viewport) -> void:
	_arrows.clear()
	if local != null and is_instance_valid(local) and not ghosts.is_empty():
		var xform := vp.get_canvas_transform()
		var size := vp.get_visible_rect().size
		var center := size * 0.5
		var half := center - Vector2(MARGIN, MARGIN)
		for id in ghosts:
			var g: Node2D = ghosts[id]
			if not is_instance_valid(g):
				continue
			var sp := xform * g.global_position
			if sp.x >= MARGIN and sp.x <= size.x - MARGIN and sp.y >= MARGIN and sp.y <= size.y - MARGIN:
				continue  # opponent is on screen — no marker needed
			var d := sp - center
			if d.length() < 1.0:
				continue
			var s := minf(half.x / maxf(absf(d.x), 0.001), half.y / maxf(absf(d.y), 0.001))
			var dx: float = g.global_position.x - local.global_position.x
			var meters := int(absf(dx) / PX_PER_M)
			var nm: String = str(g.get_meta("nm", "rival"))
			var label := "%s  %dm %s" % [nm, meters, "ahead" if dx >= 0.0 else "behind"]
			_arrows.append({
				"pos": center + d * s, "ang": d.angle(),
				"label": label, "color": g.get_meta("col", Color(0.2, 0.95, 1.0)),
			})
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	for a in _arrows:
		var pos: Vector2 = a["pos"]
		var ang: float = a["ang"]
		var col: Color = a["color"]
		var tri := PackedVector2Array([
			pos + Vector2(15, 0).rotated(ang),
			pos + Vector2(-11, -10).rotated(ang),
			pos + Vector2(-11, 10).rotated(ang),
		])
		draw_colored_polygon(tri, col)
		# Label below the arrow, pulled left so it stays on-screen at the right edge.
		draw_string(font, pos + Vector2(-30, 26), a["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.92))
