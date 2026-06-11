extends SceneTree
## Offline backdrop preview for the ascent stage: a single colossal tower modeled as a
## pseudo-3D rotating cylinder, with platforms spiralling around its exterior. As the player
## climbs, the cylinder rotates (camera orbits the column) so tower faces and platforms wrap
## front -> side -> behind. Headless Godot cannot capture live nodes, so the scene is painted
## into an Image. Modes:
##   --mode=base       1280x720  view at the tower's base (field + sky + start of the spiral)
##   --mode=ascent     1280x3600 the whole vertical climb, faces + platforms spiralling
##   --mode=turntable  six frames of one tower band at stepped rotation (shows the 3D spin)
##   godot --headless --path project --script res://tools/backdrop_stage6_tower.gd -- --mode=base --out=/abs/x.png

var W := 1280
var H := 720
var img: Image

const DARK := Color8(18, 16, 22)
const LIT := Color8(98, 92, 88)
const LIGHT := -0.5            # light direction (front-left) for cylinder shading
const EYE := Color8(255, 60, 40)
const WARMWIN := Color8(255, 168, 86)
const COLDWIN := Color8(120, 180, 235)

var cx := 640.0               # tower centre x
var t_bottom := 640.0         # tower base (y where it meets the field)
var t_top := 90.0             # tower summit
var r_base := 236.0
var r_top := 120.0
var spin := 0.0               # radians of cylinder rotation per pixel of height climbed
var phase := 0.0              # base rotation offset


func _init() -> void:
	var mode := "base"
	var out := "res://art_tower.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mode="):
			mode = a.split("=")[1]
		elif a.begins_with("--out="):
			out = a.split("=")[1]
	match mode:
		"ascent":
			_render_ascent(out)
		"turntable":
			_render_turntable(out)
		_:
			_render_base(out)
	quit()


# ---------------------------------------------------------------- modes
func _render_base(out: String) -> void:
	W = 1280
	H = 720
	cx = 640.0
	t_bottom = 648.0
	t_top = -260.0            # tower continues above the frame
	r_base = 238.0
	r_top = 150.0
	spin = 0.0
	phase = 0.35
	img = Image.create(W, H, false, Image.FORMAT_RGBA8)
	_sky(true)
	var plats := _build_platforms(7, 620.0, 60.0, 0.8)
	_draw_back_platforms(plats)
	_draw_tower()
	_draw_features(58)
	_draw_front_platforms(plats)
	_field(632)
	_save(out, "base")


func _render_ascent(out: String) -> void:
	W = 1280
	H = 3600
	cx = 640.0
	t_bottom = float(H) - 70.0
	t_top = 90.0
	r_base = 250.0
	r_top = 96.0
	spin = 0.0019                     # ~ a few revolutions over the full climb
	phase = 0.2
	img = Image.create(W, H, false, Image.FORMAT_RGBA8)
	_sky(true)
	var plats := _build_platforms(34, t_bottom - 110.0, (t_bottom - t_top - 200.0) / 34.0, 0.72)
	_draw_back_platforms(plats)
	_draw_tower()
	_draw_features(150)
	_draw_front_platforms(plats)
	_field(float(H) - 86)
	_save(out, "ascent")


func _render_turntable(out: String) -> void:
	# Six frames of one tower band at stepped rotation, tiled horizontally.
	var frames := 6
	var fw := 320
	var fh := 540
	var pad := 10
	W = frames * fw + (frames + 1) * pad
	H = fh + 2 * pad
	img = Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color8(14, 14, 20))
	for f in range(frames):
		_render_turntable_frame(f, fw, fh, pad + f * (fw + pad), pad)
	_save(out, "turntable")


func _render_turntable_frame(f: int, fw: int, fh: int, ox: int, oy: int) -> void:
	# isolated mini-render then blit into the strip
	var sub := Image.create(fw, fh, false, Image.FORMAT_RGBA8)
	var prev := img
	var pW := W
	var pH := H
	img = sub
	W = fw
	H = fh
	cx = float(fw) * 0.5
	t_bottom = float(fh) + 60.0
	t_top = -60.0
	r_base = 118.0
	r_top = 118.0
	spin = 0.0
	phase = float(f) / 6.0 * TAU      # the rotation step
	_sky(false)
	var plats := _build_platforms(3, float(fh) - 120.0, 150.0, 0.0)  # platforms at one ring, stepping with phase
	_draw_back_platforms(plats)
	_draw_tower()
	_draw_features(22)
	_draw_front_platforms(plats)
	# restore + blit
	img = prev
	W = pW
	H = pH
	img.blit_rect(sub, Rect2i(0, 0, fw, fh), Vector2i(ox, oy))


