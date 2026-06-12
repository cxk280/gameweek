extends "res://scripts/backdrops/BackdropBase.gd"
## Stage theme: bright daytime stilt-village over open water. Static sky+water gradient, two slow
## back layers (clouds + hazy misty ridges), two nearer layers of stilt houses with reflections,
## plus a mid layer carrying the signature multi-tier roofed house and a long-tail boat. Mirrors the
## structure of City.gd. The foreground play-field platforms are intentionally NOT drawn here.

# ---- palette (vivid daytime lake mood) ----
const SKY_TOP := Color8(74, 150, 222)
const SKY_HORIZON := Color8(176, 214, 238)
const HAZE_BLUE := Color8(150, 180, 208)          # distant layers fade toward this
const WATER_TOP := Color8(86, 150, 168)
const WATER_DEEP := Color8(40, 96, 124)
const ROOF_RED := Color8(176, 72, 58)
const ROOF_GREY := Color8(96, 116, 134)
const ROOF_GREEN := Color8(74, 120, 86)
const ROOF_RUST := Color8(150, 96, 62)
const WALL_WOOD := Color8(120, 84, 64)
const WALL_DARK := Color8(86, 60, 48)
const POLE := Color8(78, 58, 44)
const VEG := Color8(86, 150, 64)
const VEG_DARK := Color8(58, 110, 48)

# Bottom-anchored layers are mounted with their top at (horizon - layer_height); the live horizon
# the previewer/Main uses is 900 and the visible viewport is 720, so a LAYER_H-tall layer's row 0
# lands at frame row (900 - LAYER_H). HORIZON is the waterline in the static sky/water image (frame
# space); WATER_Y is that same waterline expressed inside a bottom-anchored layer.
const HORIZON := 372     # waterline in the 720-tall static sky image (frame space)
const LAYER_H := 720     # ground/water layers are full-viewport tall, bottom-anchored
const ANCHOR_TOP := 180  # frame row of a bottom-anchored LAYER_H layer's row 0 (900 - 720)
const WATER_Y := HORIZON - ANCHOR_TOP   # waterline row inside a bottom-anchored layer (== 192)


func build(level_w: float, view_w: int, view_h: int) -> Dictionary:
	# Static sky: bright blue gradient up top, blue-green water in the lower band (no parallax).
	var sky := _fresh(view_w, view_h)
	_sky_water(view_h)

	# Clouds: high and nearly fixed -> tiny motion.
	var clouds := _fresh(_layer_w(level_w, 0.06, view_w), 300)
	_clouds()

	# Misty mountain ridges: far -> near within this slow layer, hazier farther back.
	var ridges := _fresh(_layer_w(level_w, 0.12, view_w), LAYER_H)
	_ridge(296, 56.0, 0.0017, 0.62, Color8(120, 150, 184), 11)
	_ridge(322, 46.0, 0.0024, 0.44, Color8(98, 132, 168), 23)
	_ridge(346, 38.0, 0.0033, 0.26, Color8(78, 116, 150), 37)
	_ridge(366, 26.0, 0.0049, 0.12, Color8(66, 108, 138), 53)

	# Far stilt-house row: hazy, small, slower.
	var houses_far := _fresh(_layer_w(level_w, 0.30, view_w), LAYER_H)
	_house_band(WATER_Y + 10, 24, 40, 24, 42, 0.34, 41)

	# Mid layer: the larger near houses plus the signature temple house and boat landmarks.
	var houses_mid := _fresh(_layer_w(level_w, 0.50, view_w), LAYER_H)
	_house_band(WATER_Y + 64, 48, 74, 44, 78, 0.12, 73)
	_landmarks(level_w)

	return {
		"sky": sky,
		"layers": [
			{"image": clouds, "motion": 0.06, "top": 40.0, "anchor_bottom": false},
			{"image": ridges, "motion": 0.12, "top": 0.0, "anchor_bottom": true},
			{"image": houses_far, "motion": 0.30, "top": 0.0, "anchor_bottom": true},
			{"image": houses_mid, "motion": 0.50, "top": 0.0, "anchor_bottom": true},
		],
	}


