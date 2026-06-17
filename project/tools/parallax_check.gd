extends SceneTree
const Backdrop := preload("res://scripts/Backdrop.gd")
## Verifies the 2.5D backdrop: composites Backdrop layers at two camera positions so the parallax
## can be inspected offline (each layer shifts by camera_x * motion_scale). Saves two 1280x720
## frames; comparing them shows the moon/sky barely moving while nearer building rows shift more.
##   godot --headless --path project --script res://tools/parallax_check.gd -- --out=/abs/dir

func _init() -> void:
	var out_dir := "res://"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.split("=")[1]
	var horizon := 900.0
	var data := Backdrop.new().build("city", 9600.0, 1280, 720)
	for shot in [{"cam": 0.0, "name": "a"}, {"cam": 2200.0, "name": "b"}]:
		var cam: float = shot["cam"]
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
		var path := "%s/parallax_%s.png" % [out_dir, shot["name"]]
		print("parallax frame %s: ok=%s -> %s" % [shot["name"], frame.save_png(path) == OK, path])
	quit()
