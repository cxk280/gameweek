extends SceneTree
const Backdrop := preload("res://scripts/Backdrop.gd")
## Composites a layered backdrop theme into a single 1280x720 frame for offline review (flattens
## the parallax layers at a chosen camera x). Lets a theme be verified without running the game.
##   godot --headless --path project --script res://tools/backdrop_preview.gd -- --theme=town --cam=0 --out=/abs/x.png

func _init() -> void:
	var theme := "city"
	var cam := 0.0
	var out := "res://preview.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--theme="):
			theme = a.split("=")[1]
		elif a.begins_with("--cam="):
			cam = float(a.split("=")[1])
		elif a.begins_with("--out="):
			out = a.split("=")[1]
	var horizon := 900.0
	var data := Backdrop.new().build(theme, 9600.0, 1280, 720)
	var frame := Image.create(1280, 720, false, Image.FORMAT_RGBA8)
	frame.blit_rect(data["sky"], Rect2i(0, 0, 1280, 720), Vector2i(0, 0))
	for ld in data["layers"]:
		var img: Image = ld["image"]
		var m: float = ld["motion"]
		var top: float = horizon - float(img.get_height()) if bool(ld.get("anchor_bottom", false)) else float(ld["top"])
		var src_x := int(cam * m)
		var w := mini(1280, img.get_width() - src_x)
		if w <= 0:
			continue
		frame.blend_rect(img, Rect2i(src_x, 0, w, img.get_height()), Vector2i(0, int(top)))
	print("preview %s @cam=%d: ok=%s -> %s" % [theme, int(cam), frame.save_png(out) == OK, out])
	quit()
