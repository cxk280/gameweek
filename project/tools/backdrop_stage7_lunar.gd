extends SceneTree
## Offline backdrop preview for a stage set on a barren gray surface beneath a star-filled
## void, with a domed outpost built in overlapping depth bands. Paints flat pixel-vector art
## into a single PNG so the art direction can be inspected pixel-by-pixel without running the
## game (headless Godot cannot capture live nodes). Composition is authored far->near so the
## scene reads with depth: distant structures sit higher, smaller, and hazier; near structures
## are larger, lower, and sharper. A non-repeating envelope + deterministic hash keep a long
## stage from ever looking tiled. These numbers port directly into the live backdrop builder.
##   godot --headless --path project --script res://tools/backdrop_stage7_lunar.gd -- --width=4800 --out=/abs/path.png

var W := 1280
var H := 720
var img: Image

# palette: black void, blue marble, gray ground, white/silver structures, green+amber lights
const SILVER := Color8(214, 222, 232)
const STEEL := Color8(150, 162, 178)
const STEEL_DK := Color8(86, 96, 112)
const WIN_GREEN := Color8(120, 235, 150)
const WIN_AMBER := Color8(255, 196, 92)
const TECH_EDGE := Color8(120, 240, 255)
const INTERIOR_G := Color8(70, 200, 120)


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
	_stars()
	_sun(Vector2(W * 0.04 + 30.0, 92.0))
	_earth(Vector2(W * 0.30, 150.0), 118.0)           # hero landmark, high + unclipped
	# far -> near ground/structure bands. Farther = higher base, lighter haze, smaller.
	_ground_band(456.0, Color8(118, 122, 130), 0.55, 17)
	_colony_band(456.0, 30, 54, 150, 230, 0.52, 0.30, 11)
	_ground_band(520.0, Color8(96, 100, 108), 0.34, 29)
	_colony_band(522.0, 46, 80, 200, 320, 0.30, 0.42, 23)
	_signature_dome(Vector2(W * 0.50, 540.0), 132.0)   # lush-interior glass dome (hero #2)
	_big_dish(Vector2(W * 0.80, 470.0), 1.0)           # distinct skyline dish landmark
	_ground_band(596.0, Color8(74, 78, 86), 0.14, 41)
	_colony_band(600.0, 64, 110, 260, 400, 0.10, 0.50, 37)
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


# upper half-disc (dome silhouette): only paints rows at or above the center y
func _dome_fill(center: Vector2, r: float, c: Color) -> void:
	var r2 := r * r
	for yy in range(int(center.y - r), int(center.y) + 1):
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


# low-frequency, non-repeating envelope (clustered outposts + quieter stretches)
func _envelope(x: float) -> float:
	var a := 0.5 + 0.5 * sin(x * 0.0013)
	var b := 0.5 + 0.5 * sin(x * 0.0041 + 2.1)
	return clampf(0.30 + 0.5 * a + 0.28 * b - 0.08, 0.0, 1.0)


# ---------------------------------------------------------------- sky + sky bodies
func _sky() -> void:
	# the only gradient in the piece: near-black void easing very slightly toward the horizon
	var top := Color8(4, 5, 12)
	var horizon := Color8(10, 11, 22)
	for y in range(H):
		var row := top.lerp(horizon, pow(float(y) / float(H), 1.4))
		for x in range(W):
			img.set_pixel(x, y, row)
	# faint diffuse band drifting across the upper sky (a distant luminous river of stars)
	for y in range(40, 300):
		var a := (1.0 - absf(float(y) - 150.0) / 130.0) * 0.05
		if a > 0.0:
			_rect(0, y, W, 1, Color(0.62, 0.66, 0.85, a))


func _stars() -> void:
	var earth := Vector2(W * 0.30, 150.0)
	var n := int(W * 0.42)
	for i in range(n):
		var sx := int(_h(i * 7 + 1) * W)
		var sy := int(_h(i * 13 + 3) * 430.0)
		if Vector2(sx, sy).distance_to(earth) < 150.0:
			continue
		var b := 0.40 + _h(i * 5) * 0.6
		var bright := _h(i * 3)
		var size := 1
		if bright > 0.94:
			size = 2
		_rect(sx, sy, size, size, Color(b, b, b * 1.06, 0.92))
		if bright > 0.985:  # rare bright star gets a soft cross-glow
			_px(sx - 1, sy, Color(b, b, b, 0.4))
			_px(sx + 2, sy, Color(b, b, b, 0.4))
			_px(sx, sy - 1, Color(b, b, b, 0.4))
			_px(sx, sy + 2, Color(b, b, b, 0.4))


