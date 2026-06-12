extends SceneTree
## Offline backdrop preview for an interior hall stage: paints a stylized flat pixel-vector
## composition into a single PNG so the art direction can be inspected pixel-by-pixel without
## running the game (headless Godot cannot capture live nodes). The hall recedes horizontally in
## overlapping depth bands (far bays small/high and washed with warm haze; near bays large/low and
## sharp), with deterministic detail grids for the packed shelves and curated non-repeating
## landmarks so a long stage never looks tiled. These numbers port into the live backdrop builder.
##   godot --headless --path project --script res://tools/backdrop_stage10_library.gd -- --width=4800 --out=/abs/path.png

var W := 1280
var H := 720
var img: Image

# ---- warm opulent palette ----------------------------------------------------
const WOOD_DARK := Color8(58, 36, 22)
const WOOD := Color8(96, 60, 34)
const WOOD_LIT := Color8(140, 92, 52)
const GOLD := Color8(232, 186, 96)
const GOLD_BRIGHT := Color8(255, 222, 140)
const CREAM := Color8(244, 228, 196)
const MARBLE := Color8(238, 230, 214)
const MARBLE_SH := Color8(196, 184, 162)
const AMBER := Color8(255, 200, 110)
const HAZE := Color8(214, 176, 120)  # warm golden atmosphere far bays lerp toward

# book-spine colors (deep, readable, varied)
const SPINES := [
	Color8(150, 44, 38), Color8(120, 30, 28), Color8(64, 46, 30),
	Color8(40, 78, 56), Color8(30, 60, 80), Color8(176, 132, 60),
	Color8(206, 188, 150), Color8(96, 40, 60), Color8(58, 50, 44),
	Color8(180, 96, 44), Color8(40, 64, 60), Color8(132, 116, 88),
]


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
	_ambient()                 # warm interior wash + ceiling/floor zones
	_ceiling_fresco()          # painted fresco band + gold ribs along the top
	# Far depth band: small, high bays washed in warm haze.
	_bay_band(286.0, 150, 0.72, 41, 150, 210)
	# Mid depth band: taller bays, gallery balcony, arched windows.
	_bay_band(366.0, 230, 0.40, 67, 210, 300)
	_cupola(int(W * 0.46), 150)   # signature domed cupola centerpiece
	_second_dome(int(W * 0.80), 168)
	# Near depth band: the largest, sharpest, warmest bays.
	_bay_band(470.0, 330, 0.12, 91, 300, 410)
	_dado(470, 560)            # marble wainscot/baseboard tying shelves down to the floor
	_floor()                   # checkered marble floor + soft reflections
	_hero_statue(int(W * 0.30), 566)   # landmark marble figure standing on the floor
	_great_window(int(W * 0.62), 470)  # landmark towering arched window set into the wall
	_statue_collection()       # a few more tasteful sculptures spread along the hall
	_foreground()              # nearest gallery-ledge platforms + props


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


# fills the wedge between top and bottom widths (a trapezoid centered on cx)
func _trap(cx: int, top_y: int, top_w: int, bot_w: int, h: int, color: Color) -> void:
	for r in range(h + 1):
		var w := int(lerpf(float(top_w), float(bot_w), float(r) / float(h)))
		_rect(cx - w / 2, top_y + r, w, 1, color)


# small deterministic hash -> 0..1
func _h(n: int) -> float:
	var x := (n * 1103515245 + 12345) & 0x7fffffff
	x = (x ^ (x >> 13)) * 1274126177 & 0x7fffffff
	return float(x % 10000) / 10000.0


# low-frequency, non-repeating envelope used to vary bay/window placement
func _envelope(x: float) -> float:
	var a := 0.5 + 0.5 * sin(x * 0.0013)
	var b := 0.5 + 0.5 * sin(x * 0.0041 + 2.1)
	return clampf(0.30 + 0.5 * a + 0.28 * b - 0.08, 0.0, 1.0)


# ---------------------------------------------------------------- ambient wash
func _ambient() -> void:
	# soft vertical warm wash: deeper amber up top (ceiling glow) easing to a lit mid-hall,
	# then warm floor. The only gradient in the piece (a gentle ambient light).
	var top := Color8(120, 78, 40)
	var mid := Color8(168, 124, 74)
	var low := Color8(150, 110, 70)
	for y in range(H):
		var t := float(y) / float(H)
		var row: Color
		if t < 0.5:
			row = top.lerp(mid, pow(t / 0.5, 0.85))
		else:
			row = mid.lerp(low, (t - 0.5) / 0.5)
		for x in range(W):
			img.set_pixel(x, y, row)
	# warm horizontal light glow across the mid-hall (windows pouring in)
	for y in range(150, 520):
		var a := (1.0 - absf(float(y) - 320.0) / 200.0) * 0.10
		if a > 0.0:
			_rect(0, y, W, 1, Color(1.0, 0.82, 0.5, a))


