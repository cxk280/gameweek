extends SceneTree
## Offline backdrop preview for a stage's stylized flat pixel-vector skyline. Paints the whole
## composition into a single Image and saves a PNG so the art direction can be inspected
## pixel-by-pixel without running the game (headless Godot cannot capture live nodes). The scene
## is authored as overlapping depth bands (far -> near) with atmospheric haze on distant layers,
## a low-frequency non-repeating height envelope, and curated landmarks spread along the length so
## a long stage never looks tiled. These numbers port into the live per-stage backdrop builder.
##   godot --headless --path project --script res://tools/backdrop_stage5_brick_valley.gd -- --width=4800 --out=/abs/path.png

var W := 1280
var H := 720
var img: Image

# muted, cool palette: brick reds/browns, painted facades, wet gray streets, misty greens, overcast sky
const SKY_TOP := Color8(196, 200, 208)
const SKY_HORIZON := Color8(222, 224, 226)
const HAZE := Color8(214, 216, 220)        # distance fade target (overcast mist)
const GLASS := Color8(120, 132, 144)       # cool gray window glass
const WARM_LIT := Color8(248, 214, 150)    # a few warm-lit windows
const EDGE := Color8(255, 226, 150)        # bright warm rooftop top-edge that pops on muted palette


func _init() -> void:
	var out := "res://art_backdrop_mock.png"
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
	# Forested ridges hemming the valley: 3 overlapping ridgelines, hazier the farther back.
	_ridge(372.0, 70.0, Color8(150, 162, 158), 0.62, 0.0011, 0.0037, 0.0, 7)
	_ridge(420.0, 86.0, Color8(112, 134, 120), 0.42, 0.0015, 0.0049, 1.7, 19)
	_ridge(468.0, 104.0, Color8(78, 112, 86), 0.20, 0.0019, 0.0061, 3.2, 31)
	# Receding brick downtown: far -> near, smaller/higher/hazier -> larger/lower/saturated.
	_block_band(508, 40, 92, 60, 110, 0.52, 11, false)
	_block_band(560, 60, 150, 80, 150, 0.34, 23, true)
	_block_band(626, 90, 210, 110, 185, 0.16, 37, true)
	# Signature landmarks (spread, non-repeating). At least one dominant near the start.
	_mill(150, 0.0)            # tall brick mill/commercial block, dominant at the start
	_mural_wall(960, 0.06)     # large painted mural wall accent
	# repeat the larger landmarks at non-repeating positions for long panoramas
	if W > 2200:
		_mill(2280, 0.05)
		_mural_wall(2860, 0.10)
	if W > 3600:
		_mill(3560, 0.0)
		_mural_wall(4480, 0.08)
	# Several modest white church steeples rising above the rooftops, spread along the full
	# length at irregular (non-repeating) positions using the deterministic hash.
	_steeples()
	# Nearest brick blocks (play-field depth, more saturated, low).
	_block_band(712, 110, 250, 130, 205, 0.05, 53, true)
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


# triangle/trapezoid: narrow top -> wide bottom (or vice versa)
func _trap(cx: int, top_y: int, top_w: int, bot_w: int, h: int, color: Color) -> void:
	for r in range(h + 1):
		var w := int(lerpf(float(top_w), float(bot_w), float(r) / float(h)))
		_rect(cx - w / 2, top_y + r, w, 1, color)


# small deterministic hash -> 0..1
func _h(n: int) -> float:
	var x := (n * 1103515245 + 12345) & 0x7fffffff
	x = (x ^ (x >> 13)) * 1274126177 & 0x7fffffff
	return float(x % 10000) / 10000.0


# low-frequency, non-repeating height/spacing envelope (denser downtown + quieter stretches)
func _envelope(x: float) -> float:
	var a := 0.5 + 0.5 * sin(x * 0.0013)
	var b := 0.5 + 0.5 * sin(x * 0.0041 + 2.1)
	return clampf(0.30 + 0.5 * a + 0.28 * b - 0.08, 0.0, 1.0)


# ---------------------------------------------------------------- sky
func _sky() -> void:
	for y in range(H):
		var row := SKY_TOP.lerp(SKY_HORIZON, pow(float(y) / float(H), 1.4))
		for x in range(W):
			img.set_pixel(x, y, row)
	# faint cool light band near the horizon
	for y in range(300, 470):
		var a := (1.0 - absf(float(y) - 392.0) / 86.0) * 0.10
		if a > 0.0:
			_rect(0, y, W, 1, Color(0.86, 0.90, 0.94, a))
	# a few hints of low mist drifting across the valley
	for i in range(int(W * 0.012) + 4):
		var mx := int(_h(i * 17 + 5) * W)
		var my := 340 + int(_h(i * 29 + 9) * 130.0)
		var mw := 80 + int(_h(i * 13 + 1) * 220.0)
		_rect(mx, my, mw, 6 + int(_h(i * 7) * 8.0), Color(0.92, 0.93, 0.95, 0.05))