# ---------------------------------------------------------------- static sky + water
func _sky_water(view_h: int) -> void:
	for y in range(view_h):
		var row: Color
		if y < HORIZON:
			row = SKY_TOP.lerp(SKY_HORIZON, pow(float(y) / float(HORIZON), 1.25))
		else:
			var t := float(y - HORIZON) / float(view_h - HORIZON)
			row = WATER_TOP.lerp(WATER_DEEP, pow(t, 0.85))
		for x in range(_w):
			_img.set_pixel(x, y, row)
	# subtle horizontal ripple lines on the water, denser near the viewer
	var ry := HORIZON + 6
	var i := 0
	while ry < view_h:
		var a := 0.05 + 0.10 * (float(ry - HORIZON) / float(view_h - HORIZON))
		var dash := 40 + int(_hash(i * 7) * 80)
		var rx := -int(_hash(i * 3) * 120)
		while rx < _w:
			_rect(rx, ry, dash, 1, Color(0.86, 0.94, 0.98, a))
			rx += dash + 30 + int(_hash(i * 11 + rx) * 60)
		ry += 7 + int(_hash(i * 5) * 6)
		i += 1


# ---------------------------------------------------------------- clouds
func _cloud(cx: float, cy: float, scale: float, seedn: int) -> void:
	# flat rounded cumulus: cluster of soft white lobes with a slightly grey underside.
	var lobes := 5 + int(_hash(seedn) * 4)
	var base_r := 14.0 * scale
	for k in range(lobes):
		var t := float(k) / float(lobes - 1)
		var lx := cx + lerpf(-46.0 * scale, 46.0 * scale, t)
		var hump := sin(t * PI)
		var ly := cy - hump * 12.0 * scale
		var r := base_r * (0.55 + 0.55 * hump) * (0.8 + _hash(seedn * 7 + k) * 0.5)
		_disc(Vector2(lx, ly + r * 0.5), r, Color8(190, 200, 214))
		_disc(Vector2(lx, ly), r, Color8(248, 251, 255))
	_rect(int(cx - 50 * scale), int(cy + 9 * scale), int(100 * scale), int(5 * scale), Color8(196, 206, 220))


func _clouds() -> void:
	# upper-sky cumulus, non-repeating placement/size across the full length.
	var step := 240.0
	var x := 60.0
	var i := 0
	while x < _w + 120:
		var jitter := (_hash(i * 13 + 3) - 0.5) * 150.0
		var cx := x + jitter
		var cy := 60.0 + _hash(i * 9 + 1) * 120.0
		var scale := 0.7 + _hash(i * 5 + 2) * 1.1
		if _hash(i * 17) < 0.82:
			_cloud(cx, cy, scale, i * 29 + 5)
		x += step * (0.7 + _hash(i * 3) * 0.8)
		i += 1


# ---------------------------------------------------------------- mountain ridges
func _ridge(base_y: int, amp: float, freq: float, haze: float, fill: Color, seedn: int) -> void:
	# smooth sine-based ridgeline; nearer ridges are lower, less hazy. Atmospheric perspective fades
	# each band toward the hazy blue distance color. base_y is given in static-frame space; this
	# bottom-anchored layer's waterline sits lower than the frame's, so shift every y by `off`.
	var off := WATER_Y - HORIZON   # shift frame y into layer y
	var col := fill.lerp(HAZE_BLUE, haze)
	for x in range(_w):
		var fx := float(x) + float(seedn) * 90.0
		var ridge := float(base_y) - (
			amp * (0.5 + 0.5 * sin(fx * freq))
			+ amp * 0.45 * sin(fx * freq * 2.7 + 1.3)
			+ amp * 0.22 * sin(fx * freq * 5.1 + 0.4)
		)
		var ry := int(ridge) + off
		_rect(x, ry, 1, (base_y + off) - ry + 40, col)
	# faint lit rim along the ridgeline for a touch of form
	for x in range(_w):
		var fx2 := float(x) + float(seedn) * 90.0
		var ridge2 := float(base_y) - (
			amp * (0.5 + 0.5 * sin(fx2 * freq))
			+ amp * 0.45 * sin(fx2 * freq * 2.7 + 1.3)
			+ amp * 0.22 * sin(fx2 * freq * 5.1 + 0.4)
		)
		_px(x, int(ridge2) + off, Color(1, 1, 1, 0.10 * (1.0 - haze)))


