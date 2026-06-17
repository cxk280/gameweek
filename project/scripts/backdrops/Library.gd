extends "res://scripts/backdrops/BackdropBase.gd"
## Stage theme: an opulent INTERIOR hall. Unlike the exterior themes there is no sky; instead the
## static layer is a warm ambient wash plus the non-scrolling upper ceiling (painted fresco + a
## gilded domed centerpiece). Depth here = the hall RECEDING horizontally: a slow layer of small,
## high, haze-washed FAR shelf bays; a mid layer of taller bays with fluted columns and arched
## windows; and a fast NEAR layer of large gallery bookshelves, marble statues and a great window
## over a checkered marble floor. The play-field ledges are live level geometry and NOT drawn here.

# ---- warm opulent palette ----------------------------------------------------
const WOOD_DARK := Color8(58, 36, 22)
const WOOD := Color8(96, 60, 34)
const WOOD_LIT := Color8(140, 92, 52)
const GOLD := Color8(232, 186, 96)
const GOLD_D := Color8(178, 138, 64)
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


func build(level_w: float, view_w: int, view_h: int) -> Dictionary:
	# Static layer: warm ambient wash + the upper ceiling band (fresco + gilded cupola centerpiece
	# + a smaller echo dome) that barely parallaxes — the fixed top of the hall.
	var sky := _fresh(view_w, view_h)
	_ambient(view_w, view_h)
	_ceiling_fresco(view_w)
	_cupola(int(view_w * 0.46), 150)
	_second_dome(int(view_w * 0.80), 168)

	# FAR bays: small, high, washed in warm haze; barely moves. The far wall reaches up to just
	# under the ceiling cornice so there is no dead band between ceiling and shelves.
	var far := _fresh(_layer_w(level_w, 0.10, view_w), 760)
	_bay_band(330.0, 18, 0.72, 41, 150, 210)

	# MID bays: taller bays + fluted columns with gold capitals + arched glowing windows.
	var mid := _fresh(_layer_w(level_w, 0.30, view_w), 760)
	_bay_band(366.0, 230, 0.40, 67, 210, 300)

	# NEAR: the largest, sharpest gallery shelves + marble statues + a great window + marble floor.
	var near := _fresh(_layer_w(level_w, 0.55, view_w), 760)
	_bay_band(470.0, 330, 0.12, 91, 300, 410)
	_dado(470, 560)
	_floor(560, 760)
	_great_window(int(_w * 0.62), 470)
	_statues()

	return {
		"sky": sky,
		"layers": [
			{"image": far, "motion": 0.10, "top": 0.0, "anchor_bottom": true},
			{"image": mid, "motion": 0.30, "top": 0.0, "anchor_bottom": true},
			{"image": near, "motion": 0.55, "top": 0.0, "anchor_bottom": true},
		],
	}


# ---------------------------------------------------------------- ambient wash (static)
func _ambient(view_w: int, view_h: int) -> void:
	# soft vertical warm wash: deeper amber up top (ceiling glow) easing to a lit mid-hall.
	var top := Color8(120, 78, 40)
	var mid := Color8(168, 124, 74)
	var low := Color8(150, 110, 70)
	for y in range(view_h):
		var t := float(y) / float(view_h)
		var row: Color
		if t < 0.5:
			row = top.lerp(mid, pow(t / 0.5, 0.85))
		else:
			row = mid.lerp(low, (t - 0.5) / 0.5)
		for x in range(view_w):
			_img.set_pixel(x, y, row)
	# warm horizontal light glow across the mid-hall (windows pouring in)
	for y in range(150, 520):
		var a := (1.0 - absf(float(y) - 320.0) / 200.0) * 0.10
		if a > 0.0:
			_rect(0, y, view_w, 1, Color(1.0, 0.82, 0.5, a))


