extends WhiteDayScreen
## The White Shift screen: the shared day screen of White Kit with the swipe board, the best route and the texts.
## Progress of each day is saved as the attempt records (user://progress.json), so a reload continues where you were.
## Debug (screenshots, nothing saved): -- --shot=<png> [--date=YYYY-MM-DD] [--practice] [--level=N] [--keys=DRzr] [--lang=en] [--best]

var best_btn: Button


func _game_id() -> String:
	return "white-shift"


func _game_title() -> String:
	return "WHITE SHIFT"


func _first_day() -> String:
	return ShiftDaily.FIRST_DAY


func _texts() -> Dictionary:
	return Strings.TEXT


func _load_day(d: String) -> Array:
	return ShiftPuzzles.day(d)


func _load_practice(index: int) -> Array:
	var out := []
	for i in 3:
		out.append(ShiftPuzzles.practice(index, i))
	return out


func _practice_count() -> int:
	return ShiftPuzzles.practice_count()


func _new_attempt(puzzle: Dictionary, _count_mode: int) -> WhiteAttempt:
	return ShiftAttempt.new(puzzle.board)


func _make_view() -> Control:
	var v := BoardView.new()
	v.swiped.connect(_on_swipe)
	return v


func _view_show(a: WhiteAttempt) -> void:
	view.show_board((a as ShiftAttempt).board, a.state)


func _view_clear() -> void:
	view.board = null
	view.queue_redraw()


func _view_update(a: WhiteAttempt) -> void:
	view.set_state(a.state)


func _extra_buttons() -> Array[Button]:
	best_btn = WhiteUi.button("", _show_best)
	refreshed.connect(func() -> void: best_btn.text = Strings.t("show_best"))
	return [best_btn]


func _hint_text() -> String:
	return Strings.t("hint") + "\n" + Strings.t("rule_more")


func _key_move(event: InputEventKey) -> Variant:
	match event.keycode:
		KEY_RIGHT, KEY_D:
			return ShiftBoard.Dir.RIGHT
		KEY_LEFT, KEY_A:
			return ShiftBoard.Dir.LEFT
		KEY_DOWN, KEY_S:
			return ShiftBoard.Dir.DOWN
		KEY_UP, KEY_W:
			return ShiftBoard.Dir.UP
	return null


func _on_debug_extra() -> void:
	if _debug.has("best"):
		_on_swipe_all_best()


func _on_swipe(dir: int) -> void:
	_on_move(dir)


## Debug: solve the current puzzle along its best route.
func _on_swipe_all_best() -> void:
	for dir in puzzles[level].path:
		_on_swipe(dir)


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
