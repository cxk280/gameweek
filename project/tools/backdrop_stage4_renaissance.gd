extends SceneTree
## Offline backdrop preview for a warm golden-hour stage: paints a stylized flat pixel-vector
## cityscape of terracotta rooftops into a single PNG so the art direction can be inspected
## pixel-by-pixel without running the game (headless Godot cannot capture live nodes). The
## composition is authored in overlapping far->near depth bands with atmospheric haze so the
## scene reads with depth, a non-repeating low-frequency envelope, and curated landmarks so a
## long stage never looks tiled. These numbers port into the live per-stage backdrop builder.
##   godot --headless --path project --script res://tools/backdrop_stage4_renaissance.gd -- --width=4800 --out=/abs/path.png

var W := 1280
var H := 720
var img: Image

# ---- palette (warm golden-hour mood) -----------------------------------------
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
const CYPRESS := Color8(54, 74, 58)           # dark green tree silhouette


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
	_clouds()
	_hills()
	# Far -> near rooftop bands. Each is hazier/higher/smaller farther back.
	_roof_band(486.0, 26, 70, 50, 96, Color8(214, 150, 96), Color8(228, 172, 112), 0.58, 0.10, 0.62, 11)
	_roof_band(548.0, 40, 120, 70, 140, Color8(208, 132, 80), Color8(226, 158, 96), 0.38, 0.20, 0.58, 23)
	# Signature landmark sits above the mid rooftop sea near the start; echoes along the length.
	_great_dome(Vector2(372, 540), 1.0)
	if W > 2600:
		_church(Vector2(2480, 520), 0.74)
	if W > 3900:
		_great_dome(Vector2(4180, 544), 0.88)
	# A few extra tall slender bell towers rising above the rooftop sea — special vertical
	# accents at non-repeating positions, varied in height/banding/tint, never a forest.
	if W > 1100:
		_bell_tower(Vector2(940, 552), 280.0, 0.82, Color8(232, 214, 184), 4)
	if W > 1900:
		_bell_tower(Vector2(1640, 540), 320.0, 0.92, Color8(224, 208, 182), 5)
	if W > 3000:
		_bell_tower(Vector2(2960, 548), 250.0, 0.78, Color8(236, 220, 192), 4)
	if W > 4400:
		_bell_tower(Vector2(3720, 544), 300.0, 0.88, Color8(220, 204, 176), 5)
	_roof_band(622.0, 60, 180, 96, 172, Color8(200, 116, 66), Color8(222, 146, 84), 0.18, 0.34, 0.56, 37)
	_roof_band(720.0, 80, 240, 116, 200, Color8(192, 104, 58), Color8(216, 138, 76), 0.05, 0.44, 0.54, 53)
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
			var dx := float(xx) - center.x
			var dy := float(yy) - center.y
			if dx * dx + dy * dy <= r2:
				_px(xx, yy, c)


# upper half-disc only (for domes): paints where dy <= 0
func _half_disc(center: Vector2, r: float, c: Color) -> void:
	var r2 := r * r
	for yy in range(int(center.y - r), int(center.y) + 1):
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


# low-frequency, non-repeating height envelope (denser clusters + quieter stretches)
func _envelope(x: float) -> float:
	var a := 0.5 + 0.5 * sin(x * 0.0013)
	var b := 0.5 + 0.5 * sin(x * 0.0041 + 2.1)
	return clampf(0.30 + 0.5 * a + 0.28 * b - 0.08, 0.0, 1.0)


# trapezoid: top-centered, flares to bottom width over height h
func _trap(cx: int, top_y: int, top_w: int, bot_w: int, h: int, color: Color) -> void:
	for r in range(h + 1):
		var w := int(lerpf(float(top_w), float(bot_w), float(r) / float(h)))
		_rect(cx - w / 2, top_y + r, w, 1, color)


# ---------------------------------------------------------------- sky
func _sky() -> void:
	for y in range(H):
		# warm blue overhead easing to peach/gold near the horizon
		var row := SKY_TOP.lerp(SKY_HORIZON, pow(float(y) / float(H), 1.5))
		for x in range(W):
			img.set_pixel(x, y, row)
	# hazy warm glow band low on the horizon
	for y in range(430, 600):
		var a := (1.0 - absf(float(y) - 512.0) / 84.0) * 0.30
		if a > 0.0:
			_rect(0, y, W, 1, Color(GLOW.r, GLOW.g, GLOW.b, a))


func _clouds() -> void:
	# a few warm-lit stylized flat clouds; deterministic placement, non-repeating
	var n := maxi(3, int(W / 360))
	for i in range(n):
		var cx := int((_h(i * 17 + 3) * 0.9 + 0.05) * W)
		var cy := 90 + int(_h(i * 31 + 5) * 150.0)
		var s := 0.7 + _h(i * 13 + 1) * 0.9
		_cloud(Vector2(cx, cy), s)


