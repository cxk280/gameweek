extends RefCounted
class_name CharacterArt
## Hand-authored neon-cyberpunk-runner pixel art (FFVI-idiom chibi). All runners share the
## proven body/run/jump geometry (BODY_*) and get a unique head + palette, giving distinct
## silhouettes (spiky-visor / hood / chrome-antenna / topknot-mask / helmet-scarf) without
## re-deriving the body each time. The same grids feed the in-game sprite and the offline
## PNG preview (tools/render_preview.gd). '.' / unknown char = transparent.

static func roster() -> Dictionary:
	return {
		"vex": _char("Vex", "Courier", Color8(70, 240, 255), HEAD_VEX, {
			"H": Color8(42, 46, 70), "h": Color8(255, 70, 150),
			"V": Color8(70, 240, 255), "e": Color8(255, 70, 150),
		}),
		"glitch": _char("Glitch", "Netrunner", Color8(120, 255, 130), HEAD_GLITCH, {
			"C": Color8(30, 50, 58), "c": Color8(20, 36, 42), "o": Color8(120, 255, 130),
			"J": Color8(32, 52, 58), "j": Color8(20, 36, 42),
			"T": Color8(120, 255, 130), "S": Color8(120, 255, 130), "L": Color8(120, 255, 130),
		}),
		"echo": _char("Echo", "Android", Color8(255, 185, 70), HEAD_ECHO, {
			"M": Color8(158, 168, 188), "m": Color8(98, 106, 128),
			"A": Color8(120, 128, 150), "E": Color8(255, 185, 70),
			"J": Color8(92, 102, 126), "j": Color8(60, 68, 88),
			"T": Color8(255, 185, 70), "S": Color8(255, 185, 70), "L": Color8(255, 185, 70),
			"g": Color8(120, 128, 150), "G": Color8(120, 128, 150),
		}),
		"kira": _char("Kira", "Street Samurai", Color8(240, 70, 80), HEAD_KIRA, {
			"H": Color8(22, 20, 30), "d": Color8(240, 70, 80), "M": Color8(210, 56, 64),
			"E": Color8(255, 90, 90),
			"J": Color8(58, 30, 40), "j": Color8(40, 20, 28),
			"T": Color8(240, 70, 80), "S": Color8(240, 70, 80), "L": Color8(240, 70, 80),
		}),
		"pax": _char("Pax", "Drone Rider", Color8(255, 160, 70), HEAD_PAX, {
			"O": Color8(240, 140, 60), "o": Color8(120, 220, 255), "s": Color8(232, 92, 52),
			"J": Color8(78, 58, 50), "j": Color8(52, 38, 34),
			"T": Color8(255, 160, 70), "S": Color8(255, 160, 70), "L": Color8(255, 160, 70),
		}),
	}


static func ids() -> Array:
	return roster().keys()


static func get_char(id: String) -> Dictionary:
	var r := roster()
	return r[id] if r.has(id) else r[r.keys()[0]]


# ----------------------------------------------------------------- Shared body (rows 11-24)
const BODY_IDLE := [
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

const BODY_RUN1 := [
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
	".........KKK....",
]

const BODY_RUN2 := [
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
	"...KLLLK........",
	"....KKK.........",
]

const BODY_JUMP := [
	"...KKJJJJJJKK...",
	"..KJJTTTTTTJJK..",
	"..KJSjJJJJjbbK..",
	"..KJjSJJJjJbbK..",
	"...KJjJSJjJJK...",
	"...KJJJJJJJK....",
	"...KPPPPPPK.....",
	"..KPPKKPPPK.....",
	"..KGGK.KGGK.....",
	"..KLLK.KLLK.....",
	"...KK...KK......",
	"...............",
	"...............",
	"...............",
]


# ------------------------------------------------------------------------- Heads (rows 0-10)
const HEAD_VEX := [
	"......KKKK......",
	".....KHHHHK.....",
	"....KHHHHHHK....",
	"....KHHHHHHHK...",
	"....KhHHHHHHK...",
	"...KHFFFFFFHK...",
	"...KFFFFFFFFK...",
	"...KFVVVVVVFKe..",
	"...KFfFFFFFfK...",
	"....KFFFFFFK....",
	".....KKFFKK.....",
]

const HEAD_GLITCH := [
	"....KKKKKKK.....",
	"...KCCCCCCCK....",
	"..KCCCCCCCCCK...",
	"..KCCCCCCCCCK...",
	"..KCcFFFFFcCK...",
	"..KCFFFFFFFCK...",
	"..KCFoooooFCK...",
	"..KCFoooooFCK...",
	"...KCFFFFFCK....",
	"....KcFFcK.....",
	".....KKFKK.....",
]

const HEAD_ECHO := [
	".......KAK.....",
	".......KAK.....",
	"....KKMMMMKK...",
	"...KMMMMMMMMK..",
	"..KMMMmmmMMMK..",
	"..KMMEEEEEMMK..",
	"..KMMmEEEmMMK..",
	"..KMMMMMMMMMK..",
	"...KMMMMMMMK...",
	"....KMMMMMK....",
	".....KKMKK.....",
]

const HEAD_KIRA := [
	"......KdK......",
	".....KdddK.....",
	"....KHHHHHK....",
	"...KHHHHHHHK...",
	"..KHHHHHHHHHK..",
	"..KHFFFFFFFHK..",
	"..KHFEEFEEFHK..",
	"..KKMMMMMMMKK..",
	"...KMMMMMMMK...",
	"....KMMMMMK....",
	".....KKMKK.....",
]

const HEAD_PAX := [
	"....KKKKKK.....",
	"...KOOOOOOK....",
	"..KOOOOOOOOK...",
	"..KOOOOOOOOK...",
	"..KOoooooooK...",
	"..KOoooooooK...",
	"..KOFFFFFFK....",
	"...KFFFFFFK....",
	"..KssssssssK...",
	"..KsssssssssK..",
	"...KKsssKK.....",
]


static func _base_palette() -> Dictionary:
	return {
		"K": Color8(18, 16, 26),     # outline
		"F": Color8(236, 184, 150),  # skin
		"f": Color8(198, 142, 112),  # skin shade
		"J": Color8(54, 52, 96),     # jacket
		"j": Color8(36, 34, 70),     # jacket shade
		"T": Color8(255, 70, 150),   # collar trim
		"S": Color8(70, 240, 255),   # crossbody strap
		"b": Color8(40, 38, 68),     # bag
		"g": Color8(70, 74, 100),    # gloves
		"G": Color8(70, 74, 100),    # boots
		"L": Color8(70, 240, 255),   # boot soles (neon)
		"P": Color8(30, 32, 48),     # pants
		"W": Color8(240, 250, 255),  # highlight
	}


static func _char(nm: String, sub: String, accent: Color, head: Array, extra: Dictionary) -> Dictionary:
	var pal := _base_palette()
	for k in extra:
		pal[k] = extra[k]
	return {
		"name": nm,
		"subtitle": sub,
		"accent": accent,
		"palette": pal,
		"frames": {
			"idle": [head + BODY_IDLE],
			"run": [head + BODY_RUN1, head + BODY_IDLE, head + BODY_RUN2, head + BODY_IDLE],
			"jump": [head + BODY_JUMP],
		},
	}
