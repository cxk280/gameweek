extends "res://scripts/backdrops/BackdropBase.gd"
## Stage theme: overcast brick valley town. Static muted gray-white overcast sky + two misty
## forested ridge layers (very slow, grayer/hazier farther back) + two red-brick building rows
## (nearer, faster) with painted-facade variety and small windows. White church steeples, a
## painted mural wall, and a smokestack mill are distributed as landmarks across the mid row.
## Wider, irregular building spacing lets misty green show between blocks. No play-field platforms.

# muted, cool palette: brick reds/browns, painted facades, misty greens, overcast sky
const SKY_TOP := Color8(196, 200, 208)
const SKY_HORIZON := Color8(222, 224, 226)
const HAZE := Color8(214, 216, 220)        # distance fade target (overcast mist)
const GLASS := Color8(120, 132, 144)       # cool gray window glass
const WARM_LIT := Color8(248, 214, 150)    # a few warm-lit windows

const BRICKS := [
	Color8(150, 74, 60), Color8(128, 62, 52), Color8(166, 92, 70),
	Color8(112, 70, 58), Color8(138, 80, 64),
]
const PAINTED := [Color8(208, 196, 168), Color8(120, 138, 150), Color8(186, 150, 96)]  # cream, faded blue, ochre


func build(level_w: float, view_w: int, view_h: int) -> Dictionary:
	var sky := _fresh(view_w, view_h)
	_vgrad(SKY_TOP, SKY_HORIZON, 1.4)
	_sky_mist()

	# Bottom-anchored layers mount with their image bottom at the world horizon, so each image is
	# sized to the viewport and the content baseline sits a little below the visible ground line;
	# blank rows below the baseline simply fall past the bottom of the frame.
	var ground := float(view_h) - 280.0   # baseline (in image space) for ridge/building feet

	# Forested ridges hemming the valley: two slow bottom-anchored layers, hazier farther back.
	var ridge_far := _fresh(_layer_w(level_w, 0.08, view_w), view_h)
	_ridge(ground - 196.0, 70.0, Color8(150, 162, 158), 0.62, 0.0011, 0.0037, 0.0, 7)
	_ridge(ground - 148.0, 86.0, Color8(112, 134, 120), 0.42, 0.0015, 0.0049, 1.7, 19)

	var ridge_near := _fresh(_layer_w(level_w, 0.16, view_w), view_h)
	_ridge(ground - 100.0, 104.0, Color8(78, 112, 86), 0.20, 0.0019, 0.0061, 3.2, 31)

	# Receding brick downtown, far -> near: smaller/higher/hazier -> larger/lower/saturated.
	var brick_far := _fresh(_layer_w(level_w, 0.3, view_w), view_h)
	_block_band(ground, 40, 92, 60, 110, 0.40, 11, false)
	_block_band(ground, 60, 150, 80, 150, 0.22, 23, true)
	_landmarks(ground)

	var brick_near := _fresh(_layer_w(level_w, 0.5, view_w), view_h)
	_block_band(ground, 90, 210, 110, 185, 0.10, 37, true)

	return {
		"sky": sky,
		"layers": [
			{"image": ridge_far, "motion": 0.08, "top": 0.0, "anchor_bottom": true},
			{"image": ridge_near, "motion": 0.16, "top": 0.0, "anchor_bottom": true},
			{"image": brick_far, "motion": 0.3, "top": 0.0, "anchor_bottom": true},
			{"image": brick_near, "motion": 0.5, "top": 0.0, "anchor_bottom": true},
		],
	}


# ---------------------------------------------------------------- sky mist
func _sky_mist() -> void:
	# faint cool light band, then a few hints of low drifting mist (deterministic, non-repeating)
	for y in range(int(_h * 0.42), int(_h * 0.66)):
		var a := (1.0 - absf(float(y) - float(_h) * 0.54) / (float(_h) * 0.12)) * 0.10
		if a > 0.0:
			_rect(0, y, _w, 1, Color(0.86, 0.90, 0.94, a))
	for i in range(int(_w * 0.012) + 4):
		var mx := int(_hash(i * 17 + 5) * _w)
		var my := int(_h * 0.47) + int(_hash(i * 29 + 9) * (_h * 0.18))
		var mw := 80 + int(_hash(i * 13 + 1) * 220.0)
		_rect(mx, my, mw, 6 + int(_hash(i * 7) * 8.0), Color(0.92, 0.93, 0.95, 0.05))


