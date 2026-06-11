extends SceneTree
## Offline backdrop preview: paints a stage's night-city skyline backdrop into a single PNG so
## the art direction can be inspected pixel-by-pixel without running the game (headless Godot
## cannot capture live nodes). The composition is authored in overlapping depth bands so the
## skyline reads as a city with depth (buildings in front of one another), with a non-repeating
## height envelope and curated landmarks so a long stage never looks tiled. These numbers port
## directly into the live per-stage backdrop builder.
##   godot --headless --path project --script res://tools/render_backdrop.gd -- --width=4800 --out=/abs/path.png

var W := 1280
var H := 720
var img: Image

const WARM := Color8(255, 196, 92)
const COOL := Color8(120, 230, 240)
const MAG := Color8(255, 120, 200)
const CYAN := Color8(60, 240, 255)
const VIOLET := Color8(170, 110, 255)
const GREEN := Color8(70, 235, 150)


func _init() -> void:
	var out := "res://art_backdrop_mock.png"
	var theme := "city"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--width="):
			W = int(a.split("=")[1])
		elif a.begins_with("--out="):
			out = a.split("=")[1]
		elif a.begins_with("--theme="):
			theme = a.split("=")[1]

	img = Image.create(W, H, false, Image.FORMAT_RGBA8)
	match theme:
		"town":
			_compose_town()
		_:
			_compose_city()

	var err := img.save_png(out)
	print("backdrop saved: ok=%s -> %s (%dx%d)" % [err == OK, out, W, H])
	quit()


# ---------------------------------------------------------------- compositions
func _compose_city() -> void:
	# Stage 1 — neon night metropolis. Overlapping depth bands + curated landmarks.
	_sky()
	_stars()
	_moon(Vector2(1012, 138), 64.0)               # parallax-fixed in game; shown in the start view
	_band(470, 60, 170, 34, 80, Color8(15, 14, 30), Color8(22, 18, 40), 0.62, 0.16, [COOL, WARM], 0.82, 0.0, 11, false)
	_band(548, 110, 270, 48, 104, Color8(15, 14, 32), Color8(24, 18, 42), 0.40, 0.26, [COOL, WARM, MAG], 0.70, 0.06, 23, true)
	_band(628, 170, 380, 64, 130, Color8(17, 15, 35), Color8(27, 20, 48), 0.20, 0.40, [WARM, COOL, WARM, MAG], 0.62, 0.16, 37, true)
	_spire(Vector2(182, 556), 116.0)              # signature lattice broadcast tower
	_band(720, 200, 470, 84, 168, Color8(18, 16, 38), Color8(30, 21, 52), 0.06, 0.50, [WARM, COOL, WARM, MAG], 0.58, 0.22, 53, true)
	_landmarks()
	_foreground()


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


func _line(a: Vector2, b: Vector2, c: Color, thick: int = 1) -> void:
	var steps := int(maxf(absf(b.x - a.x), absf(b.y - a.y))) + 1
	for i in range(steps + 1):
		var p := a.lerp(b, float(i) / float(steps))
		for oy in range(thick):
			for ox in range(thick):
				_px(int(p.x) + ox, int(p.y) + oy, c)


# small deterministic hash -> 0..1
func _h(n: int) -> float:
	var x := (n * 1103515245 + 12345) & 0x7fffffff
	x = (x ^ (x >> 13)) * 1274126177 & 0x7fffffff
	return float(x % 10000) / 10000.0


# low-frequency, non-repeating skyline height envelope (downtown clusters + quieter stretches)
func _envelope(x: float) -> float:
	var a := 0.5 + 0.5 * sin(x * 0.0013)
	var b := 0.5 + 0.5 * sin(x * 0.0041 + 2.1)
	return clampf(0.30 + 0.5 * a + 0.28 * b - 0.08, 0.0, 1.0)


# ---------------------------------------------------------------- sky + sky bodies
func _sky() -> void:
	var top := Color8(7, 8, 22)
	var horizon := Color8(24, 16, 44)
	for y in range(H):
		var row := top.lerp(horizon, pow(float(y) / float(H), 1.3))
		for x in range(W):
			img.set_pixel(x, y, row)
	for y in range(470, 640):
		var a := (1.0 - absf(float(y) - 555.0) / 85.0) * 0.06
		if a > 0.0:
			_rect(0, y, W, 1, Color(0.55, 0.35, 0.30, a))


