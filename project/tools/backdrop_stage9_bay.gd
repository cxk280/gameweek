extends SceneTree
## Offline backdrop preview for a bright tropical bay-city stage. Paints a stylized flat
## pixel-vector backdrop into a single Image and saves it as a PNG so the art direction can be
## inspected pixel-by-pixel without running the game (headless Godot cannot capture live nodes).
## The composition is authored in overlapping far->near depth bands with atmospheric haze on the
## distant terrain, a non-repeating height/colour envelope, and curated non-repeating landmarks
## so a long stage never looks tiled. Flat chunky shapes + deterministic detail grids only; the
## only gradients are the sky and the water.
##   godot --headless --path project --script res://tools/backdrop_stage9_bay.gd -- --width=4800 --out=/abs/path.png

var W := 1280
var H := 720
var img: Image

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

const FG_FILL := Color8(232, 226, 210)    # warm promenade/rooftop fill
const FG_FILL2 := Color8(206, 198, 182)
const FG_EDGE := Color8(255, 250, 236)    # bright top edge that pops


func _init() -> void:
	var out := "res://backdrop_stage9.png"
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


func _compose() -> void:
	_sky()
	_clouds()
	# Far -> near terrain bands (distant = hazier/bluer, smaller). Each band is a rolling
	# rounded ridgeline; bold individual peaks are punched in on top for silhouette variety.
	_peak_band(456.0, 70.0, 168.0, PEAK_FAR, 0.55, 0.00210, 2.4, 9)
	_peak_band(478.0, 90.0, 196.0, PEAK_MID, 0.34, 0.00170, 3.0, 23)
	_peak_band(500.0, 96.0, 188.0, PEAK_NEAR, 0.12, 0.00150, 3.6, 41)
	# Bold rounded landmark peaks sit proud of the near band (drawn on top, not clipped).
	# The signature pair (statue peak + cable-car dome) is dominant near the start; on long
	# stages extra rounded peaks/lookouts are spread at non-repeating spots so nothing tiles.
	for lm in _landmark_spots():
		match int(lm.y):
			0: _statue_peak(int(lm.x))
			1: _dome(int(lm.x))
			_: _lookout_peak(int(lm.x))
	_hillside_houses()         # multicolour boxes climbing the near green slopes
	_water()                    # bay + beach + ripples
	_city_towers()              # white apartment towers clustered along the shore
	_foreground()               # nearest promenade/rooftop platforms with props


# Landmark placement spread across the FULL width with no repetition. kind: 0=statue peak,
# 1=cable-car dome, 2=lookout peak. The signature statue+dome anchor the start view; beyond that
# rounded peaks are spaced with jitter and a deterministic kind sequence so a long stage varies.
func _landmark_spots() -> Array:
	var spots := []
	spots.append(Vector2(128, 0))    # signature statue peak near the start (~0.10 of start view)
	spots.append(Vector2(512, 1))    # signature cable-car dome (~0.40 of start view)
	spots.append(Vector2(845, 2))    # a first lookout (~0.66 of start view)
	# additional spread peaks for wider panoramas, starting past the start view
	var x := 1500.0
	var i := 0
	# kind cycle avoids two of the same landmark adjacent; statue echoes are rarer
	var cycle := [1, 2, 1, 2, 0, 2, 1, 2]
	while x < W - 220.0:
		var k: int = cycle[i % cycle.size()]
		spots.append(Vector2(x, float(k)))
		x += 820.0 + _h(9000 + i * 7) * 360.0
		i += 1
	return spots


# ================================================================ pixel helpers
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
			var dx := float(xx) - center.x
			var dy := float(yy) - center.y
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


# low-frequency, non-repeating envelope (clustered peaks + quieter stretches)
func _envelope(x: float) -> float:
	var a := 0.5 + 0.5 * sin(x * 0.0013)
	var b := 0.5 + 0.5 * sin(x * 0.0041 + 2.1)
	return clampf(0.30 + 0.5 * a + 0.28 * b - 0.08, 0.0, 1.0)


