extends RefCounted
class_name CharacterArt
## Hand-authored neon-cyberpunk-runner pixel art. Grids are FFVI-idiom chibi sprites; the
## same grids feed the in-game sprite and the offline PNG preview. Palettes use Color8 so
## they live in static funcs (const can't call Color8). '.' = transparent.
##
## Roster grows here after the art direction is approved. Each char: idle / run(×N) / jump.

static func roster() -> Dictionary:
	return {"vex": _vex()}


static func ids() -> Array:
	return roster().keys()


static func get_char(id: String) -> Dictionary:
	var r := roster()
	return r[id] if r.has(id) else r[r.keys()[0]]


# ----------------------------------------------------------------------------- Vex · Courier
const _VEX_IDLE := [
	"......KKKK......",
	".....KHHHHK.....",
	"....KHHHHHHK....",
	"....KHHHHHHHK...",
	"....KhHHHHHHK...",
	"...KHFFFFFFHK...",
	"...KFFFFFFFFK...",
	"...KFVVVVVVFKe.",
	"...KFfFFFFFfK...",
	"....KFFFFFFK....",
	".....KKFFKK.....",
	"...KKJJJJJJKK...",
	"..KgJJTTTTJJgK..",
	"..KgJSjJJJjJgK..",
	"..KgJjSJJJjJgK..",
	"..KgJjJSJJjbbK..",
	"...KJjJJSjbbK...",
	"...KJJJJJJJJK...",
	"...KPPPPPPPPK...",
	"...KPPPKKPPPK...",
	"...KPPK..KPPK...",
	"...KPPK..KPPK...",
	"..KGGGK..KGGGK..",
	"..KLLLK..KLLLK..",
	"..KKKK....KKKK..",
]

const _VEX_RUN1 := [
	"......KKKK......",
	".....KHHHHK.....",
	"....KHHHHHHK....",
	"....KHHHHHHHK...",
	"....KhHHHHHHK...",
	"...KHFFFFFFHK...",
	"...KFFFFFFFFK...",
	"...KFVVVVVVFKe.",
	"...KFfFFFFFfK...",
	"....KFFFFFFK....",
	".....KKFFKK.....",
	"...KKJJJJJJKK...",
	".KgJJTTTTJJgK...",
	"..gJSjJJJjJgK...",
	"..KJjSJJJjJbbK..",
	"...KjJSJJjbbK...",
	"...KJjJJSjJK....",
	"...KJJJJJJJK....",
	"...KPPPPPPK.....",
	"..KPPKKPPPK.....",
	".KGGK..KPPPK....",
	".KLLK...KPPK....",
	"..KK....KGGGK...",
	"........KLLLK...",
	".........KKK...",
]

const _VEX_RUN2 := [
	"......KKKK......",
	".....KHHHHK.....",
	"....KHHHHHHK....",
	"....KHHHHHHHK...",
	"....KhHHHHHHK...",
	"...KHFFFFFFHK...",
	"...KFFFFFFFFK...",
	"...KFVVVVVVFKe.",
	"...KFfFFFFFfK...",
	"....KFFFFFFK....",
	".....KKFFKK.....",
	"...KKJJJJJJKK...",
	"...KgJJTTTTJJgK.",
	"...KgJSjJJJjJg..",
	"..KbbJjSJJJjJK..",
	"...KbbjSJJjJK...",
	"....KJjSJJjJK...",
	"....KJJJJJJJK...",
	".....KPPPPPPK...",
	".....KPPPKKPPK..",
	"....KPPPK..KGGK.",
	"....KPPK...KLLK.",
	"...KGGGK....KK..",
	"...KLLLK.......",
	"....KKK........",
]

const _VEX_JUMP := [
	"...W..KKKK..W...",
	"...W.KHHHHK.W...",
	"..KKKHHHHHHKKK..",
	".KgK KHHHHHHK Kg",
	".g.KKhHHHHHHK.g.",
	"...KHFFFFFFHK...",
	"...KFFFFFFFFK...",
	"...KFVVVVVVFKe.",
	"...KFfFFFFFfK...",
	"....KFFFFFFK....",
	".....KKFFKK.....",
	"...KKJJJJJJKK...",
	"..KJJTTTTTTJJK..",
	"..KJSjJJJJjbbK..",
	"..KJjSJJJjJbbK..",
	"...KJjJSJjJJK...",
	"...KJJJJJJJK....",
	"...KPPPPPPK....",
	"..KPPKKPPPK....",
	"..KGGK.KGGK....",
	"..KLLK.KLLK....",
	"...KK...KK.....",
	"...............",
	"...............",
	"...............",
]


static func _vex() -> Dictionary:
	var pal := {
		"K": Color8(18, 16, 26),     # outline
		"H": Color8(42, 46, 70),     # hair
		"h": Color8(255, 70, 150),   # neon hair streak
		"F": Color8(236, 184, 150),  # skin
		"f": Color8(198, 142, 112),  # skin shade
		"V": Color8(70, 240, 255),   # visor (cyan glow)
		"e": Color8(255, 70, 150),   # earpiece
		"J": Color8(54, 52, 96),     # jacket
		"j": Color8(36, 34, 70),     # jacket shade
		"T": Color8(255, 70, 150),   # collar trim (magenta)
		"S": Color8(70, 240, 255),   # crossbody strap (cyan glow)
		"b": Color8(40, 38, 68),     # bag
		"g": Color8(70, 74, 100),    # gloves
		"G": Color8(70, 74, 100),    # boots
		"L": Color8(70, 240, 255),   # boot soles (neon)
		"P": Color8(30, 32, 48),     # pants
		"W": Color8(240, 250, 255),  # highlight
	}
	return {
		"name": "Vex",
		"subtitle": "Courier",
		"accent": Color8(70, 240, 255),
		"palette": pal,
		"frames": {
			"idle": [_VEX_IDLE],
			"run": [_VEX_RUN1, _VEX_IDLE, _VEX_RUN2, _VEX_IDLE],
			"jump": [_VEX_JUMP],
		},
	}
