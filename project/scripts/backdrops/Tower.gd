extends "res://scripts/backdrops/BackdropBase.gd"
## Stage theme: a dramatic vertical ascent backdrop. This module paints ONLY the environment that
## sits BEHIND the stage's central gameplay structure — an ominous sunset sky, a slow distant
## cloud/haze band high up, and a low glowing field at the foot of the climb. The big climbable
## column and its platforms are live level geometry added elsewhere, so the mid-area is left clean.

const SKY_TOP := Color8(40, 70, 120)      # deep blue, high in the frame
const SKY_MID := Color8(120, 120, 150)    # hazy band toward the middle
const SKY_LOW := Color8(232, 150, 70)     # warm gold/orange near the bottom (ominous sunset)
const FIELD_HI := Color8(150, 20, 24)     # field near its top edge
const FIELD_LO := Color8(220, 30, 30)     # field deepening toward the bottom


func build(level_w: float, view_w: int, view_h: int) -> Dictionary:
	# static sky: blue high -> hazy mid -> warm sunset low (two-stop curve)
	var sky := _fresh(view_w, view_h)
	_sky_gradient(view_h)

	# distant cloud / haze band: barely moves, sits high (anchor_bottom:false, negative top)
	var clouds := _fresh(_layer_w(level_w, 0.05, view_w), 300)
	_clouds()

	# glowing red field at the very foot of the climb: moves more, bottom-anchored
	var field := _fresh(_layer_w(level_w, 0.30, view_w), 200)
	_field()

	return {
		"sky": sky,
		"layers": [
			{"image": clouds, "motion": 0.05, "top": -40.0, "anchor_bottom": false},
			{"image": field, "motion": 0.30, "top": 0.0, "anchor_bottom": true},
		],
	}


## Two-stop vertical sky fill painted directly into the current (sky) image.
func _sky_gradient(view_h: int) -> void:
	for y in range(_h):
		var t := float(y) / float(view_h)
		var row: Color
		if t < 0.55:
			row = SKY_TOP.lerp(SKY_MID, t / 0.55)
		else:
			row = SKY_MID.lerp(SKY_LOW, (t - 0.55) / 0.45)
		for x in range(_w):
			_img.set_pixel(x, y, row)


## Soft puffy clouds scattered across the full width, varied by hash so there is no obvious repeat.
func _clouds() -> void:
	var count := int(_w / 360) + 4
	for i in range(count):
		var cxp := _hash(i * 23 + 3) * float(_w)
		var cyp := 40.0 + _hash(i * 17 + 5) * float(_h) * 0.5
		var s := 16.0 + _hash(i * 7 + 1) * 22.0
		var a := 0.78 + _hash(i * 11 + 2) * 0.18
		for k in range(5):
			var ox := (float(k) - 2.0) * s * 0.8
			var oy := absf(float(k) - 2.0) * s * 0.22
			var rr := s * (1.0 - absf(float(k) - 2.0) * 0.12)
			_disc(Vector2(cxp + ox, cyp + oy), rr, Color(0.95, 0.95, 0.97, a))


## Deep red field with a soft glow and scattered rose speckle along its top edge.
func _field() -> void:
	# vertical body: lighter red at the top edge -> deeper red toward the bottom
	for y in range(_h):
		var t := float(y) / float(_h)
		var col := FIELD_HI.lerp(FIELD_LO, t)
		for x in range(_w):
			_img.set_pixel(x, y, col)
	# soft red glow rising off the top edge, spread along the length
	var glows := int(_w / 520) + 3
	for g in range(glows):
		var gx := _hash(g * 29 + 7) * float(_w)
		for k in range(6, 0, -1):
			var rr := 60.0 * (1.0 + float(k) * 0.22)
			_disc(Vector2(gx, 0.0), rr, Color(1.0, 0.12, 0.10, 0.05))
	# scattered rose speckle concentrated near the top edge of the field
	var speckle := int(_w * 0.45)
	for i in range(speckle):
		var x := _hash(i * 5 + 1) * float(_w)
		var y := _hash(i * 3 + 2) * _hash(i * 3 + 2) * float(_h)
		var b := 0.4 + _hash(i * 9 + 4) * 0.4
		_rect(int(x), int(y), 2, 2, Color(1.0, 0.4 + b * 0.1, 0.4, b))