func _sun(center: Vector2) -> void:
	# small, very bright distant disc with subtle glare
	for k in range(10, 0, -1):
		_disc(center, 7.0 * (1.0 + float(k) * 0.6), Color(1.0, 0.99, 0.95, 0.018))
	_disc(center, 9.0, Color(1.0, 0.99, 0.94, 0.5))
	_disc(center, 6.0, Color8(255, 255, 250))


func _earth(center: Vector2, r: float) -> void:
	# blue marble: ocean base, flat landmass shapes, white cloud swirls, cyan atmosphere rim.
	# soft atmosphere rim-glow
	for k in range(16, 0, -1):
		_disc(center, r * (1.0 + float(k) * 0.022), Color(0.40, 0.72, 1.0, 0.030))
	_disc(center, r * 1.05, Color(0.45, 0.75, 1.0, 0.16))
	# ocean
	var ocean := Color8(38, 92, 175)
	var ocean_dk := Color8(26, 66, 138)
	_disc(center, r, ocean)
	# subtly darker oceanic lower-right for a hint of form
	_disc(center + Vector2(r * 0.30, r * 0.30), r * 0.74, Color(ocean_dk.r, ocean_dk.g, ocean_dk.b, 0.45))

	# deterministic flat landmasses (green/brown), clipped to the disc
	var land := Color8(86, 150, 78)
	var land_b := Color8(150, 134, 86)
	var blobs := [
		Vector2(-0.40, -0.18), Vector2(-0.08, -0.42), Vector2(0.34, -0.30),
		Vector2(0.46, 0.06), Vector2(0.18, 0.30), Vector2(-0.20, 0.46),
		Vector2(-0.50, 0.22), Vector2(0.06, -0.02),
	]
	for bi in range(blobs.size()):
		var off: Vector2 = blobs[bi]
		var lc := center + Vector2(off.x * r, off.y * r)
		var lr := r * (0.12 + _h(bi * 17 + 5) * 0.13)
		var lcol: Color = land if _h(bi * 7) < 0.7 else land_b
		# cluster a few discs into an irregular flat landmass, clipped to the globe
		for j in range(5):
			var jx := (_h(bi * 31 + j * 3) - 0.5) * lr * 1.6
			var jy := (_h(bi * 53 + j * 5) - 0.5) * lr * 1.6
			var p := lc + Vector2(jx, jy)
			if p.distance_to(center) < r - 3.0:
				_disc(p, lr * (0.5 + _h(bi * 13 + j) * 0.5), lcol)

	# white cloud swirls (flat, clipped)
	var cloud := Color(1.0, 1.0, 1.0, 0.55)
	var clouds := [
		Vector2(-0.32, -0.40), Vector2(0.40, -0.18), Vector2(-0.42, 0.18),
		Vector2(0.12, 0.44), Vector2(0.30, 0.10), Vector2(-0.10, -0.12),
		Vector2(0.50, 0.28),
	]
	for ci in range(clouds.size()):
		var co: Vector2 = clouds[ci]
		var cc := center + Vector2(co.x * r, co.y * r)
		for j in range(4):
			var jx := (_h(ci * 41 + j * 7) - 0.5) * r * 0.5
			var jy := (_h(ci * 59 + j * 9) - 0.5) * r * 0.28
			var p := cc + Vector2(jx, jy)
			if p.distance_to(center) < r - 2.0:
				_disc(p, r * (0.05 + _h(ci * 23 + j) * 0.07), cloud)

	# bright terminator highlight on the upper-left limb (toward the sun)
	for k in range(6, 0, -1):
		_disc(center + Vector2(-r * 0.30, -r * 0.30), r * 0.16 * float(k) / 6.0, Color(0.8, 0.92, 1.0, 0.05))


