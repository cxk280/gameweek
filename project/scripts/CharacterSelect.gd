extends CanvasLayer
class_name CharacterSelect
## Roster-driven character picker shown before the race. Renders each character's idle
## sprite live (via SpriteFactory) so the screen always matches the in-game art. Emits the
## chosen id and hides itself. Scales automatically as the roster grows.

signal chosen(char_id: String)

const PREVIEW_SCALE := 5


func _ready() -> void:
	layer = 50
	_build()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.07, 0.92)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	add_child(dim)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	add_child(center)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	center.add_child(col)

	var game_title := Label.new()
	game_title.text = "ROOFTOP RUSH"
	game_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_title.add_theme_font_size_override("font_size", 64)
	game_title.add_theme_color_override("font_color", Color(1.0, 0.15, 0.7))
	col.add_child(game_title)

	var tagline := Label.new()
	tagline.text = "a real-time multiplayer rooftop race"
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.add_theme_color_override("font_color", Color(0.0, 0.95, 1.0))
	col.add_child(tagline)

	var title := Label.new()
	title.text = "▾  SELECT YOUR RUNNER  ▾"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.7, 0.72, 0.85))
	col.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)

	for id in CharacterArt.ids():
		row.add_child(_make_card(id))

	var hint := Label.new()
	hint.text = "Arrow keys / A-D move · Space jump · Shift dash"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.7, 0.72, 0.85))
	col.add_child(hint)


func _make_card(id: String) -> Control:
	var cd := CharacterArt.get_char(id)
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 6)

	var idle_grid: Array = cd["frames"]["idle"][0]
	var tex := SpriteFactory.make_texture(idle_grid, cd["palette"])
	var tr := TextureRect.new()
	tr.texture = tex
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(tex.get_width() * PREVIEW_SCALE, tex.get_height() * PREVIEW_SCALE)
	card.add_child(tr)

	var btn := Button.new()
	btn.text = "%s · %s" % [cd.get("name", id), cd.get("subtitle", "")]
	btn.pressed.connect(_on_pick.bind(id))
	card.add_child(btn)
	return card


func _on_pick(id: String) -> void:
	chosen.emit(id)
	queue_free()
