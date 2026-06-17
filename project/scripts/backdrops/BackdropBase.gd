extends RefCounted
## Shared drawing primitives for layered 2.5D stage backdrops. A theme module extends this and
## implements `build(level_w, view_w, view_h) -> Dictionary` returning:
##   { "sky": Image,                                  # static full-viewport gradient (no parallax)
##     "layers": [ {image:Image, motion:float, top:float, anchor_bottom:bool} ... ] }  # back->front
## Each layer is mounted by Main in a ParallaxLayer at its motion_scale, so distant layers (small
## motion) barely move while nearer ones track the camera. Layer image widths should be sized
## ~ level_w * motion + view_w so the whole traversal is covered without tiling/repetition.
## Building/landscape rows are transparent above their content and bottom-anchored to the horizon;
## sky bodies (moon, sun) sit on a high, near-static layer. Do NOT draw the play-field platforms —
## those are the live level geometry.

var _img: Image
var _w: int
var _h: int
var _scratch: Image   # reusable buffer so alpha fills can use C++ blend_rect, not per-pixel


## Allocate a fresh transparent layer image and make it the current draw target.
func _fresh(w: int, h: int) -> Image:
	_w = w
	_h = h
	_img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	return _img


## Convenience: width to cover a parallax layer across the whole level for a given motion_scale.
func _layer_w(level_w: float, motion: float, view_w: int) -> int:
	return int(level_w * motion) + view_w + 80


func _px(x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= _w or y >= _h:
		return
	if c.a >= 0.999:
		_img.set_pixel(x, y, c)
	else:
		var b := _img.get_pixel(x, y)
		_img.set_pixel(x, y, b.lerp(Color(c.r, c.g, c.b, 1.0), c.a))


func _rect(x: int, y: int, w: int, h: int, c: Color) -> void:
	if c.a >= 0.999:
		# fast C++ path for opaque fills (building bodies, etc.)
		var rx := maxi(x, 0)
		var ry := maxi(y, 0)
		var rw := mini(x + w, _w) - rx
		var rh := mini(y + h, _h) - ry
		if rw > 0 and rh > 0:
			_img.fill_rect(Rect2i(rx, ry, rw, rh), Color(c.r, c.g, c.b, 1.0))
		return
	# alpha fill: composite via C++ blend_rect using a reusable scratch buffer (fast)
	var rx := maxi(x, 0)
	var ry := maxi(y, 0)
	var rw := mini(x + w, _w) - rx
	var rh := mini(y + h, _h) - ry
	if rw <= 0 or rh <= 0:
		return
	if rw <= 1024 and rh <= 1024:
		if _scratch == null or _scratch.get_width() < rw or _scratch.get_height() < rh:
			_scratch = Image.create(maxi(1024, rw), maxi(1024, rh), false, Image.FORMAT_RGBA8)
		_scratch.fill_rect(Rect2i(0, 0, rw, rh), c)
		_img.blend_rect(_scratch, Rect2i(0, 0, rw, rh), Vector2i(rx, ry))
	else:
		for yy in range(ry, ry + rh):
			for xx in range(rx, rx + rw):
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


## Symmetric trapezoid (flared roofs, tiered shapes): top_w at top_y, widening to bot_w over h rows.
func _trap(cx: int, top_y: int, top_w: int, bot_w: int, h: int, color: Color) -> void:
	for r in range(h + 1):
		var w := int(lerpf(float(top_w), float(bot_w), float(r) / float(h)))
		_rect(cx - w / 2, top_y + r, w, 1, color)


## Deterministic hash -> 0..1 (use for all "randomness" so output is reproducible).
func _hash(n: int) -> float:
	var x := (n * 1103515245 + 12345) & 0x7fffffff
	x = (x ^ (x >> 13)) * 1274126177 & 0x7fffffff
	return float(x % 10000) / 10000.0


## Low-frequency, non-repeating envelope for skyline/terrain height & density along the length.
func _envelope(x: float) -> float:
	var a := 0.5 + 0.5 * sin(x * 0.0013)
	var b := 0.5 + 0.5 * sin(x * 0.0041 + 2.1)
	return clampf(0.30 + 0.5 * a + 0.28 * b - 0.08, 0.0, 1.0)


## Vertical gradient fill of the current image (for sky), top->bottom with an optional curve.
func _vgrad(top: Color, bottom: Color, curve := 1.0) -> void:
	for y in range(_h):
		var row := top.lerp(bottom, pow(float(y) / float(_h), curve))
		_img.fill_rect(Rect2i(0, y, _w, 1), Color(row.r, row.g, row.b, 1.0))
