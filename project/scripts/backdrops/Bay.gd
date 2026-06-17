extends "res://scripts/backdrops/BackdropBase.gd"
## Stage theme: bright tropical bay. Static blue sky + bay/sand band as the static base, stylized
## cumulus on a slow cloud layer, granite/green peaks layered slow->mid (farther = hazier/bluer)
## including a rounded peak with a thin cable-car line and a tall peak crowned by a pale hilltop
## statue with outstretched arms, then nearer shore-tower and multicolour hillside-house rows in
## tuned clustered/irregular spacing. Bottom-anchored peak/building rows; no foreground play-field
## platforms (those are live level geometry). Mirrors the City exemplar's structure.
##
## Geometry note: the live game flattens bottom-anchored layers with the image bottom below the
## viewport (horizon ~900 vs 720 view). All composition is authored in the upper ~540 rows of each
## 720-tall layer so the meaningful silhouette stays inside the visible window, and the static sky's
## lower band (bay + sand) is positioned to meet the peak feet at that same waterline.

# ----- palette (vivid tropical day) -----
const SKY_TOP := Color8(54, 138, 224)
const SKY_HZN := Color8(176, 222, 246)
const CLOUD := Color8(252, 252, 255)
const CLOUD_SH := Color8(214, 224, 240)

const PEAK_FAR := Color8(150, 178, 170)   # hazy bluish-green distant peaks
const PEAK_MID := Color8(96, 150, 96)
const PEAK_NEAR := Color8(58, 124, 70)    # lush near green
const GRANITE := Color8(150, 142, 138)    # granite dome rock
const GRANITE_SH := Color8(116, 108, 106)
const GRANITE_LIT := Color8(186, 180, 176)

const WATER_FAR := Color8(96, 178, 196)
const WATER_NEAR := Color8(40, 134, 170)
const SAND := Color8(238, 214, 158)
const SAND_SH := Color8(220, 192, 134)

const TOWER := Color8(244, 244, 238)      # white/cream city towers
const TOWER_SH := Color8(212, 212, 206)
const WINDOW := Color8(120, 150, 170)

const STATUE := Color8(238, 238, 232)     # pale stone statue
const STATUE_SH := Color8(198, 198, 192)

# hillside box colours (warm multicolour)
const HILLSIDE := [
	Color8(232, 120, 110), Color8(244, 168, 84), Color8(248, 214, 96),
	Color8(120, 196, 152), Color8(112, 168, 224), Color8(236, 146, 178),
	Color8(238, 110, 78), Color8(170, 206, 120), Color8(214, 232, 240),
]

# Waterline / band geometry shared across layers (image-row space, 720-tall layers).
const WATER_TOP := 470   # bay starts here on the static sky (screen-space) and peak feet meet it
const SAND_TOP := 528    # golden sand band begins (screen-space)
const SAND_BOT := 600    # sand band ends (rest of layer below the visible window)

# Bottom-anchored layers are mounted with their image bottom below the viewport (the live game uses
# horizon ~900 for 720-tall layers), so image-row R appears at screen y = R + ANCHOR_OFF. Peak/tower
# rows author their feet at (waterline - ANCHOR_OFF) so they meet the static bay band on screen.
const ANCHOR_OFF := 180
const PEAK_FOOT := WATER_TOP - ANCHOR_OFF   # 290: image-row waterline for anchored layers
const TOWER_FOOT := SAND_TOP - ANCHOR_OFF   # 348: image-row sand line for the shore-tower layer