# ---------------------------------------------------------------- forested ridges
func _ridge(base_y: float, amp: float, col: Color, haze: float, f1: float, f2: float, phase: float, seed: int) -> void:
	# misty tree-covered ridgeline: hazed fill + deterministic darker-green tree clusters (not noisy)
	var fill := col.lerp(HAZE, haze)
	var dark := Color8(int(col.r8 * 0.62), int(col.g8 * 0.66), int(col.b8 * 0.6)).lerp(HAZE, haze)
	for x in range(W):
		var r := base_y - (amp * (0.5 + 0.5 * sin(x * f1 + phase)) + amp * 0.45 * (0.5 + 0.5 * sin(x * f2 + phase * 1.7)))
		_rect(x, int(r), 1, H - int(r), fill)
	# darker-green tree clusters suggesting forest texture
	var step := 16
	var i := 0
	var x := 0
	while x < W:
		var r := base_y - (amp * (0.5 + 0.5 * sin(x * f1 + phase)) + amp * 0.45 * (0.5 + 0.5 * sin(x * f2 + phase * 1.7)))
		var rows := int((H - r) / float(step))
		for ry in range(rows):
			var idx := seed * 211 + i * 7 + ry * 3
			if _h(idx) > 0.34:
				continue
			var cy := int(r) + 4 + ry * step + int(_h(idx * 2) * 5.0)
			var cw := 5 + int(_h(idx * 3) * 6.0)
			_rect(x + int(_h(idx * 5) * step), cy, cw, cw, dark)
		x += step
		i += 1
	# soft hazy top edge to read as misty
	for x2 in range(W):
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
			if _h(idx) > density:
				continue
			var warm := _h(idx * 5) < 0.16
			var col: Color = WARM_LIT if warm else GLASS
			var a := (0.55 + _h(idx * 3) * 0.35) * (1.0 - haze * 0.6)
			_rect(bx + 6 + cx * step, by + 8 + cy * step, 5, 6, Color(col.r, col.g, col.b, a))


# rooftop variety props for a block (chunky, flat)
func _roof_prop(x: int, byt: int, bw: int, seedn: int, haze: float) -> void:
	var cx := x + bw / 2
	var k := int(_h(seedn * 7) * 5)
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
	var bricks := [Color8(150, 74, 60), Color8(128, 62, 52), Color8(166, 92, 70), Color8(112, 70, 58), Color8(138, 80, 64)]
	var painted := [Color8(208, 196, 168), Color8(120, 138, 150), Color8(186, 150, 96)]  # cream, faded blue, ochre
	var x := -90.0
	var i := 0
	while x < W + 90:
		var s := seed * 1000 + i
		var e := _envelope(x + float(seed) * 140.0)
		var bw := int(wmin + _h(s * 9 + 2) * (wmax - wmin))
		var bh := clampi(int((hmin + e * (hmax - hmin)) * (0.74 + _h(s * 5 + 7) * 0.55)), hmin, int(hmax * 1.18))
		var byt := int(base_y) - bh
		var is_painted := _h(s * 17) < 0.24
		var base: Color = painted[int(_h(s * 6) * painted.size()) % painted.size()] if is_painted else bricks[int(_h(s * 4) * bricks.size()) % bricks.size()]
		var fill := base.lerp(HAZE, haze)
		_rect(int(x), byt, bw, H - byt, fill)
		# shaded right portion for chunky volume
		_rect(int(x) + int(bw * 0.66), byt, int(bw * 0.34), H - byt, Color(0, 0, 0, 0.14 * (1.0 - haze)))
		# flat/low roof cap line
		_rect(int(x), byt, bw, 2, base.darkened(0.25).lerp(HAZE, haze))
		if feat:
			_roof_prop(int(x), byt, bw, s, haze)
		_windows(int(x), byt, bw, H - byt, s, (0.34 + _h(s * 3) * 0.16) * (1.0 - haze * 0.4), haze)
		# Spread-out valley town: clear the full building width, then add a large irregular gap
		# so misty hills / trees / open ground show through between brick blocks (no packed wall).
		var gap := 40.0 + _h(s * 11 + 5) * 130.0
		x += bw + gap
		i += 1


