extends SceneTree
## Offline backdrop preview: paints a stage's lake stilt-village backdrop into a single PNG so the
## art direction can be inspected pixel-by-pixel without running the game (headless Godot cannot
## capture live nodes). The composition is authored in overlapping depth bands so the scene reads
## with real front-to-back depth (mountains behind a village over water), with atmospheric haze on
## distant layers and non-repeating placement so a long stage never looks tiled. These numbers port
## directly into the live per-stage backdrop builder.
##   godot --headless --path project --script res://tools/backdrop_stage3_lake.gd -- --width=4800 --out=/abs/path.png

var W := 1280
var H := 720
var img: Image

# ---- palette (vivid daytime lake mood) ----
const SKY_TOP := Color8(74, 150, 222)
const SKY_HORIZON := Color8(176, 214, 238)
const HAZE_BLUE := Color8(150, 180, 208)          # color distant layers fade toward
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
const EDGE_LIT := Color8(255, 214, 130)           # bright warm top edge that pops on this palette


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
const HORIZON := 372    # waterline: sky/mountains above, water below


func _compose() -> void:
	_sky()
	_clouds()
	# Far -> near mountain ridges: each nearer ridge is lower, less hazy, more saturated.
	_ridge(296, 56.0, 0.0017, 0.62, Color8(120, 150, 184), 11)
	_ridge(322, 46.0, 0.0024, 0.44, Color8(98, 132, 168), 23)
	_ridge(346, 38.0, 0.0033, 0.26, Color8(78, 116, 150), 37)
	_ridge(366, 26.0, 0.0049, 0.12, Color8(66, 108, 138), 53)
	_water()
	# Midground stilt-house village in overlapping depth bands (far -> near), each reflected.
	_house_band(382, 24, 34, 22, 34, 0.50, 41)
	_house_band(404, 34, 50, 30, 50, 0.30, 57)
	_house_band(436, 48, 74, 44, 78, 0.12, 73)
	_temple(0.10)                                  # signature larger temple-roofed house (front)
	_boats()                                       # signature long-tail boats with standing figure
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


# small deterministic hash -> 0..1
func _h(n: int) -> float:
	var x := (n * 1103515245 + 12345) & 0x7fffffff
	x = (x ^ (x >> 13)) * 1274126177 & 0x7fffffff
	return float(x % 10000) / 10000.0


# low-frequency, non-repeating envelope (cluster/quieter stretches along the length)
func _envelope(x: float) -> float:
	var a := 0.5 + 0.5 * sin(x * 0.0013)
	var b := 0.5 + 0.5 * sin(x * 0.0041 + 2.1)
	return clampf(0.30 + 0.5 * a + 0.28 * b - 0.08, 0.0, 1.0)


# ---------------------------------------------------------------- trapezoid (pitched roof)
func _trap(cx: int, top_y: int, top_w: int, bot_w: int, h: int, color: Color) -> void:
	for r in range(h + 1):
		var w := int(lerpf(float(top_w), float(bot_w), float(r) / float(h)))
		_rect(cx - w / 2, top_y + r, w, 1, color)


# ---------------------------------------------------------------- sky + clouds
func _sky() -> void:
	for y in range(HORIZON):
		var row := SKY_TOP.lerp(SKY_HORIZON, pow(float(y) / float(HORIZON), 1.25))
		for x in range(W):
			img.set_pixel(x, y, row)


func _cloud(cx: float, cy: float, scale: float, seedn: int) -> void:
	# flat rounded cumulus: cluster of soft white lobes with a slightly grey underside.
	var lobes := 5 + int(_h(seedn) * 4)
	var base_r := 14.0 * scale
	for k in range(lobes):
		var t := float(k) / float(lobes - 1)
		var lx := cx + lerpf(-46.0 * scale, 46.0 * scale, t)
		var hump := sin(t * PI)                     # taller in the middle
		var ly := cy - hump * 12.0 * scale
		var r := base_r * (0.55 + 0.55 * hump) * (0.8 + _h(seedn * 7 + k) * 0.5)
		_disc(Vector2(lx, ly + r * 0.5), r, Color8(190, 200, 214))  # grey underside
		_disc(Vector2(lx, ly), r, Color8(248, 251, 255))            # white top
	_rect(int(cx - 50 * scale), int(cy + 9 * scale), int(100 * scale), int(5 * scale), Color8(196, 206, 220))


