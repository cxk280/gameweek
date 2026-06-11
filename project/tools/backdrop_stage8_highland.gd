extends SceneTree
## Offline backdrop preview for a bright daytime highland-capital stage. Paints a flat
## pixel-vector skyline into a single PNG so the art direction can be inspected pixel-by-pixel
## without running the game (headless Godot cannot capture live nodes). Composition is authored
## in overlapping far->near depth bands with atmospheric haze on distant ranges, a non-repeating
## height envelope, and curated non-repeating landmarks so a long stage never looks tiled.
##   godot --headless --path project --script res://tools/backdrop_stage8_highland.gd -- --width=4800 --out=/abs/path.png

var W := 1280
var H := 720
var img: Image

# ---- daytime dry-highland palette (flat, chunky, low-saturation) ----
const SKY_TOP := Color8(74, 142, 206)      # clear dry highland blue (upper)
const SKY_HORIZON := Color8(196, 220, 234) # pale warm haze at horizon
const CLOUD := Color8(248, 250, 252)
const SUN := Color8(255, 248, 224)

# arid mountains (far->near get darker/less hazy)
const MTN_FAR := Color8(150, 158, 150)
const MTN_MID := Color8(150, 140, 116)
const MTN_NEAR := Color8(138, 120, 90)

# buildings
const CREAM := Color8(238, 232, 218)
const WHITE := Color8(246, 246, 242)
const PALE := Color8(214, 208, 196)
const GLASS := Color8(150, 186, 206)       # glass-blue facade
const GLASS_LIT := Color8(196, 218, 230)
const STONE := Color8(224, 214, 196)       # colonial pale stone

# accents
const TERRACOTTA := Color8(186, 86, 58)    # red tiled roofs
const TERRA_LIT := Color8(212, 110, 78)
const TREE := Color8(74, 122, 64)
const TREE_DK := Color8(56, 98, 50)
const PALM := Color8(82, 134, 70)
const WINDOW_DK := Color8(120, 130, 138)   # window glass on pale facades (daylight)


func _init() -> void:
	var out := "res://backdrop_stage8.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--width="):
			W = int(a.split("=")[1])
		elif a.begins_with("--out="):
			out = a.split("=")[1]

	img = Image.create(W, H, false, Image.FORMAT_RGBA8)
	_compose()

	var err := img.save_png(out)
	print("backdrop saved: ok=%s -> %s (%dx%d)" % [err == OK, out, W, H])
	quit()


# ---------------------------------------------------------------- composition
func _compose() -> void:
	_sky()
	_clouds()
	# distant arid ranges: far (most haze) -> near (least), darker + lower each step
	_range(326.0, MTN_FAR, 0.62, 0.0048, 0.012, 30.0, 12.0, 101)
	_range(352.0, MTN_FAR.lerp(MTN_MID, 0.5), 0.44, 0.0039, 0.010, 40.0, 16.0, 211)
	_range(380.0, MTN_MID, 0.26, 0.0031, 0.009, 52.0, 22.0, 307)
	_range(404.0, MTN_NEAR, 0.12, 0.0026, 0.008, 60.0, 26.0, 419)

	# downtown depth bands, far -> near. Nearer = lower base / taller / brighter / less haze.
	_band(452, 44, 120, 34, 74, 0.50, [GLASS, CREAM, PALE], 0.86, 11, false)
	_band(498, 64, 168, 46, 100, 0.34, [CREAM, GLASS, WHITE, PALE], 0.72, 23, true)
	_band(548, 88, 214, 60, 128, 0.18, [WHITE, CREAM, GLASS, STONE], 0.62, 37, true)

	# signature landmarks spread across the length (church dominant near start)
	_church(260, 560)                       # colonial church w/ tall steeple + rose window
	_turrets(int(W * 0.42), 560)            # twin-turret colonial building
	_modern_tower(int(W * 0.72), 560)       # modern tower with distinctive top
	if W > 1700:
		_turrets(int(W * 0.90), 560)
	if W > 2600:
		_church(int(W * 0.62), 560)
		_modern_tower(int(W * 0.34), 560)
	if W > 3600:
		_turrets(int(W * 0.18) + 40, 560)
		_modern_tower(int(W * 0.95), 560)

	# nearest mixed band of colonial houses (red roofs) + street greenery
	_band(596, 96, 230, 78, 150, 0.04, [WHITE, CREAM, STONE, GLASS], 0.56, 53, true)
	_street_greenery()
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