# ---------------------------------------------------------------- forested ridges
func _ridge(base_y: float, amp: float, col: Color, haze: float, f1: float, f2: float, phase: float, seed: int) -> void:
	# misty tree-covered ridgeline: hazed fill + deterministic darker-green clusters (not noisy)
	var fill := col.lerp(HAZE, haze)
	var dark := Color8(int(col.r8 * 0.62), int(col.g8 * 0.66), int(col.b8 * 0.6)).lerp(HAZE, haze)
	for x in range(_w):
		var r := base_y - (amp * (0.5 + 0.5 * sin(x * f1 + phase)) + amp * 0.45 * (0.5 + 0.5 * sin(x * f2 + phase * 1.7)))
		_rect(x, int(r), 1, _h - int(r), fill)
	var step := 16
	var i := 0
	var cx := 0
	while cx < _w:
		var r := base_y - (amp * (0.5 + 0.5 * sin(cx * f1 + phase)) + amp * 0.45 * (0.5 + 0.5 * sin(cx * f2 + phase * 1.7)))
		var rows := int((float(_h) - r) / float(step))
		for ry in range(rows):
			var idx := seed * 211 + i * 7 + ry * 3
			if _hash(idx) > 0.34:
				continue
			var cy := int(r) + 4 + ry * step + int(_hash(idx * 2) * 5.0)
			var cw := 5 + int(_hash(idx * 3) * 6.0)
			_rect(cx + int(_hash(idx * 5) * step), cy, cw, cw, dark)
		cx += step
		i += 1
	for x2 in range(_w):
		var r2 := base_y - (amp * (0.5 + 0.5 * sin(x2 * f1 + phase)) + amp * 0.45 * (0.5 + 0.5 * sin(x2 * f2 + phase * 1.7)))
		_px(x2, int(r2), Color(HAZE.r, HAZE.g, HAZE.b, 0.4))


# ---------------------------------------------------------------- brick window grid
func _windows(bx: int, by: int, bw: int, bh: int, seedn: int, density: float, haze: float) -> void:
	var step := 12
	var cols := int((bw - 8) / step)
	var rows := int((bh - 12) / step)
	for cy in range(rows):
		for cx in range(cols):
			var idx := seedn * 131 + cy * 17 + cx * 3
			if _hash(idx) > density:
				continue
			var warm := _hash(idx * 5) < 0.16
			var col: Color = WARM_LIT if warm else GLASS
			var a := (0.55 + _hash(idx * 3) * 0.35) * (1.0 - haze * 0.6)
			_rect(bx + 6 + cx * step, by + 8 + cy * step, 5, 6, Color(col.r, col.g, col.b, a))


# rooftop variety props for a block (chunky, flat)
func _roof_prop(x: int, byt: int, bw: int, seedn: int, haze: float) -> void:
	var cx := x + bw / 2
	var k := int(_hash(seedn * 7) * 5)
	if k == 1:  # low parapet step
		var sw := int(bw * 0.5)
		_rect(cx - sw / 2, byt - 8, sw, 8, Color8(70, 64, 64).lerp(HAZE, haze))
	elif k == 2:  # rooftop box (HVAC)
		var tw := mini(26, int(bw * 0.5))
		_rect(cx - tw / 2, byt - 12, tw, 12, Color8(96, 96, 104).lerp(HAZE, haze))
		_rect(cx - tw / 2, byt - 12, tw, 2, Color8(132, 132, 140).lerp(HAZE, haze))
	elif k == 3 and haze < 0.3:  # short chimney
		_rect(cx - 4, byt - 16, 8, 16, Color8(108, 72, 60).lerp(HAZE, haze))