func _clouds() -> void:
	# upper-sky cumulus, non-repeating placement/size across the full length.
	var step := 240.0
	var x := 60.0
	var i := 0
	while x < W + 120:
		var jitter := (_h(i * 13 + 3) - 0.5) * 150.0
		var cx := x + jitter
		var cy := 70.0 + _h(i * 9 + 1) * 130.0
		var scale := 0.7 + _h(i * 5 + 2) * 1.1
		if _h(i * 17) < 0.82:                        # occasional gaps for variety
			_cloud(cx, cy, scale, i * 29 + 5)
		x += step * (0.7 + _h(i * 3) * 0.8)
		i += 1


# ---------------------------------------------------------------- mountain ridges
func _ridge(base_y: int, amp: float, freq: float, haze: float, fill: Color, seedn: int) -> void:
	# smooth sine-based ridgeline; nearer ridges are lower, less hazy. Atmospheric perspective
	# fades each band toward the hazy blue distance color.
	var col := fill.lerp(HAZE_BLUE, haze)
	for x in range(W):
		var fx := float(x) + float(seedn) * 90.0
		var ridge := float(base_y) - (
			amp * (0.5 + 0.5 * sin(fx * freq))
			+ amp * 0.45 * sin(fx * freq * 2.7 + 1.3)
			+ amp * 0.22 * sin(fx * freq * 5.1 + 0.4)
		)
		_rect(x, int(ridge), 1, base_y - int(ridge) + 40, col)
	# faint lit rim along the ridgeline for a touch of form
	for x in range(W):
		var fx2 := float(x) + float(seedn) * 90.0
		var ridge2 := float(base_y) - (
			amp * (0.5 + 0.5 * sin(fx2 * freq))
			+ amp * 0.45 * sin(fx2 * freq * 2.7 + 1.3)
			+ amp * 0.22 * sin(fx2 * freq * 5.1 + 0.4)
		)
		_px(x, int(ridge2), Color(1, 1, 1, 0.10 * (1.0 - haze)))


# ---------------------------------------------------------------- water
func _water() -> void:
	for y in range(HORIZON, H):
		var t := float(y - HORIZON) / float(H - HORIZON)
		var row := WATER_TOP.lerp(WATER_DEEP, pow(t, 0.85))
		for x in range(W):
			img.set_pixel(x, y, row)
	# subtle horizontal ripple lines, denser near the viewer
	var y := HORIZON + 6
	var i := 0
	while y < H:
		var a := 0.05 + 0.10 * (float(y - HORIZON) / float(H - HORIZON))
		var dash := 40 + int(_h(i * 7) * 80)
		var x := -int(_h(i * 3) * 120)
		while x < W:
			_rect(x, y, dash, 1, Color(0.86, 0.94, 0.98, a))
			x += dash + 30 + int(_h(i * 11 + x) * 60)
		y += 7 + int(_h(i * 5) * 6)
		i += 1


# reflect a vertical column downward across the waterline, dimmer + wavy
func _reflect_col(x: int, top_y: int, height: int, c: Color, dim: float) -> void:
	if x < 0 or x >= W:
		return
	var rc := c.lerp(WATER_DEEP, dim)
	var wob := int(round(2.0 * sin(float(x) * 0.10)))     # gentle horizontal wobble
	for r in range(height):
		var src_y := top_y + r                            # source row in the object
		var dy := HORIZON + (HORIZON - src_y)             # mirror across the waterline
		if dy <= HORIZON:
			continue
		var fade := 1.0 - float(dy - HORIZON) / 96.0       # reflections decay with depth
		if fade <= 0.0:
			continue
		_px(x + wob, dy, Color(rc.r, rc.g, rc.b, clampf(fade, 0.0, 1.0) * 0.72))


# ---------------------------------------------------------------- stilt houses
func _bamboo_cluster(x: int, count: int, haze: float) -> void:
	# thin poles sticking out of the water (fish-trap frames), slight lean and varied height.
	var col := POLE.lerp(HAZE_BLUE, haze * 0.6)
	for k in range(count):
		var px := x + k * (4 + int(_h(x * 3 + k) * 5))
		var ph := 14 + int(_h(x * 7 + k) * 22)
		var lean := int((_h(x * 5 + k) - 0.5) * 6)
		_line(Vector2(px, HORIZON + 2), Vector2(px + lean, HORIZON + 2 - ph), col, 1)
	# occasional cross-tie between frames
	if _h(x) < 0.5 and count >= 3:
		_line(Vector2(x, HORIZON - 8), Vector2(x + (count - 1) * 6, HORIZON - 14), col, 1)


