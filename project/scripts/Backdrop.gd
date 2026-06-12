extends RefCounted
## Builds a stage's backdrop as a set of independent DEPTH LAYERS (2.5D parallax): each layer is
## a baked texture that Main mounts in a ParallaxLayer with its own motion_scale, so distant
## things (sky/moon) barely move while nearer building rows scroll progressively faster. The
## compositions mirror the approved per-stage art. Currently provides the "city" theme (the neon
## night metropolis used by the existing courses); further themes plug in the same way.
##
## build(theme, level_w, view_w, view_h) -> {
##   "sky":   Image,                       # static full-viewport gradient (no parallax)
##   "layers":[ {image:Image, motion:float, top:float} ... ],  # back -> front
## }
## A layer's sprite is placed at world x=0; `top` is its world-y top (sky bodies float high,
## building rows are bottom-anchored to the horizon by Main).

const WARM := Color8(255, 196, 92)
const COOL := Color8(120, 230, 240)
const MAG := Color8(255, 120, 200)
const CYAN := Color8(60, 240, 255)
const SKY_TINT := Color8(24, 16, 44)   # far buildings haze toward this

var _img: Image
var _w: int
var _h: int


func build(theme: String, level_w: float, view_w: int, view_h: int) -> Dictionary:
	match theme:
		_:
			return _build_city(level_w, view_w, view_h)


# ---------------------------------------------------------------- city theme
func _build_city(level_w: float, view_w: int, view_h: int) -> Dictionary:
	var sky := _fresh(view_w, view_h)
	_city_sky()

	# moon + stars: nearly fixed (distant) -> tiny motion_scale
	var moon_w := int(level_w * 0.05) + view_w + 80
	var moon := _fresh(moon_w, 460)
	_city_moonstars()

	# four building rows, back -> front, each its own image (bottom-anchored by Main)
	var far := _fresh(int(level_w * 0.12) + view_w + 80, 720)
	_city_band(480, 60, 170, 34, 80, Color8(15, 14, 30), Color8(22, 18, 40), 0.55, 0.16, [COOL, WARM], 0.82, 0.0, 11, false)

	var mid_far := _fresh(int(level_w * 0.22) + view_w + 80, 720)
	_city_band(548, 110, 270, 48, 104, Color8(15, 14, 32), Color8(24, 18, 42), 0.40, 0.26, [COOL, WARM, MAG], 0.70, 0.06, 23, true)

	var mid := _fresh(int(level_w * 0.40) + view_w + 80, 720)
	_city_band(628, 170, 380, 64, 130, Color8(17, 15, 35), Color8(27, 20, 48), 0.20, 0.40, [WARM, COOL, WARM, MAG], 0.62, 0.16, 37, true)
	_city_spires()

	var near := _fresh(int(level_w * 0.62) + view_w + 80, 720)
	_city_band(720, 200, 470, 84, 168, Color8(18, 16, 38), Color8(30, 21, 52), 0.06, 0.50, [WARM, COOL, WARM, MAG], 0.58, 0.22, 53, true)
	_city_landmarks()

	return {
		"sky": sky,
		"layers": [
			{"image": moon, "motion": 0.04, "top": -150.0, "anchor_bottom": false},
			{"image": far, "motion": 0.12, "top": 0.0, "anchor_bottom": true},
			{"image": mid_far, "motion": 0.22, "top": 0.0, "anchor_bottom": true},
			{"image": mid, "motion": 0.40, "top": 0.0, "anchor_bottom": true},
			{"image": near, "motion": 0.62, "top": 0.0, "anchor_bottom": true},
		],
	}


func _city_sky() -> void:
	var top := Color8(7, 8, 22)
	var horizon := Color8(24, 16, 44)
	for y in range(_h):
		var row := top.lerp(horizon, pow(float(y) / float(_h), 1.3))
		for x in range(_w):
			_img.set_pixel(x, y, row)


func _city_moonstars() -> void:
	var center := Vector2(1012, 240)
	for i in range(int(_w * 0.14)):
		var sx := int(_hash(i * 7 + 1) * _w)
		var sy := int(_hash(i * 13 + 3) * (_h - 60))
		if Vector2(sx, sy).distance_to(center) < 120.0:
			continue
		var b := 0.45 + _hash(i * 5) * 0.5
		var sz := 1 if _hash(i * 3) < 0.85 else 2
		_rect(sx, sy, sz, sz, Color(b, b, b * 1.08, 0.9))
	var warm := Color(1.0, 0.94, 0.80)
	for k in range(14, 0, -1):
		_disc(center, 64.0 * (1.0 + float(k) * 0.16), Color(warm.r, warm.g, warm.b, 0.028))
	_disc(center, 64.0 * 1.12, Color(warm.r, warm.g, warm.b, 0.14))
	_disc(center, 64.0, Color8(246, 234, 198))
	_disc(center + Vector2(9, 7), 55.0, Color(0.91, 0.86, 0.73, 0.45))
	_disc(center + Vector2(-22, -14), 9.0, Color(0.88, 0.83, 0.70, 0.5))
	_disc(center + Vector2(16, 20), 6.0, Color(0.88, 0.83, 0.70, 0.5))