# ---------------------------------------------------------------- brick depth bands
func _block_band(base_y: float, hmin: int, hmax: int, wmin: int, wmax: int, haze: float, seed: int, feat: bool) -> void:
	# brick reds/browns plus a few painted facades; overlapping, varied so it never tiles
	var x := -90.0
	var i := 0
	while x < _w + 90:
		var s := seed * 1000 + i
		var e := _envelope(x + float(seed) * 140.0)
		var bw := int(wmin + _hash(s * 9 + 2) * (wmax - wmin))
		var bh := clampi(int((hmin + e * (hmax - hmin)) * (0.74 + _hash(s * 5 + 7) * 0.55)), hmin, int(hmax * 1.18))
		var byt := int(base_y) - bh
		var is_painted := _hash(s * 17) < 0.24
		var base: Color = PAINTED[int(_hash(s * 6) * PAINTED.size()) % PAINTED.size()] if is_painted else BRICKS[int(_hash(s * 4) * BRICKS.size()) % BRICKS.size()]
		var fill := base.lerp(HAZE, haze)
		_rect(int(x), byt, bw, _h - byt, fill)
		# shaded right portion for chunky volume
		_rect(int(x) + int(bw * 0.66), byt, int(bw * 0.34), _h - byt, Color(0, 0, 0, 0.14 * (1.0 - haze)))
		# flat/low roof cap line
		_rect(int(x), byt, bw, 2, base.darkened(0.25).lerp(HAZE, haze))
		if feat:
			_roof_prop(int(x), byt, bw, s, haze)
		_windows(int(x), byt, bw, _h - byt, s, (0.34 + _hash(s * 3) * 0.16) * (1.0 - haze * 0.4), haze)
		# Spread-out valley town: clear the full building width, then a large irregular gap so
		# misty hills show through between brick blocks (no packed wall).
		var gap := 40.0 + _hash(s * 11 + 5) * 130.0
		x += bw + gap
		i += 1


# ---------------------------------------------------------------- landmark distribution
# Spread the mill, mural wall, and several white steeples across the full width at irregular
# hash-jittered positions so a long stage never looks tiled or repeated.
func _landmarks(base_y: float) -> void:
	var kinds := ["mill", "mural", "steeple", "steeple", "steeple"]
	var x := 150.0
	var n := 0
	while x < float(_w) - 80.0:
		var px := int(x + (_hash(n * 13 + 3) - 0.5) * 260.0)
		match kinds[n % kinds.size()]:
			"mill": _mill(px, base_y, _hash(n * 5) * 0.10)
			"mural": _mural_wall(px, base_y, 0.04 + _hash(n * 7) * 0.10)
			"steeple":
				var sc := 0.7 + _hash(n * 9) * 0.5
				var bod := 150 + int(_hash(n * 11) * 120.0)
				_steeple(px, base_y, _hash(n * 17) * 0.16, sc, bod)
		x += 620.0 + _hash(n * 19) * 520.0
		n += 1


# ---------------------------------------------------------------- landmark: brick mill
func _mill(bx: int, base_y: float, haze: float) -> void:
	var bw := 116
	var bh := 300
	var byt := int(base_y) - bh
	var brick := Color8(140, 68, 56).lerp(HAZE, haze)
	_rect(bx, byt, bw, int(base_y) - byt, brick)
	_rect(bx + int(bw * 0.7), byt, int(bw * 0.3), int(base_y) - byt, Color(0, 0, 0, 0.14 * (1.0 - haze)))
	_rect(bx, byt, bw, 3, brick.darkened(0.3))
	# corbelled cornice band
	_rect(bx - 3, byt + 6, bw + 6, 6, brick.darkened(0.18))
	# dense window grid (commercial block)
	_windows(bx, byt + 18, bw, int(base_y) - byt - 18, 8801, 0.6, haze)
	# stair-step / tower parapet so it reads as a tall mill
	_rect(bx + bw / 2 - 16, byt - 18, 32, 18, brick.darkened(0.06))
	_rect(bx + bw / 2 - 16, byt - 20, 32, 3, brick.darkened(0.3))
	# tall smokestack beside it
	_rect(bx + bw - 14, byt - 70, 14, 70 + (int(base_y) - byt), brick.darkened(0.12).lerp(HAZE, haze * 1.2))
	_rect(bx + bw - 14, byt - 70, 14, 4, brick.darkened(0.3))