func build(level_w: float, view_w: int, view_h: int) -> Dictionary:
	# Static sky: blue gradient + warm horizon wash + bay & sand as the lower band (no parallax).
	var sky := _fresh(view_w, view_h)
	_vgrad_bay()
	_bay_band(view_w, WATER_TOP, SAND_TOP, SAND_BOT)

	# Stylized cumulus on a slow (distant) layer so clouds drift gently.
	var clouds := _fresh(_layer_w(level_w, 0.06, view_w), 360)
	_clouds()

	# Granite/green peaks, slow -> mid (farther = hazier/bluer). Feet meet the static waterline.
	var peaks_far := _fresh(_layer_w(level_w, 0.10, view_w), 720)
	_peak_band(PEAK_FOOT - 14, 70.0, 168.0, PEAK_FAR, 0.55, 0.00210, 2.4, 9)

	var peaks_mid := _fresh(_layer_w(level_w, 0.18, view_w), 720)
	_peak_band(PEAK_FOOT - 4, 90.0, 196.0, PEAK_MID, 0.30, 0.00170, 3.0, 23)

	var peaks_near := _fresh(_layer_w(level_w, 0.26, view_w), 720)
	_peak_band(PEAK_FOOT, 96.0, 188.0, PEAK_NEAR, 0.12, 0.00150, 3.6, 41)
	# Bold rounded landmark peaks sit proud of the near band (drawn on top, not clipped):
	# the hilltop-statue peak, the cable-car dome, and spread lookout peaks. Distributed across the
	# full width with jitter so nothing tiles or repeats.
	for spot in _landmark_spots():
		var d: Dictionary = spot
		match int(d["kind"]):
			0: _statue_peak(int(d["x"]))
			1: _dome(int(d["x"]))
			_: _lookout_peak(int(d["x"]))
	# Multicolour hillside houses climbing the near green slopes (clustered/irregular spacing).
	_hillside_houses()

	# Shore towers: clustered/irregular spacing, nearer layer (~0.35).
	var towers := _fresh(_layer_w(level_w, 0.35, view_w), 720)
	_city_towers()

	return {
		"sky": sky,
		"layers": [
			{"image": clouds, "motion": 0.06, "top": 40.0, "anchor_bottom": false},
			{"image": peaks_far, "motion": 0.10, "top": 0.0, "anchor_bottom": true},
			{"image": peaks_mid, "motion": 0.18, "top": 0.0, "anchor_bottom": true},
			{"image": peaks_near, "motion": 0.26, "top": 0.0, "anchor_bottom": true},
			{"image": towers, "motion": 0.35, "top": 0.0, "anchor_bottom": true},
		],
	}


# ================================================================ sky + bay band (static)
func _vgrad_bay() -> void:
	for y in range(_h):
		var row := SKY_TOP.lerp(SKY_HZN, pow(float(y) / float(_h * 0.85), 1.1))
		for x in range(_w):
			_img.set_pixel(x, y, row)
	# warm sunlight wash near the horizon
	for y in range(WATER_TOP - 150, WATER_TOP):
		var a := (1.0 - absf(float(y) - float(WATER_TOP - 78)) / 92.0) * 0.10
		if a > 0.0:
			_rect(0, y, _w, 1, Color(1.0, 0.92, 0.74, a))


func _bay_band(view_w: int, water_top: int, sand_top: int, sand_bot: int) -> void:
	# blue-green bay gradient
	for y in range(water_top, sand_top):
		var t := float(y - water_top) / float(sand_top - water_top)
		_rect(0, y, view_w, 1, WATER_FAR.lerp(WATER_NEAR, t))
	# subtle horizontal ripples (deterministic)
	for y in range(water_top + 4, sand_top, 6):
		var a := 0.10 + _hash(y) * 0.06
		_rect(0, y, view_w, 1, Color(1, 1, 1, a))
		_rect(0, y + 2, view_w, 1, Color(0, 0, 0, a * 0.5))
	# golden sand band at the base
	for y in range(sand_top, _h):
		var t := clampf(float(y - sand_top) / float(sand_bot - sand_top), 0.0, 1.0)
		_rect(0, y, view_w, 1, SAND.lerp(SAND_SH, t * 0.6))
	# foam line where water meets sand
	for x in range(view_w):
		var wob := int(3.0 * sin(float(x) * 0.03) + 2.0 * sin(float(x) * 0.011 + 1.0))
		_rect(x, sand_top - 2 + wob, 1, 4, Color(1, 1, 1, 0.55))
	# scattered sand speckle for texture
	for k in range(int(view_w * 0.5)):
		var sx := int(_hash(k * 7 + 1) * view_w)
		var syf := float(sand_top + 6) + _hash(k * 13 + 3) * float(_h - sand_top - 6)
		_px(sx, int(syf), Color(0, 0, 0, 0.06))


