extends "res://scripts/backdrops/BackdropBase.gd"
## Stage theme: warm golden-hour rooftop city. Static peach/gold sky + a slow cloud layer + hazy
## blue-green hills on a slow layer + terracotta-tiled rooftop rows back->front at increasing
## motion, with cream-stone walls and warm windows. A great ribbed dome and several slender bell
## towers are distributed across a mid/near layer as non-repeating vertical accents. No play-field
## platforms are drawn here — those are the live level geometry. Mirrors City.gd's structure.

# ---- palette (warm golden-hour mood) ----------------------------------------
const SKY_TOP := Color8(126, 154, 196)        # soft warm blue overhead
const SKY_HORIZON := Color8(252, 214, 158)    # peach/gold near the horizon
const GLOW := Color8(255, 196, 120)           # hazy warm horizon band
const HILL_FAR := Color8(150, 168, 168)       # hazy blue-green ridge, farthest
const HILL_MID := Color8(122, 150, 146)
const HILL_NEAR := Color8(96, 132, 124)
const HAZE := Color8(244, 210, 168)           # atmospheric tint distant shapes lerp toward
const STONE := Color8(232, 214, 184)          # cream stone wall
const STONE_DK := Color8(206, 184, 150)
const SHUTTER := Color8(150, 116, 78)         # window shutter / opening
const LIT := Color8(255, 206, 120)            # warm lit window glow
const RIDGE_LT := Color8(255, 232, 188)       # bright roof ridge highlight
const DOME := Color8(196, 96, 56)             # great dome terracotta
const DOME_LT := Color8(224, 130, 78)
const DOME_DK := Color8(150, 66, 42)

# Layer pixel heights (taller than the rows reach; bottom-anchored to the horizon).
const HILL_H := 600
const ROW_H := 720
const LAND_H := 720


func build(level_w: float, view_w: int, view_h: int) -> Dictionary:
	# Static golden-hour sky: warm blue overhead easing to peach/gold near the horizon.
	var sky := _fresh(view_w, view_h)
	_vgrad(SKY_TOP, SKY_HORIZON, 1.5)
	for y in range(430, 600):
		var a := (1.0 - absf(float(y) - 512.0) / 84.0) * 0.30
		if a > 0.0:
			_rect(0, y, view_w, 1, Color(GLOW.r, GLOW.g, GLOW.b, a))

	# Warm-lit clouds: a high, slow layer that barely tracks the camera.
	var clouds := _fresh(_layer_w(level_w, 0.06, view_w), 320)
	_clouds()

	# Hazy blue-green hills: a slow distant layer, bottom-anchored to the horizon.
	var hills := _fresh(_layer_w(level_w, 0.10, view_w), HILL_H)
	_hills()

	# Rooftop seas, back->front, hazier/higher/smaller farther back. base_y values are tuned so
	# that, with the layer bottom-anchored to the horizon, the rooftop sea fills the lower frame.
	var far := _fresh(_layer_w(level_w, 0.20, view_w), ROW_H)
	_roof_band(360.0, 40, 110, 50, 96, Color8(214, 150, 96), Color8(228, 172, 112), 0.58, 0.12, 0.60, 11)

	var mid := _fresh(_layer_w(level_w, 0.40, view_w), ROW_H)
	_roof_band(470.0, 70, 200, 96, 172, Color8(200, 116, 66), Color8(222, 146, 84), 0.18, 0.36, 0.54, 37)

	# Landmark layer: the great dome + slender bell towers, distributed across the full width.
	var land := _fresh(_layer_w(level_w, 0.50, view_w), LAND_H)
	_landmarks()

	var near := _fresh(_layer_w(level_w, 0.62, view_w), ROW_H)
	_roof_band(600.0, 90, 280, 116, 200, Color8(192, 104, 58), Color8(216, 138, 76), 0.05, 0.46, 0.52, 53)

	return {
		"sky": sky,
		"layers": [
			{"image": clouds, "motion": 0.06, "top": 40.0, "anchor_bottom": false},
			{"image": hills, "motion": 0.10, "top": 0.0, "anchor_bottom": true},
			{"image": far, "motion": 0.20, "top": 0.0, "anchor_bottom": true},
			{"image": mid, "motion": 0.40, "top": 0.0, "anchor_bottom": true},
			{"image": land, "motion": 0.50, "top": 0.0, "anchor_bottom": true},
			{"image": near, "motion": 0.62, "top": 0.0, "anchor_bottom": true},
		],
	}