# ---------------------------------------------------------------- ceiling fresco (static)
func _ceiling_fresco(view_w: int) -> void:
	# painted fresco band along the very top: soft cream/peach/blue panels framed by gold ribs.
	var band_h := 150
	_rect(0, 0, view_w, band_h, Color8(232, 206, 168))
	var i := 0
	var x := -40
	while x < view_w + 40:
		var s := 5100 + i
		var bw := 120 + int(_hash(s * 7) * 160)
		var cy := 30 + int(_hash(s * 3) * 80)
		var hue := _hash(s * 5)
		var col: Color
		if hue < 0.4:
			col = Color8(248, 222, 196)     # peach/cream
		elif hue < 0.72:
			col = Color8(206, 220, 236)     # soft sky blue
		else:
			col = Color8(236, 200, 176)     # warm rose
		_disc(Vector2(x + bw / 2, cy), float(bw) * 0.28, Color(col.r, col.g, col.b, 0.6))
		_disc(Vector2(x + bw / 2 + 18, cy + 14), float(bw) * 0.2, Color(col.r, col.g, col.b, 0.45))
		# a suggested robed figure softly blended into the cloud
		if _hash(s * 11) < 0.5:
			var fx := x + int(bw * 0.34)
			var fy := cy + 18
			_disc(Vector2(fx, fy + 14), 9.0, Color(0.78, 0.6, 0.48, 0.4))
			_disc(Vector2(fx, fy + 4), 5.0, Color(0.85, 0.68, 0.55, 0.45))
			_disc(Vector2(fx, fy + 18), 13.0, Color(col.r, col.g, col.b, 0.3))
		x += bw
		i += 1
	# coffered panel frame: gold rib grid across the band
	var panel := 150
	x = 0
	while x < view_w:
		_line(Vector2(x, 0), Vector2(x + 30, band_h), GOLD, 2)
		_rect(x, 0, panel - 4, 3, Color(GOLD.r, GOLD.g, GOLD.b, 0.5))
		x += panel
	# horizontal gold cornice closing the band off from the wall below
	_rect(0, band_h - 8, view_w, 8, GOLD_D)
	_rect(0, band_h - 8, view_w, 3, GOLD_BRIGHT)
	_rect(0, band_h, view_w, 4, Color8(70, 44, 26))   # shadow line under cornice


# ---------------------------------------------------------------- bays band
# Renders a horizontal run of wall bays at one depth: each bay = bookshelf tiers + a gallery
# balcony rail, separated by carved columns with gilded capitals/bases. Haze lerps the whole bay
# toward the warm atmosphere so far bands recede. Some bays carry a glowing arched window. Drawn
# into the current layer image (bottom-anchored), filling down to the image bottom.
func _bay_band(base_y: float, top_y: int, haze: float, seed: int, wmin: int, wmax: int) -> void:
	var x := -60.0
	var i := 0
	while x < float(_w) + 60.0:
		var s := seed * 1000 + i
		var bw := int(wmin + _hash(s * 9 + 2) * (wmax - wmin))
		var col_w := maxi(14, int(bw * 0.12))         # column between bays
		var inner_x := int(x) + col_w
		var inner_w := bw - col_w
		var wall_top := top_y
		var wall_h := int(base_y) - wall_top
		# back wall plaster behind shelves (warm, hazed)
		var plaster := Color8(120, 84, 52).lerp(HAZE, haze)
		_rect(int(x), wall_top, bw, _h - wall_top, plaster)
		# two tiers of bookshelves split by a gallery balcony
		var gallery_y := wall_top + int(wall_h * 0.46)
		_bookshelf(inner_x, wall_top + 6, inner_w, gallery_y - wall_top - 10, s * 3 + 1, haze)
		_bookshelf(inner_x, gallery_y + 14, inner_w, int(base_y) - gallery_y - 16, s * 3 + 2, haze)
		# gallery balcony rail crossing the bay
		_balcony(inner_x, gallery_y, inner_w, haze)
		# some bays get a glowing arched window
		if _hash(s * 17) < 0.34:
			_arched_window(inner_x + inner_w / 2, gallery_y + 18, int(inner_w * 0.5),
				int(base_y) - gallery_y - 28, haze)
		# carved column between bays with gilded capital + base
		_column(int(x), wall_top, col_w, int(base_y) - wall_top, haze)
		x += float(bw)
		i += 1