# ---------------------------------------------------------------- ceiling fresco
func _ceiling_fresco() -> void:
	# painted fresco band along the very top: soft cream/peach/blue panels framed by gold ribs.
	var band_h := 150
	# base painted plaster
	_rect(0, 0, W, band_h, Color8(232, 206, 168))
	# soft pastel cloud/figure suggestions (flat blobs, no gradients)
	var i := 0
	var x := -40
	while x < W + 40:
		var s := 5100 + i
		var bw := 120 + int(_h(s * 7) * 160)
		var cy := 30 + int(_h(s * 3) * 80)
		var hue := _h(s * 5)
		var col: Color
		if hue < 0.4:
			col = Color8(248, 222, 196)     # peach/cream
		elif hue < 0.72:
			col = Color8(206, 220, 236)     # soft sky blue
		else:
			col = Color8(236, 200, 176)     # warm rose
		_disc(Vector2(x + bw / 2, cy), float(bw) * 0.28, Color(col.r, col.g, col.b, 0.6))
		_disc(Vector2(x + bw / 2 + 18, cy + 14), float(bw) * 0.2, Color(col.r, col.g, col.b, 0.45))
		# a suggested robed figure: soft warm mass blended into the cloud, not a hard lollipop
		if _h(s * 11) < 0.5:
			var fx := x + int(bw * 0.34)
			var fy := cy + 18
			_disc(Vector2(fx, fy + 14), 9.0, Color(0.78, 0.6, 0.48, 0.4))     # robe
			_disc(Vector2(fx, fy + 4), 5.0, Color(0.85, 0.68, 0.55, 0.45))    # head/shoulder
			_disc(Vector2(fx, fy + 18), 13.0, Color(col.r, col.g, col.b, 0.3))  # blend back in
		x += bw
		i += 1
	# coffered panel frame: gold rib grid across the band
	var panel := 150
	x = 0
	while x < W:
		_line(Vector2(x, 0), Vector2(x + 30, band_h), GOLD, 2)  # diagonal rib catches the eye
		_rect(x, 0, panel - 4, 3, Color(GOLD.r, GOLD.g, GOLD.b, 0.5))
		x += panel
	# horizontal gold cornice closing the band off from the wall below
	_rect(0, band_h - 8, W, 8, GOLD_DARK())
	_rect(0, band_h - 8, W, 3, GOLD_BRIGHT)
	_rect(0, band_h, W, 4, Color8(70, 44, 26))   # shadow line under cornice


func GOLD_DARK() -> Color:
	return Color8(178, 138, 64)


# ---------------------------------------------------------------- bays band
# Renders a horizontal run of wall bays at one depth: each bay = bookshelf tiers + a gallery
# balcony rail, separated by carved columns with gilded capitals/bases. Haze lerps the whole bay
# toward the warm atmosphere so far bands recede. Some bays carry a glowing arched window.
func _bay_band(base_y: float, top_y: int, haze: float, seed: int, wmin: int, wmax: int) -> void:
	var x := -60.0
	var i := 0
	var sharp := 1.0 - haze
	while x < W + 60:
		var s := seed * 1000 + i
		var e := _envelope(x + float(seed) * 130.0)
		var bw := int(wmin + _h(s * 9 + 2) * (wmax - wmin))
		var col_w := maxi(14, int(bw * 0.12))         # column between bays
		var inner_x := int(x) + col_w
		var inner_w := bw - col_w
		var wall_top := top_y
		var wall_h := int(base_y) - wall_top
		# back wall plaster behind shelves (warm, hazed)
		var plaster := Color8(120, 84, 52).lerp(HAZE, haze)
		_rect(int(x), wall_top, bw, int(base_y) - wall_top, plaster)
		# two tiers of bookshelves split by a gallery balcony
		var gallery_y := wall_top + int(wall_h * 0.46)
		_bookshelf(inner_x, wall_top + 6, inner_w, gallery_y - wall_top - 10, s * 3 + 1, haze)
		_bookshelf(inner_x, gallery_y + 14, inner_w, int(base_y) - gallery_y - 16, s * 3 + 2, haze)
		# gallery balcony rail crossing the bay
		_balcony(inner_x, gallery_y, inner_w, haze)
		# some bays get a glowing arched window instead of full lower shelving variety
		if _h(s * 17) < 0.34:
			_arched_window(inner_x + inner_w / 2, gallery_y + 18, int(inner_w * 0.5),
				int(base_y) - gallery_y - 28, haze)
		# carved column between bays with gilded capital + base
		_column(int(x), wall_top, col_w, int(base_y) - wall_top, haze)
		x += float(bw)
		i += 1