func _city_spires() -> void:
	# a couple of lattice broadcast towers along the length
	var x := 182.0
	while x < float(_w):
		_spire(Vector2(x, 556), 116.0)
		x += 3400.0 + _hash(int(x)) * 900.0


func _spire(base: Vector2, base_w: float) -> void:
	var steel := Color8(54, 60, 88)
	var steel_lit := Color8(78, 86, 120)
	var tip := base + Vector2(0, -440)
	var half_b := base_w * 0.5
	_line(Vector2(base.x - half_b, base.y), Vector2(tip.x - 4.0, tip.y), steel, 2)
	_line(Vector2(base.x + half_b, base.y), Vector2(tip.x + 4.0, tip.y), steel, 2)
	var segs := 13
	for i in range(segs + 1):
		var t := float(i) / float(segs)
		var t2 := float(i + 1) / float(segs)
		var ly := lerpf(base.y, tip.y, t)
		var lw := lerpf(half_b, 4.0, t)
		var lw2 := lerpf(half_b, 4.0, t2)
		var ly2 := lerpf(base.y, tip.y, t2)
		_line(Vector2(base.x - lw, ly), Vector2(base.x + lw, ly), steel, 1)
		if i < segs:
			_line(Vector2(base.x - lw, ly), Vector2(base.x + lw2, ly2), steel_lit, 1)
			_line(Vector2(base.x + lw, ly), Vector2(base.x - lw2, ly2), steel_lit, 1)
	_disc(Vector2(base.x, tip.y + 150), 16.0, steel)
	_disc(Vector2(base.x, tip.y + 150), 11.0, Color8(40, 44, 66))
	_disc(tip, 5.0, Color8(255, 70, 70))
	_disc(tip, 9.0, Color(1.0, 0.27, 0.27, 0.35))


func _city_band(base_y: float, hmin: int, hmax: int, wmin: int, wmax: int, fa: Color, fb: Color, haze: float, dens: float, pal: Array, step_frac: float, neon_p: float, seed: int, feat: bool) -> void:
	var x := -90.0
	var i := 0
	while x < _w + 90:
		var s := seed * 1000 + i
		var e := _envelope(x + float(seed) * 140.0)
		var bw := int(wmin + _hash(s * 9 + 2) * (wmax - wmin))
		var bh := clampi(int((hmin + e * (hmax - hmin)) * (0.78 + _hash(s * 5 + 7) * 0.5)), hmin, int(hmax * 1.15))
		var byt := int(base_y) - bh
		var fill := fa.lerp(fb, _hash(s * 4)).lerp(SKY_TINT, haze)
		_rect(int(x), byt, bw, _h - byt, fill)
		_rect(int(x) + int(bw * 0.62), byt, int(bw * 0.38), _h - byt, Color(0, 0, 0, 0.16 * (1.0 - haze)))
		if feat:
			_roof(int(x), byt, bw, fill, s, haze)
		_windows(int(x), byt, bw, _h - byt, s, dens * (1.0 - haze * 0.55), pal, 1.0 - haze * 0.65)
		if _hash(s * 21) < neon_p:
			var ne: Color = CYAN if _hash(s * 13) < 0.6 else MAG
			_rect(int(x), byt - 2, bw, 3, Color(ne.r, ne.g, ne.b, 0.8 * (1.0 - haze * 0.5)))
			_rect(int(x), byt - 7, bw, 6, Color(ne.r, ne.g, ne.b, 0.16))
		x += maxf(bw * step_frac, 16.0)
		i += 1


func _windows(bx: int, by: int, bw: int, bh: int, seedn: int, density: float, palette: Array, amul := 1.0) -> void:
	var step := 11
	var cols := int((bw - 8) / step)
	var rows := int((bh - 10) / step)
	for cy in range(rows):
		for cx in range(cols):
			var idx := seedn * 131 + cy * 17 + cx * 3
			if _hash(idx) > density:
				continue
			var col: Color = palette[int(_hash(idx * 2) * palette.size()) % palette.size()]
			var a := (0.45 + _hash(idx * 3) * 0.45) * amul
			_rect(bx + 6 + cx * step, by + 7 + cy * step, 5, 5, Color(col.r, col.g, col.b, a))


