extends Node
class_name Levels
## Data-driven level definitions. Level.gd builds geometry, props, hazards, checkpoints and
## finish from these dicts; each carries a "backdrop" theme key that Main feeds to the layered
## 2.5D backdrop system. Platforms are Rect2(x, y, w, h) with y = top surface; coordinates grow
## right/down. Keep gaps <= ~200px and up-steps <= ~100px so the jump (≈120px height, ≈270px air
## distance) clears them — the generator below enforces this so every course is completable.
##
## Stage 1 is the hand-tuned reference course. Stages 2-10 are generated with per-theme profiles
## (varied base height, height variation, gap/width ranges, and net rise) so each plays and looks
## distinct. All courses run left->right (the spire course also climbs) so the autopilot/racebot
## and multiplayer racing work on every stage.

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


# ----------------------------------------------------------------- generated courses
static func _hh(n: int) -> float:
	var x := (n * 1103515245 + 12345) & 0x7fffffff
	x = (x ^ (x >> 13)) * 1274126177 & 0x7fffffff
	return float(x % 10000) / 10000.0


## Build a playable left->right course. `rise` lifts the whole course over its length (a climb).
## Constraints (gap<=gap_max<=200, up-step<=100) guarantee the jump clears every transition.
static func _course(name: String, backdrop: String, seed: int, length: float, base_y: float, amp: float, gap_min: float, gap_max: float, w_min: float, w_max: float, rise: float, haz_n: int) -> Dictionary:
	var H := 340.0
	var platforms: Array = []
	var hazards: Array = []
	var checkpoints: Array = []
	var start_w := 540.0
	platforms.append(Rect2(0.0, base_y, start_w, H))
	var prev_top := base_y
	var x := start_w
	var i := 0
	while x < length - 1100.0:
		var t := x / length
		var local_base := base_y - rise * t
		var gap := gap_min + _hh(seed * 101 + i * 7) * (gap_max - gap_min)
		x += gap
		var w := w_min + _hh(seed * 131 + i * 5) * (w_max - w_min)
		var target := local_base - amp * 0.5 + amp * _hh(seed * 167 + i * 3)
		if prev_top - target > 100.0:
			target = prev_top - 100.0          # cap up-step to a clearable height
		if target - prev_top > 300.0:
			target = prev_top + 300.0          # cap drop so the next ledge stays in reach
		target = clampf(target, 360.0, 700.0)
		platforms.append(Rect2(x, target, w, H))
		if hazards.size() < haz_n and _hh(seed * 199 + i) > 0.74 and gap > 110.0:
			hazards.append(Rect2(x - gap * 0.5 - 60.0, 800.0, 120.0, 24.0))
		prev_top = target
		x += w
		i += 1
	x += gap_min
	var finish_top := clampf(base_y - rise, 360.0, 700.0)
	platforms.append(Rect2(x, finish_top, 860.0, H))
	var total := x + 860.0
	var n := platforms.size()
	for k in range(1, 6):
		var r: Rect2 = platforms[int(float(n) * float(k) / 6.0)]
		checkpoints.append(Vector2(r.position.x + r.size.x * 0.5, r.position.y))
	return {
		"name": name,
		"backdrop": backdrop,
		"start": Vector2(120, base_y - 40.0),
		"finish": Vector2(x + 120.0, finish_top),
		"bounds": Rect2(-200, 0, total + 1000.0, 900),
		"platforms": platforms,
		"hazards": hazards,
		"checkpoints": checkpoints,
	}


# Stage order 1-10, each a distinct theme + play profile. Names are original/fantasy.
static var ALL: Array = [
	LEVEL_1,                                                                                            # 1 neon city
	_course("Lantern Quarter",   "town",       2, 8200.0, 560.0, 130.0,  90.0, 180.0, 200.0, 440.0,   0.0, 3),  # 2
	_course("Stilt Harbor",      "lake",       3, 8600.0, 540.0, 110.0, 120.0, 200.0, 180.0, 420.0,   0.0, 4),  # 3
	_course("Terracotta Heights","terracotta", 4, 8800.0, 520.0, 170.0,  90.0, 180.0, 200.0, 460.0,   0.0, 3),  # 4
	_course("Foundry Flats",     "brick",      5, 8000.0, 560.0,  90.0, 100.0, 190.0, 220.0, 480.0,   0.0, 4),  # 5
	_course("The Obsidian Spire","tower",      6, 8400.0, 640.0, 120.0, 100.0, 180.0, 200.0, 420.0, 250.0, 3),  # 6 climbs
	_course("Selene Outpost",    "lunar",      7, 8600.0, 540.0, 150.0, 120.0, 200.0, 180.0, 420.0,   0.0, 3),  # 7
	_course("Highland Bastion",  "highland",   8, 8800.0, 520.0, 160.0,  90.0, 180.0, 200.0, 460.0,   0.0, 3),  # 8
	_course("Cabana Bay",        "bay",        9, 8400.0, 560.0, 100.0, 110.0, 195.0, 200.0, 460.0,   0.0, 4),  # 9
	_course("The Grand Athenaeum","library",  10, 8200.0, 540.0, 120.0,  90.0, 175.0, 200.0, 440.0,   0.0, 3),  # 10 interior
]