func _cloud(pos: Vector2, s: float) -> void:
	var body := Color(1.0, 0.93, 0.84, 0.85)
	var lit := Color(1.0, 0.88, 0.70, 0.9)      # warm underside catching the low sun
	var lobes := [
		Vector2(-46, 4), Vector2(-22, -8), Vector2(4, -12),
		Vector2(30, -6), Vector2(52, 2), Vector2(18, 6), Vector2(-10, 8),
	]
	for l in lobes:
		_disc(pos + l * s, (14.0 + _h(int(l.x) * 7) * 8.0) * s, body)
	# warm lit base strip
	for l in [Vector2(-30, 9), Vector2(0, 11), Vector2(28, 9)]:
		_disc(pos + l * s, 9.0 * s, lit)


# ---------------------------------------------------------------- hills
func _hills() -> void:
	# 2-3 overlapping sine ridgelines, hazier/lighter farther back (atmospheric perspective)
	_ridge(470.0, 30.0, 0.0038, 0.011, 0.0, HILL_FAR, 0.62)
	_ridge(486.0, 34.0, 0.0029, 0.009, 1.7, HILL_MID, 0.50)
	_ridge(502.0, 26.0, 0.0052, 0.015, 3.4, HILL_NEAR, 0.40)


func _ridge(base_y: float, amp: float, f1: float, f2: float, phase: float, col: Color, haze: float) -> void:
	var c := col.lerp(HAZE, haze)
	for x in range(W):
		var ridge := base_y - (amp * (0.5 + 0.5 * sin(x * f1 + phase)) + 0.5 * amp * sin(x * f2 + phase * 2.0))
		_rect(x, int(ridge), 1, int(base_y + 120.0 - ridge), c)


# ---------------------------------------------------------------- rooftop houses
func _windows(x: int, top: int, w: int, h: int, seedn: int, density: float, haze: float) -> void:
	# small shuttered windows on a cream-stone wall; some warm-lit
	var step := 13
	var cols := int((w - 8) / step)
	var rows := int((h - 6) / step)
	for cy in range(rows):
		for cx in range(cols):
			var idx := seedn * 131 + cy * 17 + cx * 3
			if _h(idx) > density:
				continue
			var wx := x + 6 + cx * step
			var wy := top + 5 + cy * step
			var lit := _h(idx * 5) < 0.34
			var col: Color = (LIT if lit else SHUTTER).lerp(HAZE, haze * 0.7)
			var a := (0.8 if lit else 0.62) * (1.0 - haze * 0.5)
			_rect(wx, wy, 5, 6, Color(col.r, col.g, col.b, a))


func _house(x: int, base_y: int, w: int, h: int, roof: Color, haze: float, seedn: int) -> void:
	# cream-stone wall body topped with a flared/pitched or gabled terracotta roof
	var roof_h := clampi(int(h * 0.40), 12, 60)
	var wall_h := h - roof_h
	var wall_top := base_y - wall_h
	var roof_top := wall_top - roof_h
	var wall := STONE.lerp(STONE_DK, _h(seedn * 3)).lerp(HAZE, haze)
	var r2 := roof.lerp(HAZE, haze)
	_rect(x, wall_top, w, wall_h, wall)
	_rect(x, wall_top, w, 2, Color(0, 0, 0, 0.16 * (1.0 - haze)))  # eave shadow
	# shaded right portion for chunky form
	_rect(x + int(w * 0.66), wall_top, int(w * 0.34), wall_h, Color(0, 0, 0, 0.10 * (1.0 - haze)))
	_windows(x, wall_top, w, wall_h, seedn, 0.45 - haze * 0.2, haze)

	var k := int(_h(seedn * 7) * 3)
	if k == 0:
		# flared pitched roof (wider eaves than ridge)
		_trap(x + w / 2, roof_top, int(w * 0.34), int(w * 1.12), roof_h, r2)
	elif k == 1:
		# gabled block: flat-ish low pitch
		_trap(x + w / 2, roof_top + int(roof_h * 0.4), int(w * 0.6), int(w * 1.04), int(roof_h * 0.6), r2)
		_rect(x, roof_top + int(roof_h * 0.4), w, int(roof_h * 0.4), r2.darkened(0.06))
	else:
		# asymmetric mono-pitch shed roof (orientation variety)
		var dir := 1 if _h(seedn * 11) < 0.5 else -1
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
	while x < W + 90:
		var s := seed * 1000 + i
		var e := _envelope(x + float(seed) * 130.0)
		var w := int(wmin + _h(s * 9 + 2) * (wmax - wmin))
		var h := clampi(int((hmin + e * (hmax - hmin)) * (0.80 + _h(s * 5 + 7) * 0.5)), hmin, int(hmax * 1.12))
		# vary ochre shade per house so the sea never looks tiled
		var roof := roof_a.lerp(roof_b, _h(s * 4))
		_house(int(x), int(base_y), w, h, roof, haze, s)
		x += maxf(float(w) * step_frac, 16.0)
		i += 1