func _stilt_house(x: int, base_y: int, w: int, hbody: int, wall: Color, roof: Color, haze: float, seedn: int) -> void:
	# wooden house body on poles over water, with a pitched/metal roof; reflected below.
	var wall_c := wall.lerp(HAZE_BLUE, haze)
	var roof_c := roof.lerp(HAZE_BLUE, haze)
	var pole_c := POLE.lerp(HAZE_BLUE, haze)

	# stilts down to the water
	var leg_top := base_y
	var n_legs := maxi(2, int(w / 14))
	for l in range(n_legs):
		var lx := x + 3 + int(float(l) / float(n_legs - 1) * (w - 6))
		_rect(lx, leg_top, 2, HORIZON - leg_top + 3, pole_c)

	# body
	var body_top := base_y - hbody
	_rect(x, body_top, w, hbody, wall_c)
	_rect(x, body_top, w, 2, Color(1, 1, 1, 0.10 * (1.0 - haze)))            # lit top of wall
	_rect(x, body_top, 2, hbody, Color(0, 0, 0, 0.18 * (1.0 - haze)))       # shaded left
	_rect(x + w - 2, body_top, 2, hbody, Color(0, 0, 0, 0.22 * (1.0 - haze)))

	# windows / door (deterministic small grid)
	var ww := 3 + int(haze < 0.3)
	var cols := maxi(1, int((w - 6) / 10))
	for cx in range(cols):
		if _h(seedn * 31 + cx) < 0.7:
			var wx := x + 5 + cx * 10
			_rect(wx, body_top + int(hbody * 0.35), ww, maxi(3, int(hbody * 0.3)), Color8(58, 70, 86).lerp(HAZE_BLUE, haze))
	# door on larger houses
	if w > 40:
		_rect(x + w / 2 - 2, base_y - int(hbody * 0.55), 5, int(hbody * 0.55), WALL_DARK.lerp(HAZE_BLUE, haze))

	# pitched roof (overhanging trapezoid) + ridge highlight
	var roof_h := maxi(6, int(hbody * 0.55))
	var roof_top := body_top - roof_h
	_trap(x + w / 2, roof_top, int(w * 0.30), int(w * 1.18), roof_h, roof_c)
	_rect(x - int(w * 0.06), roof_top, int(w * 1.12), 2, roof_c.lightened(0.18))  # ridge cap
	# metal-roof corrugation lines
	for r in range(1, 3):
		_rect(x - int(w * 0.05), roof_top + int(roof_h * float(r) / 3.0), int(w * 1.1), 1, Color(0, 0, 0, 0.10 * (1.0 - haze)))

	# reflection: mirror body+roof columns across the waterline
	if haze < 0.45:
		for xx in range(x - int(w * 0.06), x + int(w * 1.06)):
			_reflect_col(xx, roof_top, base_y - roof_top, wall.lerp(roof, 0.5), 0.35)


func _house_band(base_y: int, hmin: int, hmax: int, wmin: int, wmax: int, haze: float, seed: int) -> void:
	var roofs := [ROOF_RED, ROOF_GREY, ROOF_GREEN, ROOF_RUST, ROOF_RED, ROOF_GREY]
	var walls := [WALL_WOOD, WALL_DARK, WALL_WOOD]
	var x := -60.0
	var i := 0
	var cluster_left := 0    # >0 while a tight bunch of houses is being placed
	while x < W + 60:
		var s := seed * 1000 + i
		var e := _envelope(x + float(seed) * 130.0)
		var w := int(wmin + _h(s * 9 + 2) * (wmax - wmin))
		var hbody := clampi(int((hmin + e * (hmax - hmin)) * (0.8 + _h(s * 5 + 7) * 0.5)), hmin, int(hmax * 1.15))
		var roof: Color = roofs[int(_h(s * 13) * roofs.size()) % roofs.size()]
		var wall: Color = walls[int(_h(s * 17) * walls.size()) % walls.size()]
		# nearer bands sit a touch lower (toward the viewer)
		var by := base_y + int(_h(s * 3) * 6)
		_stilt_house(int(x), by, w, hbody, wall, roof, haze, s)
		# Strongly irregular horizontal spacing: most gaps are modest but hash^2 lets some open up
		# into wide stretches of open water. A cluster mode occasionally bunches 2-3 houses almost
		# adjacent, then forces a large gap after — so there is no even rhythm along the length.
		var gap: float
		if cluster_left > 0:
			gap = 4.0 + _h(s * 11) * 10.0                     # bunched: nearly adjacent
			cluster_left -= 1
			if cluster_left == 0:
				gap += 120.0 + _h(s * 31) * 180.0            # big open-water gap after a cluster
		else:
			var g := _h(s * 11)
			gap = 16.0 + g * g * 260.0                        # mostly small, occasionally huge
			if _h(s * 37) < 0.28:                             # start a new tight cluster
				cluster_left = 1 + int(_h(s * 41) * 2.0)
		# scatter bamboo fish-trap frames in the gaps
		if _h(s * 23) < 0.55:
			_bamboo_cluster(int(x) + w + 6 + int(_h(s * 19) * 14), 3 + int(_h(s * 29) * 3), haze)
		x += w + gap
		i += 1