func _stars() -> void:
	var moon := Vector2(1012, 138)
	var n := int(W * 0.13)
	for i in range(n):
		var sx := int(_h(i * 7 + 1) * W)
		var sy := int(_h(i * 13 + 3) * 450.0)
		if Vector2(sx, sy).distance_to(moon) < 130.0:
			continue
		var b := 0.45 + _h(i * 5) * 0.5
		var size := 1 if _h(i * 3) < 0.85 else 2
		_rect(sx, sy, size, size, Color(b, b, b * 1.08, 0.9))


func _moon(center: Vector2, r: float) -> void:
	var warm := Color(1.0, 0.94, 0.80)
	for k in range(14, 0, -1):
		_disc(center, r * (1.0 + float(k) * 0.16), Color(warm.r, warm.g, warm.b, 0.028))
	_disc(center, r * 1.12, Color(warm.r, warm.g, warm.b, 0.14))
	_disc(center, r, Color8(246, 234, 198))
	_disc(center + Vector2(9, 7), r * 0.86, Color(0.91, 0.86, 0.73, 0.45))
	_disc(center + Vector2(-22, -14), 9.0, Color(0.88, 0.83, 0.70, 0.5))
	_disc(center + Vector2(16, 20), 6.0, Color(0.88, 0.83, 0.70, 0.5))
	_disc(center + Vector2(-6, 26), 5.0, Color(0.88, 0.83, 0.70, 0.5))


# ---------------------------------------------------------------- signature: lattice spire
func _spire(base: Vector2, base_w: float) -> void:
	var steel := Color8(54, 60, 88)
	var steel_lit := Color8(78, 86, 120)
	var tip := base + Vector2(0, -440)
	var half_b := base_w * 0.5
	var top_half := 4.0
	_line(Vector2(base.x - half_b, base.y), Vector2(tip.x - top_half, tip.y), steel, 2)
	_line(Vector2(base.x + half_b, base.y), Vector2(tip.x + top_half, tip.y), steel, 2)
	var segs := 13
	for i in range(segs + 1):
		var t := float(i) / float(segs)
		var t2 := float(i + 1) / float(segs)
		var ly := lerpf(base.y, tip.y, t)
		var lw := lerpf(half_b, top_half, t)
		var lw2 := lerpf(half_b, top_half, t2)
		var ly2 := lerpf(base.y, tip.y, t2)
		_line(Vector2(base.x - lw, ly), Vector2(base.x + lw, ly), steel, 1)
		if i < segs:
			_line(Vector2(base.x - lw, ly), Vector2(base.x + lw2, ly2), steel_lit, 1)
			_line(Vector2(base.x + lw, ly), Vector2(base.x - lw2, ly2), steel_lit, 1)
	_disc(Vector2(base.x, tip.y + 150), 16.0, steel)
	_disc(Vector2(base.x, tip.y + 150), 11.0, Color8(40, 44, 66))
	_disc(tip, 5.0, Color8(255, 70, 70))
	_disc(tip, 9.0, Color(1.0, 0.27, 0.27, 0.35))
	_disc(Vector2(base.x, tip.y + 150), 3.0, Color8(255, 70, 70))


# ---------------------------------------------------------------- depth bands
func _windows(bx: int, by: int, bw: int, bh: int, seedn: int, density: float, palette: Array, amul := 1.0) -> void:
	var step := 11
	var cols := int((bw - 8) / step)
	var rows := int((bh - 10) / step)
	for cy in range(rows):
		for cx in range(cols):
			var idx := seedn * 131 + cy * 17 + cx * 3
			if _h(idx) > density:
				continue
			var col: Color = palette[int(_h(idx * 2) * palette.size()) % palette.size()]
			var a := (0.45 + _h(idx * 3) * 0.45) * amul
			_rect(bx + 6 + cx * step, by + 7 + cy * step, 5, 5, Color(col.r, col.g, col.b, a))


