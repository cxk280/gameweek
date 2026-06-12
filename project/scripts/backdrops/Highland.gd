extends "res://scripts/backdrops/BackdropBase.gd"
## Stage theme: bright dry highland capital (daytime). Static clear-blue sky with a warm sun glow +
## a slow wispy-cloud layer; arid tan/dusty mountain ranges on slow bottom-anchored layers (farther
## = lighter/dustier); downtown building rows nearer (cream/white + glass-blue facades with window
## grids, plus colonial gabled forms and red-tiled roofs); colonial church, twin-turret building and
## a modern tower as distributed landmarks; scattered round trees + palms. Bottom-anchored ground
## rows; NO foreground play-field strip (those ledges are live level geometry). Mirrors City/Town.

# ---- daytime dry palette (flat, chunky, low-saturation) ----
const SKY_TOP := Color8(74, 142, 206)        # clear dry blue (upper)
const SKY_HORIZON := Color8(196, 220, 234)   # pale warm haze at horizon
const CLOUD := Color8(248, 250, 252)
const SUN := Color8(255, 248, 224)

# arid mountains (far->near get darker / less dusty)
const MTN_FAR := Color8(150, 158, 150)
const MTN_MID := Color8(150, 140, 116)
const MTN_NEAR := Color8(138, 120, 90)

# buildings
const CREAM := Color8(238, 232, 218)
const WHITE := Color8(246, 246, 242)
const PALE := Color8(214, 208, 196)
const GLASS := Color8(150, 186, 206)         # glass-blue facade
const GLASS_LIT := Color8(196, 218, 230)
const STONE := Color8(224, 214, 196)         # colonial pale stone

# accents
const TERRACOTTA := Color8(186, 86, 58)      # red tiled roofs
const TERRA_LIT := Color8(212, 110, 78)
const TREE := Color8(74, 122, 64)
const TREE_DK := Color8(56, 98, 50)
const PALM := Color8(82, 134, 70)
const WINDOW_DK := Color8(120, 130, 138)     # window glass on pale facades (daylight)


func build(level_w: float, view_w: int, view_h: int) -> Dictionary:
	var sky := _fresh(view_w, view_h)
	_sky()

	# thin wispy clouds: high, near-static (drift just slightly)
	var clouds := _fresh(_layer_w(level_w, 0.06, view_w), 320)
	_clouds()

	# arid mountain ranges, far -> near. Farther blends more toward the horizon haze and sits
	# higher/lighter; nearer is darker, lower and barely moves relative to the buildings.
	# ranges sit high in their (420px, bottom-anchored) image so ridges peek above the skyline
	var mtn_far := _fresh(_layer_w(level_w, 0.08, view_w), 420)
	_range(118.0, MTN_FAR, 0.62, 0.0048, 0.012, 34.0, 14.0, 101)

	var mtn_mid := _fresh(_layer_w(level_w, 0.12, view_w), 420)
	_range(150.0, MTN_FAR.lerp(MTN_MID, 0.5), 0.42, 0.0039, 0.010, 44.0, 18.0, 211)

	var mtn_near := _fresh(_layer_w(level_w, 0.18, view_w), 420)
	_range(182.0, MTN_NEAR, 0.18, 0.0028, 0.009, 60.0, 26.0, 419)

	# downtown depth bands, far -> near. Nearer = lower base / taller / brighter / less haze.
	var far := _fresh(_layer_w(level_w, 0.30, view_w), 720)
	_band(560, 64, 168, 46, 100, 0.34, [GLASS, CREAM, PALE, WHITE], 0.72, 23, true)

	# distributed signature landmarks on the mid layer
	var marks := _fresh(_layer_w(level_w, 0.40, view_w), 720)
	_landmarks()

	var near := _fresh(_layer_w(level_w, 0.50, view_w), 720)
	_band(640, 88, 222, 64, 134, 0.12, [WHITE, CREAM, GLASS, STONE], 0.60, 53, true)

	# scattered street greenery on the nearest layer
	var green := _fresh(_layer_w(level_w, 0.58, view_w), 720)
	_greenery()

	return {
		"sky": sky,
		"layers": [
			{"image": clouds, "motion": 0.06, "top": 40.0, "anchor_bottom": false},
			{"image": mtn_far, "motion": 0.08, "top": 0.0, "anchor_bottom": true},
			{"image": mtn_mid, "motion": 0.12, "top": 0.0, "anchor_bottom": true},
			{"image": mtn_near, "motion": 0.18, "top": 0.0, "anchor_bottom": true},
			{"image": far, "motion": 0.30, "top": 0.0, "anchor_bottom": true},
			{"image": marks, "motion": 0.40, "top": 0.0, "anchor_bottom": true},
			{"image": near, "motion": 0.50, "top": 0.0, "anchor_bottom": true},
			{"image": green, "motion": 0.58, "top": 0.0, "anchor_bottom": true},
		],
	}