# ---------------------------------------------------------------- ground depth bands
func _ground_band(base_y: float, fill: Color, haze: float, seed: int) -> void:
	# a rolling regolith ridge; farther bands are lighter (haze) so depth reads even airless.
	var sky := Color8(10, 11, 22)
	var col := fill.lerp(sky, haze)
	var col_lo := Color(col.r * 0.86, col.g * 0.86, col.b * 0.88, 1.0)
	for x in range(W):
		var e := 0.5 + 0.5 * sin((x + seed * 90) * 0.0017)
		var n := 0.5 + 0.5 * sin((x + seed * 50) * 0.011 + 1.3)
		var ridge := base_y - (10.0 + 18.0 * e + 7.0 * n)
		_rect(x, int(ridge), 1, H - int(ridge), col)
		# darker lower seam for a subtle terrain shelf
		_rect(x, int(base_y + 26.0), 1, 4, col_lo)

	# scattered craters (rings) and rocks across this band, deterministic + non-repeating
	var step := 150
	var i := 0
	while i * step < W + step:
		var hx := _h(seed * 311 + i * 7)
		var cx := int((float(i) + hx) * step) - 40
		var cy := int(base_y + 22.0 + _h(seed * 131 + i * 5) * 34.0)
		var cr := 10.0 + _h(seed * 71 + i * 3) * (22.0 - haze * 10.0)
		_crater(Vector2(cx, cy), cr, col, haze)
		if _h(seed * 53 + i) < 0.6:
			var rx := cx + int((_h(seed * 17 + i) - 0.5) * 120.0)
			var ry := cy + int(_h(seed * 19 + i) * 20.0)
			var rr := 3.0 + _h(seed * 23 + i) * 6.0
			_disc(Vector2(rx, ry), rr, col_lo)
			_disc(Vector2(rx, ry - rr * 0.4), rr * 0.6, col.lightened(0.10))
		i += 1


func _crater(center: Vector2, r: float, ground: Color, haze: float) -> void:
	# flat ring: bright far rim, darker interior — no gradient, just two flat tones
	var rim := ground.lightened(0.22 * (1.0 - haze * 0.5))
	var floor_c := ground.darkened(0.28 * (1.0 - haze * 0.4))
	_disc(center, r, rim)
	_disc(center, r * 0.78, floor_c)
	# bright crescent on the lit (upper-left) rim
	_disc(center + Vector2(-r * 0.18, -r * 0.20), r * 0.74, Color(rim.r, rim.g, rim.b, 0.0))
	for a in range(0, 360, 8):
		var rad := deg_to_rad(float(a))
		var p := center + Vector2(cos(rad), sin(rad)) * r * 0.88
		if cos(rad) < -0.1 and sin(rad) < 0.2:
			_disc(p, maxf(1.0, r * 0.10), Color(rim.r, rim.g, rim.b, 0.7))


# ---------------------------------------------------------------- colony depth bands
func _colony_band(base_y: float, smin: int, smax: int, gmin: int, gmax: int, haze: float, lit: float, seed: int) -> void:
	# place a non-repeating run of outpost structures along the whole width. Structure type is
	# chosen deterministically so the skyline varies; haze fades distant bands toward the void.
	var x := -60.0
	var i := 0
	while x < W + 60:
		var s := seed * 1000 + i
		var e := _envelope(x + float(seed) * 130.0)
		var sz := int(smin + (e * 0.6 + _h(s * 9 + 2) * 0.4) * (smax - smin))
		var kind := int(_h(s * 13 + 4) * 4.0)
		var cx := int(x) + sz
		match kind:
			0:
				_dome(Vector2(cx, base_y), float(sz), haze, false)
			1:
				_habitat_ring(int(x), base_y, sz, haze, lit, s)
			2:
				_dish(Vector2(cx, base_y - sz * 0.2), float(sz) * 0.7, haze)
			_:
				_solar_array(int(x), int(base_y - sz * 0.1), sz, haze)
		# occasional connecting corridor stub between structures (depth + connectivity)
		if _h(s * 29) < 0.5:
			_rect(int(x) + sz, int(base_y - 10.0), int(sz * 0.7), 9, _struct(STEEL_DK, haze))
		x += float(sz) + float(gmin) + _h(s * 3) * float(gmax - gmin)
		i += 1