func _bookshelf(x: int, y: int, w: int, h: int, seed: int, haze: float) -> void:
	if w <= 6 or h <= 8:
		return
	# dark wood case
	var case := WOOD_DARK.lerp(HAZE, haze)
	_rect(x, y, w, h, case)
	# horizontal shelf boards: rows of books between them
	var shelf_h := 16
	var rows := maxi(1, h / shelf_h)
	var sharp := 1.0 - haze
	for r in range(rows):
		var ry := y + r * shelf_h
		var rh := mini(shelf_h, y + h - ry)
		if rh < 6:
			continue
		# the book strip (leave a couple px for the shelf board below)
		var book_top := ry + 1
		var book_h := rh - 3
		var bx := x + 2
		var end := x + w - 2
		while bx < end:
			var idx := seed * 131 + r * 29 + bx
			var bwid := 2 + int(_h(idx) * 4)
			if bx + bwid > end:
				bwid = end - bx
			var base: Color = SPINES[int(_h(idx * 2) * SPINES.size()) % SPINES.size()]
			var lit := lerpf(0.0, 0.18, _h(idx * 5))
			var col := base.lightened(lit).lerp(HAZE, haze * 0.7)
			var bh := book_h - int(_h(idx * 7) * 3)   # slightly uneven tops
			_rect(bx, book_top + (book_h - bh), bwid, bh, col)
			# tiny gold title fleck on some spines (only when sharp enough to read)
			if sharp > 0.55 and bwid >= 4 and _h(idx * 11) < 0.3:
				_rect(bx + 1, book_top + (book_h - bh) + bh / 2, bwid - 2, 1,
					Color(GOLD_BRIGHT.r, GOLD_BRIGHT.g, GOLD_BRIGHT.b, 0.8))
			bx += bwid
		# shelf board (lit top edge of wood)
		_rect(x, ry + rh - 2, w, 2, WOOD_LIT.lerp(HAZE, haze))
		_rect(x, ry + rh - 1, w, 1, Color(0, 0, 0, 0.25 * (1.0 - haze)))


func _balcony(x: int, y: int, w: int, haze: float) -> void:
	# the gallery walkway band + a gilded railing of small balusters
	var board := WOOD.lerp(HAZE, haze)
	_rect(x - 2, y, w + 4, 12, board)
	_rect(x - 2, y, w + 4, 2, WOOD_LIT.lerp(HAZE, haze))
	# gilded top rail
	_rect(x - 2, y - 4, w + 4, 3, GOLD.lerp(HAZE, haze * 0.6))
	# balusters
	var step := 9
	var bx := x + 2
	while bx < x + w - 2:
		_rect(bx, y - 4, 2, 5, Color(WOOD_LIT.r, WOOD_LIT.g, WOOD_LIT.b, 0.9).lerp(HAZE, haze))
		bx += step


func _column(x: int, top: int, w: int, h: int, haze: float) -> void:
	# carved wood column/pilaster: shaft with flutes, gilded capital and base
	var shaft := WOOD.lerp(HAZE, haze)
	var shaft_lit := WOOD_LIT.lerp(HAZE, haze)
	var cap_h := maxi(8, int(w * 0.8))
	var base_h := maxi(7, int(w * 0.7))
	var shaft_top := top + cap_h
	var shaft_h := h - cap_h - base_h
	_rect(x, shaft_top, w, shaft_h, shaft)
	# vertical flute highlights
	var fl := 4
	var fx := x + 2
	while fx < x + w - 1:
		_rect(fx, shaft_top, 1, shaft_h, Color(shaft_lit.r, shaft_lit.g, shaft_lit.b, 0.5))
		fx += fl
	# gilded capital (flares slightly)
	_rect(x - 2, top, w + 4, cap_h, GOLD.lerp(HAZE, haze * 0.55))
	_rect(x - 2, top, w + 4, 2, GOLD_BRIGHT.lerp(HAZE, haze * 0.4))
	_rect(x - 3, top + cap_h - 3, w + 6, 3, GOLD_DARK().lerp(HAZE, haze * 0.5))
	# gilded base
	_rect(x - 2, top + h - base_h, w + 4, base_h, GOLD.lerp(HAZE, haze * 0.6))
	_rect(x - 2, top + h - base_h, w + 4, 2, GOLD_BRIGHT.lerp(HAZE, haze * 0.4))


func _arched_window(cx: int, top: int, w: int, h: int, haze: float) -> void:
	if w < 10 or h < 16:
		return
	var glow := AMBER.lerp(HAZE, haze * 0.5)
	var frame := WOOD_DARK.lerp(HAZE, haze)
	var arch_h := int(w * 0.5)
	# outer frame
	_rect(cx - w / 2 - 2, top - 1, w + 4, h + 2, frame)
	# rectangular glass body
	_rect(cx - w / 2, top + arch_h, w, h - arch_h, glow)
	# arched top (stacked rows approximating a semicircle)
	for r in range(arch_h):
		var hw := int(sqrt(maxf(0.0, float(arch_h * arch_h - (arch_h - r) * (arch_h - r)))))
		_rect(cx - hw, top + r, hw * 2, 1, glow)
	# bright inner pour of light
	_rect(cx - w / 2 + 2, top + arch_h + 2, w - 4, h - arch_h - 4,
		Color(GOLD_BRIGHT.r, GOLD_BRIGHT.g, GOLD_BRIGHT.b, 0.5 * (1.0 - haze * 0.5)))
	# muntins (panes)
	var sharp := 1.0 - haze
	_rect(cx - 1, top + 2, 2, h - 4, Color(frame.r, frame.g, frame.b, 0.8))
	var py := top + arch_h
	while py < top + h - 4:
		_rect(cx - w / 2 + 1, py, w - 2, 1, Color(frame.r, frame.g, frame.b, 0.7))
		py += 12
	# soft halo of light spilling out
	if sharp > 0.4:
		_rect(cx - w / 2 - 6, top - 4, w + 12, h + 8, Color(1.0, 0.84, 0.5, 0.06))