func _trap(cx: int, top_y: int, top_w: int, bot_w: int, h: int, color: Color) -> void:
	for r in range(h + 1):
		var w := int(lerpf(float(top_w), float(bot_w), float(r) / float(maxf(h, 1.0))))
		_rect(cx - w / 2, top_y + r, w, 1, color)


# ================================================================ sky + clouds
func _sky() -> void:
	for y in range(H):
		var row := SKY_TOP.lerp(SKY_HZN, pow(float(y) / float(H * 0.62), 1.1))
		for x in range(W):
			img.set_pixel(x, y, row)
	# warm sunlight wash near the horizon
	for y in range(300, 470):
		var a := (1.0 - absf(float(y) - 392.0) / 92.0) * 0.10
		if a > 0.0:
			_rect(0, y, W, 1, Color(1.0, 0.92, 0.74, a))


func _cloud(cx: float, cy: float, scale: float) -> void:
	# flat stylized cumulus: a cluster of overlapping discs with a soft underside shadow
	var lobes := [
		Vector2(-1.0, 0.10), Vector2(-0.45, -0.32), Vector2(0.15, -0.45),
		Vector2(0.75, -0.20), Vector2(1.2, 0.12), Vector2(0.35, 0.10), Vector2(-0.3, 0.18),
	]
	# shadowed underside
	for l in lobes:
		_disc(Vector2(cx + l.x * 42.0 * scale, cy + l.y * 30.0 * scale + 6.0 * scale), 26.0 * scale, CLOUD_SH)
	for l in lobes:
		_disc(Vector2(cx + l.x * 42.0 * scale, cy + l.y * 30.0 * scale), 26.0 * scale, CLOUD)


func _clouds() -> void:
	# a few stylized cumulus spread without repetition along the full width
	var x := 80.0
	var i := 0
	while x < W + 120.0:
		var s := 5000 + i
		var cy := 70.0 + _h(s * 7 + 1) * 120.0
		var sc := 0.7 + _h(s * 5 + 3) * 0.9
		# skip the statue-peak summit zone so the pale figure keeps contrast against blue sky
		if absf(x - 128.0) > 130.0 or cy > 150.0:
			_cloud(x, cy, sc)
		x += 240.0 + _h(s * 3 + 2) * 360.0
		i += 1


# ================================================================ peaks (terrain bands)
# Shared ridgeline function so hillside boxes can sit exactly on the drawn near-peak slope.
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
	for x in range(W):
		var fx := float(x) + float(seedn) * 130.0
		var top := _ridge_y(float(x), base_y, hmin, hmax, freq, sharp, seedn)
		# subtle lit/shadow split per slope direction (deterministic detail, not a gradient)
		var slope := cos(fx * freq + float(seedn)) >= 0.0
		var c: Color = col if slope else col.lerp(shade, 0.55)
		_rect(x, int(top), 1, H - int(top), c)