func _struct(c: Color, haze: float) -> Color:
	var void_c := Color8(10, 11, 22)
	return c.lerp(void_c, haze)


# silver geodesic dome on columns; lush variant draws a green terraced interior through glass
func _dome(center: Vector2, r: float, haze: float, lush: bool) -> void:
	var skin := _struct(SILVER, haze)
	var skin_dk := _struct(STEEL, haze)
	# support columns/stilts under the dome rim
	var col_c := _struct(STEEL_DK, haze)
	var legn := 3
	for li in range(legn):
		var lx := center.x + lerpf(-r * 0.62, r * 0.62, float(li) / float(legn - 1))
		_rect(int(lx) - 2, int(center.y), 4, 18, col_c)
	# base platform / rim
	_rect(int(center.x - r * 0.92), int(center.y) - 4, int(r * 1.84), 8, skin_dk)
	# dome shell
	_dome_fill(center, r, skin)
	# subtle shaded right flank (flat, not a gradient)
	_dome_fill(center + Vector2(r * 0.30, 0), r * 0.82, Color(skin_dk.r, skin_dk.g, skin_dk.b, 0.30))

	if lush:
		_lush_interior(center, r, haze)

	# triangular lattice lines over the shell
	var lat := _struct(STEEL, haze)
	var lat_a := Color(lat.r, lat.g, lat.b, 0.55 * (1.0 - haze * 0.4))
	var rings := 4
	for ri in range(1, rings + 1):
		var rr := r * float(ri) / float(rings)
		# horizontal latitude arc (approximate with a clipped disc outline)
		for a in range(180, 361, 6):
			var rad := deg_to_rad(float(a))
			var p := center + Vector2(cos(rad), sin(rad)) * rr
			if p.y <= center.y:
				_px(int(p.x), int(p.y), lat_a)
	# longitude spokes
	for sp in range(-3, 4):
		var ang := deg_to_rad(90.0 + float(sp) * 24.0)
		_line(center, center + Vector2(cos(ang), -absf(sin(ang))) * r, lat_a, 1)
	# bright apex cap
	_disc(Vector2(center.x, center.y - r + 3.0), maxf(2.0, r * 0.06), _struct(TECH_EDGE, haze))


func _lush_interior(center: Vector2, r: float, haze: float) -> void:
	# a curved green terraced interior glowing through the dome glass: layered green hills,
	# a blue water strip, and tiny trees — all clipped to the dome's upper half.
	var soft := 1.0 - haze * 0.5
	# glass glow base
	_dome_fill(center, r * 0.95, Color(0.16, 0.42, 0.26, 0.55 * soft))
	# terraced green bands following the dome curve
	var greens := [Color8(46, 150, 90), Color8(70, 190, 110), Color8(96, 215, 130)]
	for ti in range(3):
		var ty := center.y - r * (0.10 + float(ti) * 0.16)
		var tw := sqrt(maxf(0.0, r * r - (center.y - ty) * (center.y - ty)))
		var g: Color = greens[ti]
		_rect(int(center.x - tw), int(ty), int(tw * 2.0), int(r * 0.12) + 1, Color(g.r, g.g, g.b, 0.80 * soft))
	# blue water strip across the middle
	var wy := center.y - r * 0.34
	var ww := sqrt(maxf(0.0, r * r - (center.y - wy) * (center.y - wy))) * 0.7
	_rect(int(center.x - ww), int(wy), int(ww * 2.0), maxf(3, int(r * 0.07)), Color(0.30, 0.70, 0.95, 0.8 * soft))
	# tiny trees as little dark-green discs on the terraces
	for k in range(7):
		var tx := center.x + (_h(int(center.x) * 5 + k * 11) - 0.5) * r * 1.3
		var tyt := center.y - r * (0.12 + _h(int(center.x) * 7 + k * 3) * 0.55)
		if Vector2(tx, tyt).distance_to(center) < r * 0.92 and tyt < center.y:
			_disc(Vector2(tx, tyt), maxf(1.5, r * 0.035), Color(0.12, 0.40, 0.20, 0.9 * soft))
	# soft overall glow halo above the dome
	for kk in range(5, 0, -1):
		_dome_fill(center, r * (0.7 + float(kk) * 0.06), Color(0.4, 1.0, 0.6, 0.02 * soft))