# ---------------------------------------------------------------- sky + sky bodies
func _sky() -> void:
	# clear dry blue easing to a pale warm horizon
	_vgrad(SKY_TOP, SKY_HORIZON, 1.05)
	# clean warm sun glow in the upper area, not clipping anything
	var sun := Vector2(_w * 0.82, 96.0)
	for k in range(20, 0, -1):
		_disc(sun, 30.0 + float(k) * 7.0, Color(SUN.r, SUN.g, SUN.b, 0.018))
	_disc(sun, 30.0, Color(SUN.r, SUN.g, SUN.b, 0.55))
	_disc(sun, 20.0, Color(SUN.r, SUN.g, SUN.b, 0.85))


func _clouds() -> void:
	# thin wispy lozenges of soft white, deterministic + non-repeating across the full width
	var n := int(float(_w) / 150.0) + 4
	for i in range(n):
		var cx := _hash(i * 7 + 3) * (float(_w) + 200.0) - 100.0
		var cy := 40.0 + _hash(i * 13 + 1) * 150.0
		var wisps := 3 + int(_hash(i * 5) * 4.0)
		for j in range(wisps):
			var wx := cx + (float(j) - float(wisps) * 0.5) * (16.0 + _hash(i * 11 + j) * 26.0)
			var wy := cy + (_hash(i * 17 + j) - 0.5) * 14.0
			var rw := 24.0 + _hash(i * 3 + j) * 40.0
			var rh := 3.0 + _hash(i * 9 + j) * 3.0
			var a := 0.55 + _hash(i * 23 + j) * 0.35
			_ellipse(Vector2(wx, wy), rw, rh, Color(1.0, 1.0, 1.0, a))


# flat filled ellipse (local helper; base has no ellipse primitive)
func _ellipse(c: Vector2, rw: float, rh: float, col: Color) -> void:
	for yy in range(int(c.y - rh), int(c.y + rh) + 1):
		for xx in range(int(c.x - rw), int(c.x + rw) + 1):
			var dx := (float(xx) - c.x) / rw
			var dy := (float(yy) - c.y) / rh
			if dx * dx + dy * dy <= 1.0:
				_px(xx, yy, col)


# ---------------------------------------------------------------- arid mountain ranges
func _range(base_y: float, col: Color, haze: float, freq_a: float, freq_b: float, amp_a: float, amp_b: float, seed: int) -> void:
	# smooth dusty ridgeline filled to the bottom of the (bottom-anchored) layer; farther ranges
	# blend more toward the horizon haze for atmospheric perspective.
	var fill := col.lerp(SKY_HORIZON, haze)
	var crest := Color(fill.r, fill.g, fill.b, 1.0).lightened(0.10)
	var ph := float(seed) * 0.7
	for x in range(_w):
		var fx := float(x)
		var ridge := base_y - (amp_a * sin(fx * freq_a + ph) + amp_b * sin(fx * freq_b + ph * 1.7) + 6.0 * sin(fx * 0.02 + ph))
		_rect(x, int(ridge), 1, _h - int(ridge), fill)
		_rect(x, int(ridge), 1, 2, crest)   # subtle sunlit crest line


# ---------------------------------------------------------------- downtown depth bands
func _windows(bx: int, by: int, bw: int, bh: int, seedn: int, density: float, glass: bool, haze: float) -> void:
	# deterministic daylight window grid. Pale facades read as dark recesses; glass facades as
	# cool blue panes with occasional bright reflections.
	var step := 10
	var cols := int(float(bw - 8) / float(step))
	var rows := int(float(bh - 10) / float(step))
	for cy in range(rows):
		for cx in range(cols):
			var idx := seedn * 131 + cy * 17 + cx * 3
			if _hash(idx) > density:
				continue
			var col: Color
			if glass:
				col = GLASS_LIT if _hash(idx * 2) < 0.30 else GLASS.darkened(0.12)
			else:
				col = WINDOW_DK
			var a := (0.55 + _hash(idx * 3) * 0.35) * (1.0 - haze * 0.7)
			_rect(bx + 6 + cx * step, by + 7 + cy * step, 5, 6, Color(col.r, col.g, col.b, a))