# ================================================================ clouds (slow layer)
func _cloud(cx: float, cy: float, scale: float) -> void:
	# flat stylized cumulus: a cluster of overlapping discs with a soft underside shadow
	var lobes := [
		Vector2(-1.0, 0.10), Vector2(-0.45, -0.32), Vector2(0.15, -0.45),
		Vector2(0.75, -0.20), Vector2(1.2, 0.12), Vector2(0.35, 0.10), Vector2(-0.3, 0.18),
	]
	for l in lobes:
		var v: Vector2 = l
		_disc(Vector2(cx + v.x * 42.0 * scale, cy + v.y * 30.0 * scale + 6.0 * scale), 26.0 * scale, CLOUD_SH)
	for l in lobes:
		var v: Vector2 = l
		_disc(Vector2(cx + v.x * 42.0 * scale, cy + v.y * 30.0 * scale), 26.0 * scale, CLOUD)


func _clouds() -> void:
	# a few stylized cumulus spread without repetition along the full width
	var x := 80.0
	var i := 0
	while x < float(_w) + 120.0:
		var s := 5000 + i
		var cy := 80.0 + _hash(s * 7 + 1) * 150.0
		var sc := 0.7 + _hash(s * 5 + 3) * 0.9
		_cloud(x, cy, sc)
		x += 240.0 + _hash(s * 3 + 2) * 360.0
		i += 1


# ================================================================ peaks (terrain bands)
# Shared ridgeline so hillside boxes can sit exactly on the drawn near-peak slope.
func _ridge_y(x: float, base_y: float, hmin: float, hmax: float, freq: float, sharp: float, seedn: int) -> float:
	var fx := x + float(seedn) * 130.0
	var e := _envelope(fx)
	var rid := 0.5 + 0.5 * sin(fx * freq + float(seedn))
	rid += 0.34 * (0.5 + 0.5 * sin(fx * freq * 2.7 + 1.3))
	rid += 0.16 * (0.5 + 0.5 * sin(fx * freq * 6.1 + 4.0))
	rid = pow(clampf(rid / 1.50, 0.0, 1.0), 1.0 / sharp)
	return base_y - (hmin + (hmax - hmin) * (0.4 + 0.6 * e) * rid)


func _peak_band(base_y: float, hmin: float, hmax: float, fill: Color, haze: float, freq: float, sharp: float, seedn: int) -> void:
	# smooth rounded ridgeline drawn as vertical columns; haze blends toward the horizon sky.
	var col := fill.lerp(SKY_HZN, haze)
	var shade := fill.darkened(0.16).lerp(SKY_HZN, haze)
	# Peaks rise from the green and stop just past the waterline so the static bay band shows below
	# (peak columns must NOT fill to the off-screen image bottom or they hide the water/sand).
	var foot := int(base_y) + 12
	for x in range(_w):
		var fx := float(x) + float(seedn) * 130.0
		var top := _ridge_y(float(x), base_y, hmin, hmax, freq, sharp, seedn)
		var slope := cos(fx * freq + float(seedn)) >= 0.0
		var c: Color = col if slope else col.lerp(shade, 0.55)
		_rect(x, int(top), 1, foot - int(top), c)


