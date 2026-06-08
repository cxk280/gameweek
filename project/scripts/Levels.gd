extends Node
class_name Levels
## Data-driven level definitions. Each level is plain data; Level.gd builds the geometry,
## checkpoints and finish from it. Adding a level (Day 5) = adding a dictionary here.
##
## Platforms are Rect2(x, y, w, h) with y = top surface. Coordinates grow right/down.

const LEVEL_1 := {
	"name": "Neon Rooftops",
	"start": Vector2(120, 500),
	"finish": Vector2(4320, 540),
	"bounds": Rect2(-200, 0, 5000, 900),
	"platforms": [
		Rect2(0, 560, 620, 240),
		Rect2(780, 560, 380, 240),
		Rect2(1320, 480, 360, 320),
		Rect2(1850, 540, 300, 260),
		Rect2(2300, 460, 320, 340),
		Rect2(2780, 560, 380, 240),
		Rect2(3350, 500, 300, 300),
		Rect2(3820, 560, 820, 240),
	],
	"checkpoints": [
		Vector2(1500, 480),
		Vector2(2460, 460),
		Vector2(3500, 500),
	],
}

const ALL := [LEVEL_1]