# ---------------------------------------------------------------- landmark: cupola
func _cupola(cx: int, frame_top: int) -> void:
	# signature domed cupola: a great arched fresco rising into the ceiling, ringed with small
	# clerestory windows that drop golden light. Sits above the back wall, into the fresco band.
	var dome_r := 150.0
	var base_y := frame_top + 40
	# soft golden glow halo behind it
	for k in range(10, 0, -1):
		_disc(Vector2(cx, base_y), dome_r * (1.0 + float(k) * 0.05), Color(1.0, 0.82, 0.46, 0.02))
	# the dome body (painted fresco interior) — flat warm shell
	for r in range(int(dome_r)):
		var hw := int(sqrt(maxf(0.0, dome_r * dome_r - float(r * r))))
		var t := float(r) / dome_r
		var shell := Color8(236, 214, 180).lerp(Color8(208, 176, 150), t)
		_rect(cx - hw, base_y - r, hw * 2, 1, shell)
	# gold rib lines radiating down the dome
	for k in range(9):
		var ang := lerpf(-1.35, 1.35, float(k) / 8.0)
		var ex := cx + int(sin(ang) * dome_r * 0.96)
		var ey := base_y - int(cos(ang) * dome_r * 0.96)
		_line(Vector2(cx, base_y - int(dome_r * 0.04)), Vector2(ex, ey), GOLD, 2)
	# central painted medallion
	_disc(Vector2(cx, base_y - int(dome_r * 0.5)), 26.0, Color8(206, 220, 236))
	_disc(Vector2(cx, base_y - int(dome_r * 0.5)), 26.0, Color(0.86, 0.7, 0.5, 0.3))
	_disc(Vector2(cx, base_y - int(dome_r * 0.5)), 14.0, Color8(248, 220, 150))
	# ring of clerestory windows around the drum
	var ring_n := 11
	for k in range(ring_n):
		var a := lerpf(-1.2, 1.2, float(k) / float(ring_n - 1))
		var wx := cx + int(sin(a) * dome_r * 0.82)
		var wy := base_y - int(cos(a) * dome_r * 0.82) + 6
		_rect(wx - 4, wy - 8, 8, 14, GOLD_DARK())
		_rect(wx - 3, wy - 7, 6, 12, GOLD_BRIGHT)
		# shaft of light dropping from each
		_rect(wx - 2, wy + 6, 4, 40, Color(1.0, 0.86, 0.5, 0.10))
	# gilded base cornice ring
	_rect(cx - int(dome_r), base_y - 2, int(dome_r * 2), 6, GOLD)
	_rect(cx - int(dome_r), base_y - 2, int(dome_r * 2), 2, GOLD_BRIGHT)
	# lantern finial at the crown
	_disc(Vector2(cx, base_y - int(dome_r) - 6), 9.0, GOLD)
	_disc(Vector2(cx, base_y - int(dome_r) - 6), 5.0, GOLD_BRIGHT)


func _second_dome(cx: int, frame_top: int) -> void:
	# a smaller echo of the cupola further down the hall (depth + variety)
	var dome_r := 78.0
	var base_y := frame_top + 24
	for k in range(8, 0, -1):
		_disc(Vector2(cx, base_y), dome_r * (1.0 + float(k) * 0.05), Color(1.0, 0.82, 0.46, 0.02))
	for r in range(int(dome_r)):
		var hw := int(sqrt(maxf(0.0, dome_r * dome_r - float(r * r))))
		var t := float(r) / dome_r
		var shell := Color8(230, 208, 176).lerp(HAZE, 0.25).lerp(Color8(204, 176, 150), t)
		_rect(cx - hw, base_y - r, hw * 2, 1, shell)
	for k in range(7):
		var ang := lerpf(-1.3, 1.3, float(k) / 6.0)
		var ex := cx + int(sin(ang) * dome_r * 0.95)
		var ey := base_y - int(cos(ang) * dome_r * 0.95)
		_line(Vector2(cx, base_y - 4), Vector2(ex, ey), Color(GOLD.r, GOLD.g, GOLD.b, 0.8), 1)
	_disc(Vector2(cx, base_y - int(dome_r * 0.5)), 11.0, Color8(244, 220, 160))
	_rect(cx - int(dome_r), base_y - 2, int(dome_r * 2), 4, Color(GOLD.r, GOLD.g, GOLD.b, 0.9))
	_disc(Vector2(cx, base_y - int(dome_r) - 4), 5.0, GOLD)


