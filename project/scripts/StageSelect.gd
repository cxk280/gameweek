extends CanvasLayer
## Free-run stage picker (also handy for debugging). Lists every course; click a row or press its
## number (1-9, 0 = stage 10) to jump there. Built in code and shown over the game; emits `chosen`
## with the level index. Toggle/closeable so it works as both the entry picker and an in-run menu.

signal chosen(index: int)

var _can_cancel := false


func _init(can_cancel := false) -> void:
	_can_cancel = can_cancel
	layer = 60


func _ready() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.05, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(640, 360)
	box.custom_minimum_size = Vector2(420, 0)
	box.add_theme_constant_override("separation", 6)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	dim.add_child(box)

	var title := Label.new()
	title.text = "SELECT STAGE"
	title.add_theme_font_size_override("font_size", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	for i in range(Levels.ALL.size()):
		var name: String = Levels.ALL[i].get("name", "Stage %d" % (i + 1))
		var b := Button.new()
		b.text = "%d.  %s" % [i + 1, name]
		b.add_theme_font_size_override("font_size", 20)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_pick.bind(i))
		box.add_child(b)

	var hint := Label.new()
	hint.text = "press 1-9 / 0 to jump" + ("    ·    ESC to close" if _can_cancel else "")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(1, 1, 1, 0.6)
	box.add_child(hint)


func _pick(index: int) -> void:
	chosen.emit(index)
	queue_free()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	var key: int = (event as InputEventKey).keycode
	if _can_cancel and key == KEY_ESCAPE:
		queue_free()
		get_viewport().set_input_as_handled()
		return
	var n := -1
	if key >= KEY_1 and key <= KEY_9:
		n = key - KEY_1
	elif key == KEY_0:
		n = 9
	if n >= 0 and n < Levels.ALL.size():
		get_viewport().set_input_as_handled()
		_pick(n)
