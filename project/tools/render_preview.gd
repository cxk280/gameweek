extends SceneTree
## Offline art preview: renders every character frame to a single scaled PNG so the art can
## be inspected without the game running.
##   godot --headless --path project --script res://tools/render_preview.gd
## Output: project/art_preview.png

func _init() -> void:
	var scale := 12
	var pad := 8
	var bg := Color8(20, 18, 30)

	var only_idle := not OS.get_cmdline_user_args().has("--all")
	var imgs: Array = []
	var roster := CharacterArt.roster()
	for id in roster:
		var cd: Dictionary = roster[id]
		if only_idle:
			# Roster lineup: idle + run1 + jump per character.
			imgs.append(SpriteFactory.make_image(cd["frames"]["idle"][0], cd["palette"]))
			imgs.append(SpriteFactory.make_image(cd["frames"]["run"][0], cd["palette"]))
			imgs.append(SpriteFactory.make_image(cd["frames"]["jump"][0], cd["palette"]))
		else:
			for anim in cd["frames"]:
				for grid in cd["frames"][anim]:
					imgs.append(SpriteFactory.make_image(grid, cd["palette"]))

	var maxh := 1
	var total_w := pad
	for img: Image in imgs:
		maxh = maxi(maxh, img.get_height())
		total_w += img.get_width() + pad

	var sheet := Image.create(total_w * scale, (maxh + 2 * pad) * scale, false, Image.FORMAT_RGBA8)
	sheet.fill(bg)

	var x := pad
	for img: Image in imgs:
		var w := img.get_width()
		var h := img.get_height()
		var scaled := img.duplicate() as Image
		scaled.resize(w * scale, h * scale, Image.INTERPOLATE_NEAREST)
		var y := pad + (maxh - h)  # bottom-align so feet line up
		sheet.blend_rect(scaled, Rect2i(0, 0, w * scale, h * scale), Vector2i(x * scale, y * scale))
		x += w + pad

	var err := sheet.save_png("res://art_preview.png")
	print("preview saved: %s (%dx%d)" % [err == OK, sheet.get_width(), sheet.get_height()])
	quit()