# fills a vertical trapezoid (gable / spire / ridge): top edge top_w, bottom edge bot_w
func _trap(cx: int, top_y: int, top_w: int, bot_w: int, h: int, color: Color) -> void:
	for r in range(h + 1):
		var w := int(lerpf(float(top_w), float(bot_w), float(r) / float(maxf(float(h), 1.0))))
		_rect(cx - w / 2, top_y + r, w, 1, color)


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
	# the only gradient in the piece: clear dry-highland blue easing to a pale warm horizon
	for y in range(H):
		var t := pow(float(y) / float(H), 1.05)
		var row := SKY_TOP.lerp(SKY_HORIZON, t)
		for x in range(W):
			img.set_pixel(x, y, row)
	# clean warm sun glow (slightly warm light), upper area, not clipping anything
	var sun := Vector2(W * 0.82, 96.0)
	for k in range(20, 0, -1):
		_disc(sun, 30.0 + float(k) * 7.0, Color(SUN.r, SUN.g, SUN.b, 0.018))
	_disc(sun, 30.0, Color(SUN.r, SUN.g, SUN.b, 0.55))
	_disc(sun, 20.0, Color(SUN.r, SUN.g, SUN.b, 0.85))


func _clouds() -> void:
	# thin wispy high clouds: stretched flat lozenges of soft white, deterministic + non-repeating
	var n := int(W / 150.0) + 4
	for i in range(n):
		var cx := _h(i * 7 + 3) * (W + 200.0) - 100.0
		var cy := 60.0 + _h(i * 13 + 1) * 150.0
		var wisps := 3 + int(_h(i * 5) * 4.0)
		for j in range(wisps):
			var wx := cx + (float(j) - float(wisps) * 0.5) * (16.0 + _h(i * 11 + j) * 26.0)
			var wy := cy + (_h(i * 17 + j) - 0.5) * 14.0
			var rw := 24.0 + _h(i * 3 + j) * 40.0
			var rh := 3.0 + _h(i * 9 + j) * 3.0
			var a := 0.30 + _h(i * 23 + j) * 0.28
			_ellipse(Vector2(wx, wy), rw, rh, Color(CLOUD.r, CLOUD.g, CLOUD.b, a))


func _ellipse(c: Vector2, rw: float, rh: float, col: Color) -> void:
	for yy in range(int(c.y - rh), int(c.y + rh) + 1):
		for xx in range(int(c.x - rw), int(c.x + rw) + 1):
			var dx := (xx - c.x) / rw
			var dy := (yy - c.y) / rh
			if dx * dx + dy * dy <= 1.0:
				_px(xx, yy, col)


# ---------------------------------------------------------------- arid mountain ranges
func _range(base_y: float, col: Color, haze: float, freq_a: float, freq_b: float, amp_a: float, amp_b: float, seed: int) -> void:
	# smooth dusty ridgeline; farther ranges blend more toward the horizon haze colour
	var fill := col.lerp(SKY_HORIZON, haze)
	var ph := float(seed) * 0.7
	for x in range(W):
		var fx := float(x)
		var ridge := base_y - (amp_a * sin(fx * freq_a + ph) + amp_b * sin(fx * freq_b + ph * 1.7) + 6.0 * sin(fx * 0.02 + ph))
		# a touch of dusty texture banding (very low contrast)
		_rect(x, int(ridge), 1, H - int(ridge), fill)
		# subtle lighter sunlit crest line
		_rect(x, int(ridge), 1, 2, Color(fill.r, fill.g, fill.b, 1.0).lightened(0.10))