func _dome(cx: int) -> void:
	# granite rounded peak (tall bullet-shaped rock dome) with a thin cable-car line and cabins
	var base_y := 506
	var r := 90.0
	var cy := float(base_y) - r * 1.05   # tall rock rising above the green
	# green forested skirt the rock emerges from
	_trap(cx, base_y - 36, int(r * 1.5), int(r * 2.5), 36, PEAK_NEAR.darkened(0.06))
	# rounded granite body: a rounded-top column emerging from the green (bullet silhouette).
	# Build it as columns so the top is a clean half-round and the sides taper gently.
	var body_bot := base_y - 24
	for yy in range(int(cy - r), body_bot):
		var t := clampf(float(yy - int(cy - r)) / float(body_bot - int(cy - r)), 0.0, 1.0)
		var hw: float
		if yy < int(cy):
			# rounded cap
			var dy := float(int(cy) - yy)
			hw = sqrt(maxf(r * r - dy * dy, 0.0))
		else:
			# gently tapering column widening downward then settling
			hw = r * (1.0 - 0.16 * t)
		# flat lit/shade split: left lit, right shaded, no sphere blob
		for xx in range(int(cx - hw), int(cx + hw)):
			var c: Color = GRANITE_LIT if float(xx) < float(cx) - hw * 0.15 else GRANITE_SH
			if float(xx) > float(cx) - hw * 0.45 and float(xx) < float(cx) + hw * 0.25:
				c = GRANITE   # mid band
			_px(xx, yy, c)
	# a couple of vertical rock striations for texture
	for k in range(3):
		var sx := cx - int(r * 0.4) + k * int(r * 0.4)
		_line(Vector2(sx, cy - r * 0.5), Vector2(sx + 3, body_bot - 6), Color(0, 0, 0, 0.05), 1)
	# cable car: anchor pylon on a small knoll -> up to the dome summit
	var anchor := Vector2(cx + 168, 472)
	var summit := Vector2(float(cx) + r * 0.15, cy - r * 0.74)
	_disc(anchor + Vector2(0, 30), 30.0, PEAK_MID)             # support knoll
	_rect(int(anchor.x) - 2, int(anchor.y), 4, 46, GRANITE_SH) # pylon
	_line(anchor, summit, Color8(64, 64, 70), 1)               # support cable
	_line(anchor + Vector2(0, 4), summit + Vector2(0, 4), Color8(64, 64, 70), 1)
	for t in [0.32, 0.62]:                                     # cabins riding the line
		var p: Vector2 = anchor.lerp(summit, t)
		_rect(int(p.x) - 5, int(p.y), 10, 6, Color8(220, 80, 70))
		_rect(int(p.x) - 5, int(p.y) - 2, 10, 2, Color8(64, 64, 70))


func _statue_peak(cx: int) -> void:
	# tallest lush peak crowned by a pale hilltop figure with outstretched horizontal arms.
	# A bold rounded silhouette that clearly rises above the surrounding ridge.
	var base_y := 506
	var r := 132.0
	var cy := float(base_y) - r * 0.78   # raise the summit well above the skyline
	# rounded forested summit (tall dome)
	_disc(Vector2(cx, cy), r, PEAK_NEAR)
	_rect(cx - int(r), int(cy), int(r * 2.0), base_y - int(cy), PEAK_NEAR)
	# crisp silhouette rim so it separates from the band behind
	for ang in range(-90, 91, 2):
		var a := deg_to_rad(float(ang))
		var px := cx + sin(a) * r
		var py := cy - cos(a) * r
		_px(int(px), int(py), PEAK_NEAR.darkened(0.22))
	_disc(Vector2(cx + r * 0.36, cy + r * 0.1), r * 0.7, PEAK_NEAR.darkened(0.16))
	_disc(Vector2(cx - r * 0.38, cy - r * 0.22), r * 0.4, PEAK_NEAR.lightened(0.14))
	# deterministic forest dapple
	for k in range(70):
		var a2 := _h(k * 13 + 7) * TAU
		var rr := _h(k * 5 + 2) * r * 0.88
		var px2 := cx + cos(a2) * rr
		var py2 := cy + sin(a2) * rr * 0.82
		if py2 < base_y:
			_disc(Vector2(px2, py2), 3.0, PEAK_NEAR.darkened(0.10) if _h(k) < 0.5 else PEAK_NEAR.lightened(0.08))
	# pedestal block on the summit
	var sy := int(cy - r * 1.0)
	_rect(cx - 12, sy, 24, 22, STATUE_SH)
	_rect(cx - 12, sy, 24, 3, STATUE)                  # lit pedestal top
	# figure: head, robe body, outstretched horizontal arms (large, dominant silhouette)
	var fy := sy - 2
	var bh := 64                                       # body height
	_rect(cx - 7, fy - bh, 14, bh, STATUE)             # body/robe
	_trap(cx, fy - 8, 14, 30, 8, STATUE)               # robe flare at base
	_disc(Vector2(cx, fy - bh - 9), 9.0, STATUE)       # head
	# horizontal outstretched arms
	var arm_y := fy - bh + 16
	_rect(cx - 58, arm_y, 116, 9, STATUE)              # arm span
	_rect(cx - 58, arm_y, 116, 2, STATUE_SH)           # subtle top shade
	_rect(cx - 58, arm_y + 7, 116, 2, STATUE_SH)       # underside shade
	# soft lit highlight on the figure's left side
	_rect(cx - 7, fy - bh, 3, bh, Color(1, 1, 1, 0.22))