# ---------------------------------------------------------------- landmark: white church steeple
func _steeple(bx: int, base_y: float, haze: float, scale: float = 1.0, body_h: int = 210) -> void:
	var white := Color8(232, 230, 224).lerp(HAZE, haze)
	var shade := Color8(196, 196, 196).lerp(HAZE, haze)
	var body_top := int(base_y) - body_h   # sits on a church body above the rooftops
	var tw := int(36 * scale)
	var belfry := int(44 * scale)
	var spire_h := int(96 * scale)
	# church body / tower base
	_rect(bx, body_top, tw, body_h, white)
	_rect(bx + int(tw * 0.66), body_top, int(tw * 0.34), body_h, Color(0, 0, 0, 0.10 * (1.0 - haze)))
	# belfry box with arched openings
	_rect(bx + 2, body_top - belfry, tw - 4, belfry, white)
	_rect(bx + int(tw * 0.2), body_top - belfry + 6, maxi(3, int(8 * scale)), int(22 * scale), shade.darkened(0.25))
	_rect(bx + tw - int(tw * 0.2) - int(8 * scale), body_top - belfry + 6, maxi(3, int(8 * scale)), int(22 * scale), shade.darkened(0.25))
	_rect(bx + 2, body_top - belfry, tw - 4, 3, shade)
	# tapering white spire (clearly above rooftops)
	_trap(bx + tw / 2, body_top - belfry - spire_h, 4, tw - 6, spire_h, white)
	# spire shaded side for volume
	for r in range(spire_h):
		var w := int(lerpf(4.0, float(tw - 6), float(r) / float(spire_h)))
		_rect(bx + tw / 2 + w / 6, body_top - belfry - spire_h + r, maxi(1, w / 3), 1, Color(0, 0, 0, 0.08 * (1.0 - haze)))
	# finial
	_rect(bx + tw / 2 - 1, body_top - belfry - spire_h - int(10 * scale), 2, int(10 * scale), shade.darkened(0.2))
	_disc(Vector2(bx + tw / 2, body_top - belfry - spire_h - int(12 * scale)), 2.0 * scale, shade.darkened(0.2))


# ---------------------------------------------------------------- landmark: painted mural wall
func _mural_wall(bx: int, base_y: float, haze: float) -> void:
	var bw := 132
	var bh := 234
	var byt := int(base_y) - bh
	# host building (brick), mural painted on its broad side
	var brick := Color8(132, 70, 58).lerp(HAZE, haze)
	_rect(bx, byt, bw, int(base_y) - byt, brick)
	_rect(bx, byt, bw, 2, brick.darkened(0.3))
	# soft pastel scene block (mural accent) — sky, hills, water bands
	var mx := bx + 12
	var my := byt + 22
	var mw := bw - 24
	var mh := bh - 44
	var msky := Color8(176, 198, 214).lerp(HAZE, haze)       # pale mural sky
	var hill := Color8(150, 180, 150).lerp(HAZE, haze)       # soft green
	var water := Color8(150, 176, 192).lerp(HAZE, haze)      # pale water
	_rect(mx, my, mw, mh, msky)
	_rect(mx, my + int(mh * 0.46), mw, int(mh * 0.30), hill)
	# rolling hill silhouette top
	for c in range(mw):
		var hy := my + int(mh * 0.46) - int(6.0 * (0.5 + 0.5 * sin((mx + c) * 0.07)))
		_rect(mx + c, hy, 1, my + int(mh * 0.46) - hy, hill)
	_rect(mx, my + int(mh * 0.76), mw, int(mh * 0.24), water)
	# a sun disc + a few pastel tree dabs, all muted
	_disc(Vector2(mx + mw - 18, my + 16), 7.0, Color8(238, 224, 180).lerp(HAZE, haze))
	for t in range(3):
		var tx := mx + 14 + t * int(mw * 0.34)
		_rect(tx, my + int(mh * 0.42), 7, 14, Color8(96, 132, 96).lerp(HAZE, haze))
	# thin painted frame
	_rect(mx - 2, my - 2, mw + 4, 2, brick.darkened(0.4))
	_rect(mx - 2, my + mh, mw + 4, 2, brick.darkened(0.4))
	# a few real windows on the rest of the facade
	_windows(bx + bw - 20, byt + 10, 20, int(base_y) - byt - 10, 8820, 0.5, haze)