# circular habitat ring module with rows of green+amber lit windows, raised on a low base
func _habitat_ring(x: int, base_y: float, sz: int, haze: float, lit: float, seed: int) -> void:
	var body := _struct(SILVER, haze)
	var body_dk := _struct(STEEL, haze)
	var h := int(sz * 0.42)
	var w := int(sz * 1.7)
	var top := int(base_y) - h
	# low support base
	_rect(x + int(w * 0.18), int(base_y) - 6, int(w * 0.64), 10, _struct(STEEL_DK, haze))
	# ring body (rounded slab look: main band + lighter top cap + darker underside)
	_rect(x, top, w, h, body)
	_rect(x, top, w, 4, body.lightened(0.12))
	_rect(x, top + h - 4, w, 4, Color(body_dk.r, body_dk.g, body_dk.b, 0.6))
	# rounded end caps
	_disc(Vector2(x, top + h / 2.0), h / 2.0, body)
	_disc(Vector2(x + w, top + h / 2.0), h / 2.0, body)
	# window rows: green + amber
	var step := 13
	var cols := int((w - 10) / step)
	var rows := maxi(1, int((h - 10) / 11))
	for cyi in range(rows):
		for cxi in range(cols):
			var idx := seed * 131 + cyi * 17 + cxi * 3
			if _h(idx) > lit:
				continue
			var wcol := WIN_GREEN if _h(idx * 2) < 0.55 else WIN_AMBER
			var a := (0.55 + _h(idx * 3) * 0.4) * (1.0 - haze * 0.55)
			var wc := _struct(wcol, haze * 0.5)
			# glow + core
			_rect(x + 7 + cxi * step - 1, top + 6 + cyi * 11 - 1, 7, 7, Color(wc.r, wc.g, wc.b, a * 0.25))
			_rect(x + 7 + cxi * step, top + 6 + cyi * 11, 5, 5, Color(wc.r, wc.g, wc.b, a))
	# clean tech top edge
	_rect(x, top - 2, w, 2, _struct(TECH_EDGE, haze * 0.5))


# dish antenna on a mast
func _dish(center: Vector2, r: float, haze: float) -> void:
	var mast := _struct(STEEL_DK, haze)
	var dish := _struct(SILVER, haze)
	var dish_dk := _struct(STEEL, haze)
	_rect(int(center.x) - 2, int(center.y), 4, 40, mast)
	_rect(int(center.x) - int(r * 0.5), int(center.y) + 38, int(r) + 1, 5, mast)  # footing
	# dish bowl (disc) tilted: bright face + darker rim crescent
	_disc(center, r, dish_dk)
	_disc(center + Vector2(-r * 0.12, -r * 0.10), r * 0.86, dish)
	_disc(center, r * 0.18, dish_dk)  # feed hub shadow
	_rect(int(center.x) - 1, int(center.y), 2, int(r * 0.7), dish_dk)  # feed arm
	_disc(Vector2(center.x, center.y - r * 0.7), maxf(1.5, r * 0.10), _struct(WIN_AMBER, haze))  # feed tip light


# flat dark-blue solar panel array on a low frame
func _solar_array(x: int, top: int, sz: int, haze: float) -> void:
	var frame := _struct(STEEL_DK, haze)
	var panel := _struct(Color8(34, 52, 110), haze)
	var grid := _struct(Color8(60, 86, 150), haze)
	var w := int(sz * 1.5)
	var h := int(sz * 0.5)
	# tilt legs
	_rect(x + 4, top + h, 4, 16, frame)
	_rect(x + w - 8, top + h, 4, 16, frame)
	_rect(x, top, w, h, frame)
	_rect(x + 2, top + 2, w - 4, h - 4, panel)
	# grid lines
	var gc := 5
	for c in range(1, gc):
		_rect(x + 2 + int((w - 4) * float(c) / float(gc)), top + 2, 1, h - 4, grid)
	for rr in range(1, 3):
		_rect(x + 2, top + 2 + int((h - 4) * float(rr) / 3.0), w - 4, 1, grid)