# ---------------------------------------------------------------- downtown depth bands
func _windows(bx: int, by: int, bw: int, bh: int, seedn: int, density: float, glass: bool, haze: float) -> void:
	# deterministic daylight window grid. On pale facades windows read as dark recesses;
	# on glass facades as cool blue panes with occasional bright reflections.
	var step := 10
	var cols := int((bw - 8) / step)
	var rows := int((bh - 10) / step)
	for cy in range(rows):
		for cx in range(cols):
			var idx := seedn * 131 + cy * 17 + cx * 3
			if _h(idx) > density:
				continue
			var col: Color
			if glass:
				col = GLASS_LIT if _h(idx * 2) < 0.30 else GLASS.darkened(0.12)
			else:
				col = WINDOW_DK
			var a := (0.55 + _h(idx * 3) * 0.35) * (1.0 - haze * 0.7)
			_rect(bx + 6 + cx * step, by + 7 + cy * step, 5, 6, Color(col.r, col.g, col.b, a))


func _roof_feat(x: int, byt: int, bw: int, fill: Color, seedn: int, haze: float, glass: bool) -> void:
	# silhouette variety on building tops: red-tiled gable, parapet, small cupola, AC block
	var cx := x + bw / 2
	var k := int(_h(seedn * 7) * 6)
	if k == 0:  # red-tiled gable roof (colonial flavour)
		var rh := clampi(int(bw * 0.22), 10, 30)
		var t := TERRACOTTA.lerp(SKY_HORIZON, haze)
		_trap(cx, byt - rh, int(bw * 0.10), bw, rh, t)
		_rect(cx - bw / 2, byt - 2, bw, 3, Color(TERRA_LIT.r, TERRA_LIT.g, TERRA_LIT.b, (1.0 - haze)))
	elif k == 1:  # stepped parapet setback
		var sw := int(bw * 0.54)
		_rect(cx - sw / 2, byt - 16, sw, 16, fill.lightened(0.05))
		_rect(cx - sw / 2, byt - 18, sw, 2, Color(1, 1, 1, 0.35 * (1.0 - haze)))
	elif k == 2 and haze < 0.4:  # little cupola / corner turret cap
		var tw := clampi(int(bw * 0.22), 8, 18)
		_rect(cx - tw / 2, byt - 14, tw, 14, fill.lightened(0.04))
		_trap(cx, byt - 14 - tw, 1, tw + 4, tw, TERRACOTTA.lerp(SKY_HORIZON, haze))
		_rect(cx, byt - 16 - tw, 1, 6, Color(1, 1, 1, 0.5 * (1.0 - haze)))
	elif k == 3 and haze < 0.5:  # rooftop AC / vent block
		var vw := clampi(int(bw * 0.34), 10, 30)
		_rect(cx - vw / 2, byt - 8, vw, 8, fill.darkened(0.10))
		_rect(cx - vw / 2, byt - 8, vw, 2, fill.lightened(0.08))
	elif k == 4 and glass and haze < 0.4:  # bright glass crown band
		_rect(x, byt, bw, 10, Color(GLASS_LIT.r, GLASS_LIT.g, GLASS_LIT.b, 0.7 * (1.0 - haze)))


func _band(base_y: float, hmin: int, hmax: int, wmin: int, wmax: int, haze: float, pal: Array, step_frac: float, seed: int, feat: bool) -> void:
	var x := -90.0
	var i := 0
	while x < W + 90:
		var s := seed * 1000 + i
		var e := _envelope(x + float(seed) * 140.0)
		var bw := int(wmin + _h(s * 9 + 2) * (wmax - wmin))
		var bh := clampi(int((hmin + e * (hmax - hmin)) * (0.80 + _h(s * 5 + 7) * 0.46)), hmin, int(hmax * 1.12))
		var byt := int(base_y) - bh
		var base: Color = pal[int(_h(s * 4) * pal.size()) % pal.size()]
		var glass := base == GLASS
		var fill := base.lerp(SKY_HORIZON, haze)
		# body + a soft shaded right third for chunky volume
		_rect(int(x), byt, bw, H - byt, fill)
		_rect(int(x) + int(bw * 0.66), byt, int(bw * 0.34), H - byt, Color(0, 0, 0, 0.10 * (1.0 - haze)))
		# bright sunlit top edge (warm/white pop)
		_rect(int(x), byt, bw, 2, Color(1.0, 0.99, 0.94, 0.8 * (1.0 - haze)))
		if feat:
			_roof_feat(int(x), byt, bw, fill, s, haze, glass)
		_windows(int(x), byt, bw, H - byt, s, dens_for(haze), glass, haze)
		x += maxf(bw * step_frac, 16.0)
		i += 1