func _lookout_peak(cx: int) -> void:
	# smaller echo peak with a tiny lookout platform on top
	var base_y := 500
	var r := 92.0
	var cy := float(base_y) - r * 0.7
	_disc(Vector2(cx, cy), r, PEAK_NEAR)
	_rect(cx - int(r), int(cy), int(r * 2.0), base_y - int(cy), PEAK_NEAR)
	# crisp silhouette rim
	for ang in range(-90, 91, 3):
		var a := deg_to_rad(float(ang))
		_px(int(cx + sin(a) * r), int(cy - cos(a) * r), PEAK_NEAR.darkened(0.22))
	_disc(Vector2(cx + r * 0.32, cy + r * 0.12), r * 0.66, PEAK_NEAR.darkened(0.16))
	_disc(Vector2(cx - r * 0.34, cy - r * 0.2), r * 0.34, PEAK_NEAR.lightened(0.12))
	# lookout: a small post + flat platform at the summit
	var ly := int(cy - r) + 2
	_rect(cx - 9, ly, 18, 4, GRANITE_LIT)
	_rect(cx - 9, ly, 18, 1, Color(1, 1, 1, 0.4))
	_rect(cx - 1, ly + 4, 2, 8, GRANITE_SH)


# ================================================================ hillside hillsides
# Sample the actual near-band ridgeline so boxes hug the green slope (no floating blobs).
func _near_ridge(x: float) -> float:
	return _ridge_y(x, 500.0, 96.0, 188.0, 0.00150, 3.6, 41)


func _hillside_houses() -> void:
	# multicolour stacked boxes climbing the near green slopes; sparse, clustered, slope-hugging.
	# Boxes only occupy the lower portion of each slope so the green hillside still reads.
	var shore := 506   # boxes never spill past this into the water
	# keep clear of the bold landmark peaks so they stay readable (radius per landmark kind)
	var clear := []
	for lm in _landmark_spots():
		var rad := 150.0 if int(lm.y) == 0 else (120.0 if int(lm.y) == 1 else 96.0)
		clear.append(Vector2(lm.x, rad))
	var i := 0
	var x := 6.0
	while x < W - 6.0:
		var s := 6000 + i
		var box := 7 + int(_h(s * 9) * 4)
		var skip := false
		for cz in clear:
			if absf(x - cz.x) < cz.y:
				skip = true
				break
		if skip:
			x += float(box) + 1.0
			i += 1
			continue
		var ridge := _near_ridge(x)
		# top of this column's houses: a little below the ridge, with a deterministic band depth
		var depth := 24.0 + _h(s * 7 + 1) * 70.0
		var col_top := ridge + 14.0 + _h(s * 5 + 2) * 26.0
		var col_bot := minf(col_top + depth, float(shore))
		# leave gaps so vegetation shows between house clusters
		if _h(s * 11) < 0.30:
			x += float(box) + 2.0
			i += 1
			continue
		var y := col_top
		var row := 0
		while y < col_bot:
			var idx := s * 131 + row * 23
			if _h(idx * 3) > 0.16:   # a few blanks = greenery peeking through
				var c: Color = HILLSIDE[int(_h(idx * 5) * HILLSIDE.size()) % HILLSIDE.size()]
				var jit := int((_h(idx * 9) - 0.5) * 3.0)
				_rect(int(x) + jit, int(y), box - 1, box - 1, c)
				_rect(int(x) + jit, int(y), box - 1, 1, c.lightened(0.16))            # lit roof edge
				_rect(int(x) + jit, int(y) + box - 2, box - 1, 1, c.darkened(0.22))   # base shade
				_rect(int(x) + jit + 1, int(y) + 2, 2, 2, Color8(70, 56, 50))         # tiny window
			y += float(box)
			row += 1
		x += float(box) + 1.0
		i += 1