# ---------------------------------------------------------------- reflections
func _reflect_col(x: int, top_y: int, height: int, c: Color, dim: float) -> void:
	# mirror a vertical column downward across the layer's waterline, dimmer + wavy.
	if x < 0 or x >= _w:
		return
	var rc := c.lerp(WATER_DEEP, dim)
	var wob := int(round(2.0 * sin(float(x) * 0.10)))
	for r in range(height):
		var src_y := top_y + r
		var dy := WATER_Y + (WATER_Y - src_y)
		if dy <= WATER_Y:
			continue
		var fade := 1.0 - float(dy - WATER_Y) / 96.0
		if fade <= 0.0:
			continue
		_px(x + wob, dy, Color(rc.r, rc.g, rc.b, clampf(fade, 0.0, 1.0) * 0.72))


# ---------------------------------------------------------------- stilt houses
func _bamboo_cluster(x: int, count: int, haze: float) -> void:
	# thin poles sticking out of the water (fish-trap frames), slight lean and varied height.
	var col := POLE.lerp(HAZE_BLUE, haze * 0.6)
	for k in range(count):
		var px := x + k * (4 + int(_hash(x * 3 + k) * 5))
		var ph := 14 + int(_hash(x * 7 + k) * 22)
		var lean := int((_hash(x * 5 + k) - 0.5) * 6)
		_line(Vector2(px, WATER_Y + 2), Vector2(px + lean, WATER_Y + 2 - ph), col, 1)
	if _hash(x) < 0.5 and count >= 3:
		_line(Vector2(x, WATER_Y - 8), Vector2(x + (count - 1) * 6, WATER_Y - 14), col, 1)


func _stilt_house(x: int, base_y: int, w: int, hbody: int, wall: Color, roof: Color, haze: float, seedn: int) -> void:
	# wooden house body on poles over water, with a pitched roof; reflected below.
	var wall_c := wall.lerp(HAZE_BLUE, haze)
	var roof_c := roof.lerp(HAZE_BLUE, haze)
	var pole_c := POLE.lerp(HAZE_BLUE, haze)

	# stilts down to the water
	var leg_top := base_y
	var n_legs := maxi(2, int(w / 14))
	for l in range(n_legs):
		var lx := x + 3 + int(float(l) / float(n_legs - 1) * (w - 6))
		_rect(lx, leg_top, 2, WATER_Y - leg_top + 3, pole_c)

	# body
	var body_top := base_y - hbody
	_rect(x, body_top, w, hbody, wall_c)
	_rect(x, body_top, w, 2, Color(1, 1, 1, 0.10 * (1.0 - haze)))
	_rect(x, body_top, 2, hbody, Color(0, 0, 0, 0.18 * (1.0 - haze)))
	_rect(x + w - 2, body_top, 2, hbody, Color(0, 0, 0, 0.22 * (1.0 - haze)))

	# windows / door
	var ww := 3 + int(haze < 0.3)
	var cols := maxi(1, int((w - 6) / 10))
	for cx in range(cols):
		if _hash(seedn * 31 + cx) < 0.7:
			var wx := x + 5 + cx * 10
			_rect(wx, body_top + int(hbody * 0.35), ww, maxi(3, int(hbody * 0.3)), Color8(58, 70, 86).lerp(HAZE_BLUE, haze))
	if w > 40:
		_rect(x + w / 2 - 2, base_y - int(hbody * 0.55), 5, int(hbody * 0.55), WALL_DARK.lerp(HAZE_BLUE, haze))

	# pitched roof (overhanging trapezoid) + ridge highlight
	var roof_h := maxi(6, int(hbody * 0.55))
	var roof_top := body_top - roof_h
	_trap(x + w / 2, roof_top, int(w * 0.30), int(w * 1.18), roof_h, roof_c)
	_rect(x - int(w * 0.06), roof_top, int(w * 1.12), 2, roof_c.lightened(0.18))
	for r in range(1, 3):
		_rect(x - int(w * 0.05), roof_top + int(roof_h * float(r) / 3.0), int(w * 1.1), 1, Color(0, 0, 0, 0.10 * (1.0 - haze)))

	# reflection
	if haze < 0.45:
		for xx in range(x - int(w * 0.06), x + int(w * 1.06)):
			_reflect_col(xx, roof_top, base_y - roof_top, wall.lerp(roof, 0.5), 0.35)