# ---------------------------------------------------------------- signature temple-roofed house
func _temple(haze: float) -> void:
	# A larger multi-tier roofed house — the village's standout structure. Spread out, not on a
	# repeat; placed once near the start and again deep into a long panorama.
	var spots := [648]
	if W > 2600:
		spots.append(2380)
	if W > 4400:
		spots.append(4180)
	for sx in spots:
		_temple_at(sx, haze)


func _temple_at(cx: int, haze: float) -> void:
	var base_y := 452
	var w := 112
	var hbody := 70
	var wall_c := Color8(140, 96, 72).lerp(HAZE_BLUE, haze)
	var roof_c := ROOF_RED.lerp(HAZE_BLUE, haze)
	var pole_c := POLE.lerp(HAZE_BLUE, haze)
	var x := cx - w / 2

	# stilts
	for l in range(6):
		var lx := x + 4 + int(float(l) / 5.0 * (w - 8))
		_rect(lx, base_y, 3, HORIZON - base_y + 3, pole_c)

	# body
	var body_top := base_y - hbody
	_rect(x, body_top, w, hbody, wall_c)
	_rect(x, body_top, w, 2, Color(1, 1, 1, 0.12))
	_rect(x, body_top, 2, hbody, Color(0, 0, 0, 0.18))
	_rect(x + w - 2, body_top, 2, hbody, Color(0, 0, 0, 0.22))
	# veranda rail + window row
	_rect(x, base_y - int(hbody * 0.42), w, 2, Color8(180, 150, 120).lerp(HAZE_BLUE, haze))
	for cxi in range(8):
		_rect(x + 8 + cxi * 13, body_top + 16, 6, 18, Color8(60, 74, 92).lerp(HAZE_BLUE, haze))
	# central door
	_rect(cx - 4, base_y - int(hbody * 0.5), 9, int(hbody * 0.5), WALL_DARK.lerp(HAZE_BLUE, haze))

	# stacked roofs (three tiers) for a distinct temple silhouette
	var tier_w := float(w) * 1.30
	var ty := body_top
	for tier in range(3):
		var rh := 22 - tier * 4
		ty -= rh
		_trap(cx, ty, int(tier_w * 0.30), int(tier_w), rh, roof_c)
		_rect(cx - int(tier_w) / 2, ty, int(tier_w), 2, roof_c.lightened(0.22))
		# upturned eaves accent
		_px(cx - int(tier_w) / 2, ty, roof_c.lightened(0.3))
		_px(cx + int(tier_w) / 2 - 1, ty, roof_c.lightened(0.3))
		tier_w *= 0.7
	# finial spire
	_rect(cx - 1, ty - 16, 3, 16, Color8(210, 180, 120))
	for k in range(3):
		_disc(Vector2(cx, ty - 4 - k * 5), 3.0, Color8(232, 202, 132))
	_disc(Vector2(cx, ty - 18), 4.0, Color8(244, 216, 150))

	# reflection
	if haze < 0.5:
		for xx in range(x - 14, x + w + 14):
			_reflect_col(xx, int(ty), base_y - int(ty), roof_c.lerp(wall_c, 0.5), 0.3)


# ---------------------------------------------------------------- signature boats
func _boats() -> void:
	var spots := [Vector2(940, HORIZON + 60)]
	if W > 2600:
		spots.append(Vector2(2100, HORIZON + 92))
	if W > 4400:
		spots.append(Vector2(3760, HORIZON + 70))
	for p in spots:
		_boat(int(p.x), int(p.y), 1.0 + _h(int(p.x)) * 0.3)


