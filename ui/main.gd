extends Control
## The prototype screen: today's three puzzles (or practice), the board, the counters and the buttons.
## Progress of each day is saved as the attempt records (user://progress.json), so a reload continues where you were.
## Debug (screenshots, nothing saved): -- --shot=<png> [--date=YYYY-MM-DD] [--practice] [--level=N] [--keys=DRzr] [--lang=en] [--best]

const SAVE := "user://progress.json"
const BG := Color("1B1F26")
const TEXT := Color("E6E9EF")
const DIM := Color("8A94A6")
const ACCENT := Color("FFFFFF")

var date := ""
var practice := false
var practice_index := 0
var level := 0
var puzzles: Array = [] ## the three puzzles on screen: {board, par, solutions, path}
var attempts: Array = [] ## ShiftAttempt per level
var times: Array = [0, 0, 0] ## ms spent per level before the current run of the clock
var _clock_from := -1 ## ticks when the clock started on the current level, -1 = stopped
var _replaying := false
var _save := {"lang": "nl", "days": {}}
var _debug := {}

var view: BoardView
var title: Label
var subtitle: Label
var tabs: Array[Button] = []
var counter: Label
var par_label: Label
var clock_label: Label
var message: Label
var undo_btn: Button
var restart_btn: Button
var best_btn: Button
var share_btn: Button
var next_btn: Button
var mode_btn: Button
var lang_btn: Button


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		_debug[a.get_slice("=", 0).trim_prefix("--")] = a.get_slice("=", 1) if a.contains("=") else "1"
	if not _debug.has("shot"):
		_load_save()
	Strings.lang = str(_debug.get("lang", _save.get("lang", "nl")))
	_build()
	date = str(_debug.get("date", ShiftDaily.today()))
	practice_index = randi() % maxi(1, ShiftPuzzles.practice_count())
	if _debug.has("practice"):
		practice_index = 0
		_open_practice()
	else:
		_open_day()
	if _debug.has("shot"):
		_debug_shot()


func _debug_shot() -> void:
	if _debug.has("level"):
		_pick_level(int(_debug.level))
	for ch in str(_debug.get("keys", "")):
		match ch:
			"z":
				_on_undo()
			"r":
				_on_restart()
			_:
				_on_swipe(ShiftBoard.LETTERS.find(ch))
	if _debug.has("best"):
		_on_swipe_all_best()
	await get_tree().create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(str(_debug.shot))
	get_tree().quit()


## Debug: solve the current puzzle along its best route.
func _on_swipe_all_best() -> void:
	for dir in puzzles[level].path:
		_on_swipe(dir)


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	margin.add_child(col)

	var top := HBoxContainer.new()
	col.add_child(top)
	title = _label("WHITE SHIFT", 34, ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	mode_btn = _button("", _toggle_mode)
	top.add_child(mode_btn)
	lang_btn = _button("", _toggle_lang)
	top.add_child(lang_btn)

	subtitle = _label("", 22, DIM)
	col.add_child(subtitle)

	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 8)
	col.add_child(tab_row)
	for i in 3:
		var b := _button("", _pick_level.bind(i))
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_row.add_child(b)
		tabs.append(b)

	var info := HBoxContainer.new()
	col.add_child(info)
	counter = _label("", 26, TEXT)
	counter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(counter)
	par_label = _label("", 26, DIM)
	par_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	par_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_child(par_label)
	clock_label = _label("", 26, DIM)
	clock_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info.add_child(clock_label)

	view = BoardView.new()
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.custom_minimum_size = Vector2(0, 300)
	view.swiped.connect(_on_swipe)
	col.add_child(view)

	message = _label("", 20, DIM)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.custom_minimum_size = Vector2(0, 84)
	col.add_child(message)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	undo_btn = _button("", _on_undo)
	restart_btn = _button("", _on_restart)
	best_btn = _button("", _show_best)
	share_btn = _button("", _share)
	next_btn = _button("", _next)
	for b in [undo_btn, restart_btn, best_btn, share_btn, next_btn]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 64)
	b.add_theme_font_size_override("font_size", 22)
	for state in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
		var box := StyleBoxFlat.new()
		box.bg_color = {"normal": Color("2A303B"), "hover": Color("343B48"), "pressed": Color("4A5363"),
			"hover_pressed": Color("4A5363"), "disabled": Color("20252D")}[state]
		box.set_corner_radius_all(10)
		box.content_margin_left = 14
		box.content_margin_right = 14
		b.add_theme_stylebox_override(state, box)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_pressed_color", ACCENT)
	b.add_theme_color_override("font_disabled_color", Color("4A5363"))
	b.pressed.connect(action)
	return b