# ---------------------------------------------------------------- clouds
func _clouds() -> void:
	var n := maxi(3, int(_w / 360))
	for i in range(n):
		var cx := int((_hash(i * 17 + 3) * 0.94 + 0.03) * _w)
		var cy := 40 + int(_hash(i * 31 + 5) * 150.0)
		var s := 0.7 + _hash(i * 13 + 1) * 0.9
		_cloud(Vector2(cx, cy), s)


func _cloud(pos: Vector2, s: float) -> void:
	var body := Color(1.0, 0.93, 0.84, 0.85)
	var lit := Color(1.0, 0.88, 0.70, 0.9)      # warm underside catching the low sun
	var lobes := [
		Vector2(-46, 4), Vector2(-22, -8), Vector2(4, -12),
		Vector2(30, -6), Vector2(52, 2), Vector2(18, 6), Vector2(-10, 8),
	]
	for l in lobes:
		var lv: Vector2 = l
		_disc(pos + lv * s, (14.0 + _hash(int(lv.x) * 7) * 8.0) * s, body)
	for l in [Vector2(-30, 9), Vector2(0, 11), Vector2(28, 9)]:
		var lv2: Vector2 = l
		_disc(pos + lv2 * s, 9.0 * s, lit)


# ---------------------------------------------------------------- hills
func _hills() -> void:
	# 3 overlapping sine ridgelines, hazier/lighter farther back (atmospheric perspective).
	# Drawn in this short layer's local space; its bottom sits on the horizon when mounted.
	_ridge(116.0, 30.0, 0.0038, 0.011, 0.0, HILL_FAR, 0.62)
	_ridge(142.0, 34.0, 0.0029, 0.009, 1.7, HILL_MID, 0.50)
	_ridge(168.0, 26.0, 0.0052, 0.015, 3.4, HILL_NEAR, 0.40)


func _ridge(base_y: float, amp: float, f1: float, f2: float, phase: float, col: Color, haze: float) -> void:
	var c := col.lerp(HAZE, haze)
	for x in range(_w):
		var ridge := base_y - (amp * (0.5 + 0.5 * sin(x * f1 + phase)) + 0.5 * amp * sin(x * f2 + phase * 2.0))
		_rect(x, int(ridge), 1, _h - int(ridge), c)


# ---------------------------------------------------------------- rooftop houses
func _windows(x: int, top: int, w: int, h: int, seedn: int, density: float, haze: float) -> void:
	# small shuttered windows on a cream-stone wall; some warm-lit
	var step := 13
	var cols := int((w - 8) / step)
	var rows := int((h - 6) / step)
	for cy in range(rows):
		for cx in range(cols):
			var idx := seedn * 131 + cy * 17 + cx * 3
			if _hash(idx) > density:
				continue
			var wx := x + 6 + cx * step
			var wy := top + 5 + cy * step
			var is_lit := _hash(idx * 5) < 0.34
			var col: Color = (LIT if is_lit else SHUTTER).lerp(HAZE, haze * 0.7)
			var a := (0.8 if is_lit else 0.62) * (1.0 - haze * 0.5)
			_rect(wx, wy, 5, 6, Color(col.r, col.g, col.b, a))


