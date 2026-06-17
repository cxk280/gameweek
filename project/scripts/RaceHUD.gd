extends CanvasLayer
class_name RaceHUD
## Client race UI: lobby (player list + ready), synced countdown, live standings, and the
## results screen. Driven by Main from Net's race_event; emits ready_pressed back out.

signal ready_pressed(is_ready: bool)
signal practice_requested

const CYAN := Color(0.2, 0.95, 1.0)
const GOLD := Color(1.0, 0.85, 0.2)
const DIM := Color(0.7, 0.72, 0.85)
const GREEN := Color(0.45, 1.0, 0.55)

var _is_ready := false

var _lobby: Control
var _lobby_course: Label
var _lobby_presence: Label
var _lobby_waiting: Label
var _lobby_list: VBoxContainer
var _lobby_board: VBoxContainer
var _ready_btn: Button
var _invite_btn: Button
var _countdown: Label
var _standings: VBoxContainer
var _results: Control
var _results_list: VBoxContainer
var _toast: Label


func _ready() -> void:
	layer = 40
	_build_lobby()
	_build_countdown()
	_build_standings()
	_build_results()
	_build_toast()
	hide_all()


func hide_all() -> void:
	_lobby.visible = false
	_countdown.visible = false
	_standings.visible = false
	_results.visible = false
	_toast.visible = false


# ------------------------------------------------------------------------ public, from Main

func show_lobby(payload: Dictionary, my_id: int) -> void:
	hide_all()
	_lobby.visible = true
	_lobby_course.text = "NEXT COURSE:  %s" % payload.get("level_name", "—")
	var wins: Dictionary = payload.get("wins", {})
	for c in _lobby_list.get_children():
		c.queue_free()
	var names: Dictionary = payload.get("names", {})
	var readies: Dictionary = payload.get("readies", {})
	var n_players := names.size()
	var n_ready := 0
	for id in names:
		if readies.get(id, false):
			n_ready += 1
		var is_r: bool = readies.get(id, false)
		var row := Label.new()
		var you := "  (you)" if int(id) == my_id else ""
		var nm := str(names[id])
		var wn := int(wins.get(nm, 0))
		var badge := "   (%d wins)" % wn if wn > 0 else ""
		row.text = "   %s%s%s%s" % [nm, you, badge, "      READY" if is_r else "      not ready"]
		row.add_theme_font_size_override("font_size", 20)
		row.add_theme_color_override("font_color", GREEN if is_r else DIM)
		_lobby_list.add_child(row)
	# Presence line — the player should always know how many real humans are here.
	if n_players <= 1:
		_lobby_presence.text = "You're the only one here — invite a friend, or ready up for a solo time trial."
		_lobby_presence.add_theme_color_override("font_color", GOLD)
	else:
		_lobby_presence.text = "%d racers in the lobby   ·   %d/%d ready" % [n_players, n_ready, n_players]
		_lobby_presence.add_theme_color_override("font_color", GREEN)
	# Mid-race joiners wait here for the next race rather than being dropped into a running one.
	_lobby_waiting.visible = bool(payload.get("race_in_progress", false))
	_is_ready = bool(readies.get(my_id, false))
	_ready_btn.text = "READY — waiting for others" if _is_ready else "READY UP"
	_ready_btn.add_theme_color_override("font_color", GREEN if _is_ready else GOLD)
	for c in _lobby_board.get_children():
		c.queue_free()
	_fill_board(_lobby_board, payload.get("board", []))


func _fill_board(target: VBoxContainer, b: Array) -> void:
	var head := Label.new()
	head.text = "— BEST TIMES —"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_color_override("font_color", CYAN)
	target.add_child(head)
	if b.is_empty():
		var none := Label.new()
		none.text = "no times yet — set one!"
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		none.add_theme_color_override("font_color", DIM)
		target.add_child(none)
		return
	var place := 0
	for e in b:
		place += 1
		if place > 5:
			break
		var row := Label.new()
		row.text = "%d. %s   %s" % [place, e["name"], _fmt(int(e["ms"]))]
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_theme_color_override("font_color", DIM)
		target.add_child(row)


func show_countdown(n: int) -> void:
	hide_all()
	_countdown.visible = true
	_countdown.text = "GO!" if n <= 0 else str(n)


func start_racing() -> void:
	hide_all()
	_standings.visible = true
	for c in _standings.get_children():
		c.queue_free()


func update_standings(order: Array, my_id: int) -> int:
	_standings.visible = true
	for c in _standings.get_children():
		c.queue_free()
	var title := Label.new()
	title.text = "FINISHED"
	title.add_theme_color_override("font_color", CYAN)
	_standings.add_child(title)
	var my_place := 0
	var place := 0
	for f in order:
		place += 1
		var row := Label.new()
		row.text = "%d. %s  %s" % [place, f["name"], _fmt(int(f["ms"]))]
		row.add_theme_color_override("font_color", GOLD if int(f["id"]) == my_id else DIM)
		_standings.add_child(row)
		if int(f["id"]) == my_id:
			my_place = place
	return my_place