# --- puzzles -----------------------------------------------------------------------------------------------------

func _open_day() -> void:
	_stop_clock()
	practice = false
	puzzles = ShiftPuzzles.day(date)
	attempts = []
	times = [0, 0, 0]
	var saved: Array = _save.days.get(date, [])
	for i in puzzles.size():
		var rec: String = saved[i].record if i < saved.size() else ""
		attempts.append(ShiftAttempt.replay(puzzles[i].board, rec))
		times[i] = int(saved[i].time_ms) if i < saved.size() else 0
	level = 0
	for i in attempts.size():
		if not attempts[i].solved():
			level = i
			break
	_show_level()


func _open_practice() -> void:
	_stop_clock()
	practice = true
	puzzles = []
	attempts = []
	times = [0, 0, 0]
	for i in 3:
		puzzles.append(ShiftPuzzles.practice(practice_index, i))
		attempts.append(ShiftAttempt.new(puzzles[i].board))
	_show_level()


func _show_level() -> void:
	_replaying = false
	if puzzles.is_empty():
		view.board = null
		view.queue_redraw()
	else:
		var a: ShiftAttempt = attempts[level]
		view.show_board(a.board, a.state)
	_refresh()


func _refresh() -> void:
	subtitle.text = (Strings.t("practice") + " %d" % (practice_index + 1)) if practice else Strings.t("today") % ShiftDaily.number(date)
	mode_btn.text = Strings.t("daily") if practice else Strings.t("practice")
	lang_btn.text = Strings.t("lang")
	undo_btn.text = Strings.t("undo")
	restart_btn.text = Strings.t("restart")
	best_btn.text = Strings.t("show_best")
	share_btn.text = Strings.t("share")
	next_btn.text = Strings.t("next")
	var names: Array = Strings.t("levels")
	for i in 3:
		var done: bool = i < attempts.size() and attempts[i].solved()
		tabs[i].text = names[i] + (" · %d" % attempts[i].swipes if done else "")
		tabs[i].button_pressed = i == level
	if puzzles.is_empty():
		counter.text = ""
		par_label.text = ""
		clock_label.text = ""
		message.text = Strings.t("no_puzzle")
		for b in [undo_btn, restart_btn, best_btn, share_btn, next_btn]:
			b.visible = false
		return
	var a: ShiftAttempt = attempts[level]
	var p: Dictionary = puzzles[level]
	counter.text = Strings.t("swipes") % a.swipes
	par_label.text = Strings.t("par") % p.par
	clock_label.text = Strings.clock(_elapsed())
	var solved := a.solved()
	undo_btn.visible = not solved
	restart_btn.visible = not solved
	undo_btn.disabled = a.history.is_empty()
	restart_btn.disabled = a.history.is_empty()
	best_btn.visible = solved
	share_btn.visible = solved and not practice
	next_btn.visible = solved and (practice or level < 2)
	if solved:
		var line: String = Strings.t("solved") % [a.swipes, p.par, Strings.clock(_elapsed())]
		if a.swipes == p.par:
			line += "  " + Strings.t("perfect")
		message.text = line
	elif a.swipes == 0:
		message.text = Strings.t("hint") + "\n" + Strings.t("rule_more")
	else:
		message.text = ""


func _elapsed() -> int:
	var t: int = times[level]
	if _clock_from >= 0:
		t += Time.get_ticks_msec() - _clock_from
	return t


