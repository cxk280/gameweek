extends Node
class_name Levels
## Data-driven level definitions. Level.gd builds geometry, props, hazards, checkpoints and
## finish from this. Adding a course = adding a dictionary. Platforms are Rect2(x, y, w, h)
## with y = top surface; coordinates grow right/down. Keep gaps <= ~210px and up-steps
## <= ~120px so the jump (≈120px height, ≈270px air distance) clears them.

const LEVEL_1 := {
	"name": "Neon Rooftops",
	"backdrop": "city",
	"start": Vector2(120, 520),
	"finish": Vector2(8760, 520),
	"bounds": Rect2(-200, 0, 9600, 900),
	"platforms": [
		Rect2(0, 580, 560, 260),
		Rect2(720, 560, 360, 280),
		Rect2(1240, 520, 220, 320),
		Rect2(1610, 560, 200, 280),
		Rect2(1970, 500, 200, 340),
		Rect2(2330, 560, 160, 280),
		Rect2(2650, 510, 160, 330),
		Rect2(2970, 470, 180, 370),
		Rect2(3320, 560, 440, 280),
		Rect2(3920, 500, 200, 340),
		Rect2(4280, 450, 200, 390),
		Rect2(4640, 520, 180, 320),
		Rect2(4980, 560, 520, 280),
		Rect2(5660, 500, 200, 340),
		Rect2(6020, 450, 180, 390),
		Rect2(6360, 520, 180, 320),
		Rect2(6700, 560, 220, 280),
		Rect2(7090, 500, 200, 340),
		Rect2(7450, 560, 240, 280),
		Rect2(7850, 520, 200, 320),
		Rect2(8210, 560, 820, 280),
	],
	"hazards": [
		Rect2(2210, 800, 120, 24),
		Rect2(5540, 800, 120, 24),
		Rect2(6940, 800, 150, 24),
	],
	"checkpoints": [
		Vector2(1700, 560),
		Vector2(3060, 470),
		Vector2(4730, 520),
		Vector2(6450, 520),
		Vector2(7570, 560),
	],
}

const LEVEL_2 := {
	"name": "Spire Climb",
	"backdrop": "city",
	"start": Vector2(120, 600),
	"finish": Vector2(6760, 360),
	"bounds": Rect2(-200, 0, 7400, 960),
	"platforms": [
		Rect2(0, 660, 480, 300),
		Rect2(640, 620, 200, 340),
		Rect2(980, 560, 160, 400),
		Rect2(1300, 600, 180, 360),
		Rect2(1640, 540, 160, 420),
		Rect2(1960, 600, 160, 360),
		Rect2(2280, 540, 160, 420),
		Rect2(2600, 480, 180, 480),
		Rect2(2960, 560, 420, 400),
		Rect2(3560, 500, 160, 460),
		Rect2(3880, 440, 160, 520),
		Rect2(4200, 500, 160, 460),
		Rect2(4520, 440, 160, 520),
		Rect2(4840, 400, 180, 560),
		Rect2(5200, 460, 160, 500),
		Rect2(5520, 400, 160, 560),
		Rect2(5840, 360, 180, 600),
		Rect2(6200, 420, 160, 540),
		Rect2(6520, 420, 560, 540),
	],
	"hazards": [
		Rect2(840, 920, 140, 24),
		Rect2(3380, 920, 180, 24),
	],
	"checkpoints": [
		Vector2(1720, 540),
		Vector2(2690, 480),
		Vector2(3960, 440),
		Vector2(4930, 400),
		Vector2(5930, 360),
	],
}

const LEVEL_3 := {
	"name": "Skyline Sprint",
	"backdrop": "city",
	"start": Vector2(120, 500),
	"finish": Vector2(8700, 520),
	"bounds": Rect2(-200, 0, 9400, 900),
	"platforms": [
		Rect2(0, 560, 520, 320),
		Rect2(670, 540, 300, 320),
		Rect2(1130, 560, 260, 320),
		Rect2(1540, 520, 240, 320),
		Rect2(1940, 560, 200, 320),
		Rect2(2290, 510, 200, 320),
		Rect2(2650, 560, 300, 320),
		Rect2(3100, 520, 200, 320),
		Rect2(3460, 470, 200, 320),
		Rect2(3810, 520, 240, 320),
		Rect2(4210, 560, 400, 320),
		Rect2(4760, 500, 200, 320),
		Rect2(5120, 540, 200, 320),
		Rect2(5470, 490, 220, 320),
		Rect2(5850, 540, 200, 320),
		Rect2(6200, 500, 240, 320),
		Rect2(6600, 560, 300, 320),
		Rect2(7050, 520, 200, 320),
		Rect2(7410, 560, 240, 320),
		Rect2(7800, 520, 200, 320),
		Rect2(8160, 560, 820, 320),
	],
	"hazards": [
		Rect2(2140, 800, 150, 24),
		Rect2(4960, 800, 160, 24),
		Rect2(6900, 800, 150, 24),
	],
	"checkpoints": [
		Vector2(1660, 520),
		Vector2(3200, 520),
		Vector2(4860, 500),
		Vector2(6320, 500),
		Vector2(7530, 560),
	],
}

const ALL := [LEVEL_1, LEVEL_2, LEVEL_3]