func _roof(x: int, byt: int, bw: int, fill: Color, seedn: int, haze: float) -> void:
	var cx := x + bw / 2
	var k := int(_h(seedn * 7) * 5)
	if k == 1:  # stepped setback (silhouette variety)
		var sw := int(bw * 0.52)
		_rect(cx - sw / 2, byt - 18, sw, 18, fill.lightened(0.06))
		_rect(cx - sw / 2, byt - 20, sw, 2, Color(0, 0, 0, 0.25))
	elif k == 2:  # water tank on legs
		var tw := mini(24, int(bw * 0.5))
		_rect(cx - tw / 2, byt - 6, 3, 6, Color8(40, 42, 60))
		_rect(cx + tw / 2 - 3, byt - 6, 3, 6, Color8(40, 42, 60))
		_rect(cx - tw / 2, byt - 16, tw, 12, Color8(34, 32, 50))
		_rect(cx - tw / 2, byt - 16, tw, 3, Color8(54, 52, 72))
	elif k == 3 and haze < 0.3:  # antenna + red tip
		_rect(cx, byt - 30, 2, 30, Color8(70, 74, 96))
		_rect(cx - 1, byt - 34, 4, 4, Color8(255, 70, 70))
	elif k == 4 and haze < 0.45:  # twin masts
		_rect(x + int(bw * 0.3), byt - 16, 2, 16, Color8(70, 74, 96))
		_rect(x + int(bw * 0.7), byt - 24, 2, 24, Color8(70, 74, 96))
		_rect(x + int(bw * 0.7) - 1, byt - 27, 3, 3, Color8(255, 70, 70))


func _band(base_y: float, hmin: int, hmax: int, wmin: int, wmax: int, fa: Color, fb: Color, haze: float, dens: float, pal: Array, step_frac: float, neon_p: float, seed: int, feat: bool) -> void:
	var sky := Color8(24, 16, 44)
	var x := -90.0
	var i := 0
	while x < W + 90:
		var s := seed * 1000 + i
		var e := _envelope(x + float(seed) * 140.0)
		var bw := int(wmin + _h(s * 9 + 2) * (wmax - wmin))
		var bh := clampi(int((hmin + e * (hmax - hmin)) * (0.78 + _h(s * 5 + 7) * 0.5)), hmin, int(hmax * 1.15))
		var byt := int(base_y) - bh
		var fill := fa.lerp(fb, _h(s * 4)).lerp(sky, haze)
		_rect(int(x), byt, bw, H - byt, fill)
		_rect(int(x) + int(bw * 0.62), byt, int(bw * 0.38), H - byt, Color(0, 0, 0, 0.16 * (1.0 - haze)))
		if feat:
			_roof(int(x), byt, bw, fill, s, haze)
		_windows(int(x), byt, bw, H - byt, s, dens * (1.0 - haze * 0.55), pal, 1.0 - haze * 0.65)
		if _h(s * 21) < neon_p:
			var ne: Color = CYAN if _h(s * 13) < 0.6 else MAG
			_rect(int(x), byt - 2, bw, 3, Color(ne.r, ne.g, ne.b, 0.8 * (1.0 - haze * 0.5)))
			_rect(int(x), byt - 7, bw, 6, Color(ne.r, ne.g, ne.b, 0.16))
		x += maxf(bw * step_frac, 16.0)
		i += 1


# ---------------------------------------------------------------- curated landmarks (no repeats)
func _landmarks() -> void:
	_teal_slab(1452)
	_amber_crown(2560)
	_twins(3430)
	_billboard(4230)


func _teal_slab(bx: int) -> void:
	var bw := 122
	var byt := 720 - 442
	_rect(bx, byt, bw, H - byt, Color8(15, 30, 40))
	_rect(bx + int(bw * 0.62), byt, int(bw * 0.38), H - byt, Color(0, 0, 0, 0.16))
	_windows(bx, byt, bw, H - byt, 7771, 0.80, [COOL, COOL, WARM])
	_rect(bx + bw / 2 - 2, byt, 4, H - byt, Color(COOL.r, COOL.g, COOL.b, 0.5))
	_rect(bx, byt - 2, bw, 3, Color(COOL.r, COOL.g, COOL.b, 0.9))
	_rect(bx, byt - 8, bw, 7, Color(COOL.r, COOL.g, COOL.b, 0.22))