# ================================================================ water + beach
func _water() -> void:
	var water_top := 500
	var sand_top := 556
	# blue-green bay gradient
	for y in range(water_top, sand_top):
		var t := float(y - water_top) / float(sand_top - water_top)
		var row := WATER_FAR.lerp(WATER_NEAR, t)
		_rect(0, y, W, 1, row)
	# subtle horizontal ripples (deterministic)
	for y in range(water_top + 4, sand_top, 6):
		var a := 0.10 + _h(y) * 0.06
		_rect(0, y, W, 1, Color(1, 1, 1, a))
		_rect(0, y + 2, W, 1, Color(0, 0, 0, a * 0.5))
	# golden sand strip at the base, curving brightness
	for y in range(sand_top, 720):
		var t := float(y - sand_top) / float(720 - sand_top)
		var row := SAND.lerp(SAND_SH, t * 0.6)
		_rect(0, y, W, 1, row)
	# foam line where water meets sand
	for x in range(W):
		var wob := int(3.0 * sin(float(x) * 0.03) + 2.0 * sin(float(x) * 0.011 + 1.0))
		_rect(x, sand_top - 2 + wob, 1, 4, Color(1, 1, 1, 0.55))
	# scattered sand speckle for texture
	for k in range(int(W * 0.5)):
		var sx := int(_h(k * 7 + 1) * W)
		var syf := 560.0 + _h(k * 13 + 3) * 150.0
		_px(sx, int(syf), Color(0, 0, 0, 0.06))


# ================================================================ city towers
func _city_towers() -> void:
	# white/cream apartment towers clustered along the shore, between water and the beach band.
	# Deterministic window grids; non-repeating heights/widths via the envelope.
	var base_y := 528
	var x := -30.0
	var i := 0
	while x < W + 30.0:
		var s := 7000 + i
		var e := _envelope(x * 1.4 + float(s) * 90.0)
		var bw := int(22 + _h(s * 9 + 2) * 30)
		var bh := int((52 + e * 96) * (0.7 + _h(s * 5 + 7) * 0.6))
		var byt := base_y - bh
		# tint each tower slightly between white and cream
		var fill := TOWER.lerp(Color8(238, 230, 214), _h(s * 4))
		_rect(int(x), byt, bw, base_y - byt, fill)
		# shaded right third
		_rect(int(x) + int(bw * 0.66), byt, int(bw * 0.34), base_y - byt, TOWER_SH)
		# bright top edge
		_rect(int(x), byt, bw, 2, Color(1, 1, 1, 0.7))
		# deterministic window grid
		_tower_windows(int(x), byt, bw, base_y - byt, s)
		# occasional rooftop prop
		var k := int(_h(s * 7) * 4)
		if k == 0:
			_rect(int(x) + bw / 2 - 1, byt - 12, 2, 12, TOWER_SH)   # antenna
		elif k == 1:
			_rect(int(x) + 4, byt - 6, 8, 6, TOWER_SH)              # rooftop box
		x += float(bw) + 5.0 + _h(s * 3) * 14.0
		i += 1


func _tower_windows(bx: int, byt: int, bw: int, bh: int, seedn: int) -> void:
	var step := 6
	var cols := int((bw - 4) / step)
	var rows := int((bh - 6) / step)
	for cy in range(rows):
		for cx in range(cols):
			var idx := seedn * 131 + cy * 17 + cx * 3
			if _h(idx) < 0.18:
				continue   # some blanks for variety
			var c := WINDOW
			if _h(idx * 5) < 0.10:
				c = Color8(255, 232, 170)   # a few warm-lit
			_rect(bx + 3 + cx * step, byt + 4 + cy * step, 3, 3, Color(c.r, c.g, c.b, 0.7))