func _dome(cx: int) -> void:
	# granite rounded peak (tall bullet-shaped rock dome) with a thin cable-car line and cabins
	var base_y := PEAK_FOOT
	var r := 90.0
	var cy := float(base_y) - r * 1.05   # tall rock rising above the green
	_trap(cx, base_y - 36, int(r * 1.5), int(r * 2.5), 36, PEAK_NEAR.darkened(0.06))
	# rounded granite body built as columns: a clean half-round top over a gently tapering column.
	var body_bot := base_y - 24
	for yy in range(int(cy - r), body_bot):
		var t := clampf(float(yy - int(cy - r)) / float(body_bot - int(cy - r)), 0.0, 1.0)
		var hw: float
		if yy < int(cy):
			var dy := float(int(cy) - yy)
			hw = sqrt(maxf(r * r - dy * dy, 0.0))
		else:
			hw = r * (1.0 - 0.16 * t)
		for xx in range(int(cx - hw), int(cx + hw)):
			var c: Color = GRANITE_LIT if float(xx) < float(cx) - hw * 0.15 else GRANITE_SH
			if float(xx) > float(cx) - hw * 0.45 and float(xx) < float(cx) + hw * 0.25:
				c = GRANITE
			_px(xx, yy, c)
	for k in range(3):
		var sx := cx - int(r * 0.4) + k * int(r * 0.4)
		_line(Vector2(sx, cy - r * 0.5), Vector2(sx + 3, body_bot - 6), Color(0, 0, 0, 0.05), 1)
	# cable car: anchor pylon on a small knoll -> up to the dome summit
	var anchor := Vector2(cx + 168, base_y - 34)
	var summit := Vector2(float(cx) + r * 0.15, cy - r * 0.74)
	_disc(anchor + Vector2(0, 30), 30.0, PEAK_MID)             # support knoll
	_rect(int(anchor.x) - 2, int(anchor.y), 4, 46, GRANITE_SH) # pylon
	_line(anchor, summit, Color8(64, 64, 70), 1)               # support cable
	_line(anchor + Vector2(0, 4), summit + Vector2(0, 4), Color8(64, 64, 70), 1)
	for t in [0.32, 0.62]:                                     # cabins riding the line
		var tt: float = t
		var p: Vector2 = anchor.lerp(summit, tt)
		_rect(int(p.x) - 5, int(p.y), 10, 6, Color8(220, 80, 70))
		_rect(int(p.x) - 5, int(p.y) - 2, 10, 2, Color8(64, 64, 70))


func _statue_peak(cx: int) -> void:
	# tallest lush peak crowned by a pale hilltop figure with outstretched horizontal arms.
	var base_y := PEAK_FOOT
	var r := 132.0
	var cy := float(base_y) - r * 0.78   # raise the summit well above the skyline
	_disc(Vector2(cx, cy), r, PEAK_NEAR)
	_rect(cx - int(r), int(cy), int(r * 2.0), base_y - int(cy), PEAK_NEAR)
	# crisp silhouette rim so it separates from the band behind
	for ang in range(-90, 91, 2):
		var a := deg_to_rad(float(ang))
		_px(int(cx + sin(a) * r), int(cy - cos(a) * r), PEAK_NEAR.darkened(0.22))
	_disc(Vector2(cx + r * 0.36, cy + r * 0.1), r * 0.7, PEAK_NEAR.darkened(0.16))
	_disc(Vector2(cx - r * 0.38, cy - r * 0.22), r * 0.4, PEAK_NEAR.lightened(0.14))
	# deterministic forest dapple
	for k in range(70):
		var a2 := _hash(k * 13 + 7) * TAU
		var rr := _hash(k * 5 + 2) * r * 0.88
		var px2 := cx + cos(a2) * rr
		var py2 := cy + sin(a2) * rr * 0.82
		if py2 < base_y:
			_disc(Vector2(px2, py2), 3.0, PEAK_NEAR.darkened(0.10) if _hash(k) < 0.5 else PEAK_NEAR.lightened(0.08))
	# pedestal block on the summit
	var sy := int(cy - r * 1.0)
	_rect(cx - 12, sy, 24, 22, STATUE_SH)
	_rect(cx - 12, sy, 24, 3, STATUE)
	# figure: head, robe body, outstretched horizontal arms (large, dominant silhouette)
	var fy := sy - 2
	var bh := 64
	_rect(cx - 7, fy - bh, 14, bh, STATUE)
	_trap(cx, fy - 8, 14, 30, 8, STATUE)
	_disc(Vector2(cx, fy - bh - 9), 9.0, STATUE)
	var arm_y := fy - bh + 16
	_rect(cx - 58, arm_y, 116, 9, STATUE)
	_rect(cx - 58, arm_y, 116, 2, STATUE_SH)
	_rect(cx - 58, arm_y + 7, 116, 2, STATUE_SH)
	_rect(cx - 7, fy - bh, 3, bh, Color(1, 1, 1, 0.22))