func show_results(payload: Dictionary, my_id: int) -> void:
	hide_all()
	_results.visible = true
	var order: Array = payload.get("order", [])
	for c in _results_list.get_children():
		c.queue_free()
	var head := Label.new()
	head.text = payload.get("level_name", "RESULTS")
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_color_override("font_color", GOLD)
	_results_list.add_child(head)
	var place := 0
	for f in order:
		place += 1
		var row := Label.new()
		var medal: String = ["🥇", "🥈", "🥉"][place - 1] if place <= 3 else "  "
		row.text = "%s  %d. %s   %s" % [medal, place, f["name"], _fmt(int(f["ms"]))]
		row.add_theme_font_size_override("font_size", 22)
		row.add_theme_color_override("font_color", GOLD if int(f["id"]) == my_id else Color.WHITE)
		_results_list.add_child(row)
	if order.is_empty():
		var none := Label.new()
		none.text = "No finishers"
		none.add_theme_color_override("font_color", DIM)
		_results_list.add_child(none)
	var spacer := Label.new()
	spacer.text = " "
	_results_list.add_child(spacer)
	_fill_board(_results_list, payload.get("board", []))


func toast(text: String, color: Color) -> void:
	_toast.visible = true
	_toast.text = text
	_toast.add_theme_color_override("font_color", color)


# ------------------------------------------------------------------------------ build helpers

func _build_lobby() -> void:
	_lobby = _dim_panel()
	add_child(_lobby)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	_center(_lobby, box)
	_title(box, "ONLINE LOBBY")

	_lobby_presence = Label.new()
	_lobby_presence.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lobby_presence.add_theme_font_size_override("font_size", 18)
	box.add_child(_lobby_presence)

	_lobby_course = Label.new()
	_lobby_course.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lobby_course.add_theme_font_size_override("font_size", 18)
	_lobby_course.add_theme_color_override("font_color", GOLD)
	box.add_child(_lobby_course)

	_lobby_list = VBoxContainer.new()
	_lobby_list.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(_lobby_list)

	_lobby_waiting = Label.new()
	_lobby_waiting.text = "A race is underway — ready up and you'll start the next one."
	_lobby_waiting.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lobby_waiting.add_theme_color_override("font_color", GOLD)
	_lobby_waiting.visible = false
	box.add_child(_lobby_waiting)

	_ready_btn = Button.new()
	_ready_btn.text = "READY UP"
	_ready_btn.custom_minimum_size = Vector2(300, 56)
	_ready_btn.add_theme_font_size_override("font_size", 24)
	_ready_btn.add_theme_color_override("font_color", GOLD)
	_ready_btn.pressed.connect(_on_ready)
	box.add_child(_ready_btn)

	var hint := Label.new()
	hint.text = "The race begins the moment everyone is READY."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", DIM)
	box.add_child(hint)

	_invite_btn = Button.new()
	_invite_btn.text = "Invite a friend  —  copy race link"
	_invite_btn.custom_minimum_size = Vector2(300, 40)
	_invite_btn.add_theme_color_override("font_color", CYAN)
	_invite_btn.pressed.connect(_on_invite)
	box.add_child(_invite_btn)

	var practice := Button.new()
	practice.text = "Practice solo instead"
	practice.flat = true
	practice.add_theme_color_override("font_color", DIM)
	practice.pressed.connect(func() -> void: practice_requested.emit())
	box.add_child(practice)

	_lobby_board = VBoxContainer.new()
	box.add_child(_lobby_board)


func _on_invite() -> void:
	# Copy the page URL so opening it in another window / sending it to a friend joins the
	# same server. The whole "how do I play with someone" question answered in one click.
	var ok := false
	if OS.has_feature("web"):
		JavaScriptBridge.eval("navigator.clipboard && navigator.clipboard.writeText(window.location.href)", true)
		ok = true
	else:
		DisplayServer.clipboard_set("https://rooftop-web-production.up.railway.app/")
		ok = true
	_invite_btn.text = "Link copied! Open it in another browser window" if ok else "Copy failed — copy the page URL"
	_invite_btn.add_theme_color_override("font_color", GREEN if ok else GOLD)


func _build_countdown() -> void:
	_countdown = Label.new()
	_countdown.anchor_right = 1.0
	_countdown.anchor_bottom = 1.0
	_countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_countdown.add_theme_font_size_override("font_size", 140)
	_countdown.add_theme_color_override("font_color", CYAN)
	add_child(_countdown)


func _build_standings() -> void:
	_standings = VBoxContainer.new()
	_standings.position = Vector2(1040, 70)
	add_child(_standings)


func _build_results() -> void:
	_results = _dim_panel()
	add_child(_results)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_center(_results, box)
	_title(box, "RESULTS")
	_results_list = VBoxContainer.new()
	box.add_child(_results_list)
	var foot := Label.new()
	foot.text = "Next race starting soon..."
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.add_theme_color_override("font_color", DIM)
	box.add_child(foot)


func _build_toast() -> void:
	_toast = Label.new()
	_toast.anchor_right = 1.0
	_toast.offset_top = 110.0
	_toast.offset_bottom = 150.0
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 30)
	add_child(_toast)


func _dim_panel() -> Control:
	var c := ColorRect.new()
	c.color = Color(0.02, 0.02, 0.07, 0.86)
	c.anchor_right = 1.0
	c.anchor_bottom = 1.0
	return c


func _center(parent: Control, child: Control) -> void:
	var cc := CenterContainer.new()
	cc.anchor_right = 1.0
	cc.anchor_bottom = 1.0
	parent.add_child(cc)
	cc.add_child(child)


func _title(box: VBoxContainer, text: String) -> void:
	var t := Label.new()
	t.text = text
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 40)
	t.add_theme_color_override("font_color", CYAN)
	box.add_child(t)


func _on_ready() -> void:
	_is_ready = not _is_ready
	_ready_btn.text = "CANCEL" if _is_ready else "READY UP"
	ready_pressed.emit(_is_ready)


func _fmt(ms: int) -> String:
	return "%d:%02d.%03d" % [ms / 60000, (ms / 1000) % 60, ms % 1000]
