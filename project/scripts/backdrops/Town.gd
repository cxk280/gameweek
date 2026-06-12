extends "res://scripts/backdrops/BackdropBase.gd"
## Stage theme: dusk old town. Static lavender->peach sky + a far hazy ridge on a slow layer +
## three tiled-rooftop rows back->front (warm lantern-lit windows) + tiered-tower landmarks
## distributed across a mid layer. Bottom-anchored ground rows; no foreground play-field strip
## (those ledges are live level geometry). Mirrors the City exemplar's structure.

const HAZE := Color(0.91, 0.79, 0.72)        # warm horizon haze for atmospheric perspective
const AMBER := Color8(255, 186, 96)          # lantern-lit windows
const RIDGE := Color8(150, 146, 156)         # distant tree-covered hills


func build(level_w: float, view_w: int, view_h: int) -> Dictionary:
	var sky := _fresh(view_w, view_h)
	_vgrad(Color8(150, 150, 174), Color8(232, 202, 184), 1.6)
	_dusk_glow()

	# far hazy ridge: very slow, near-static distance
	var hills := _fresh(_layer_w(level_w, 0.10, view_w), 720)
	_hills()

	# tiered-tower landmarks distributed across a mid layer
	var towers := _fresh(_layer_w(level_w, 0.30, view_w), 720)
	_towers()

	# tiled-rooftop rows, back -> front at increasing motion. base_y kept well above the layer
	# bottom so the lantern-lit walls land in the visible frame (the preview clips ~180px of the
	# bottom-anchored layers below the horizon line).
	var far := _fresh(_layer_w(level_w, 0.20, view_w), 720)
	_roof_band(470, 70, 150, 80, 150, Color8(96, 78, 66), Color8(120, 98, 82), Color8(120, 120, 140), 0.34, 0.22, 0.66, 24)

	var mid := _fresh(_layer_w(level_w, 0.40, view_w), 720)
	_roof_band(540, 100, 210, 100, 175, Color8(78, 60, 48), Color8(104, 80, 62), Color8(96, 98, 118), 0.16, 0.34, 0.60, 36)

	var near := _fresh(_layer_w(level_w, 0.60, view_w), 720)
	_roof_band(620, 130, 270, 120, 200, Color8(66, 50, 40), Color8(92, 68, 52), Color8(80, 82, 102), 0.04, 0.42, 0.56, 52)

	return {
		"sky": sky,
		"layers": [
			{"image": hills, "motion": 0.10, "top": 0.0, "anchor_bottom": true},
			{"image": towers, "motion": 0.30, "top": 0.0, "anchor_bottom": true},
			{"image": far, "motion": 0.20, "top": 0.0, "anchor_bottom": true},
			{"image": mid, "motion": 0.40, "top": 0.0, "anchor_bottom": true},
			{"image": near, "motion": 0.60, "top": 0.0, "anchor_bottom": true},
		],
	}


func _dusk_glow() -> void:
	# warm band of light along the horizon line
	for y in range(360, 520):
		var a := (1.0 - absf(float(y) - 448.0) / 80.0) * 0.20
		if a > 0.0:
			_rect(0, y, _w, 1, Color(1.0, 0.70, 0.45, a))


func _hills() -> void:
	# soft, hazy ridge far behind the town, undulating along the full length
	var base := float(_h) - 268.0
	for x in range(_w):
		var ridge := base - (20.0 + 16.0 * sin(x * 0.0042) + 9.0 * sin(x * 0.013 + 1.0))
		_rect(x, int(ridge), 1, 150, Color(RIDGE.r, RIDGE.g, RIDGE.b, 0.5))