func _house(x: int, base_y: int, w: int, h: int, roof: Color, haze: float, seedn: int) -> void:
	# cream-stone wall body topped with a flared/pitched or gabled terracotta roof
	var roof_h := clampi(int(h * 0.40), 12, 60)
	var wall_h := h - roof_h
	var wall_top := base_y - wall_h
	var roof_top := wall_top - roof_h
	var wall := STONE.lerp(STONE_DK, _hash(seedn * 3)).lerp(HAZE, haze)
	var r2 := roof.lerp(HAZE, haze)
	_rect(x, wall_top, w, wall_h, wall)
	_rect(x, wall_top, w, 2, Color(0, 0, 0, 0.16 * (1.0 - haze)))  # eave shadow
	_rect(x + int(w * 0.66), wall_top, int(w * 0.34), wall_h, Color(0, 0, 0, 0.10 * (1.0 - haze)))
	_windows(x, wall_top, w, wall_h, seedn, 0.45 - haze * 0.2, haze)

	var k := int(_hash(seedn * 7) * 3)
	if k == 0:
		# flared pitched roof (wider eaves than ridge)
		_trap(x + w / 2, roof_top, int(w * 0.34), int(w * 1.12), roof_h, r2)
	elif k == 1:
		# gabled block: flat-ish low pitch
		_trap(x + w / 2, roof_top + int(roof_h * 0.4), int(w * 0.6), int(w * 1.04), int(roof_h * 0.6), r2)
		_rect(x, roof_top + int(roof_h * 0.4), w, int(roof_h * 0.4), r2.darkened(0.06))
	else:
		# asymmetric mono-pitch shed roof (orientation variety)
		var dir := 1 if _hash(seedn * 11) < 0.5 else -1
		for r in range(roof_h + 1):
			var t := float(r) / float(roof_h)
			var ww := int(lerpf(float(w) * 1.06, float(w) * 0.5, t)) if dir > 0 else int(lerpf(float(w) * 0.5, float(w) * 1.06, t))
			var ox := x if dir > 0 else x + w - ww
			_rect(ox - int(w * 0.03), roof_top + r, ww, 1, r2)
	# bright ridge highlight + tile shading lines
	_rect(x - int(w * 0.04), roof_top - 1, int(w * 1.08), 2, Color(RIDGE_LT.r, RIDGE_LT.g, RIDGE_LT.b, 0.5 * (1.0 - haze)))
	for r in range(1, 3):
		_rect(x - int(w * 0.03), roof_top + int(roof_h * float(r) / 3.0), int(w * 1.06), 1, Color(0, 0, 0, 0.10 * (1.0 - haze)))


func _roof_band(base_y: float, hmin: int, hmax: int, wmin: int, wmax: int, roof_a: Color, roof_b: Color, haze: float, dens: float, step_frac: float, seed: int) -> void:
	var x := -90.0
	var i := 0
	while x < _w + 90:
		var s := seed * 1000 + i
		var e := _envelope(x + float(seed) * 130.0)
		var w := int(wmin + _hash(s * 9 + 2) * (wmax - wmin))
		var h := clampi(int((hmin + e * (hmax - hmin)) * (0.80 + _hash(s * 5 + 7) * 0.5)), hmin, int(hmax * 1.12))
		var roof := roof_a.lerp(roof_b, _hash(s * 4))  # vary ochre so the sea never tiles
		_house(int(x), int(base_y), w, h, roof, haze, s)
		x += maxf(float(w) * step_frac, 16.0)
		i += 1


# ---------------------------------------------------------------- landmark distribution
func _landmarks() -> void:
	# Distribute the great dome and slender bell towers across the full width via a while-loop
	# with hash jitter, so positions never repeat and the long stage never looks tiled. A dome
	# appears occasionally; bell towers fill the gaps between — several, not a forest.
	var x := 240.0
	var n := 0
	while x < float(_w):
		var jitter := _hash(n * 23 + 5)
		if n % 3 == 0:
			# the great ribbed dome (size varies slightly per instance)
			_great_dome(Vector2(x, 470.0), 0.86 + jitter * 0.18)
		else:
			var height := 250.0 + _hash(n * 17 + 2) * 80.0
			var sc := 0.78 + _hash(n * 11 + 7) * 0.16
			var stone := STONE.lerp(STONE_DK, _hash(n * 13) * 0.5)
			var tiers := 4 + int(_hash(n * 7) * 2.0)
			_bell_tower(Vector2(x, 480.0), height, sc, stone, tiers)
		x += 900.0 + jitter * 800.0
		n += 1


# Upper half of a disc (dome cap): paints only rows at or above the center y. A small local
# shape helper built from the inherited per-pixel primitive (the base has no half-disc).
func _dome_cap(center: Vector2, r: float, c: Color) -> void:
	var r2 := r * r
	for yy in range(int(center.y - r), int(center.y) + 1):
		for xx in range(int(center.x - r), int(center.x + r) + 1):
			var dx := float(xx) - center.x
			var dy := float(yy) - center.y
			if dx * dx + dy * dy <= r2:
				_px(xx, yy, c)