func _bookshelf(x: int, y: int, w: int, h: int, seed: int, haze: float) -> void:
	if w <= 6 or h <= 8:
		return
	var case := WOOD_DARK.lerp(HAZE, haze)
	_rect(x, y, w, h, case)
	var shelf_h := 16
	var rows := maxi(1, h / shelf_h)
	var sharp := 1.0 - haze
	for r in range(rows):
		var ry := y + r * shelf_h
		var rh := mini(shelf_h, y + h - ry)
		if rh < 6:
			continue
		var book_top := ry + 1
		var book_h := rh - 3
		var bx := x + 2
		var end := x + w - 2
		while bx < end:
			var idx := seed * 131 + r * 29 + bx
			var bwid := 2 + int(_hash(idx) * 4)
			if bx + bwid > end:
				bwid = end - bx
			var base: Color = SPINES[int(_hash(idx * 2) * SPINES.size()) % SPINES.size()]
			var lit := lerpf(0.0, 0.18, _hash(idx * 5))
			var col := base.lightened(lit).lerp(HAZE, haze * 0.7)
			var bh := book_h - int(_hash(idx * 7) * 3)
			_rect(bx, book_top + (book_h - bh), bwid, bh, col)
			# tiny gold title fleck on some spines (only when sharp enough to read)
			if sharp > 0.55 and bwid >= 4 and _hash(idx * 11) < 0.3:
				_rect(bx + 1, book_top + (book_h - bh) + bh / 2, bwid - 2, 1,
					Color(GOLD_BRIGHT.r, GOLD_BRIGHT.g, GOLD_BRIGHT.b, 0.8))
			bx += bwid
		_rect(x, ry + rh - 2, w, 2, WOOD_LIT.lerp(HAZE, haze))
		_rect(x, ry + rh - 1, w, 1, Color(0, 0, 0, 0.25 * (1.0 - haze)))


func _balcony(x: int, y: int, w: int, haze: float) -> void:
	# the gallery walkway band + a gilded railing of small balusters
	var board := WOOD.lerp(HAZE, haze)
	_rect(x - 2, y, w + 4, 12, board)
	_rect(x - 2, y, w + 4, 2, WOOD_LIT.lerp(HAZE, haze))
	_rect(x - 2, y - 4, w + 4, 3, GOLD.lerp(HAZE, haze * 0.6))   # gilded top rail
	var step := 9
	var bx := x + 2
	while bx < x + w - 2:
		_rect(bx, y - 4, 2, 5, Color(WOOD_LIT.r, WOOD_LIT.g, WOOD_LIT.b, 0.9).lerp(HAZE, haze))
		bx += step


func _column(x: int, top: int, w: int, h: int, haze: float) -> void:
	# carved column/pilaster: fluted shaft with gilded capital and base
	var shaft := WOOD.lerp(HAZE, haze)
	var shaft_lit := WOOD_LIT.lerp(HAZE, haze)
	var cap_h := maxi(8, int(w * 0.8))
	var base_h := maxi(7, int(w * 0.7))
	var shaft_top := top + cap_h
	var shaft_h := h - cap_h - base_h
	_rect(x, shaft_top, w, shaft_h, shaft)
	var fl := 4
	var fx := x + 2
	while fx < x + w - 1:
		_rect(fx, shaft_top, 1, shaft_h, Color(shaft_lit.r, shaft_lit.g, shaft_lit.b, 0.5))
		fx += fl
	# gilded capital
	_rect(x - 2, top, w + 4, cap_h, GOLD.lerp(HAZE, haze * 0.55))
	_rect(x - 2, top, w + 4, 2, GOLD_BRIGHT.lerp(HAZE, haze * 0.4))
	_rect(x - 3, top + cap_h - 3, w + 6, 3, GOLD_D.lerp(HAZE, haze * 0.5))
	# gilded base
	_rect(x - 2, top + h - base_h, w + 4, base_h, GOLD.lerp(HAZE, haze * 0.6))
	_rect(x - 2, top + h - base_h, w + 4, 2, GOLD_BRIGHT.lerp(HAZE, haze * 0.4))