# ---------------------------------------------------------------- landmark: brick mill
func _mill(bx: int, haze: float) -> void:
	var bw := 116
	var bh := 300
	var byt := 712 - bh
	var brick := Color8(140, 68, 56).lerp(HAZE, haze)
	_rect(bx, byt, bw, 712 - byt, brick)
	_rect(bx + int(bw * 0.7), byt, int(bw * 0.3), 712 - byt, Color(0, 0, 0, 0.14 * (1.0 - haze)))
	_rect(bx, byt, bw, 3, brick.darkened(0.3))
	# corbelled cornice band
	_rect(bx - 3, byt + 6, bw + 6, 6, brick.darkened(0.18))
	# dense window grid (commercial block)
	_windows(bx, byt + 18, bw, 712 - byt - 18, 8801, 0.6, haze)
	# stair-step / tower parapet so it reads as a tall mill
	_rect(bx + bw / 2 - 16, byt - 18, 32, 18, brick.darkened(0.06))
	_rect(bx + bw / 2 - 16, byt - 20, 32, 3, brick.darkened(0.3))
	# tall smokestack beside it
	_rect(bx + bw - 14, byt - 70, 14, 70 + (712 - byt), brick.darkened(0.12).lerp(HAZE, haze * 1.2))
	_rect(bx + bw - 14, byt - 70, 14, 4, brick.darkened(0.3))


# ---------------------------------------------------------------- landmarks: church steeples
# Spread several modest steeples along the full length at irregular hash-driven positions,
# skipping the bands reserved for the mill/mural anchors so they never collide or repeat.
func _steeples() -> void:
	var spacing := 360.0
	var i := 0
	var x := 120.0
	while x < W - 80:
		var s := 6100 + i * 13
		# irregular jitter so positions never look evenly tiled
		var px := int(x + (_h(s) - 0.5) * 220.0)
		var skip := false
		for anchor in [150, 960, 2280, 2860, 3560, 4480]:
			if absi(px - anchor) < 150:
				skip = true
		# vary base height, size, and distance-haze per steeple (smaller/hazier = farther)
		if not skip and _h(s * 3) < 0.74:
			var sc := 0.7 + _h(s * 5) * 0.5
			var bod := 150 + int(_h(s * 7) * 120.0)
			var hz := _h(s * 9) * 0.18
			_steeple(px, hz, sc, bod)
		x += spacing
		i += 1


func _steeple(bx: int, haze: float, scale: float = 1.0, body_h: int = 210) -> void:
	var white := Color8(232, 230, 224).lerp(HAZE, haze)
	var shade := Color8(196, 196, 196).lerp(HAZE, haze)
	var base_y := 712 - body_h   # sits on a church body above the rooftops
	var tw := int(36 * scale)
	var belfry := int(44 * scale)
	var spire_h := int(96 * scale)
	# church body / tower base
	_rect(bx, base_y, tw, body_h, white)
	_rect(bx + int(tw * 0.66), base_y, int(tw * 0.34), body_h, Color(0, 0, 0, 0.10 * (1.0 - haze)))
	# belfry box with arched openings
	_rect(bx + 2, base_y - belfry, tw - 4, belfry, white)
	_rect(bx + int(tw * 0.2), base_y - belfry + 6, maxi(3, int(8 * scale)), int(22 * scale), shade.darkened(0.25))
	_rect(bx + tw - int(tw * 0.2) - int(8 * scale), base_y - belfry + 6, maxi(3, int(8 * scale)), int(22 * scale), shade.darkened(0.25))
	_rect(bx + 2, base_y - belfry, tw - 4, 3, shade)
	# tapering white spire (clearly above rooftops, not clipping top)
	_trap(bx + tw / 2, base_y - belfry - spire_h, 4, tw - 6, spire_h, white)
	# spire shaded side for volume
	for r in range(spire_h):
		var w := int(lerpf(4.0, float(tw - 6), float(r) / float(spire_h)))
		_rect(bx + tw / 2 + w / 6, base_y - belfry - spire_h + r, maxi(1, w / 3), 1, Color(0, 0, 0, 0.08 * (1.0 - haze)))
	# finial
	_rect(bx + tw / 2 - 1, base_y - belfry - spire_h - int(10 * scale), 2, int(10 * scale), shade.darkened(0.2))
	_disc(Vector2(bx + tw / 2, base_y - belfry - spire_h - int(12 * scale)), 2.0 * scale, shade.darkened(0.2))