func _roof(x: int, byt: int, bw: int, fill: Color, seedn: int, haze: float) -> void:
	var cx := x + bw / 2
	var k := int(_hash(seedn * 7) * 5)
	if k == 1:
		var sw := int(bw * 0.52)
		_rect(cx - sw / 2, byt - 18, sw, 18, fill.lightened(0.06))
		_rect(cx - sw / 2, byt - 20, sw, 2, Color(0, 0, 0, 0.25))
	elif k == 2:
		var tw := mini(24, int(bw * 0.5))
		_rect(cx - tw / 2, byt - 16, tw, 12, Color8(34, 32, 50))
		_rect(cx - tw / 2, byt - 16, tw, 3, Color8(54, 52, 72))
	elif k == 3 and haze < 0.3:
		_rect(cx, byt - 30, 2, 30, Color8(70, 74, 96))
		_rect(cx - 1, byt - 34, 4, 4, Color8(255, 70, 70))


func _city_landmarks() -> void:
	# distinct accent towers distributed (not repeated) across the near-layer width
	var kinds := ["teal", "amber", "twins", "billboard"]
	var x := 412.0
	var n := 0
	while x < float(_w):
		match kinds[n % kinds.size()]:
			"teal": _lm_teal(int(x))
			"amber": _lm_amber(int(x))
			"twins": _lm_twins(int(x))
			"billboard": _lm_billboard(int(x))
		x += 1900.0 + _hash(n * 17) * 1100.0
		n += 1


func _lm_teal(bx: int) -> void:
	var bw := 122
	var byt := 720 - 442
	_rect(bx, byt, bw, _h - byt, Color8(15, 30, 40))
	_windows(bx, byt, bw, _h - byt, 7771, 0.80, [COOL, COOL, WARM])
	_rect(bx + bw / 2 - 2, byt, 4, _h - byt, Color(COOL.r, COOL.g, COOL.b, 0.5))
	_rect(bx, byt - 2, bw, 3, Color(COOL.r, COOL.g, COOL.b, 0.9))


func _lm_amber(bx: int) -> void:
	var bw := 92
	var byt := 720 - 488
	_rect(bx, byt, bw, _h - byt, Color8(26, 18, 16))
	_windows(bx, byt, bw, _h - byt, 7782, 0.30, [WARM])
	_windows(bx, byt, bw, 120, 7783, 0.95, [WARM])
	_rect(bx, byt - 2, bw, 3, Color(WARM.r, WARM.g, WARM.b, 0.95))


func _lm_twins(bx: int) -> void:
	for t in range(2):
		var tx := bx + t * 66
		var bh := 524 + t * 30
		var byt := 720 - bh
		_rect(tx, byt, 48, _h - byt, Color8(19, 18, 42))
		_windows(tx, byt, 48, _h - byt, 7790 + t, 0.5, [COOL, WARM])
		_rect(tx + 23, byt - 28, 2, 28, Color8(70, 74, 96))
		_rect(tx + 22, byt - 32, 4, 4, Color8(255, 70, 70))


func _lm_billboard(bx: int) -> void:
	var bw := 150
	var byt := 720 - 300
	_rect(bx, byt, bw, _h - byt, Color8(22, 18, 40))
	_windows(bx, byt, bw, _h - byt, 7795, 0.32, [WARM, MAG])
	_rect(bx + 24, byt + 30, 102, 54, Color(MAG.r, MAG.g, MAG.b, 0.28))
	_rect(bx + 24, byt + 28, 102, 3, Color(CYAN.r, CYAN.g, CYAN.b, 0.85))
	_rect(bx + 24, byt + 84, 102, 3, Color(CYAN.r, CYAN.g, CYAN.b, 0.85))


# ---------------------------------------------------------------- pixel helpers
func _fresh(w: int, h: int) -> Image:
	_w = w
	_h = h
	_img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	return _img


func _px(x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= _w or y >= _h:
		return
	if c.a >= 0.999:
		_img.set_pixel(x, y, c)
	else:
		var b := _img.get_pixel(x, y)
		_img.set_pixel(x, y, b.lerp(Color(c.r, c.g, c.b, 1.0), c.a))


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


func _line(a: Vector2, b: Vector2, c: Color, thick: int = 1) -> void:
	var steps := int(maxf(absf(b.x - a.x), absf(b.y - a.y))) + 1
	for i in range(steps + 1):
		var p := a.lerp(b, float(i) / float(steps))
		for oy in range(thick):
			for ox in range(thick):
				_px(int(p.x) + ox, int(p.y) + oy, c)


func _hash(n: int) -> float:
	var x := (n * 1103515245 + 12345) & 0x7fffffff
	x = (x ^ (x >> 13)) * 1274126177 & 0x7fffffff
	return float(x % 10000) / 10000.0


func _envelope(x: float) -> float:
	var a := 0.5 + 0.5 * sin(x * 0.0013)
	var b := 0.5 + 0.5 * sin(x * 0.0041 + 2.1)
	return clampf(0.30 + 0.5 * a + 0.28 * b - 0.08, 0.0, 1.0)