func _amber_crown(bx: int) -> void:
	var bw := 92
	var byt := 720 - 488
	_rect(bx, byt, bw, H - byt, Color8(26, 18, 16))
	_rect(bx + int(bw * 0.62), byt, int(bw * 0.38), H - byt, Color(0, 0, 0, 0.16))
	_windows(bx, byt, bw, H - byt, 7782, 0.30, [WARM])
	_windows(bx, byt, bw, 120, 7783, 0.95, [WARM])  # fully-lit crown
	_rect(bx, byt - 2, bw, 3, Color(WARM.r, WARM.g, WARM.b, 0.95))
	_rect(bx, byt - 8, bw, 7, Color(WARM.r, WARM.g, WARM.b, 0.25))


func _twins(bx: int) -> void:
	# slender twin towers with a sky-bridge — a distinct downtown silhouette
	for t in range(2):
		var tx := bx + t * 66
		var bh := 524 + t * 30
		var byt := 720 - bh
		_rect(tx, byt, 48, H - byt, Color8(19, 18, 42))
		_rect(tx + 30, byt, 18, H - byt, Color(0, 0, 0, 0.18))
		_windows(tx, byt, 48, H - byt, 7790 + t, 0.5, [COOL, WARM])
		_rect(tx + 23, byt - 28, 2, 28, Color8(70, 74, 96))
		_rect(tx + 22, byt - 32, 4, 4, Color8(255, 70, 70))
	_rect(bx + 48, 720 - 360, 18, 10, Color8(40, 50, 70))  # sky-bridge


func _billboard(bx: int) -> void:
	var bw := 150
	var byt := 720 - 300
	_rect(bx, byt, bw, H - byt, Color8(22, 18, 40))
	_windows(bx, byt, bw, H - byt, 7795, 0.32, [WARM, MAG])
	# big neon billboard on the face
	_rect(bx + 24, byt + 30, 102, 54, Color8(20, 10, 24))
	_rect(bx + 24, byt + 30, 102, 54, Color(MAG.r, MAG.g, MAG.b, 0.28))
	_rect(bx + 24, byt + 28, 102, 3, Color(CYAN.r, CYAN.g, CYAN.b, 0.85))
	_rect(bx + 24, byt + 84, 102, 3, Color(CYAN.r, CYAN.g, CYAN.b, 0.85))
	_rect(bx + 34, byt + 44, 60, 6, Color(CYAN.r, CYAN.g, CYAN.b, 0.8))
	_rect(bx + 34, byt + 58, 82, 6, Color(WARM.r, WARM.g, WARM.b, 0.8))


# ---------------------------------------------------------------- play-field hint
func _foreground() -> void:
	# Nearest rooftop ledges in the live play-field style (dark fill + neon top edge), with
	# varied heights and gaps along the length to read as a long, varied stage. Gaps reveal
	# the layered city behind (depth).
	var fill := Color8(14, 17, 32)
	var fill2 := Color8(20, 22, 40)
	var edges := [CYAN, MAG, VIOLET, GREEN]
	var x := -40
	var i := 0
	while x < W + 40:
		var w := 200 + int(_h(i * 9 + 1) * 280)
		var top := 590 + int(_h(i * 5 + 2) * 74)
		var neon: Color = edges[i % edges.size()]
		_ledge(x, top, w, fill, fill2, neon)
		if _h(i * 4) < 0.5:  # antenna prop
			_rect(x + 40, top - 30, 3, 30, Color8(100, 105, 130))
			_rect(x + 39, top - 34, 5, 5, Color8(255, 70, 70))
		else:  # vent prop
			_rect(x + int(w * 0.5), top - 16, 26, 16, Color8(30, 33, 50))
			_rect(x + int(w * 0.5), top - 16, 26, 3, Color8(52, 56, 78))
		x += w + 64 + int(_h(i * 3) * 130)
		i += 1


func _ledge(x: int, top: int, w: int, fill: Color, fill2: Color, neon: Color) -> void:
	_rect(x, top, w, H - top, fill)
	_rect(x, top + (H - top) / 2, w, (H - top) / 2, fill2)
	_rect(x, top - 6, w, 8, Color(neon.r, neon.g, neon.b, 0.22))
	_rect(x, top, w, 3, neon)