# ---------------------------------------------------------------- landmark: hero statue
func _hero_statue(cx: int, ground_y: int) -> void:
	# a marble figure on a tall ornate pedestal — the hall's centerpiece sculpture
	var ped_w := 64
	var ped_h := 120
	var ped_top := ground_y - ped_h
	# pedestal
	_rect(cx - ped_w / 2, ped_top, ped_w, ped_h, MARBLE)
	_rect(cx - ped_w / 2, ped_top, 3, ped_h, MARBLE_SH)          # shaded side
	_rect(cx + ped_w / 2 - 3, ped_top, 3, ped_h, MARBLE.lightened(0.1))
	# cap + base moldings (gilded accents)
	_rect(cx - ped_w / 2 - 6, ped_top, ped_w + 12, 8, MARBLE_SH)
	_rect(cx - ped_w / 2 - 6, ped_top + 6, ped_w + 12, 2, GOLD)
	_rect(cx - ped_w / 2 - 8, ground_y - 12, ped_w + 16, 12, MARBLE_SH)
	_rect(cx - ped_w / 2 - 8, ground_y - 12, ped_w + 16, 2, GOLD)
	# inscription plaque
	_rect(cx - 18, ped_top + 40, 36, 22, MARBLE_SH)
	_rect(cx - 16, ped_top + 46, 32, 2, Color(GOLD.r, GOLD.g, GOLD.b, 0.6))
	_rect(cx - 16, ped_top + 52, 26, 2, Color(GOLD.r, GOLD.g, GOLD.b, 0.5))
	# the figure (flat chunky marble silhouette, seated/robed)
	var fy := ped_top
	# robed lower body (a trapezoid)
	_trap(cx, fy - 70, 22, 46, 70, MARBLE)
	_rect(cx - 23, fy - 18, 46, 18, MARBLE)
	_trap(cx, fy - 70, 8, 18, 70, MARBLE_SH)   # central drape fold (shadow)
	# torso
	_rect(cx - 16, fy - 110, 32, 44, MARBLE)
	_rect(cx - 16, fy - 110, 5, 44, MARBLE_SH)
	# raised arm holding a torch-like gold accent
	_line(Vector2(cx + 14, fy - 104), Vector2(cx + 34, fy - 138), MARBLE, 6)
	_disc(Vector2(cx + 36, fy - 142), 6.0, GOLD)
	_disc(Vector2(cx + 36, fy - 146), 4.0, GOLD_BRIGHT)
	for k in range(6, 0, -1):
		_disc(Vector2(cx + 36, fy - 144), 6.0 + k * 2.0, Color(1.0, 0.84, 0.5, 0.05))
	# other arm
	_line(Vector2(cx - 14, fy - 104), Vector2(cx - 22, fy - 78), MARBLE, 6)
	# head
	_disc(Vector2(cx, fy - 122), 11.0, MARBLE)
	_disc(Vector2(cx - 3, fy - 123), 9.0, MARBLE_SH)
	# soft uplight from below
	for k in range(5, 0, -1):
		_disc(Vector2(cx, fy - 30), 30.0 + k * 8.0, Color(1.0, 0.86, 0.52, 0.03))


# ---------------------------------------------------------------- sculpture collection
func _statue_collection() -> void:
	# A small, distinguished set of marble figures on pedestals, spread at non-repeating spots
	# along the full length (positions scale with width so they stay evenly distributed and never
	# crowd the hero statue or each other). Varied poses keep it a curated collection, not a mob.
	# Each entry: fractional x, pose id, slight scale variation.
	var picks := [
		[0.085, 1, 0.92],   # robed figure (calm, hands lowered)
		[0.485, 2, 0.98],   # scholar holding a book
		[0.90, 3, 0.9],     # a bust
	]
	for p in picks:
		var fx: float = p[0]
		var pose: int = int(p[1])
		var sc: float = p[2]
		_statue(int(W * fx), 566, pose, sc)