func _great_dome(pos: Vector2, scale: float) -> void:
	# great ribbed terracotta dome on a cream octagonal drum, with a lantern cupola on top
	var cx := int(pos.x)
	var base_y := int(pos.y)
	var dome_r := 78.0 * scale

	# octagonal cream drum the dome sits on
	var drum_w := int(dome_r * 1.7)
	var drum_h := int(58 * scale)
	_rect(cx - drum_w / 2, base_y - drum_h, drum_w, drum_h, STONE)
	_rect(cx - drum_w / 2, base_y - drum_h, drum_w, 3, Color(0, 0, 0, 0.12))
	for wi in range(4):
		var wx := cx - drum_w / 2 + int(drum_w * (0.18 + 0.21 * wi))
		_disc(Vector2(wx, base_y - drum_h / 2), 4.0 * scale, SHUTTER.darkened(0.1))

	# the dome: stacked half-discs darkening downward for a domed read
	var dome_base_y := base_y - drum_h
	_dome_cap(Vector2(cx, dome_base_y), dome_r, DOME_DK)
	_dome_cap(Vector2(cx, dome_base_y), dome_r * 0.97, DOME)
	_dome_cap(Vector2(cx - dome_r * 0.16, dome_base_y), dome_r * 0.78, DOME_LT)  # left-lit crescent
	_dome_cap(Vector2(cx, dome_base_y), dome_r * 0.62, DOME)
	# vertical ribs converging at the apex (stylized flat ribbing)
	var ribs := 7
	for ri in range(ribs):
		var t := float(ri) / float(ribs - 1)
		var bx := cx + int(lerpf(-dome_r * 0.92, dome_r * 0.92, t))
		_line(Vector2(cx, dome_base_y - dome_r), Vector2(bx, dome_base_y), DOME_DK, maxi(1, int(scale * 1.5)))

	# lantern cupola on top (sits well inside the frame)
	var lan_w := int(20 * scale)
	var lan_h := int(30 * scale)
	var apex_y := dome_base_y - int(dome_r)
	_rect(cx - lan_w / 2, apex_y - lan_h, lan_w, lan_h, STONE)
	_rect(cx - lan_w / 2, apex_y - lan_h, lan_w, lan_h, Color(LIT.r, LIT.g, LIT.b, 0.18))
	_rect(cx - int(lan_w * 0.18), apex_y - lan_h + int(lan_h * 0.3), int(lan_w * 0.36), int(lan_h * 0.5), SHUTTER)
	_trap(cx, apex_y - lan_h - int(14 * scale), 2, lan_w, int(14 * scale), DOME_DK)  # conical cap
	_rect(cx - 1, apex_y - lan_h - int(24 * scale), 2, int(10 * scale), Color8(214, 176, 96))
	_disc(Vector2(cx, apex_y - lan_h - int(24 * scale)), 3.0 * scale, Color8(236, 200, 120))  # finial


func _bell_tower(pos: Vector2, height: float, scale: float, stone: Color, tiers: int) -> void:
	# A standalone tall slender bell tower rising above the rooftop sea: light-stone shaft with
	# banded tiers, paired arched openings, and a crenellated cap. A special vertical accent.
	var cx := int(pos.x)
	var base_y := int(pos.y)
	var tw := int(34 * scale)
	var tx := cx - tw / 2
	var t_top := base_y - int(height)
	if t_top < 26:
		t_top = 26  # keep the cap inside the frame
	var shaft_h := base_y - t_top
	var stone_dk := stone.darkened(0.10)
	_rect(tx, t_top, tw, shaft_h, stone)
	_rect(tx + int(tw * 0.7), t_top, int(tw * 0.3), shaft_h, Color(0, 0, 0, 0.10))  # shaded side
	for ti in range(tiers):
		var ty := t_top + int(float(shaft_h) * (0.10 + (0.86 / float(tiers)) * ti))
		_rect(tx - 1, ty, tw + 2, 3, stone_dk)
		_rect(tx + int(tw * 0.20), ty + 6, int(tw * 0.18), int(15 * scale), SHUTTER)
		_rect(tx + int(tw * 0.60), ty + 6, int(tw * 0.18), int(15 * scale), SHUTTER)
	# crenellated cap (must not clip top)
	_rect(tx - 2, t_top - int(8 * scale), tw + 4, int(8 * scale), stone_dk)
	for cbi in range(3):
		_rect(tx + 2 + cbi * int(tw * 0.34), t_top - int(15 * scale), int(tw * 0.2), int(8 * scale), stone_dk)