func dens_for(haze: float) -> float:
	return 0.62 * (1.0 - haze * 0.45)


# ---------------------------------------------------------------- signature landmarks
func _church(bx: int, base_y: int) -> void:
	# pale-stone colonial church: nave + tall steeple with clock + tapered spire + rose window
	var stone := STONE
	var roof := TERRACOTTA
	# --- nave (main hall) with red gable roof ---
	var nave_w := 110
	var nave_h := 92
	var nx := bx
	var ny := base_y - nave_h
	_rect(nx, ny, nave_w, nave_h, stone)
	_rect(nx, ny, nave_w, 2, Color(1, 1, 1, 0.6))
	# gable roof on nave
	_trap(nx + nave_w / 2, ny - 26, 6, nave_w + 6, 26, roof)
	_rect(nx + nave_w / 2 - (nave_w + 6) / 2, ny - 2, nave_w + 6, 3, TERRA_LIT)
	# arched windows along the nave
	for wj in range(3):
		var wx := nx + 18 + wj * 32
		_rect(wx, ny + 30, 14, 34, WINDOW_DK.darkened(0.1))
		_disc(Vector2(wx + 7, ny + 30), 7.0, WINDOW_DK.darkened(0.1))
	# --- steeple tower (to the side, tall, dominant) ---
	var tw := 50
	var tx := nx - tw + 8
	var tower_h := 200
	var ty := base_y - tower_h
	_rect(tx, ty, tw, base_y - ty, stone)
	_rect(tx, ty, tw, 2, Color(1, 1, 1, 0.6))
	_rect(tx + int(tw * 0.7), ty, int(tw * 0.3), base_y - ty, Color(0, 0, 0, 0.10))
	# clock face near the top
	_disc(Vector2(tx + tw / 2, ty + 34), 13.0, Color(0.97, 0.96, 0.92, 1.0))
	_disc(Vector2(tx + tw / 2, ty + 34), 11.0, Color(0.90, 0.88, 0.80, 1.0))
	_line(Vector2(tx + tw / 2, ty + 34), Vector2(tx + tw / 2, ty + 26), Color8(60, 50, 44), 2)
	_line(Vector2(tx + tw / 2, ty + 34), Vector2(tx + tw / 2 + 7, ty + 34), Color8(60, 50, 44), 2)
	# tall tapered spire (terracotta) topped with a finial
	var spire_h := 78
	_trap(tx + tw / 2, ty - spire_h, 3, tw + 6, spire_h, roof)
	_rect(tx + tw / 2, ty - spire_h - 16, 2, 16, Color8(70, 58, 50))
	_disc(Vector2(tx + tw / 2, ty - spire_h - 18), 4.0, Color8(228, 206, 150))
	# rose window on the nave face
	_disc(Vector2(nx + nave_w / 2, ny + 22), 12.0, stone.darkened(0.05))
	_disc(Vector2(nx + nave_w / 2, ny + 22), 9.0, GLASS.darkened(0.05))
	for s in range(8):
		var ang := float(s) / 8.0 * TAU
		_line(Vector2(nx + nave_w / 2, ny + 22), Vector2(nx + nave_w / 2 + cos(ang) * 9.0, ny + 22 + sin(ang) * 9.0), stone, 1)