func _arched_window(cx: int, top: int, w: int, h: int, haze: float) -> void:
	if w < 10 or h < 16:
		return
	var glow := AMBER.lerp(HAZE, haze * 0.5)
	var frame := WOOD_DARK.lerp(HAZE, haze)
	var arch_h := int(w * 0.5)
	_rect(cx - w / 2 - 2, top - 1, w + 4, h + 2, frame)
	_rect(cx - w / 2, top + arch_h, w, h - arch_h, glow)
	for r in range(arch_h):
		var hw := int(sqrt(maxf(0.0, float(arch_h * arch_h - (arch_h - r) * (arch_h - r)))))
		_rect(cx - hw, top + r, hw * 2, 1, glow)
	_rect(cx - w / 2 + 2, top + arch_h + 2, w - 4, h - arch_h - 4,
		Color(GOLD_BRIGHT.r, GOLD_BRIGHT.g, GOLD_BRIGHT.b, 0.5 * (1.0 - haze * 0.5)))
	var sharp := 1.0 - haze
	_rect(cx - 1, top + 2, 2, h - 4, Color(frame.r, frame.g, frame.b, 0.8))
	var py := top + arch_h
	while py < top + h - 4:
		_rect(cx - w / 2 + 1, py, w - 2, 1, Color(frame.r, frame.g, frame.b, 0.7))
		py += 12
	if sharp > 0.4:
		_rect(cx - w / 2 - 6, top - 4, w + 12, h + 8, Color(1.0, 0.84, 0.5, 0.06))


# ---------------------------------------------------------------- cupola (static centerpiece)
func _cupola(cx: int, frame_top: int) -> void:
	# signature domed cupola: a great arched fresco ringed with clerestory windows dropping light.
	var dome_r := 150.0
	var base_y := frame_top + 40
	for k in range(10, 0, -1):
		_disc(Vector2(cx, base_y), dome_r * (1.0 + float(k) * 0.05), Color(1.0, 0.82, 0.46, 0.02))
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
		_rect(wx - 4, wy - 8, 8, 14, GOLD_D)
		_rect(wx - 3, wy - 7, 6, 12, GOLD_BRIGHT)
		_rect(wx - 2, wy + 6, 4, 40, Color(1.0, 0.86, 0.5, 0.10))
	# gilded base cornice ring + lantern finial
	_rect(cx - int(dome_r), base_y - 2, int(dome_r * 2), 6, GOLD)
	_rect(cx - int(dome_r), base_y - 2, int(dome_r * 2), 2, GOLD_BRIGHT)
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


# ---------------------------------------------------------------- dado / wainscot (near)
func _dado(y_top: int, y_bot: int) -> void:
	# a paneled marble + wood wainscot running the full length, closing the gap between the
	# bookshelf bases and the marble floor with carved panels and a gilded chair rail.
	var h := y_bot - y_top
	var wood := Color8(78, 48, 28)
	var wood_d := Color8(54, 32, 18)
	_rect(0, y_top, _w, h, wood)
	_rect(0, y_top, _w, 4, GOLD)
	_rect(0, y_top + 4, _w, 2, GOLD_BRIGHT)
	_rect(0, y_top + 6, _w, 2, Color(0, 0, 0, 0.2))
	var x := 8
	var i := 0
	while x < _w - 8:
		var pw := 70 + int(_hash(i * 9 + 3) * 70)
		if x + pw > _w - 8:
			pw = _w - 8 - x
		var inlay := Color8(214, 192, 158)
		_rect(x, y_top + 14, pw, h - 24, wood_d)
		_rect(x + 4, y_top + 18, pw - 8, h - 32, inlay)
		_rect(x + 4, y_top + 18, pw - 8, 2, Color8(236, 218, 184))
		if _hash(i * 7) < 0.5:
			_disc(Vector2(x + pw / 2, y_top + h / 2), 4.0, GOLD)
			_disc(Vector2(x + pw / 2, y_top + h / 2), 2.0, GOLD_BRIGHT)
		x += pw + 6
		i += 1
	_rect(0, y_bot - 6, _w, 6, wood_d)
	_rect(0, y_bot - 6, _w, 2, Color(GOLD.r, GOLD.g, GOLD.b, 0.5))