func _statue(cx: int, ground_y: int, pose: int, sc: float) -> void:
	# one marble figure on a pedestal; `pose` selects silhouette/prop, `sc` scales it.
	var ped_w := int(48 * sc)
	var ped_h := int(96 * sc)
	var ped_top := ground_y - ped_h
	# pedestal
	_rect(cx - ped_w / 2, ped_top, ped_w, ped_h, MARBLE)
	_rect(cx - ped_w / 2, ped_top, 3, ped_h, MARBLE_SH)
	_rect(cx + ped_w / 2 - 3, ped_top, 3, ped_h, MARBLE.lightened(0.1))
	# cap + base moldings with gilded accents
	_rect(cx - ped_w / 2 - 5, ped_top, ped_w + 10, 7, MARBLE_SH)
	_rect(cx - ped_w / 2 - 5, ped_top + 5, ped_w + 10, 2, GOLD)
	_rect(cx - ped_w / 2 - 6, ground_y - 10, ped_w + 12, 10, MARBLE_SH)
	_rect(cx - ped_w / 2 - 6, ground_y - 10, ped_w + 12, 2, GOLD)
	# small inscription plaque
	_rect(cx - int(13 * sc), ped_top + int(34 * sc), int(26 * sc), int(16 * sc), MARBLE_SH)
	_rect(cx - int(11 * sc), ped_top + int(39 * sc), int(22 * sc), 2, Color(GOLD.r, GOLD.g, GOLD.b, 0.55))
	var fy := ped_top
	if pose == 3:
		# a bust on top (chest + head only) — a more compact sculpture
		_trap(cx, fy - int(26 * sc), int(12 * sc), int(34 * sc), int(26 * sc), MARBLE)
		_rect(cx - int(17 * sc), fy - int(8 * sc), int(34 * sc), int(8 * sc), MARBLE)
		_disc(Vector2(cx, fy - int(36 * sc)), 10.0 * sc, MARBLE)
		_disc(Vector2(cx - 3, fy - int(37 * sc)), 8.0 * sc, MARBLE_SH)
	else:
		# full robed figure
		_trap(cx, fy - int(58 * sc), int(18 * sc), int(38 * sc), int(58 * sc), MARBLE)
		_rect(cx - int(19 * sc), fy - int(14 * sc), int(38 * sc), int(14 * sc), MARBLE)
		_trap(cx, fy - int(58 * sc), int(6 * sc), int(14 * sc), int(58 * sc), MARBLE_SH)  # drape fold
		# torso
		_rect(cx - int(13 * sc), fy - int(92 * sc), int(26 * sc), int(36 * sc), MARBLE)
		_rect(cx - int(13 * sc), fy - int(92 * sc), int(4 * sc), int(36 * sc), MARBLE_SH)
		# head
		_disc(Vector2(cx, fy - int(102 * sc)), 9.0 * sc, MARBLE)
		_disc(Vector2(cx - 2, fy - int(103 * sc)), 7.0 * sc, MARBLE_SH)
		match pose:
			0:
				# torch-bearer, raised arm (mirrored to the left for variety)
				_line(Vector2(cx - int(11 * sc), fy - int(86 * sc)), Vector2(cx - int(28 * sc), fy - int(116 * sc)), MARBLE, int(5 * sc))
				_disc(Vector2(cx - int(30 * sc), fy - int(120 * sc)), 5.0 * sc, GOLD)
				_disc(Vector2(cx - int(30 * sc), fy - int(124 * sc)), 3.0 * sc, GOLD_BRIGHT)
				for k in range(5, 0, -1):
					_disc(Vector2(cx - int(30 * sc), fy - int(122 * sc)), 5.0 * sc + k * 2.0, Color(1.0, 0.84, 0.5, 0.05))
				_line(Vector2(cx + int(11 * sc), fy - int(86 * sc)), Vector2(cx + int(17 * sc), fy - int(64 * sc)), MARBLE, int(5 * sc))
			2:
				# scholar holding a book against the chest
				_line(Vector2(cx - int(11 * sc), fy - int(84 * sc)), Vector2(cx - int(4 * sc), fy - int(66 * sc)), MARBLE, int(5 * sc))
				_line(Vector2(cx + int(11 * sc), fy - int(84 * sc)), Vector2(cx + int(4 * sc), fy - int(66 * sc)), MARBLE, int(5 * sc))
				_rect(cx - int(9 * sc), fy - int(70 * sc), int(18 * sc), int(13 * sc), CREAM)
				_rect(cx - 1, fy - int(70 * sc), 2, int(13 * sc), MARBLE_SH)  # spine
				_rect(cx - int(7 * sc), fy - int(66 * sc), int(14 * sc), 1, Color(GOLD.r, GOLD.g, GOLD.b, 0.6))
			_:
				# calm robed figure, hands lowered
				_line(Vector2(cx - int(11 * sc), fy - int(86 * sc)), Vector2(cx - int(16 * sc), fy - int(58 * sc)), MARBLE, int(5 * sc))
				_line(Vector2(cx + int(11 * sc), fy - int(86 * sc)), Vector2(cx + int(16 * sc), fy - int(58 * sc)), MARBLE, int(5 * sc))
	# soft warm uplight from below
	for k in range(5, 0, -1):
		_disc(Vector2(cx, fy - int(24 * sc)), 24.0 * sc + k * 6.0, Color(1.0, 0.86, 0.52, 0.025))