func _roof_feat(x: int, byt: int, bw: int, fill: Color, seedn: int, haze: float, glass: bool) -> void:
	# silhouette variety on building tops: red-tiled gable, parapet, small cupola, AC block, crown
	var cx := x + bw / 2
	var k := int(_hash(seedn * 7) * 6)
	if k == 0:  # red-tiled gable roof (colonial flavour)
		var rh := clampi(int(float(bw) * 0.22), 10, 30)
		var t := TERRACOTTA.lerp(SKY_HORIZON, haze)
		_trap(cx, byt - rh, int(float(bw) * 0.10), bw, rh, t)
		_rect(cx - bw / 2, byt - 2, bw, 3, Color(TERRA_LIT.r, TERRA_LIT.g, TERRA_LIT.b, 1.0 - haze))
	elif k == 1:  # stepped parapet setback
		var sw := int(float(bw) * 0.54)
		_rect(cx - sw / 2, byt - 16, sw, 16, fill.lightened(0.05))
		_rect(cx - sw / 2, byt - 18, sw, 2, Color(1, 1, 1, 0.35 * (1.0 - haze)))
	elif k == 2 and haze < 0.4:  # little cupola / corner turret cap
		var tw := clampi(int(float(bw) * 0.22), 8, 18)
		_rect(cx - tw / 2, byt - 14, tw, 14, fill.lightened(0.04))
		_trap(cx, byt - 14 - tw, 1, tw + 4, tw, TERRACOTTA.lerp(SKY_HORIZON, haze))
		_rect(cx, byt - 16 - tw, 1, 6, Color(1, 1, 1, 0.5 * (1.0 - haze)))
	elif k == 3 and haze < 0.5:  # rooftop AC / vent block
		var vw := clampi(int(float(bw) * 0.34), 10, 30)
		_rect(cx - vw / 2, byt - 8, vw, 8, fill.darkened(0.10))
		_rect(cx - vw / 2, byt - 8, vw, 2, fill.lightened(0.08))
	elif k == 4 and glass and haze < 0.4:  # bright glass crown band
		_rect(x, byt, bw, 10, Color(GLASS_LIT.r, GLASS_LIT.g, GLASS_LIT.b, 0.7 * (1.0 - haze)))


func _band(base_y: float, hmin: int, hmax: int, wmin: int, wmax: int, haze: float, pal: Array, step_frac: float, seed: int, feat: bool) -> void:
	var x := -90.0
	var i := 0
	while x < float(_w) + 90.0:
		var s := seed * 1000 + i
		var e := _envelope(x + float(seed) * 140.0)
		var bw := int(wmin + _hash(s * 9 + 2) * float(wmax - wmin))
		var bh := clampi(int((float(hmin) + e * float(hmax - hmin)) * (0.80 + _hash(s * 5 + 7) * 0.46)), hmin, int(float(hmax) * 1.12))
		var byt := int(base_y) - bh
		var base: Color = pal[int(_hash(s * 4) * float(pal.size())) % pal.size()]
		var glass := base == GLASS
		var fill := base.lerp(SKY_HORIZON, haze)
		# body + a soft shaded right third for chunky volume
		_rect(int(x), byt, bw, _h - byt, fill)
		_rect(int(x) + int(float(bw) * 0.66), byt, int(float(bw) * 0.34), _h - byt, Color(0, 0, 0, 0.10 * (1.0 - haze)))
		# bright sunlit top edge
		_rect(int(x), byt, bw, 2, Color(1.0, 0.99, 0.94, 0.8 * (1.0 - haze)))
		if feat:
			_roof_feat(int(x), byt, bw, fill, s, haze, glass)
		_windows(int(x), byt, bw, _h - byt, s, _dens_for(haze), glass, haze)
		x += maxf(float(bw) * step_frac, 16.0)
		i += 1


func _dens_for(haze: float) -> float:
	return 0.62 * (1.0 - haze * 0.45)


# ---------------------------------------------------------------- signature landmarks
func _landmarks() -> void:
	# church / twin-turret / modern-tower cycled and jittered across the full width, no fixed spots
	var base_y := _h - 160
	var x := 360.0
	var n := 0
	while x < float(_w):
		var jx := int(x + (_hash(n * 23 + 5) - 0.5) * 90.0)
		match n % 3:
			0: _church(jx, base_y)
			1: _turrets(jx, base_y)
			2: _modern_tower(jx, base_y)
		x += 1700.0 + _hash(n * 17) * 1200.0
		n += 1


