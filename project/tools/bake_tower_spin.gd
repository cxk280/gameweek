extends SceneTree
## Bakes a rotating-tower sprite sheet (N frames across) for the spire stage: a tapering stone
## cylinder with surface slit-windows and a glowing eye, painted as a pseudo-3D rotation so the
## game can swap frames by player progress to make the tower appear to turn. Transparent outside
## the cylinder so it composites over the stage backdrop.
##   godot --headless --path project --script res://tools/bake_tower_spin.gd -- --out=/abs/x.png

const N := 24
const FW := 360
const FH := 620
const LIGHT := -0.5

var img: Image


func _init() -> void:
	var out := "res://assets/tower_spin.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.split("=")[1]
	img = Image.create(FW * N, FH, false, Image.FORMAT_RGBA8)   # transparent
	for f in range(N):
		_frame(f * FW, TAU * float(f) / float(N))
	print("tower_spin baked: ok=%s frames=%d -> %s (%dx%d)" % [img.save_png(out) == OK, N, out, img.get_width(), FH])
	quit()


func _hash(n: int) -> float:
	var x := (n * 1103515245 + 12345) & 0x7fffffff
	x = (x ^ (x >> 13)) * 1274126177 & 0x7fffffff
	return float(x % 10000) / 10000.0


func _px(x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= FH:
		return
	if c.a >= 0.999:
		img.set_pixel(x, y, c)
	else:
		var b := img.get_pixel(x, y)
		img.set_pixel(x, y, b.lerp(Color(c.r, c.g, c.b, 1.0), c.a))


func _R(y: float) -> float:
	var t := clampf((y - 40.0) / float(FH - 40), 0.0, 1.0)
	return lerpf(90.0, 150.0, t)   # narrower at top, wider at base


func _frame(ox: float, theta: float) -> void:
	var cx := ox + FW * 0.5
	var dark := Color8(18, 16, 22)
	var lit := Color8(98, 92, 88)
	# body
	for y in range(40, FH):
		var r := _R(float(y))
		for x in range(int(cx - r), int(cx + r) + 1):
			var u := (float(x) - cx) / r
			var ang := asin(clampf(u, -1.0, 1.0))
			var b := clampf(0.16 + 0.84 * cos(ang - LIGHT), 0.10, 1.0)
			b *= 0.86 + 0.14 * _hash(x * 13 + y * 7)
			_px(x, y, dark.lerp(lit, b))
	# slit windows distributed over the cylinder, spiralling up; rotate with theta
	for i in range(46):
		var phi := _hash(i * 3 + 1) * TAU
		var hy := lerpf(70.0, FH - 60.0, _hash(i * 5 + 2))
		var hlen := 10.0 + _hash(i * 7) * 26.0
		var lit_col: Color = Color8(255, 168, 86) if _hash(i * 11) < 0.7 else Color8(120, 180, 235)
		for yy in range(int(hy), int(hy + hlen)):
			var a2 := phi + theta + yy * 0.012
			var depth := cos(a2)
			if depth <= 0.16:
				continue
			var r2 := _R(float(yy))
			var x := int(cx + sin(a2) * r2)
			var ww := maxi(1, int(2.0 * depth))
			_px(x - ww / 2, yy, Color(lit_col.r, lit_col.g, lit_col.b, 0.55 + 0.4 * depth))
	# glowing eye low on the shaft
	var ea := theta
	if cos(ea) > 0.12:
		var ey := FH - 150.0
		var ex := cx + sin(ea) * _R(ey)
		for ring in range(3):
			_disc(Vector2(ex, ey), 30.0 - ring * 9.0, Color(1.0, 0.12, 0.05, 0.22))
		_px(int(ex), int(ey), Color8(255, 60, 40))
		for dy in range(-8, 9):
			_px(int(ex), int(ey) + dy, Color8(255, 60, 40))
			_px(int(ex) - 1, int(ey) + dy, Color8(255, 60, 40))


func _disc(center: Vector2, r: float, c: Color) -> void:
	var r2 := r * r
	for yy in range(int(center.y - r), int(center.y + r) + 1):
		for xx in range(int(center.x - r), int(center.x + r) + 1):
			var dx := xx - center.x
			var dy := yy - center.y
			if dx * dx + dy * dy <= r2:
				_px(xx, yy, c)
