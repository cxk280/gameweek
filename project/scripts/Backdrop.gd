extends RefCounted
## Dispatcher for layered 2.5D stage backdrops. Each theme is a module under scripts/backdrops/
## that extends BackdropBase and implements `build(level_w, view_w, view_h) -> Dictionary`
## returning { "sky": Image, "layers": [ {image, motion, top, anchor_bottom} ... ] } (back->front).
## Themes are loaded dynamically so they can be added one module at a time; an unknown or
## not-yet-implemented theme falls back to the city.

const THEMES := {
	"city": "res://scripts/backdrops/City.gd",
	"town": "res://scripts/backdrops/Town.gd",
	"lake": "res://scripts/backdrops/Lake.gd",
	"terracotta": "res://scripts/backdrops/Terracotta.gd",
	"brick": "res://scripts/backdrops/Brick.gd",
	"tower": "res://scripts/backdrops/Tower.gd",
	"lunar": "res://scripts/backdrops/Lunar.gd",
	"highland": "res://scripts/backdrops/Highland.gd",
	"bay": "res://scripts/backdrops/Bay.gd",
	"library": "res://scripts/backdrops/Library.gd",
}


func build(theme: String, level_w: float, view_w: int, view_h: int) -> Dictionary:
	var path: String = THEMES.get(theme, THEMES["city"])
	var mod: Script = load(path) if ResourceLoader.exists(path) else null
	if mod == null:
		mod = load(THEMES["city"])
	return mod.new().build(level_w, view_w, view_h)