# ================================================================ Stage 2 — dusk old town
const SKY_TOWN := Color(0.91, 0.79, 0.72)  # warm horizon haze used for atmospheric perspective


func _compose_town() -> void:
	# Tiled rooftops of a traditional old town at dusk, receding in overlapping depth bands,
	# warm lantern glow, with a distant tiered-tower landmark. Our own muted stylization.
	_sky_town()
	_hill_band()
	_tiered_tower(Vector2(660, 502), 1.85)
	if W > 2200:
		_tiered_tower(Vector2(2560, 496), 1.6)
	if W > 4200:
		_tiered_tower(Vector2(4320, 506), 1.9)
	_roof_band(470, 40, 90, 60, 120, Color8(120, 104, 96), Color8(140, 122, 110), Color8(150, 150, 165), 0.55, 0.10, 0.74, 12)
	_roof_band(540, 70, 150, 80, 150, Color8(96, 78, 66), Color8(120, 98, 82), Color8(120, 120, 140), 0.34, 0.22, 0.66, 24)
	_roof_band(620, 100, 210, 100, 175, Color8(78, 60, 48), Color8(104, 80, 62), Color8(96, 98, 118), 0.16, 0.34, 0.60, 36)
	_roof_band(720, 130, 270, 120, 200, Color8(66, 50, 40), Color8(92, 68, 52), Color8(80, 82, 102), 0.04, 0.42, 0.56, 52)
	_town_foreground()


func _sky_town() -> void:
	var top := Color8(150, 150, 174)
	var horizon := Color8(232, 202, 184)
	for y in range(H):
		var row := top.lerp(horizon, pow(float(y) / float(H), 1.6))
		for x in range(W):
			img.set_pixel(x, y, row)
	for y in range(360, 520):
		var a := (1.0 - absf(float(y) - 448.0) / 80.0) * 0.20
		if a > 0.0:
			_rect(0, y, W, 1, Color(1.0, 0.70, 0.45, a))


func _hill_band() -> void:
	# soft, hazy tree-covered ridge far behind the town
	var col := Color8(150, 146, 156)
	for x in range(W):
		var ridge := 452.0 - (20.0 + 16.0 * sin(x * 0.0042) + 9.0 * sin(x * 0.013 + 1.0))
		_rect(x, int(ridge), 1, 150, Color(col.r, col.g, col.b, 0.5))


func _trap(cx: int, top_y: int, top_w: int, bot_w: int, h: int, color: Color) -> void:
	for r in range(h + 1):
		var w := int(lerpf(float(top_w), float(bot_w), float(r) / float(h)))
		_rect(cx - w / 2, top_y + r, w, 1, color)


func _tiered_tower(pos: Vector2, scale: float) -> void:
	var sil := Color8(54, 46, 56)
	var tile := Color8(86, 80, 100)
	var ridge := Color8(170, 140, 120)
	var cx := int(pos.x)
	var y := int(pos.y)
	_rect(cx - int(72 * scale), y - 6, int(144 * scale), 8, sil)
	var bw := 118.0 * scale
	for tier in range(5):
		var body_w := int(bw * 0.5)
		var body_h := int(24 * scale)
		_rect(cx - body_w / 2, y - body_h, body_w, body_h, sil)
		_rect(cx - int(body_w * 0.16), y - body_h + int(body_h * 0.3), int(body_w * 0.32), int(body_h * 0.4), Color8(150, 86, 46))
		y -= body_h
		var roof_h := int(19 * scale)
		_trap(cx, y - roof_h, int(bw * 0.42), int(bw), roof_h, tile.lerp(SKY_TOWN, 0.2))
		_rect(cx - int(bw) / 2, y - 1, int(bw), 2, Color(ridge.r, ridge.g, ridge.b, 0.6))
		y -= roof_h
		bw *= 0.82
	# finial spire
	_rect(cx - 1, y - int(32 * scale), 2, int(32 * scale), Color8(140, 116, 80))
	for k in range(4):
		_disc(Vector2(cx, y - 4 - k * int(7 * scale)), 3.0 * scale, Color8(160, 132, 86))
	_disc(Vector2(cx, y - int(34 * scale)), 4.0 * scale, Color8(180, 150, 96))