func _house_band(base_y: int, hmin: int, hmax: int, wmin: int, wmax: int, haze: float, seed: int) -> void:
	var roofs := [ROOF_RED, ROOF_GREY, ROOF_GREEN, ROOF_RUST, ROOF_RED, ROOF_GREY]
	var walls := [WALL_WOOD, WALL_DARK, WALL_WOOD]
	var x := -60.0
	var i := 0
	var cluster_left := 0
	while x < _w + 60:
		var s := seed * 1000 + i
		var e := _envelope(x + float(seed) * 130.0)
		var w := int(wmin + _hash(s * 9 + 2) * (wmax - wmin))
		var hbody := clampi(int((hmin + e * (hmax - hmin)) * (0.8 + _hash(s * 5 + 7) * 0.5)), hmin, int(hmax * 1.15))
		var roof: Color = roofs[int(_hash(s * 13) * roofs.size()) % roofs.size()]
		var wall: Color = walls[int(_hash(s * 17) * walls.size()) % walls.size()]
		var by := base_y + int(_hash(s * 3) * 6)
		_stilt_house(int(x), by, w, hbody, wall, roof, haze, s)
		# Irregular spacing: mostly modest gaps, hash^2 opens some into wide open water; a cluster
		# mode occasionally bunches 2-3 houses nearly adjacent, then forces a large gap after.
		var gap: float
		if cluster_left > 0:
			gap = 4.0 + _hash(s * 11) * 10.0
			cluster_left -= 1
			if cluster_left == 0:
				gap += 120.0 + _hash(s * 31) * 180.0
		else:
			var g := _hash(s * 11)
			gap = 16.0 + g * g * 260.0
			if _hash(s * 37) < 0.28:
				cluster_left = 1 + int(_hash(s * 41) * 2.0)
		if _hash(s * 23) < 0.55:
			_bamboo_cluster(int(x) + w + 6 + int(_hash(s * 19) * 14), 3 + int(_hash(s * 29) * 3), haze)
		x += w + gap
		i += 1


# ---------------------------------------------------------------- signature landmarks (mid layer)
func _landmarks(level_w: float) -> void:
	# A larger multi-tier roofed house and a long-tail boat, spread out (not on a fixed repeat) with
	# hash-jittered placement across the length so a long stage never looks tiled.
	var x := 620.0
	var n := 0
	while x < float(_w):
		if n % 2 == 0:
			_temple_at(int(x))
		else:
			_boat(int(x), WATER_Y + 46 + int(_hash(n * 7) * 40), 1.0 + _hash(int(x)) * 0.3)
		x += 1700.0 + _hash(n * 17) * 1300.0
		n += 1