func _stop_clock() -> void:
	if _clock_from >= 0 and level < times.size():
		times[level] += Time.get_ticks_msec() - _clock_from
	_clock_from = -1


func _process(_delta: float) -> void:
	if _clock_from >= 0:
		clock_label.text = Strings.clock(_elapsed())


# --- input -------------------------------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_RIGHT, KEY_D:
			_on_swipe(ShiftBoard.Dir.RIGHT)
		KEY_LEFT, KEY_A:
			_on_swipe(ShiftBoard.Dir.LEFT)
		KEY_DOWN, KEY_S:
			_on_swipe(ShiftBoard.Dir.DOWN)
		KEY_UP, KEY_W:
			_on_swipe(ShiftBoard.Dir.UP)
		KEY_Z, KEY_BACKSPACE:
			_on_undo()
		KEY_R:
			_on_restart()
		_:
			return
	get_viewport().set_input_as_handled()


func _on_swipe(dir: int) -> void:
	if puzzles.is_empty() or _replaying:
		return
	var a: ShiftAttempt = attempts[level]
	if not a.swipe(dir):
		return
	if _clock_from < 0:
		_clock_from = Time.get_ticks_msec()
	view.set_state(a.state)
	if a.solved():
		_stop_clock()
	_store()
	_refresh()


func _on_undo() -> void:
	if _replaying or puzzles.is_empty():
		return
	var a: ShiftAttempt = attempts[level]
	if a.undo():
		view.set_state(a.state)
		_store()
		_refresh()


func _on_restart() -> void:
	if _replaying or puzzles.is_empty():
		return
	var a: ShiftAttempt = attempts[level]
	if a.restart():
		view.set_state(a.state)
		_store()
		_refresh()


func _pick_level(i: int) -> void:
	if i >= puzzles.size():
		_refresh()
		return
	_stop_clock()
	_store()
	level = i
	_show_level()


func _next() -> void:
	if practice and level == 2:
		practice_index += 1
		_open_practice()
		level = 0
		_show_level()
		return
	_pick_level(mini(level + 1, 2))


func _toggle_mode() -> void:
	if practice:
		_open_day()
	else:
		_stop_clock()
		_store()
		level = 0
		_open_practice()


func _toggle_lang() -> void:
	Strings.lang = "en" if Strings.lang == "nl" else "nl"
	_save.lang = Strings.lang
	if not _debug.has("shot"):
		_write_save()
	_refresh()


## Plays the shortest solution from the start; the attempt itself is not changed.
func _show_best() -> void:
	if _replaying:
		return
	_replaying = true
	var p: Dictionary = puzzles[level]
	var b: ShiftBoard = p.board
	var s := b.start
	view.show_board(b, s)
	await get_tree().create_timer(0.6).timeout
	for dir in p.path:
		if not _replaying:
			return
		s = b.swipe(s, dir)
		view.set_state(s)
		await get_tree().create_timer(0.55).timeout
	_replaying = false


func _share() -> void:
	var swipes := []
	var pars := []
	for i in puzzles.size():
		swipes.append(attempts[i].swipes if attempts[i].solved() else null)
		pars.append(puzzles[i].par)
	var line := Strings.share_line(ShiftDaily.number(date), swipes, pars)
	DisplayServer.clipboard_set(line)
	message.text = line + "\n" + Strings.t("copied")


# --- saving ------------------------------------------------------------------------------------------------------

func _store() -> void:
	if practice or _debug.has("shot"):
		return
	var list := []
	for i in attempts.size():
		var t: int = times[i]
		if i == level and _clock_from >= 0:
			t = _elapsed()
		list.append({"record": attempts[i].record, "time_ms": t, "solved": attempts[i].solved()})
	_save.days[date] = list
	_write_save()


func _load_save() -> void:
	if FileAccess.file_exists(SAVE):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
		if d is Dictionary and d.get("days") is Dictionary:
			_save = d


func _write_save() -> void:
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_save))