func _turrets(bx: int, base_y: int) -> void:
	# colonial building with two corner turrets/cupolas and a red roof
	var w := 150
	var bh := 132
	var byt := base_y - bh
	_rect(bx, byt, w, bh, CREAM)
	_rect(bx, byt, w, 2, Color(1, 1, 1, 0.7))
	_rect(bx + int(w * 0.7), byt, int(w * 0.3), bh, Color(0, 0, 0, 0.08))
	# central red gable
	_trap(bx + w / 2, byt - 18, int(w * 0.3), w, 18, TERRACOTTA)
	_rect(bx, byt - 2, w, 3, TERRA_LIT)
	# window grid
	_windows(bx, byt, w, bh, 9001, 0.7, false, 0.0)
	# two corner turrets with conical caps
	for t in range(2):
		var ttx := bx + (0 if t == 0 else w - 26) + 4
		var turret_w := 22
		var turret_h := 40
		var tty := byt - turret_h
		_rect(ttx, tty, turret_w, turret_h + 18, STONE)
		_rect(ttx, tty, turret_w, 2, Color(1, 1, 1, 0.6))
		# little window slit
		_rect(ttx + turret_w / 2 - 3, tty + 12, 6, 12, WINDOW_DK.darkened(0.1))
		# conical terracotta cap
		_trap(ttx + turret_w / 2, tty - 26, 1, turret_w + 6, 26, TERRACOTTA)
		_rect(ttx + turret_w / 2, tty - 32, 2, 7, Color8(70, 58, 50))
		_disc(Vector2(ttx + turret_w / 2, tty - 33), 3.0, Color8(228, 206, 150))


func _modern_tower(bx: int, base_y: int) -> void:
	# slender modern glass tower with a distinctive stepped/angled crown
	var w := 86
	var bh := 250
	var byt := base_y - bh
	_rect(bx, byt, w, bh, GLASS)
	_rect(bx, byt, w, bh, Color(GLASS.r, GLASS.g, GLASS.b, 0.0))
	# vertical mullions + sunlit left edge
	_rect(bx, byt, w, base_y - byt, GLASS)
	_rect(bx, byt, 3, base_y - byt, GLASS_LIT)
	for m in range(1, 6):
		_rect(bx + m * int(w / 6.0), byt, 1, bh, GLASS.darkened(0.12))
	# horizontal glass reflection banding
	_windows(bx, byt, w, bh, 9100, 0.55, true, 0.0)
	# distinctive crown: a narrower lit cap + slim mast
	var cw := int(w * 0.6)
	_rect(bx + (w - cw) / 2, byt - 26, cw, 26, GLASS_LIT)
	_rect(bx + (w - cw) / 2, byt - 28, cw, 3, Color(1, 1, 1, 0.85))
	_rect(bx + w / 2 - 1, byt - 26 - 30, 2, 30, Color8(120, 130, 138))
	_disc(Vector2(bx + w / 2, byt - 26 - 32), 3.0, Color8(220, 90, 70))


# ---------------------------------------------------------------- street greenery
func _street_greenery() -> void:
	# scattered round street trees + tall palms threaded between the near buildings.
	# Sits just above the foreground so it reads as the city floor's vegetation line.
	var y := 600
	var x := 30
	var i := 0
	while x < W:
		var r := _h(i * 7 + 5)
		if r < 0.40:
			_tree(x, y - int(_h(i * 3) * 12), 0.8 + _h(i * 9) * 0.8)
		elif r < 0.62:
			_palm(x, y - int(_h(i * 3) * 16), 0.9 + _h(i * 9) * 0.7)
		x += 36 + int(_h(i * 11) * 70)
		i += 1


func _tree(x: int, base_y: int, scale: float) -> void:
	var trunk_h := int(16 * scale)
	_rect(x - 2, base_y - trunk_h, 4, trunk_h, Color8(96, 72, 50))
	var r := 13.0 * scale
	_disc(Vector2(x, base_y - trunk_h - int(r * 0.6)), r, TREE_DK)
	_disc(Vector2(x - r * 0.4, base_y - trunk_h - int(r * 0.9)), r * 0.75, TREE)
	_disc(Vector2(x + r * 0.5, base_y - trunk_h - int(r * 0.8)), r * 0.7, TREE)
	_disc(Vector2(x, base_y - trunk_h - int(r * 1.2)), r * 0.65, TREE.lightened(0.08))