# ---------------------------------------------------------------- landmark: painted mural wall
func _mural_wall(bx: int, haze: float) -> void:
	var bw := 132
	var bh := 234
	var byt := 712 - bh
	# host building (brick), mural painted on its broad side
	var brick := Color8(132, 70, 58).lerp(HAZE, haze)
	_rect(bx, byt, bw, 712 - byt, brick)
	_rect(bx, byt, bw, 2, brick.darkened(0.3))
	# soft pastel scene block (mural accent) — sky, hills, water bands
	var mx := bx + 12
	var my := byt + 22
	var mw := bw - 24
	var mh := bh - 44
	var sky := Color8(176, 198, 214).lerp(HAZE, haze)       # pale mural sky
	var hill := Color8(150, 180, 150).lerp(HAZE, haze)      # soft green
	var water := Color8(150, 176, 192).lerp(HAZE, haze)     # pale water
	_rect(mx, my, mw, mh, sky)
	_rect(mx, my + int(mh * 0.46), mw, int(mh * 0.30), hill)
	# rolling hill silhouette top
	for c in range(mw):
		var hy := my + int(mh * 0.46) - int(6.0 * (0.5 + 0.5 * sin((mx + c) * 0.07)))
		_rect(mx + c, hy, 1, my + int(mh * 0.46) - hy, hill)
	_rect(mx, my + int(mh * 0.76), mw, int(mh * 0.24), water)
	# a couple of pastel tree dabs + a sun disc, all muted
	_disc(Vector2(mx + mw - 18, my + 16), 7.0, Color8(238, 224, 180).lerp(HAZE, haze))
	for t in range(3):
		var tx := mx + 14 + t * int(mw * 0.34)
		_rect(tx, my + int(mh * 0.42), 7, 14, Color8(96, 132, 96).lerp(HAZE, haze))
	# thin painted frame
	_rect(mx - 2, my - 2, mw + 4, 2, brick.darkened(0.4))
	_rect(mx - 2, my + mh, mw + 4, 2, brick.darkened(0.4))
	# a few real windows on the rest of the facade
	_windows(bx + bw - 20, byt + 10, 20, 712 - byt - 10, 8820, 0.5, haze)


# ---------------------------------------------------------------- foreground play surface
func _foreground() -> void:
	# Nearest rooftops as solid dark platforms with a bright warm top edge, varied heights and
	# gaps along the length. Gaps reveal the layered misty town behind (depth). Wet sheen at base.
	var fill := Color8(40, 40, 48)
	var fill2 := Color8(28, 28, 36)
	var x := -40
	var i := 0
	while x < W + 40:
		var w := 200 + int(_h(i * 9 + 1) * 280)
		var top := 600 + int(_h(i * 5 + 2) * 70)
		_ledge(x, top, w, fill, fill2)
		# small props: chimney, HVAC box, fire-escape, utility pole — varied per ledge
		var k := i % 4
		if k == 0:  # chimney
			_rect(x + 38, top - 26, 12, 26, Color8(108, 70, 58))
			_rect(x + 38, top - 26, 12, 3, Color8(70, 48, 42))
		elif k == 1:  # HVAC box
			_rect(x + int(w * 0.5), top - 18, 30, 18, Color8(58, 60, 70))
			_rect(x + int(w * 0.5), top - 18, 30, 3, Color8(84, 86, 98))
		elif k == 2:  # utility pole with crossarm
			_rect(x + 60, top - 44, 3, 44, Color8(70, 56, 46))
			_rect(x + 50, top - 36, 23, 3, Color8(70, 56, 46))
		else:  # fire-escape rails
			for r in range(3):
				_rect(x + int(w * 0.4), top - 6 - r * 6, 34, 2, Color8(46, 48, 56))
			_rect(x + int(w * 0.4), top - 24, 2, 24, Color8(46, 48, 56))
			_rect(x + int(w * 0.4) + 32, top - 24, 2, 24, Color8(46, 48, 56))
		x += w + 64 + int(_h(i * 3) * 130)
		i += 1


func _ledge(x: int, top: int, w: int, fill: Color, fill2: Color) -> void:
	_rect(x, top, w, H - top, fill)
	_rect(x, top + (H - top) / 2, w, (H - top) / 2, fill2)
	# wet-street / wet-roof sheen suggestion near the base
	_rect(x, H - 10, w, 10, Color(0.62, 0.66, 0.72, 0.06))
	# bright warm top edge that pops on the muted palette
	_rect(x, top - 6, w, 8, Color(EDGE.r, EDGE.g, EDGE.b, 0.22))
	_rect(x, top, w, 3, EDGE)