# ---------------------------------------------------------------- tiered-tower landmark
func _towers() -> void:
	var base_y := float(_h) - 218.0
	var x := 660.0
	var n := 0
	while x < float(_w):
		var scale := 1.6 + _hash(n * 17 + 3) * 0.35
		var jitter := (_hash(n * 23 + 5) - 0.5) * 24.0
		_tiered_tower(Vector2(x, base_y + jitter), scale)
		x += 2400.0 + _hash(n * 11) * 1100.0
		n += 1


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
		_trap(cx, y - roof_h, int(bw * 0.42), int(bw), roof_h, tile.lerp(HAZE, 0.2))
		_rect(cx - int(bw) / 2, y - 1, int(bw), 2, Color(ridge.r, ridge.g, ridge.b, 0.6))
		y -= roof_h
		bw *= 0.82
	# finial spire
	_rect(cx - 1, y - int(32 * scale), 2, int(32 * scale), Color8(140, 116, 80))
	for k in range(4):
		_disc(Vector2(cx, y - 4 - k * int(7 * scale)), 3.0 * scale, Color8(160, 132, 86))
	_disc(Vector2(cx, y - int(34 * scale)), 4.0 * scale, Color8(180, 150, 96))


# ---------------------------------------------------------------- tiled-rooftop rows
func _roof_band(base_y: float, hmin: int, hmax: int, wmin: int, wmax: int, wood_a: Color, wood_b: Color, tile: Color, haze: float, lantern_d: float, step_frac: float, seed: int) -> void:
	var x := -80.0
	var i := 0
	while x < float(_w) + 80.0:
		var s := seed * 1000 + i
		var e := _envelope(x + float(seed) * 120.0)
		var w := int(wmin + _hash(s * 9 + 2) * (wmax - wmin))
		var hh := clampi(int((hmin + e * (hmax - hmin)) * (0.82 + _hash(s * 5 + 7) * 0.4)), hmin, int(hmax * 1.1))
		var wood := wood_a.lerp(wood_b, _hash(s * 4))
		_house(int(x), int(base_y), w, hh, wood, tile, haze, lantern_d * (1.0 - haze * 0.4), s)
		x += maxf(w * step_frac, 14.0)
		i += 1


func _house(x: int, base_y: int, w: int, h: int, wood: Color, tile: Color, haze: float, lantern_d: float, seed: int) -> void:
	var roof_h := int(h * 0.46)
	var wall_h := h - roof_h
	var wall_top := base_y - wall_h
	var roof_top := wall_top - roof_h
	var w2 := wood.lerp(HAZE, haze)
	var t2 := tile.lerp(HAZE, haze)
	# wall extends to the bottom of the layer so rows read as solid massing when stacked
	_rect(x, wall_top, w, _h - wall_top, w2)
	_rect(x, wall_top, w, 3, Color(0, 0, 0, 0.25 * (1.0 - haze)))
	_lanterns(x, wall_top, w, wall_h, seed, lantern_d, haze)
	_trap(x + w / 2, roof_top, int(w * 0.5), int(w * 1.16), roof_h, t2)
	for r in range(1, 3):
		_rect(x - int(w * 0.05), roof_top + int(roof_h * float(r) / 3.0), int(w * 1.1), 1, Color(0, 0, 0, 0.12 * (1.0 - haze)))
	_rect(x + int(w * 0.25), roof_top, int(w * 0.5), 2, Color(0.9, 0.84, 0.8, 0.4 * (1.0 - haze)))


func _lanterns(x: int, top: int, w: int, h: int, seed: int, density: float, haze: float) -> void:
	var step := 13
	var cols := int((w - 8) / step)
	var rows := int((h - 8) / step)
	for cy in range(rows):
		for cx in range(cols):
			var idx := seed * 97 + cy * 13 + cx * 5
			if _hash(idx) > density:
				continue
			var a := (0.55 + _hash(idx * 3) * 0.4) * (1.0 - haze * 0.7)
			var wx := x + 6 + cx * step
			var wy := top + 6 + cy * step
			_rect(wx - 2, wy - 2, 10, 10, Color(AMBER.r, AMBER.g, AMBER.b, a * 0.22))
			_rect(wx, wy, 6, 6, Color(AMBER.r, AMBER.g, AMBER.b, a))