func _palm(x: int, base_y: int, scale: float) -> void:
	var trunk_h := int(46 * scale)
	# slightly leaning trunk
	for s in range(trunk_h):
		var off := int(sin(float(s) / float(trunk_h) * 1.2) * 5.0 * scale)
		_rect(x + off - 1, base_y - s, 3, 1, Color8(120, 98, 66))
	var top := Vector2(x + int(sin(1.2) * 5.0 * scale), base_y - trunk_h)
	# fan of fronds
	for f in range(7):
		var ang := lerpf(-2.5, -0.6, float(f) / 6.0)
		var ex := top.x + cos(ang) * 22.0 * scale
		var ey := top.y + sin(ang) * 22.0 * scale
		_line(top, Vector2(ex, ey), PALM, maxi(1, int(2 * scale)))
		_line(top, Vector2(ex, ey + 3.0 * scale), PALM.darkened(0.12), 1)
	_disc(top, 3.0 * scale, PALM.darkened(0.1))


# ---------------------------------------------------------------- play-field foreground
func _foreground() -> void:
	# Nearest rooftops as solid platforms: mix of flat white roofs and red-tiled roofs, with a
	# BRIGHT sunlit top edge that pops for gameplay readability. Varied heights and gaps reveal
	# the layered city behind (depth). Each carries a distinct prop.
	var x := -40
	var i := 0
	while x < W + 40:
		var w := 200 + int(_h(i * 9 + 1) * 280)
		var top := 600 + int(_h(i * 5 + 2) * 64)
		var tiled := _h(i * 13 + 4) < 0.42
		_ledge(x, top, w, tiled)
		# distinct prop per ledge
		var prop := i % 4
		var px := x + int(w * (0.30 + _h(i * 3) * 0.4))
		if prop == 0:  # palm tree
			_palm(px, top, 1.1)
		elif prop == 1:  # rooftop AC unit
			_rect(px, top - 18, 34, 18, Color8(196, 198, 200))
			_rect(px, top - 18, 34, 3, Color8(224, 226, 228))
			_rect(px + 6, top - 12, 8, 8, Color8(150, 154, 158))
			_rect(px + 20, top - 12, 8, 8, Color8(150, 154, 158))
		elif prop == 2:  # flagpole
			_rect(px, top - 56, 3, 56, Color8(210, 210, 206))
			_rect(px + 3, top - 56, 30, 18, TERRACOTTA)
			_rect(px + 3, top - 56, 30, 6, TERRA_LIT)
		else:  # small cupola
			var cw := 26
			_rect(px, top - 20, cw, 20, CREAM)
			_trap(px + cw / 2, top - 20 - 18, 1, cw + 6, 18, TERRACOTTA)
			_rect(px + cw / 2, top - 20 - 24, 2, 7, Color8(70, 58, 50))
			_disc(Vector2(px + cw / 2, top - 20 - 25), 3.0, Color8(228, 206, 150))
		x += w + 60 + int(_h(i * 3) * 130)
		i += 1


func _ledge(x: int, top: int, w: int, tiled: bool) -> void:
	# solid platform body in warm shadowed wall tones
	var wall := Color8(206, 196, 178) if not tiled else Color8(178, 96, 70)
	var wall2 := wall.darkened(0.16)
	_rect(x, top, w, H - top, wall)
	_rect(x, top + (H - top) / 2, w, (H - top) / 2, wall2)
	if tiled:
		# terracotta tile roof surface with rib lines + bright sunlit ridge
		for r in range(1, 6):
			_rect(x, top + r * 6, w, 1, Color(0, 0, 0, 0.10))
		_rect(x, top - 4, w, 5, Color(TERRA_LIT.r, TERRA_LIT.g, TERRA_LIT.b, 0.55))
		_rect(x, top, w, 3, TERRA_LIT)
		_rect(x, top, w, 1, Color(1.0, 0.93, 0.82, 0.9))
	else:
		# flat white roof with a crisp bright top edge
		_rect(x, top - 4, w, 5, Color(1.0, 1.0, 0.96, 0.35))
		_rect(x, top, w, 3, WHITE)
		_rect(x, top, w, 1, Color(1.0, 1.0, 0.96, 0.95))