# ---------------------------------------------------------------- signature landmarks
func _signature_dome(center: Vector2, r: float) -> void:
	# the hero fusion landmark: a large near dome revealing a lush curved green interior.
	_dome(center, r, 0.0, true)
	# a small flag planted beside it for scale/identity
	var fx := int(center.x + r * 0.96)
	_rect(fx, int(center.y) - 28, 2, 28, STEEL_DK)
	_rect(fx + 2, int(center.y) - 28, 14, 9, Color8(70, 200, 120))


func _big_dish(center: Vector2, scale: float) -> void:
	# an oversized signature dish-on-mast that stands out on the skyline
	var mast := STEEL_DK
	var r := 56.0 * scale
	_rect(int(center.x) - 4, int(center.y), 8, 96, mast)
	_rect(int(center.x) - 26, int(center.y) + 92, 52, 8, mast)
	_disc(center, r, STEEL)
	_disc(center + Vector2(-r * 0.12, -r * 0.10), r * 0.85, SILVER)
	# dish lattice rings
	for ri in range(1, 4):
		var rr := r * float(ri) / 4.0
		for a in range(0, 360, 7):
			var rad := deg_to_rad(float(a))
			var p := center + Vector2(cos(rad), sin(rad)) * rr
			_px(int(p.x), int(p.y), Color(STEEL_DK.r, STEEL_DK.g, STEEL_DK.b, 0.5))
	_disc(center, r * 0.16, STEEL_DK)
	_rect(int(center.x) - 1, int(center.y) - int(r * 0.9), 2, int(r * 0.9), STEEL_DK)  # feed arm
	_disc(Vector2(center.x, center.y - r * 0.9), 4.0, WIN_AMBER)


# ---------------------------------------------------------------- play-field hint
func _foreground() -> void:
	# nearest habitat rooftops / dome tops as solid platforms with a bright tech top edge,
	# varied heights and gaps along the length, dressed with small props. Gaps reveal the
	# layered colony behind (depth).
	var fill := Color8(40, 46, 58)
	var fill2 := Color8(28, 33, 44)
	var x := -40
	var i := 0
	while x < W + 40:
		var w := 210 + int(_h(i * 9 + 1) * 280)
		var top := 600 + int(_h(i * 5 + 2) * 70)
		_platform(x, top, w, fill, fill2)
		# rotate through a small prop set so no two platforms read identically
		var prop := i % 5
		var px := x + int(w * 0.5)
		match prop:
			0:  # small dish
				_dish(Vector2(px, top - 26), 14.0, 0.0)
			1:  # solar panel
				_solar_array(px - 22, top - 22, 30, 0.0)
			2:  # airlock hatch
				_rect(px - 14, top - 18, 28, 18, Color8(54, 60, 74))
				_rect(px - 14, top - 18, 28, 3, STEEL)
				_disc(Vector2(px, top - 9), 6.0, Color8(40, 46, 60))
				_disc(Vector2(px, top - 9), 3.0, WIN_AMBER)
			3:  # antenna with a tip light
				_rect(px, top - 34, 3, 34, Color8(110, 120, 140))
				_rect(px - 1, top - 38, 5, 5, Color8(255, 90, 90))
			_:  # planted flag
				_rect(px, top - 30, 2, 30, STEEL_DK)
				_rect(px + 2, top - 30, 16, 10, Color8(70, 200, 120))
		x += w + 60 + int(_h(i * 3) * 140)
		i += 1


func _platform(x: int, top: int, w: int, fill: Color, fill2: Color) -> void:
	_rect(x, top, w, H - top, fill)
	_rect(x, top + (H - top) / 2, w, (H - top) / 2, fill2)
	# panel seam lines for a techy paneled rooftop
	for r in range(1, 4):
		_rect(x, top + r * 12, w, 1, Color(0, 0, 0, 0.16))
	# bright clean tech top edge (the readable play surface)
	_rect(x, top - 6, w, 8, Color(TECH_EDGE.r, TECH_EDGE.g, TECH_EDGE.b, 0.22))
	_rect(x, top, w, 3, TECH_EDGE)