# ---------------------------------------------------------------- landmark: great window
func _great_window(cx: int, ground_y: int) -> void:
	# a towering arched window flooding the hall with gold — set forward of the shelves
	var w := 150
	var h := 300
	var top := ground_y - h
	var arch_h := int(w * 0.55)
	var frame := WOOD_DARK
	# heavy outer frame
	_rect(cx - w / 2 - 8, top - 6, w + 16, h + 6, frame)
	_rect(cx - w / 2 - 8, top - 6, w + 16, 3, WOOD_LIT)
	# glowing glass
	var glow := AMBER
	_rect(cx - w / 2, top + arch_h, w, h - arch_h, glow)
	for r in range(arch_h):
		var hw := int(sqrt(maxf(0.0, float(arch_h * arch_h - (arch_h - r) * (arch_h - r)))))
		_rect(cx - hw, top + r, hw * 2, 1, glow)
	# bright core
	_rect(cx - w / 2 + 8, top + arch_h + 8, w - 16, h - arch_h - 30,
		Color(GOLD_BRIGHT.r, GOLD_BRIGHT.g, GOLD_BRIGHT.b, 0.55))
	# gridded muntins
	var mx := cx - w / 2 + 4
	while mx < cx + w / 2:
		_rect(mx, top + arch_h, 2, h - arch_h, Color(frame.r, frame.g, frame.b, 0.85))
		mx += 30
	var my := top + arch_h
	while my < top + h:
		_rect(cx - w / 2, my, w, 2, Color(frame.r, frame.g, frame.b, 0.8))
		my += 34
	# arch muntins (radial-ish)
	_line(Vector2(cx, top + arch_h), Vector2(cx, top), Color(frame.r, frame.g, frame.b, 0.8), 2)
	_line(Vector2(cx, top + arch_h), Vector2(cx - int(w * 0.34), top + int(arch_h * 0.3)), Color(frame.r, frame.g, frame.b, 0.7), 2)
	_line(Vector2(cx, top + arch_h), Vector2(cx + int(w * 0.34), top + int(arch_h * 0.3)), Color(frame.r, frame.g, frame.b, 0.7), 2)
	# gilded keystone + sill
	_disc(Vector2(cx, top + 2), 9.0, GOLD)
	_disc(Vector2(cx, top + 2), 5.0, GOLD_BRIGHT)
	_rect(cx - w / 2 - 12, ground_y - 4, w + 24, 8, GOLD)
	_rect(cx - w / 2 - 12, ground_y - 4, w + 24, 2, GOLD_BRIGHT)
	# big soft halo of light into the room
	for k in range(8, 0, -1):
		_rect(cx - w / 2 - k * 6, top - k * 4, w + k * 12, h + k * 8, Color(1.0, 0.84, 0.5, 0.015))


# ---------------------------------------------------------------- dado / wainscot
func _dado(y_top: int, y_bot: int) -> void:
	# a paneled marble + wood wainscot running the full length, closing the gap between the
	# bookshelf bases and the marble floor with carved panels and a gilded chair rail.
	var h := y_bot - y_top
	var wood := Color8(78, 48, 28)
	var wood_d := Color8(54, 32, 18)
	_rect(0, y_top, W, h, wood)
	# gilded chair rail along the top
	_rect(0, y_top, W, 4, GOLD)
	_rect(0, y_top + 4, W, 2, GOLD_BRIGHT)
	_rect(0, y_top + 6, W, 2, Color(0, 0, 0, 0.2))
	# recessed marble panels, varied widths so nothing tiles
	var x := 8
	var i := 0
	while x < W - 8:
		var pw := 70 + int(_h(i * 9 + 3) * 70)
		if x + pw > W - 8:
			pw = W - 8 - x
		var inlay := Color8(214, 192, 158)                  # warm cream marble inlay
		_rect(x, y_top + 14, pw, h - 24, wood_d)            # panel recess shadow
		_rect(x + 4, y_top + 18, pw - 8, h - 32, inlay)     # marble inlay
		_rect(x + 4, y_top + 18, pw - 8, 2, Color8(236, 218, 184))  # lit top of inlay
		# a small gilded rosette centered on some panels
		if _h(i * 7) < 0.5:
			_disc(Vector2(x + pw / 2, y_top + h / 2), 4.0, GOLD)
			_disc(Vector2(x + pw / 2, y_top + h / 2), 2.0, GOLD_BRIGHT)
		x += pw + 6
		i += 1
	# base molding meeting the floor
	_rect(0, y_bot - 6, W, 6, wood_d)
	_rect(0, y_bot - 6, W, 2, Color(GOLD.r, GOLD.g, GOLD.b, 0.5))


# ---------------------------------------------------------------- floor
func _floor() -> void:
	# checkered marble floor receding at the very bottom, with soft reflections.
	var floor_top := 560
	var light := Color8(214, 198, 168)
	var dark := Color8(150, 122, 92)
	for y in range(floor_top, H):
		var depth := float(y - floor_top) / float(H - floor_top)
		# tiles grow toward the viewer (perspective): bigger near the bottom
		var tile := int(lerpf(10.0, 40.0, depth))
		var rowi := int((y - floor_top) / maxf(6.0, lerpf(6.0, 22.0, depth)))
		for x in range(W):
			var coli := int(x / float(maxi(6, tile)))
			var c: Color = light if (coli + rowi) % 2 == 0 else dark
			# warm haze toward the back of the floor
			c = c.lerp(HAZE, (1.0 - depth) * 0.4)
			img.set_pixel(x, y, c)
	# soft warm reflections smeared down from the bright zones
	for x in range(0, W, 1):
		if _h(x * 3) < 0.5:
			var a := 0.05 + _h(x * 7) * 0.05
			_rect(x, floor_top, 1, 40, Color(1.0, 0.86, 0.5, a))