func _temple_at(cx: int) -> void:
	# A larger multi-tier roofed house — the village's standout structure.
	var base_y := WATER_Y - 12
	var w := 112
	var hbody := 70
	var wall_c := Color8(140, 96, 72)
	var roof_c := ROOF_RED
	var pole_c := POLE
	var x := cx - w / 2

	# stilts
	for l in range(6):
		var lx := x + 4 + int(float(l) / 5.0 * (w - 8))
		_rect(lx, base_y, 3, WATER_Y - base_y + 3, pole_c)

	# body
	var body_top := base_y - hbody
	_rect(x, body_top, w, hbody, wall_c)
	_rect(x, body_top, w, 2, Color(1, 1, 1, 0.12))
	_rect(x, body_top, 2, hbody, Color(0, 0, 0, 0.18))
	_rect(x + w - 2, body_top, 2, hbody, Color(0, 0, 0, 0.22))
	_rect(x, base_y - int(hbody * 0.42), w, 2, Color8(180, 150, 120))
	for cxi in range(8):
		_rect(x + 8 + cxi * 13, body_top + 16, 6, 18, Color8(60, 74, 92))
	_rect(cx - 4, base_y - int(hbody * 0.5), 9, int(hbody * 0.5), WALL_DARK)

	# stacked roofs (three tiers) for a distinct silhouette
	var tier_w := float(w) * 1.30
	var ty := body_top
	for tier in range(3):
		var rh := 22 - tier * 4
		ty -= rh
		_trap(cx, ty, int(tier_w * 0.30), int(tier_w), rh, roof_c)
		_rect(cx - int(tier_w) / 2, ty, int(tier_w), 2, roof_c.lightened(0.22))
		_px(cx - int(tier_w) / 2, ty, roof_c.lightened(0.3))
		_px(cx + int(tier_w) / 2 - 1, ty, roof_c.lightened(0.3))
		tier_w *= 0.7
	# finial spire
	_rect(cx - 1, ty - 16, 3, 16, Color8(210, 180, 120))
	for k in range(3):
		_disc(Vector2(cx, ty - 4 - k * 5), 3.0, Color8(232, 202, 132))
	_disc(Vector2(cx, ty - 18), 4.0, Color8(244, 216, 150))

	# reflection
	for xx in range(x - 14, x + w + 14):
		_reflect_col(xx, int(ty), base_y - int(ty), roof_c.lerp(wall_c, 0.5), 0.3)


func _boat(cx: int, cy: int, scale: float) -> void:
	# slender long-tail canoe with a standing figure; faint wake.
	var hull := Color8(58, 44, 34)
	var hull_lit := Color8(96, 74, 54)
	var bw := int(110 * scale)
	var bh := int(9 * scale)
	_rect(cx - bw / 2 - int(40 * scale), cy + 1, int(60 * scale), 2, Color(0.9, 0.96, 1.0, 0.25))
	_rect(cx - bw / 2 - int(20 * scale), cy + 4, int(40 * scale), 2, Color(0.9, 0.96, 1.0, 0.15))
	for r in range(bh):
		var t := float(r) / float(bh)
		var narrow := int(lerpf(0.0, float(bw) * 0.16, t))
		_rect(cx - bw / 2 + narrow, cy + r, bw - narrow * 2, 1, hull)
	_rect(cx - bw / 2, cy - 1, bw, 1, hull_lit)
	_line(Vector2(cx - bw / 2, cy), Vector2(cx - bw / 2 - int(10 * scale), cy - int(8 * scale)), hull, 2)
	_line(Vector2(cx + bw / 2, cy), Vector2(cx + bw / 2 + int(12 * scale), cy - int(7 * scale)), hull, 2)
	# standing figure (silhouette with a conical hat)
	var fx := cx + int(bw * 0.18)
	var fy := cy - int(2 * scale)
	_rect(fx - 2, fy - int(22 * scale), 4, int(22 * scale), Color8(46, 40, 50))
	_disc(Vector2(fx, fy - int(24 * scale)), 3.0 * scale, Color8(46, 40, 50))
	_trap(fx, fy - int(30 * scale), 1, int(14 * scale), int(6 * scale), Color8(206, 178, 120))
	_line(Vector2(fx, fy - int(14 * scale)), Vector2(cx - int(bw * 0.36), cy + int(10 * scale)), Color8(70, 54, 40), 1)