# ---------------------------------------------------------------- landmarks
func _great_dome(pos: Vector2, scale: float) -> void:
	# great ribbed terracotta dome with lantern cupola, beside a tall slender bell tower
	var cx := int(pos.x)
	var base_y := int(pos.y)
	var dome_r := 78.0 * scale

	# --- octagonal cream drum the dome sits on
	var drum_w := int(dome_r * 1.7)
	var drum_h := int(58 * scale)
	_rect(cx - drum_w / 2, base_y - drum_h, drum_w, drum_h, STONE)
	_rect(cx - drum_w / 2, base_y - drum_h, drum_w, 3, Color(0, 0, 0, 0.12))
	# round drum windows
	for wi in range(4):
		var wx := cx - drum_w / 2 + int(drum_w * (0.18 + 0.21 * wi))
		_disc(Vector2(wx, base_y - drum_h / 2), 4.0 * scale, SHUTTER.darkened(0.1))

	# --- the dome: stacked half-discs darkening downward for a domed read
	var dome_base_y := base_y - drum_h
	_half_disc(Vector2(cx, dome_base_y), dome_r, DOME_DK)
	_half_disc(Vector2(cx, dome_base_y), dome_r * 0.97, DOME)
	# left-lit highlight crescent
	_half_disc(Vector2(cx - dome_r * 0.16, dome_base_y), dome_r * 0.78, DOME_LT)
	_half_disc(Vector2(cx, dome_base_y), dome_r * 0.62, DOME)
	# vertical ribs converging at the apex (stylized flat ribbing)
	var ribs := 7
	for ri in range(ribs):
		var t := float(ri) / float(ribs - 1)
		var bx := cx + int(lerpf(-dome_r * 0.92, dome_r * 0.92, t))
		_line(Vector2(cx, dome_base_y - dome_r), Vector2(bx, dome_base_y), DOME_DK, maxi(1, int(scale * 1.5)))

	# --- lantern cupola on top (must not clip frame; sits well inside)
	var lan_w := int(20 * scale)
	var lan_h := int(30 * scale)
	var apex_y := dome_base_y - int(dome_r)
	_rect(cx - lan_w / 2, apex_y - lan_h, lan_w, lan_h, STONE)
	_rect(cx - lan_w / 2, apex_y - lan_h, lan_w, lan_h, Color(LIT.r, LIT.g, LIT.b, 0.18))
	_rect(cx - int(lan_w * 0.18), apex_y - lan_h + int(lan_h * 0.3), int(lan_w * 0.36), int(lan_h * 0.5), SHUTTER)
	# conical cap + golden finial
	_trap(cx, apex_y - lan_h - int(14 * scale), 2, lan_w, int(14 * scale), DOME_DK)
	_rect(cx - 1, apex_y - lan_h - int(24 * scale), 2, int(10 * scale), Color8(214, 176, 96))
	_disc(Vector2(cx, apex_y - lan_h - int(24 * scale)), 3.0 * scale, Color8(236, 200, 120))

	# --- bell tower: tall slender light-stone shaft with banded tiers
	var tw := int(30 * scale)
	var tx := cx + int(dome_r * 1.05)
	var t_top := base_y - int(290 * scale)
	if t_top < 30:
		t_top = 30  # keep inside frame
	_rect(tx, t_top, tw, base_y - t_top, STONE)
	_rect(tx + int(tw * 0.7), t_top, int(tw * 0.3), base_y - t_top, Color(0, 0, 0, 0.10))
	# banded tiers with arched openings
	var tiers := 5
	for ti in range(tiers):
		var ty := t_top + int(float(base_y - t_top) * (0.12 + 0.16 * ti))
		_rect(tx - 1, ty, tw + 2, 3, STONE_DK.darkened(0.05))
		# paired arched windows per tier
		_rect(tx + int(tw * 0.22), ty + 6, int(tw * 0.18), int(14 * scale), SHUTTER)
		_rect(tx + int(tw * 0.60), ty + 6, int(tw * 0.18), int(14 * scale), SHUTTER)
	# crenellated cap
	_rect(tx - 2, t_top - int(8 * scale), tw + 4, int(8 * scale), STONE_DK)
	for cbi in range(3):
		_rect(tx + 2 + cbi * int(tw * 0.34), t_top - int(15 * scale), int(tw * 0.2), int(8 * scale), STONE_DK)