# ---------------------------------------------------------------- play surface
func _foreground() -> void:
	# nearest gallery-balcony / bookshelf-top ledges as solid platforms with a bright gilded top
	# edge, varied heights and gaps, dressed with opulent props. Gaps reveal the hall behind.
	var wood := Color8(46, 28, 18)
	var wood2 := Color8(70, 44, 26)
	var x := -40
	var i := 0
	while x < W + 40:
		var w := 210 + int(_h(i * 9 + 1) * 280)
		var top := 600 + int(_h(i * 5 + 2) * 70)
		_ledge(x, top, w, wood, wood2)
		_prop(x, top, w, i)
		x += w + 70 + int(_h(i * 3) * 130)
		i += 1


func _ledge(x: int, top: int, w: int, fill: Color, fill2: Color) -> void:
	_rect(x, top, w, H - top, fill)
	_rect(x, top + (H - top) / 2, w, (H - top) / 2, fill2)
	# carved paneling lines
	var px := x + 10
	while px < x + w - 10:
		_rect(px, top + 6, 1, H - top - 10, Color(0, 0, 0, 0.18))
		px += 46
	# bright gilded top edge (gameplay readability)
	_rect(x, top - 6, w, 8, Color(GOLD.r, GOLD.g, GOLD.b, 0.28))
	_rect(x, top, w, 3, GOLD_BRIGHT)
	# small balustrade along the front lip
	var bx := x + 6
	while bx < x + w - 6:
		_rect(bx, top + 4, 2, 6, Color(GOLD.r, GOLD.g, GOLD.b, 0.7))
		bx += 12


func _prop(x: int, top: int, w: int, i: int) -> void:
	# a rotating cast of opulent props on the near ledges
	var k := i % 5
	var cx := x + int(w * (0.3 + _h(i * 13) * 0.4))
	match k:
		0:  # globe on a stand
			_rect(cx - 2, top - 24, 4, 24, Color8(90, 58, 34))      # stand
			_rect(cx - 14, top - 28, 28, 4, Color8(120, 80, 46))    # cradle
			_disc(Vector2(cx, top - 44), 16.0, Color8(70, 120, 140))  # ocean
			_disc(Vector2(cx + 5, top - 48), 7.0, Color8(120, 150, 90))  # land
			_disc(Vector2(cx - 7, top - 40), 5.0, Color8(120, 150, 90))
			_rect(cx - 16, top - 44, 32, 1, GOLD)                    # meridian ring
			_disc(Vector2(cx, top - 44), 16.0, Color(1.0, 0.9, 0.6, 0.12))
		1:  # candelabra
			_rect(cx - 2, top - 40, 4, 40, GOLD)
			_rect(cx - 18, top - 40, 36, 3, GOLD)
			for s in [-16, 0, 16]:
				_rect(cx + s - 1, top - 48, 2, 10, Color8(232, 222, 196))  # candle
				_disc(Vector2(cx + s, top - 50), 3.0, Color8(255, 210, 120))  # flame
				_disc(Vector2(cx + s, top - 50), 6.0, Color(1.0, 0.8, 0.4, 0.25))
		2:  # stack of books
			var sy := top
			var sw := 40
			for b in range(5):
				var bw := sw - b * 3 + int(_h(i * 7 + b) * 6)
				var col: Color = SPINES[(i * 3 + b) % SPINES.size()]
				_rect(cx - bw / 2, sy - 9, bw, 9, col)
				_rect(cx - bw / 2, sy - 9, bw, 2, col.lightened(0.2))
				_rect(cx - bw / 2 + 2, sy - 5, bw - 4, 1, Color(GOLD.r, GOLD.g, GOLD.b, 0.6))
				sy -= 9
		3:  # marble bust on a small plinth
			_rect(cx - 12, top - 18, 24, 18, MARBLE_SH)             # plinth
			_rect(cx - 12, top - 18, 24, 2, GOLD)
			_trap(cx, top - 46, 10, 30, 28, MARBLE)                 # shoulders/chest
			_disc(Vector2(cx, top - 52), 10.0, MARBLE)              # head
			_disc(Vector2(cx - 3, top - 53), 8.0, MARBLE_SH)
		4:  # reading lectern with an open book
			_line(Vector2(cx, top), Vector2(cx, top - 30), Color8(80, 52, 30), 4)  # post
			_rect(cx - 18, top - 4, 36, 4, Color8(90, 58, 34))      # foot
			# slanted desk + open book
			_trap(cx, top - 44, 40, 30, 14, Color8(110, 72, 40))
			_rect(cx - 18, top - 44, 17, 12, CREAM)                 # left page
			_rect(cx + 1, top - 44, 17, 12, Color8(228, 214, 184))  # right page
			_rect(cx - 1, top - 44, 2, 12, Color8(90, 58, 34))      # spine
			_disc(Vector2(cx, top - 50), 5.0, Color(1.0, 0.85, 0.5, 0.2))  # reading glow