func _lookout_peak(cx: int) -> void:
	# smaller echo peak with a tiny lookout platform on top
	var base_y := PEAK_FOOT
	var r := 92.0
	var cy := float(base_y) - r * 0.7
	_disc(Vector2(cx, cy), r, PEAK_NEAR)
	_rect(cx - int(r), int(cy), int(r * 2.0), base_y - int(cy), PEAK_NEAR)
	for ang in range(-90, 91, 3):
		var a := deg_to_rad(float(ang))
		_px(int(cx + sin(a) * r), int(cy - cos(a) * r), PEAK_NEAR.darkened(0.22))
	_disc(Vector2(cx + r * 0.32, cy + r * 0.12), r * 0.66, PEAK_NEAR.darkened(0.16))
	_disc(Vector2(cx - r * 0.34, cy - r * 0.2), r * 0.34, PEAK_NEAR.lightened(0.12))
	var ly := int(cy - r) + 2
	_rect(cx - 9, ly, 18, 4, GRANITE_LIT)
	_rect(cx - 9, ly, 18, 1, Color(1, 1, 1, 0.4))
	_rect(cx - 1, ly + 4, 2, 8, GRANITE_SH)


# Landmark placement spread across the FULL width with no repetition. The signature statue+dome
# anchor the start view; beyond that rounded peaks are spaced with jitter and a deterministic kind
# sequence so a long stage never tiles. kind: 0=statue peak, 1=cable-car dome, 2=lookout peak.
func _landmark_spots() -> Array:
	var spots: Array = []
	spots.append({"x": 128.0, "kind": 0})    # signature statue peak near the start
	spots.append({"x": 512.0, "kind": 1})    # signature cable-car dome
	spots.append({"x": 845.0, "kind": 2})    # a first lookout
	var x := 1500.0
	var i := 0
	var cycle := [1, 2, 1, 2, 0, 2, 1, 2]    # avoids two of the same adjacent; statue echoes rarer
	while x < float(_w) - 220.0:
		var k: int = cycle[i % cycle.size()]
		spots.append({"x": x, "kind": float(k)})
		x += 820.0 + _hash(9000 + i * 7) * 360.0
		i += 1
	return spots


# ================================================================ hillside houses
func _near_ridge(x: float) -> float:
	return _ridge_y(x, float(PEAK_FOOT), 96.0, 188.0, 0.00150, 3.6, 41)


func _hillside_houses() -> void:
	# multicolour stacked boxes climbing the near green slopes; sparse, clustered, slope-hugging.
	var shore := PEAK_FOOT + 6
	# keep clear of the bold landmark peaks so they stay readable (radius per landmark kind)
	var clear: Array = []
	for spot in _landmark_spots():
		var d: Dictionary = spot
		var rad := 150.0 if int(d["kind"]) == 0 else (120.0 if int(d["kind"]) == 1 else 96.0)
		clear.append(Vector2(d["x"], rad))
	# Tight clustered patches (a run of packed columns) separated by genuinely wide gaps of bare
	# green slope. A squared hash makes big openings common so clustering reads organically uneven.
	var i := 0
	var x := 6.0
	while x < float(_w) - 6.0:
		var inzone := false
		for cz in clear:
			var v: Vector2 = cz
			if absf(x - v.x) < v.y:
				x = v.x + v.y + 4.0
				inzone = true
				break
		if inzone:
			i += 1
			continue
		var cluster := 3 + int(_hash(i * 71 + 9) * 22.0)            # 3..24 columns packed together
		for j in range(cluster):
			if x >= float(_w) - 6.0:
				break
			var blocked := false
			for cz in clear:
				var v: Vector2 = cz
				if absf(x - v.x) < v.y:
					blocked = true
					break
			var s := 6000 + i * 29 + j
			var box := 7 + int(_hash(s * 9) * 4)
			if blocked:
				x += float(box) + 1.0
				continue
			var ridge := _near_ridge(x)
			var depth := 24.0 + _hash(s * 7 + 1) * 70.0
			var col_top := ridge + 14.0 + _hash(s * 5 + 2) * 26.0
			var col_bot := minf(col_top + depth, float(shore))
			if _hash(s * 11) > 0.12:
				var y := col_top
				var row := 0
				while y < col_bot:
					var idx := s * 131 + row * 23
					if _hash(idx * 3) > 0.16:
						var c: Color = HILLSIDE[int(_hash(idx * 5) * HILLSIDE.size()) % HILLSIDE.size()]
						var jit := int((_hash(idx * 9) - 0.5) * 3.0)
						_rect(int(x) + jit, int(y), box - 1, box - 1, c)
						_rect(int(x) + jit, int(y), box - 1, 1, c.lightened(0.16))           # lit roof
						_rect(int(x) + jit, int(y) + box - 2, box - 1, 1, c.darkened(0.22))  # base shade
						_rect(int(x) + jit + 1, int(y) + 2, 2, 2, Color8(70, 56, 50))        # window
					y += float(box)
					row += 1
			x += float(box)   # columns within a patch sit edge-to-edge (tight)
		var g := _hash(i * 47 + 3)
		x += 18.0 + g * g * 170.0
		i += 1