# ---------------------------------------------------------------- floor (near)
func _floor(floor_top: int, floor_bot: int) -> void:
	# checkered marble floor receding at the bottom of the hall, with soft warm reflections.
	var light := Color8(214, 198, 168)
	var dark := Color8(150, 122, 92)
	for y in range(floor_top, floor_bot):
		var depth := float(y - floor_top) / float(floor_bot - floor_top)
		var tile := int(lerpf(10.0, 40.0, depth))
		var rowi := int((y - floor_top) / maxf(6.0, lerpf(6.0, 22.0, depth)))
		for x in range(_w):
			var coli := int(x / float(maxi(6, tile)))
			var c: Color = light if (coli + rowi) % 2 == 0 else dark
			c = c.lerp(HAZE, (1.0 - depth) * 0.4)
			_img.set_pixel(x, y, c)
	for x in range(0, _w, 1):
		if _hash(x * 3) < 0.5:
			var a := 0.05 + _hash(x * 7) * 0.05
			_rect(x, floor_top, 1, 40, Color(1.0, 0.86, 0.5, a))


# ---------------------------------------------------------------- landmark: great window (near)
func _great_window(cx: int, ground_y: int) -> void:
	# a towering arched window flooding the hall with gold — set forward of the shelves
	var w := 150
	var h := 300
	var top := ground_y - h
	var arch_h := int(w * 0.55)
	var frame := WOOD_DARK
	_rect(cx - w / 2 - 8, top - 6, w + 16, h + 6, frame)
	_rect(cx - w / 2 - 8, top - 6, w + 16, 3, WOOD_LIT)
	var glow := AMBER
	_rect(cx - w / 2, top + arch_h, w, h - arch_h, glow)
	for r in range(arch_h):
		var hw := int(sqrt(maxf(0.0, float(arch_h * arch_h - (arch_h - r) * (arch_h - r)))))
		_rect(cx - hw, top + r, hw * 2, 1, glow)
	_rect(cx - w / 2 + 8, top + arch_h + 8, w - 16, h - arch_h - 30,
		Color(GOLD_BRIGHT.r, GOLD_BRIGHT.g, GOLD_BRIGHT.b, 0.55))
	var mx := cx - w / 2 + 4
	while mx < cx + w / 2:
		_rect(mx, top + arch_h, 2, h - arch_h, Color(frame.r, frame.g, frame.b, 0.85))
		mx += 30
	var my := top + arch_h
	while my < top + h:
		_rect(cx - w / 2, my, w, 2, Color(frame.r, frame.g, frame.b, 0.8))
		my += 34
	_line(Vector2(cx, top + arch_h), Vector2(cx, top), Color(frame.r, frame.g, frame.b, 0.8), 2)
	_line(Vector2(cx, top + arch_h), Vector2(cx - int(w * 0.34), top + int(arch_h * 0.3)), Color(frame.r, frame.g, frame.b, 0.7), 2)
	_line(Vector2(cx, top + arch_h), Vector2(cx + int(w * 0.34), top + int(arch_h * 0.3)), Color(frame.r, frame.g, frame.b, 0.7), 2)
	_disc(Vector2(cx, top + 2), 9.0, GOLD)
	_disc(Vector2(cx, top + 2), 5.0, GOLD_BRIGHT)
	_rect(cx - w / 2 - 12, ground_y - 4, w + 24, 8, GOLD)
	_rect(cx - w / 2 - 12, ground_y - 4, w + 24, 2, GOLD_BRIGHT)
	for k in range(8, 0, -1):
		_rect(cx - w / 2 - k * 6, top - k * 4, w + k * 12, h + k * 8, Color(1.0, 0.84, 0.5, 0.015))