# ================================================================ foreground play surface
func _foreground() -> void:
	# nearest beachfront promenade / rooftop platforms as solid blocks with a bright top edge,
	# varied heights and gaps (depth shows behind), plus tropical props.
	var x := -40
	var i := 0
	while x < W + 40:
		var w := 190 + int(_h(i * 9 + 1) * 260)
		var top := 612 + int(_h(i * 5 + 2) * 56)
		_ledge(x, top, w, i)
		# prop selection (non-repeating)
		var k := int(_h(i * 7 + 3) * 4)
		var pxp := x + 40 + int(_h(i * 2) * (w - 90))
		if k == 0:
			_palm(pxp, top)
		elif k == 1:
			_umbrella(pxp, top)
		elif k == 2:
			_antenna(pxp, top)
		else:
			_water_tank(pxp, top)
		x += w + 56 + int(_h(i * 3) * 120)
		i += 1


func _ledge(x: int, top: int, w: int, seedn: int) -> void:
	_rect(x, top, w, H - top, FG_FILL)
	_rect(x, top + (H - top) / 2, w, (H - top) / 2, FG_FILL2)
	# tile seams (deterministic detail grid)
	for c in range(x + 14, x + w, 28):
		_rect(c, top + 4, 1, H - top - 4, Color(0, 0, 0, 0.07))
	# bright warm/white top edge that pops
	_rect(x, top - 5, w, 6, Color(FG_EDGE.r, FG_EDGE.g, FG_EDGE.b, 0.25))
	_rect(x, top, w, 3, FG_EDGE)
	_rect(x, top + 3, w, 1, Color(0, 0, 0, 0.10))


func _palm(x: int, top: int) -> void:
	var th := 64
	# curved trunk
	for k in range(th):
		var off := int(6.0 * sin(float(k) / float(th) * 1.4))
		_rect(x + off, top - k, 4, 1, Color8(140, 104, 64))
	var cx := x + int(6.0 * sin(1.4)) + 2
	var cy := top - th
	# fronds
	for a in [-2.5, -1.7, -0.9, -0.3, 0.3, 0.9]:
		var ex := cx + int(cos(a) * 34.0)
		var ey := cy + int(sin(a) * 22.0) - 6
		_line(Vector2(cx, cy), Vector2(ex, ey), Color8(46, 150, 78), 2)
		_line(Vector2(cx, cy), Vector2((cx + ex) / 2, ey + 4), Color8(60, 170, 92), 2)
	_disc(Vector2(cx, cy), 4.0, Color8(80, 60, 40))   # coconuts hub
	_disc(Vector2(cx + 3, cy + 3), 2.0, Color8(120, 90, 50))


func _umbrella(x: int, top: int) -> void:
	var pole_h := 34
	_rect(x, top - pole_h, 2, pole_h, Color8(120, 110, 100))
	# striped canopy
	var cy := top - pole_h
	var stripes := [Color8(236, 90, 80), Color8(252, 252, 250)]
	for s in range(7):
		var hw := 28 - s * 4
		var col: Color = stripes[s % 2]
		_trap(x + 1, cy + s * 2 - 14, hw * 2 + 6, hw * 2, 2, col)
	_disc(Vector2(x + 1, cy - 14), 3.0, Color8(236, 90, 80))


func _antenna(x: int, top: int) -> void:
	var hh := 40
	_rect(x, top - hh, 2, hh, Color8(150, 150, 150))
	_rect(x - 6, top - int(hh * 0.6), 14, 1, Color8(150, 150, 150))
	_rect(x - 4, top - int(hh * 0.8), 10, 1, Color8(150, 150, 150))
	_rect(x - 1, top - hh - 4, 4, 4, Color8(230, 70, 60))


func _water_tank(x: int, top: int) -> void:
	_rect(x, top - 6, 3, 6, Color8(120, 120, 120))     # legs
	_rect(x + 22, top - 6, 3, 6, Color8(120, 120, 120))
	_rect(x, top - 24, 25, 18, Color8(180, 120, 90))   # cylindrical tank body
	_rect(x, top - 24, 25, 4, Color8(210, 150, 110))   # lit cap
	_rect(x, top - 12, 25, 1, Color(0, 0, 0, 0.12))