func _lanterns(x: int, top: int, w: int, h: int, seed: int, density: float, haze: float) -> void:
	var step := 13
	var cols := int((w - 8) / step)
	var rows := int((h - 8) / step)
	var amber := Color8(255, 186, 96)
	for cy in range(rows):
		for cx in range(cols):
			var idx := seed * 97 + cy * 13 + cx * 5
			if _h(idx) > density:
				continue
			var a := (0.55 + _h(idx * 3) * 0.4) * (1.0 - haze * 0.7)
			var wx := x + 6 + cx * step
			var wy := top + 6 + cy * step
			_rect(wx - 2, wy - 2, 10, 10, Color(amber.r, amber.g, amber.b, a * 0.22))
			_rect(wx, wy, 6, 6, Color(amber.r, amber.g, amber.b, a))


func _house(x: int, base_y: int, w: int, h: int, wood: Color, tile: Color, haze: float, lantern_d: float, seed: int) -> void:
	var roof_h := int(h * 0.46)
	var wall_h := h - roof_h
	var wall_top := base_y - wall_h
	var roof_top := wall_top - roof_h
	var w2 := wood.lerp(SKY_TOWN, haze)
	var t2 := tile.lerp(SKY_TOWN, haze)
	_rect(x, wall_top, w, wall_h, w2)
	_rect(x, wall_top, w, 3, Color(0, 0, 0, 0.25 * (1.0 - haze)))
	_lanterns(x, wall_top, w, wall_h, seed, lantern_d, haze)
	_trap(x + w / 2, roof_top, int(w * 0.5), int(w * 1.16), roof_h, t2)
	for r in range(1, 3):
		_rect(x - int(w * 0.05), roof_top + int(roof_h * float(r) / 3.0), int(w * 1.1), 1, Color(0, 0, 0, 0.12 * (1.0 - haze)))
	_rect(x + int(w * 0.25), roof_top, int(w * 0.5), 2, Color(0.9, 0.84, 0.8, 0.4 * (1.0 - haze)))


func _roof_band(base_y: float, hmin: int, hmax: int, wmin: int, wmax: int, wood_a: Color, wood_b: Color, tile: Color, haze: float, lantern_d: float, step_frac: float, seed: int) -> void:
	var x := -80.0
	var i := 0
	while x < W + 80:
		var s := seed * 1000 + i
		var e := _envelope(x + float(seed) * 120.0)
		var w := int(wmin + _h(s * 9 + 2) * (wmax - wmin))
		var h := clampi(int((hmin + e * (hmax - hmin)) * (0.82 + _h(s * 5 + 7) * 0.4)), hmin, int(hmax * 1.1))
		var wood := wood_a.lerp(wood_b, _h(s * 4))
		_house(int(x), int(base_y), w, h, wood, tile, haze, lantern_d * (1.0 - haze * 0.4), s)
		x += maxf(w * step_frac, 14.0)
		i += 1


func _town_foreground() -> void:
	var fill := Color8(40, 38, 46)
	var fill2 := Color8(30, 28, 36)
	var edge := Color8(255, 180, 90)
	var x := -40
	var i := 0
	while x < W + 40:
		var w := 200 + int(_h(i * 9 + 1) * 280)
		var top := 596 + int(_h(i * 5 + 2) * 66)
		_rect(x, top, w, H - top, fill)
		_rect(x, top + (H - top) / 2, w, (H - top) / 2, fill2)
		for r in range(1, 4):
			_rect(x, top + r * 8, w, 1, Color(0, 0, 0, 0.18))
		_rect(x, top - 6, w, 8, Color(edge.r, edge.g, edge.b, 0.22))
		_rect(x, top, w, 3, edge)
		var lx := x + 40
		_rect(lx, top - 22, 1, 12, Color8(60, 40, 30))
		_disc(Vector2(lx, top - 26), 5.0, Color(1.0, 0.7, 0.4, 0.3))
		_disc(Vector2(lx, top - 26), 3.0, Color8(255, 170, 90))
		x += w + 64 + int(_h(i * 3) * 130)
		i += 1