# ---------------------------------------------------------------- pixel helpers
func _px(x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= W or y >= H:
		return
	if c.a >= 0.999:
		img.set_pixel(x, y, c)
	else:
		var b := img.get_pixel(x, y)
		img.set_pixel(x, y, b.lerp(Color(c.r, c.g, c.b, 1.0), c.a))


func _rect(x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			_px(xx, yy, c)


func _disc(center: Vector2, r: float, c: Color) -> void:
	var r2 := r * r
	for yy in range(int(center.y - r), int(center.y + r) + 1):
		for xx in range(int(center.x - r), int(center.x + r) + 1):
			var dx := xx - center.x
			var dy := yy - center.y
			if dx * dx + dy * dy <= r2:
				_px(xx, yy, c)


func _h(n: int) -> float:
	var x := (n * 1103515245 + 12345) & 0x7fffffff
	x = (x ^ (x >> 13)) * 1274126177 & 0x7fffffff
	return float(x % 10000) / 10000.0


# ---------------------------------------------------------------- tower geometry
func _R(y: float) -> float:
	var t := clampf(inverse_lerp(t_bottom, t_top, y), 0.0, 1.0)
	return lerpf(r_base, r_top, t)


func _theta(y: float) -> float:
	return phase + (t_bottom - y) * spin


func _edge_noise(y: float, side: int) -> float:
	var n := 7.0 * sin(y * 0.05 + side * 2.3) + 4.0 * sin(y * 0.131 + side * 1.1)
	n += 6.0 * _h(int(y) * 7 + side * 131)
	# occasional larger crag
	if _h(int(y / 14.0) * 17 + side) > 0.93:
		n += 16.0
	return maxf(n, 0.0)


func _shade(u: float, x: int, y: int) -> Color:
	var ang := asin(clampf(u, -1.0, 1.0))
	var b := cos(ang - LIGHT)
	b = clampf(0.16 + 0.84 * b, 0.10, 1.0)
	# rocky speckle + vertical fissures
	b *= 0.86 + 0.14 * _h(x * 13 + y * 7)
	if _h(int(u * 9.0) + y * 3) > 0.86:
		b *= 0.7
	return DARK.lerp(LIT, b)


func _draw_tower() -> void:
	var y0 := int(maxf(t_top - 120.0, 0.0))
	var y1 := int(minf(t_bottom, float(H)))
	for y in range(y0, y1):
		var fy := float(y)
		var r := _R(fy)
		if r <= 1.0:
			continue
		var nl := _edge_noise(fy, 1)
		var nr := _edge_noise(fy, 2)
		var lx := int(cx - r - nl)
		var rx := int(cx + r + nr)
		for x in range(lx, rx):
			var u := (float(x) - cx) / r
			_px(x, y, _shade(u, x, y))
	_spires()
	_buttress_base()


func _spires() -> void:
	# jagged crown of thin tapering spires above the summit
	var n := 5
	for i in range(n):
		var sx := cx + lerpf(-_R(t_top) * 0.7, _R(t_top) * 0.7, float(i) / float(n - 1))
		sx += (_h(i * 31) - 0.5) * 26.0
		var sh := 70.0 + _h(i * 17) * 120.0
		var sw := 7.0 + _h(i * 13) * 8.0
		var top := t_top - sh
		for y in range(int(top), int(t_top)):
			var t := inverse_lerp(top, t_top, float(y))
			var hw := int(lerpf(1.0, sw, t))
			_rect(int(sx) - hw, y, hw * 2, 1, DARK.lerp(LIT, 0.18 + 0.2 * t))


func _buttress_base() -> void:
	# the tower flares into a gnarled root where it meets the ground
	var by := t_bottom
	for y in range(int(by - 120.0), int(by)):
		var t := inverse_lerp(by - 120.0, by, float(y))
		var flare := lerpf(0.0, 120.0, t * t)
		var r := _R(float(y))
		_rect(int(cx - r - flare), y, int((r + flare) * 2.0), 1, DARK.lerp(Color8(10, 8, 12), 0.3))
		# re-light the front so it doesn't read flat
		for x in range(int(cx - r), int(cx + r)):
			var u := (float(x) - cx) / r
			_px(x, y, _shade(u, x, y).darkened(0.12 * t))


# ---------------------------------------------------------------- surface features
func _draw_features(count: int) -> void:
	# slit windows distributed over the cylinder; spiral with rotation
	for i in range(count):
		var phi := _h(i * 3 + 1) * TAU
		var hy := lerpf(t_top + 40.0, t_bottom - 150.0, _h(i * 5 + 2))
		var hlen := 10.0 + _h(i * 7) * 26.0
		var lit: Color = WARMWIN if _h(i * 11) < 0.7 else COLDWIN
		for yy in range(int(hy), int(hy + hlen)):
			if yy < 0 or yy >= H:
				continue
			var ang := phi + _theta(float(yy))
			var depth := cos(ang)
			if depth <= 0.16:
				continue
			var u := sin(ang)
			var x := int(cx + u * _R(float(yy)))
			var ww := maxi(1, int(2.0 * depth))
			var a := 0.55 + 0.4 * depth
			_rect(x - ww / 2, yy, ww, 1, Color(lit.r, lit.g, lit.b, a))
	_red_eye()


func _red_eye() -> void:
	# the signature glowing eye-window, low on the shaft
	var phi := phase + 0.0
	var ey := t_bottom - 150.0
	var ang := phi + _theta(ey)
	if cos(ang) <= 0.1:
		return
	var x := cx + sin(ang) * _R(ey)
	_disc(Vector2(x, ey), 46.0, Color(1.0, 0.1, 0.05, 0.16))
	_disc(Vector2(x, ey), 26.0, Color(1.0, 0.12, 0.05, 0.28))
	_disc(Vector2(x, ey), 11.0, Color(1.0, 0.25, 0.1, 0.85))
	_rect(int(x) - 3, int(ey) - 9, 6, 18, EYE)


# ---------------------------------------------------------------- spiral platforms
func _build_platforms(n: int, y_start: float, vstep: float, dphi: float) -> Array:
	var out: Array = []
	for k in range(n):
		var y := y_start - float(k) * vstep
		var phi := float(k) * dphi
		out.append({"y": y, "phi": phi, "k": k})
	return out


func _plat_screen(p: Dictionary) -> Dictionary:
	var y: float = p["y"]
	var ang: float = p["phi"] + _theta(y)
	var depth := cos(ang)
	var u := sin(ang)
	var x := cx + u * _R(y)
	return {"x": x, "y": y, "depth": depth}


func _draw_platform(p: Dictionary, front: bool) -> void:
	var s := _plat_screen(p)
	var depth: float = s["depth"]
	if front and depth < 0.0:
		return
	if not front and depth >= 0.0:
		return
	var x: float = s["x"]
	var y: float = s["y"]
	var vis := absf(depth)                       # foreshorten width near the silhouette
	var pw := int(lerpf(34.0, 116.0, vis))
	var stone := Color8(54, 50, 56).lerp(Color8(96, 90, 92), 0.2 + 0.6 * vis)
	if not front:
		stone = stone.darkened(0.4)              # behind the tower: dimmer
	_rect(int(x) - pw / 2, int(y), pw, 12, stone)
	_rect(int(x) - pw / 2, int(y), pw, 3, stone.lightened(0.25))      # lit top edge (readability)
	_rect(int(x) - pw / 2, int(y) + 12, pw, 4, Color(0, 0, 0, 0.35))  # underside shadow
	if front and vis > 0.5:
		# a small marker post on prominent front platforms
		_rect(int(x) + pw / 2 - 6, int(y) - 16, 2, 16, Color8(120, 120, 140))
		_rect(int(x) + pw / 2 - 9, int(y) - 18, 6, 4, Color(0.2, 1.0, 0.5, 0.9))


func _draw_back_platforms(plats: Array) -> void:
	for p in plats:
		_draw_platform(p, false)


func _draw_front_platforms(plats: Array) -> void:
	for p in plats:
		_draw_platform(p, true)


# ---------------------------------------------------------------- sky + ground
func _sky(dramatic: bool) -> void:
	# blue high up -> warm gold/orange near the horizon (ominous sunset)
	var top := Color8(40, 70, 120)
	var mid := Color8(120, 120, 150)
	var horizon := Color8(232, 150, 70)
	for y in range(H):
		var t := float(y) / float(H)
		var row: Color
		if t < 0.55:
			row = top.lerp(mid, t / 0.55)
		else:
			row = mid.lerp(horizon, (t - 0.55) / 0.45)
		for x in range(W):
			img.set_pixel(x, y, row)
	if dramatic:
		_clouds()


func _clouds() -> void:
	var band := int(H * 0.10)
	for i in range(6):
		var cxp := _h(i * 23 + 3) * W
		var cyp := band + _h(i * 17) * (H * 0.22)
		var s := 18.0 + _h(i * 7) * 22.0
		for k in range(5):
			var ox := (k - 2) * s * 0.8
			var oy := absf(float(k - 2)) * s * 0.2
			_disc(Vector2(cxp + ox, cyp + oy), s * (1.0 - absf(float(k - 2)) * 0.12), Color(0.95, 0.95, 0.97, 0.9))


func _field(y0: float) -> void:
	# glowing red field of roses at the tower's foot
	for y in range(int(y0), H):
		var t := inverse_lerp(y0, float(H), float(y))
		var col := Color8(150, 20, 24).lerp(Color8(220, 30, 30), t)
		for x in range(W):
			_px(x, y, col)
	# red glow rising up the base of the shaft
	_disc(Vector2(cx, y0), 150.0, Color(1.0, 0.1, 0.1, 0.10))
	# rose speckle
	for i in range(int(W * 0.5)):
		var x := _h(i * 5 + 1) * W
		var y := lerpf(y0, float(H), 0.2 + _h(i * 3) * 0.8)
		_rect(int(x), int(y), 2, 2, Color(1.0, 0.4, 0.4, 0.5))


func _save(out: String, label: String) -> void:
	var err := img.save_png(out)
	print("tower %s saved: ok=%s -> %s (%dx%d)" % [label, err == OK, out, W, H])