func _boat(cx: int, cy: int, scale: float) -> void:
	# slender long-tail canoe with a standing figure; faint wake.
	var hull := Color8(58, 44, 34)
	var hull_lit := Color8(96, 74, 54)
	var bw := int(110 * scale)
	var bh := int(9 * scale)
	# wake
	_rect(cx - bw / 2 - int(40 * scale), cy + 1, int(60 * scale), 2, Color(0.9, 0.96, 1.0, 0.25))
	_rect(cx - bw / 2 - int(20 * scale), cy + 4, int(40 * scale), 2, Color(0.9, 0.96, 1.0, 0.15))
	# hull (long, upturned ends)
	for r in range(bh):
		var t := float(r) / float(bh)
		var narrow := int(lerpf(0.0, float(bw) * 0.16, t))
		_rect(cx - bw / 2 + narrow, cy + r, bw - narrow * 2, 1, hull)
	_rect(cx - bw / 2, cy - 1, bw, 1, hull_lit)
	# upturned prow/stern
	_line(Vector2(cx - bw / 2, cy), Vector2(cx - bw / 2 - int(10 * scale), cy - int(8 * scale)), hull, 2)
	_line(Vector2(cx + bw / 2, cy), Vector2(cx + bw / 2 + int(12 * scale), cy - int(7 * scale)), hull, 2)
	# standing figure (silhouette with a conical hat)
	var fx := cx + int(bw * 0.18)
	var fy := cy - int(2 * scale)
	_rect(fx - 2, fy - int(22 * scale), 4, int(22 * scale), Color8(46, 40, 50))      # body
	_disc(Vector2(fx, fy - int(24 * scale)), 3.0 * scale, Color8(46, 40, 50))        # head
	_trap(fx, fy - int(30 * scale), 1, int(14 * scale), int(6 * scale), Color8(206, 178, 120))  # hat
	# long oar/pole
	_line(Vector2(fx, fy - int(14 * scale)), Vector2(cx - int(bw * 0.36), cy + int(10 * scale)), Color8(70, 54, 40), 1)


# ---------------------------------------------------------------- foreground play surface
func _foreground() -> void:
	# Nearest stilt-house rooftops / docks as solid dark platforms with a bright warm top edge for
	# gameplay readability. Varied heights and gaps along the length; gaps reveal the village behind
	# (depth). Each platform carries a small prop (pole, hanging net, or potted plant).
	var fill := Color8(38, 46, 52)
	var fill2 := Color8(26, 34, 40)
	var x := -40
	var i := 0
	while x < W + 40:
		var w := 190 + int(_h(i * 9 + 1) * 260)
		var top := 600 + int(_h(i * 5 + 2) * 70)
		_dock(x, top, w, fill, fill2, i)
		x += w + 60 + int(_h(i * 3) * 130)
		i += 1


func _dock(x: int, top: int, w: int, fill: Color, fill2: Color, i: int) -> void:
	# platform body with a darker lower half (depth) and a bright lit top edge
	_rect(x, top, w, H - top, fill)
	_rect(x, top + (H - top) / 2, w, (H - top) / 2, fill2)
	# wooden plank lines
	for r in range(1, 4):
		_rect(x, top + r * 8, w, 1, Color(0, 0, 0, 0.16))
	# supporting poles dipping below the front edge
	_rect(x + 14, top, 4, H - top, Color8(30, 38, 44))
	_rect(x + w - 18, top, 4, H - top, Color8(30, 38, 44))
	# bright top edge
	_rect(x, top - 6, w, 8, Color(EDGE_LIT.r, EDGE_LIT.g, EDGE_LIT.b, 0.22))
	_rect(x, top, w, 3, EDGE_LIT)

	# varied prop
	var prop := i % 3
	var px := x + 36 + int(_h(i * 7) * (w - 80))
	if prop == 0:                                   # mooring pole with a small lamp
		_rect(px, top - 30, 3, 30, Color8(70, 52, 38))
		_disc(Vector2(px + 1, top - 33), 4.0, Color(1.0, 0.78, 0.4, 0.35))
		_disc(Vector2(px + 1, top - 33), 2.5, Color8(255, 196, 110))
	elif prop == 1:                                 # hanging fishing net between two posts
		_rect(px, top - 26, 2, 26, Color8(60, 50, 40))
		_rect(px + 34, top - 26, 2, 26, Color8(60, 50, 40))
		_line(Vector2(px, top - 24), Vector2(px + 34, top - 24), Color8(150, 140, 110), 1)
		for nx in range(0, 36, 5):
			_line(Vector2(px + nx, top - 24), Vector2(px + nx - 3, top - 6), Color(0.6, 0.56, 0.44, 0.6), 1)
		for ny in range(-20, -4, 5):
			_line(Vector2(px, top + ny), Vector2(px + 34, top + ny - 2), Color(0.6, 0.56, 0.44, 0.5), 1)
	else:                                           # potted plant
		_rect(px, top - 10, 12, 10, Color8(120, 70, 50))
		_disc(Vector2(px + 6, top - 14), 8.0, VEG_DARK)
		_disc(Vector2(px + 3, top - 16), 6.0, VEG)
		_disc(Vector2(px + 10, top - 15), 5.0, VEG)