func _church(bx: int, base_y: int) -> void:
	# pale-stone colonial church: nave + tall steeple with clock + tapered spire + rose window
	var stone := STONE
	var roof := TERRACOTTA
	# --- nave (main hall) with red gable roof ---
	var nave_w := 110
	var nave_h := 92
	var nx := bx
	var ny := base_y - nave_h
	_rect(nx, ny, nave_w, _h - ny, stone)
	_rect(nx, ny, nave_w, 2, Color(1, 1, 1, 0.6))
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
	_rect(tx, ty, tw, _h - ty, stone)
	_rect(tx, ty, tw, 2, Color(1, 1, 1, 0.6))
	_rect(tx + int(float(tw) * 0.7), ty, int(float(tw) * 0.3), _h - ty, Color(0, 0, 0, 0.10))
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
	_rect(bx, byt, w, _h - byt, CREAM)
	_rect(bx, byt, w, 2, Color(1, 1, 1, 0.7))
	_rect(bx + int(float(w) * 0.7), byt, int(float(w) * 0.3), _h - byt, Color(0, 0, 0, 0.08))
	# central red gable
	_trap(bx + w / 2, byt - 18, int(float(w) * 0.3), w, 18, TERRACOTTA)
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
	_rect(bx, byt, w, _h - byt, GLASS)
	_rect(bx, byt, 3, _h - byt, GLASS_LIT)   # sunlit left edge
	for m in range(1, 6):
		_rect(bx + m * int(float(w) / 6.0), byt, 1, bh, GLASS.darkened(0.12))
	# horizontal glass reflection banding
	_windows(bx, byt, w, bh, 9100, 0.55, true, 0.0)
	# distinctive crown: a narrower lit cap + slim mast
	var cw := int(float(w) * 0.6)
	_rect(bx + (w - cw) / 2, byt - 26, cw, 26, GLASS_LIT)
	_rect(bx + (w - cw) / 2, byt - 28, cw, 3, Color(1, 1, 1, 0.85))
	_rect(bx + w / 2 - 1, byt - 26 - 30, 2, 30, Color8(120, 130, 138))
	_disc(Vector2(bx + w / 2, byt - 26 - 32), 3.0, Color8(220, 90, 70))


# ---------------------------------------------------------------- street greenery
func _greenery() -> void:
	# scattered round street trees + tall palms threaded across the full width on the floor line
	var y := _h - 110
	var x := 30
	var i := 0
	while x < _w:
		var r := _hash(i * 7 + 5)
		if r < 0.40:
			_tree(x, y - int(_hash(i * 3) * 12.0), 0.9 + _hash(i * 9) * 0.8)
		elif r < 0.64:
			_palm(x, y - int(_hash(i * 3) * 16.0), 1.0 + _hash(i * 9) * 0.7)
		x += 36 + int(_hash(i * 11) * 70.0)
		i += 1


func _tree(x: int, base_y: int, scale: float) -> void:
	var trunk_h := int(16.0 * scale)
	_rect(x - 2, base_y - trunk_h, 4, trunk_h, Color8(96, 72, 50))
	var r := 13.0 * scale
	_disc(Vector2(x, base_y - trunk_h - int(r * 0.6)), r, TREE_DK)
	_disc(Vector2(x - r * 0.4, base_y - trunk_h - int(r * 0.9)), r * 0.75, TREE)
	_disc(Vector2(x + r * 0.5, base_y - trunk_h - int(r * 0.8)), r * 0.7, TREE)
	_disc(Vector2(x, base_y - trunk_h - int(r * 1.2)), r * 0.65, TREE.lightened(0.08))


func _palm(x: int, base_y: int, scale: float) -> void:
	var trunk_h := int(46.0 * scale)
	# slightly leaning trunk
	for s in range(trunk_h):
		var off := int(sin(float(s) / float(trunk_h) * 1.2) * 5.0 * scale)
		_rect(x + off - 1, base_y - s, 3, 1, Color8(120, 98, 66))
	var top := Vector2(float(x) + sin(1.2) * 5.0 * scale, float(base_y - trunk_h))
	# fan of fronds
	for f in range(7):
		var ang := lerpf(-2.5, -0.6, float(f) / 6.0)
		var ex := top.x + cos(ang) * 22.0 * scale
		var ey := top.y + sin(ang) * 22.0 * scale
		_line(top, Vector2(ex, ey), PALM, maxi(1, int(2.0 * scale)))
		_line(top, Vector2(ex, ey + 3.0 * scale), PALM.darkened(0.12), 1)
	_disc(top, 3.0 * scale, PALM.darkened(0.1))
