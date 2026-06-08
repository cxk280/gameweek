extends RefCounted
class_name SpriteFactory
## Turns hand-authored palette grids (arrays of strings) into pixel-art textures at runtime.
## Single source of truth for character art: the same grids drive the in-game AnimatedSprite2D
## and the offline PNG preview (tools/render_preview.gd), so what I inspect == what ships.
## '.' or any char not in the palette = transparent.


static func make_image(rows: Array, palette: Dictionary) -> Image:
	var h := rows.size()
	var w := 0
	for r in rows:
		w = maxi(w, (r as String).length())
	var img := Image.create(maxi(w, 1), maxi(h, 1), false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in h:
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			if palette.has(ch):
				img.set_pixel(x, y, palette[ch])
	return img


static func make_texture(rows: Array, palette: Dictionary) -> ImageTexture:
	return ImageTexture.create_from_image(make_image(rows, palette))


## Build a SpriteFrames resource for an AnimatedSprite2D from a character definition.
static func make_sprite_frames(char_def: Dictionary) -> SpriteFrames:
	var palette: Dictionary = char_def["palette"]
	var frames: Dictionary = char_def["frames"]
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for anim_name in frames:
		sf.add_animation(anim_name)
		sf.set_animation_loop(anim_name, anim_name != "jump")
		sf.set_animation_speed(anim_name, 10.0)
		for grid in frames[anim_name]:
			sf.add_frame(anim_name, make_texture(grid, palette))
	return sf