# ================================================================ shore towers (near layer)
func _city_towers() -> void:
	# white/cream apartment towers along the shore. Spacing is intentionally irregular: towers come
	# in tight clusters (2-4 jammed almost edge-to-edge, sometimes a lone one) separated by genuinely
	# wide gaps that reveal the bay/greenery behind. A non-linear (squared) hash makes big gaps
	# common so the rhythm never reads as even. Heights/widths/tints vary per tower via the hash.
	var base_y := TOWER_FOOT
	var x := -30.0
	var i := 0
	while x < float(_w) + 30.0:
		var cluster := 1 + int(_hash(i * 211 + 5) * _hash(i * 97 + 13) * 4.0)   # squared-ish -> mostly 1-2
		for j in range(cluster):
			var s := 7000 + i * 17 + j
			var e := _envelope(x * 1.4 + float(s) * 90.0)
			var bw := int(18 + _hash(s * 9 + 2) * 40)
			var bh := int((48 + e * 104) * (0.62 + _hash(s * 5 + 7) * 0.74))
			var byt := base_y - bh
			var fill := TOWER.lerp(Color8(238, 230, 214), _hash(s * 4))
			_rect(int(x), byt, bw, base_y - byt, fill)
			_rect(int(x) + int(bw * 0.66), byt, int(bw * 0.34), base_y - byt, TOWER_SH)
			_rect(int(x), byt, bw, 2, Color(1, 1, 1, 0.7))
			_tower_windows(int(x), byt, bw, base_y - byt, s)
			var k := int(_hash(s * 7) * 4)
			if k == 0:
				_rect(int(x) + bw / 2 - 1, byt - 12, 2, 12, TOWER_SH)     # antenna
			elif k == 1:
				_rect(int(x) + 4, byt - 6, 8, 6, TOWER_SH)                # rooftop box
			x += float(bw) + (0.0 if _hash(s * 3) < 0.45 else 1.0 + _hash(s * 31) * 5.0)
		var g := _hash(i * 53 + 7)
		x += 10.0 + g * g * 150.0
		i += 1


func _tower_windows(bx: int, byt: int, bw: int, bh: int, seedn: int) -> void:
	var step := 6
	var cols := int((bw - 4) / step)
	var rows := int((bh - 6) / step)
	for cy in range(rows):
		for cx in range(cols):
			var idx := seedn * 131 + cy * 17 + cx * 3
			if _hash(idx) < 0.18:
				continue   # some blanks for variety
			var c := WINDOW
			if _hash(idx * 5) < 0.10:
				c = Color8(255, 232, 170)   # a few warm-lit
			_rect(bx + 3 + cx * step, byt + 4 + cy * step, 3, 3, Color(c.r, c.g, c.b, 0.7))