func _church(pos: Vector2, scale: float) -> void:
	# a smaller echoing domed church further along the length
	var cx := int(pos.x)
	var base_y := int(pos.y)
	var dome_r := 50.0 * scale
	var drum_w := int(dome_r * 1.5)
	var drum_h := int(40 * scale)
	_rect(cx - drum_w / 2, base_y - drum_h, drum_w, drum_h, STONE)
	var dome_base_y := base_y - drum_h
	_half_disc(Vector2(cx, dome_base_y), dome_r, DOME_DK)
	_half_disc(Vector2(cx, dome_base_y), dome_r * 0.95, DOME)
	_half_disc(Vector2(cx - dome_r * 0.18, dome_base_y), dome_r * 0.7, DOME_LT)
	for ri in range(5):
		var t := float(ri) / 4.0
		var bx := cx + int(lerpf(-dome_r * 0.85, dome_r * 0.85, t))
		_line(Vector2(cx, dome_base_y - dome_r), Vector2(bx, dome_base_y), DOME_DK, 1)
	# small lantern
	var lan_w := int(14 * scale)
	var apex_y := dome_base_y - int(dome_r)
	_rect(cx - lan_w / 2, apex_y - int(18 * scale), lan_w, int(18 * scale), STONE)
	_trap(cx, apex_y - int(30 * scale), 2, lan_w, int(12 * scale), DOME_DK)
	_disc(Vector2(cx, apex_y - int(32 * scale)), 2.5 * scale, Color8(236, 200, 120))


func _bell_tower(pos: Vector2, height: float, scale: float, stone: Color, tiers: int) -> void:
	# A standalone tall slender bell tower rising above the rooftop sea. A special vertical
	# accent: light-stone shaft with banded tiers, arched openings, and a crenellated cap.
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
	# banded tiers with paired arched openings
	for ti in range(tiers):
		var ty := t_top + int(float(shaft_h) * (0.10 + (0.86 / float(tiers)) * ti))
		_rect(tx - 1, ty, tw + 2, 3, stone_dk)
		_rect(tx + int(tw * 0.20), ty + 6, int(tw * 0.18), int(15 * scale), SHUTTER)
		_rect(tx + int(tw * 0.60), ty + 6, int(tw * 0.18), int(15 * scale), SHUTTER)
	# crenellated cap (must not clip top)
	_rect(tx - 2, t_top - int(8 * scale), tw + 4, int(8 * scale), stone_dk)
	for cbi in range(3):
		_rect(tx + 2 + cbi * int(tw * 0.34), t_top - int(15 * scale), int(tw * 0.2), int(8 * scale), stone_dk)


# ---------------------------------------------------------------- foreground play surface
func _foreground() -> void:
	# Nearest rooftops as solid platforms with a bright cream/gold top edge that pops; varied
	# heights and gaps along the length. Gaps reveal the layered city behind (depth). Small props.
	var fill := Color8(120, 70, 46)            # warm terracotta solid
	var fill2 := Color8(92, 54, 38)
	var edge := RIDGE_LT
	var x := -40
	var i := 0
	while x < W + 40:
		var w := 200 + int(_h(i * 9 + 1) * 280)
		var top := 600 + int(_h(i * 5 + 2) * 70)
		_ledge(x, top, w, fill, fill2, edge)
		# tile-line shading
		for r in range(1, 4):
			_rect(x, top + r * 9, w, 1, Color(0, 0, 0, 0.14))
		# small props, varied
		var prop := int(_h(i * 4) * 3)
		if prop == 0:
			# chimney
			_rect(x + 36, top - 22, 16, 22, Color8(150, 92, 60))
			_rect(x + 34, top - 26, 20, 5, Color8(120, 72, 48))
		elif prop == 1:
			# roof terrace railing
			_rect(x + 24, top - 16, w - 48, 2, STONE_DK)
			for rb in range(int((w - 48) / 16)):
				_rect(x + 24 + rb * 16, top - 16, 2, 16, STONE_DK)
		else:
			# cypress tree silhouette
			var ctx := x + int(w * 0.5)
			_rect(ctx - 2, top - 14, 4, 14, Color8(80, 56, 40))
			_trap(ctx, top - 70, 4, 26, 60, CYPRESS)
			_trap(ctx, top - 70, 3, 18, 44, CYPRESS.lightened(0.06))
		x += w + 60 + int(_h(i * 3) * 130)
		i += 1


func _ledge(x: int, top: int, w: int, fill: Color, fill2: Color, edge: Color) -> void:
	_rect(x, top, w, H - top, fill)
	_rect(x, top + (H - top) / 2, w, (H - top) / 2, fill2)
	_rect(x, top - 6, w, 8, Color(edge.r, edge.g, edge.b, 0.30))  # glow
	_rect(x, top, w, 3, edge)                                      # bright top edge