# ---------------------------------------------------------------- statues (near)
func _statues() -> void:
	# A small, distinguished set of marble figures on pedestals, spread along the full length at
	# non-repeating spots via a while-loop + hash jitter. Varied poses keep it a curated collection,
	# not a crowd; large gaps between them so they never bunch up.
	var ground_y := 566
	var x := 220.0
	var n := 0
	while x < float(_w):
		var pose := n % 4   # 0 torch-bearer, 1/3 calm robed, 2 scholar w/ book
		var sc := 0.9 + _hash(n * 13 + 5) * 0.12
		_statue(int(x), ground_y, pose, sc)
		x += 900.0 + _hash(n * 17 + 3) * 700.0   # wide, jittered spacing -> tasteful, no repeat
		n += 1


func _statue(cx: int, ground_y: int, pose: int, sc: float) -> void:
	# one marble figure on a pedestal; `pose` selects silhouette/prop, `sc` scales it.
	var ped_w := int(48 * sc)
	var ped_h := int(96 * sc)
	var ped_top := ground_y - ped_h
	_rect(cx - ped_w / 2, ped_top, ped_w, ped_h, MARBLE)
	_rect(cx - ped_w / 2, ped_top, 3, ped_h, MARBLE_SH)
	_rect(cx + ped_w / 2 - 3, ped_top, 3, ped_h, MARBLE.lightened(0.1))
	_rect(cx - ped_w / 2 - 5, ped_top, ped_w + 10, 7, MARBLE_SH)
	_rect(cx - ped_w / 2 - 5, ped_top + 5, ped_w + 10, 2, GOLD)
	_rect(cx - ped_w / 2 - 6, ground_y - 10, ped_w + 12, 10, MARBLE_SH)
	_rect(cx - ped_w / 2 - 6, ground_y - 10, ped_w + 12, 2, GOLD)
	_rect(cx - int(13 * sc), ped_top + int(34 * sc), int(26 * sc), int(16 * sc), MARBLE_SH)
	_rect(cx - int(11 * sc), ped_top + int(39 * sc), int(22 * sc), 2, Color(GOLD.r, GOLD.g, GOLD.b, 0.55))
	var fy := ped_top
	# full robed figure
	_trap(cx, fy - int(58 * sc), int(18 * sc), int(38 * sc), int(58 * sc), MARBLE)
	_rect(cx - int(19 * sc), fy - int(14 * sc), int(38 * sc), int(14 * sc), MARBLE)
	_trap(cx, fy - int(58 * sc), int(6 * sc), int(14 * sc), int(58 * sc), MARBLE_SH)  # drape fold
	_rect(cx - int(13 * sc), fy - int(92 * sc), int(26 * sc), int(36 * sc), MARBLE)   # torso
	_rect(cx - int(13 * sc), fy - int(92 * sc), int(4 * sc), int(36 * sc), MARBLE_SH)
	_disc(Vector2(cx, fy - int(102 * sc)), 9.0 * sc, MARBLE)                          # head
	_disc(Vector2(cx - 2, fy - int(103 * sc)), 7.0 * sc, MARBLE_SH)
	match pose:
		0:
			# torch-bearer, raised arm
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
			_rect(cx - 1, fy - int(70 * sc), 2, int(13 * sc), MARBLE_SH)
			_rect(cx - int(7 * sc), fy - int(66 * sc), int(14 * sc), 1, Color(GOLD.r, GOLD.g, GOLD.b, 0.6))
		_:
			# calm robed figure, hands lowered
			_line(Vector2(cx - int(11 * sc), fy - int(86 * sc)), Vector2(cx - int(16 * sc), fy - int(58 * sc)), MARBLE, int(5 * sc))
			_line(Vector2(cx + int(11 * sc), fy - int(86 * sc)), Vector2(cx + int(16 * sc), fy - int(58 * sc)), MARBLE, int(5 * sc))
	# soft warm uplight from below
	for k in range(5, 0, -1):
		_disc(Vector2(cx, fy - int(24 * sc)), 24.0 * sc + k * 6.0, Color(1.0, 0.86, 0.52, 0.025))
