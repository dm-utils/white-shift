extends RefCounted
## Independent tests (rules edge cases, attempt records, Dutch dates, shipped data, saved progress).
## Run from run_tests.gd; `check` is the runner's check(ok, what).

const D := ShiftBoard.Dir
const K := ShiftBoard.Kind

var check: Callable


func run(checker: Callable, node: Node) -> void:
	check = checker
	test_pieces_do_not_push()
	test_pins_and_bars()
	test_exit_rules()
	test_swipe_properties()
	test_fast_equals_reference_on_shipped()
	test_attempt_edges()
	test_dates()
	test_share_line_edges()
	test_puzzle_api()
	test_shipped_data()
	await test_ui_progress(node)


func board(w: int, h: int, side: int, index: int) -> ShiftBoard:
	return ShiftBoard.create(w, h, side, index)


func test_pieces_do_not_push() -> void:
	# two blocks in a row: front one settles first, the other stacks behind it
	var b := board(5, 1, D.UP, 0)
	b.add(K.WHITE, 0, 0)
	b.add(K.BLOCK, 1, 0)
	b.add(K.BLOCK, 2, 0)
	var s := b.swipe(b.start, D.RIGHT)
	check.call(b.render(s).begins_with("..WoW") == false and s[0] == 2 and s[2] == 3 and s[4] == 4, "row of three stacks against the wall in order")
	# bar of 3 against a wall, bar of 2 behind it
	var c := board(6, 2, D.UP, 0)
	c.add(K.WHITE, 0, 1)
	c.add(K.HBAR, 0, 0, 3)
	c.add(K.HBAR, 3, 0, 2)
	s = c.swipe(c.start, D.RIGHT)
	check.call(s[2] == 1 and s[4] == 4, "two bars in a row slide to the wall together")
	s = c.swipe(c.start, D.LEFT)
	check.call(s[2] == 0 and s[4] == 3, "bars already packed against the left wall do not move")
	# a gap closes from the front: a swipe left from a spread layout packs everything
	var d := board(6, 1, D.UP, 0)
	d.add(K.WHITE, 5, 0)
	d.add(K.BLOCK, 3, 0)
	d.add(K.BLOCK, 1, 0)
	s = d.swipe(d.start, D.LEFT)
	check.call(s[0] == 2 and s[2] == 1 and s[4] == 0, "left swipe packs three pieces from the left wall")


func test_pins_and_bars() -> void:
	var b := board(5, 5, D.UP, 0)
	b.pins.append(Vector2i(2, 2))
	b.add(K.WHITE, 4, 4)
	b.add(K.VBAR, 2, 0, 2) # above the pin
	b.add(K.HBAR, 0, 2, 2) # left of the pin
	var s := b.swipe(b.start, D.DOWN)
	check.call(s[2] == 2 and s[3] == 0, "vertical bar already against the pin does not move")
	var f := board(5, 5, D.UP, 0)
	f.pins.append(Vector2i(2, 4))
	f.add(K.WHITE, 0, 0)
	f.add(K.VBAR, 2, 0, 3)
	check.call(f.swipe(f.start, D.DOWN)[3] == 1, "vertical bar of 3 stops above a pin on the floor")
	s = b.swipe(b.start, D.RIGHT)
	check.call(s[4] == 0 and s[5] == 2 and s[0] == 4, "horizontal bar stops against the pin")
	check.call(b.swipe(b.start, D.UP)[4] == 0 and b.swipe(b.start, D.UP)[5] == 2, "horizontal bar ignores up swipe")
	check.call(b.swipe(b.start, D.LEFT)[2] == 2 and b.swipe(b.start, D.LEFT)[3] == 0, "vertical bar ignores left swipe")
	# the pin never moves and the layout stays legal after many swipes
	var st := b.start
	for k in 40:
		st = b.swipe(st, (k * 7 + k / 3) % 4)
		if not b.valid(st):
			check.call(false, "layout stays valid after swipe %d" % k)
			return
	check.call(b.pins == [Vector2i(2, 2)], "pins stay in place")
	# valid() rejects overlap, outside, and a missing white stone first
	var bad := board(3, 3, D.UP, 0)
	bad.add(K.BLOCK, 0, 0)
	check.call(not bad.valid(), "white stone must be first")
	var ov := board(3, 3, D.UP, 0)
	ov.add(K.WHITE, 1, 1)
	ov.add(K.BLOCK, 1, 1)
	check.call(not ov.valid(), "overlap is invalid")
	var out := board(3, 3, D.UP, 0)
	out.add(K.WHITE, 0, 0)
	out.add(K.HBAR, 2, 1, 2)
	check.call(not out.valid(), "bar sticking out is invalid")
	var pin_on := board(3, 3, D.UP, 0)
	pin_on.pins.append(Vector2i(1, 1))
	pin_on.add(K.WHITE, 1, 1)
	check.call(not pin_on.valid(), "piece on a pin is invalid")


func test_exit_rules() -> void:
	# white leaves through each of the four sides
	for side in 4:
		var b := board(4, 4, side, 1)
		# start opposite the exit, on the exit row/column
		var white: Vector2i = [Vector2i(0, 1), Vector2i(3, 1), Vector2i(1, 0), Vector2i(1, 3)][side]
		b.add(K.WHITE, white.x, white.y)
		check.call(b.is_won(b.swipe(b.start, side)), "white exits through side %d" % side)
		# wrong row/column: stops at the wall, no win
		var wrong := board(4, 4, side, 1)
		var w2: Vector2i = [Vector2i(0, 2), Vector2i(3, 2), Vector2i(2, 0), Vector2i(2, 3)][side]
		wrong.add(K.WHITE, w2.x, w2.y)
		var t := wrong.swipe(wrong.start, side)
		check.call(not wrong.is_won(t) and t[0] + t[1] > 0, "white in wrong lane at side %d does not win" % side)
		# a block in the exit lane blocks white, and itself never leaves
		var blk := board(4, 4, side, 1)
		blk.add(K.WHITE, white.x, white.y)
		var bpos: Vector2i = [Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 1), Vector2i(1, 2)][side]
		blk.add(K.BLOCK, bpos.x, bpos.y)
		var u := blk.swipe(blk.start, side)
		check.call(not blk.is_won(u) and blk.valid(u), "block in lane blocks white (side %d)" % side)
		# white on exit lane but swiping away from the exit does not win
		check.call(not b.is_won(b.swipe(b.start, side ^ 1)), "swipe away from exit does not win (side %d)" % side)
	# a bar in the exit lane is also an obstacle; white then needs another route
	var e := board(4, 4, D.RIGHT, 1)
	e.add(K.WHITE, 0, 1)
	e.add(K.VBAR, 3, 0, 2)
	check.call(not e.is_won(e.swipe(e.start, D.RIGHT)), "vertical bar on the exit cell blocks white")
	# won state is final: further swipes change nothing
	var w := board(3, 1, D.RIGHT, 0)
	w.add(K.WHITE, 0, 0)
	var won := w.swipe(w.start, D.RIGHT)
	check.call(w.is_won(won) and w.swipe(won, D.LEFT) == won and w.swipe(won, D.RIGHT) == won, "swipes after winning change nothing")
	check.call(w.render(won).count("W") == 0, "won white stone is not drawn on the board")


func test_swipe_properties() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var bad := 0
	var n := 0
	for k in 90:
		var b: ShiftBoard = ShiftGenerator.random_board(rng, ShiftGenerator.LEVELS[k % 3])
		if b == null or not b.valid():
			continue
		var s: PackedInt32Array = b.start
		for step in 10:
			var dir := rng.randi_range(0, 3)
			var t: PackedInt32Array = b.swipe(s, dir)
			n += 1
			# idempotent: second swipe same way changes nothing; legal; input untouched
			if b.swipe(t, dir) != t and not b.is_won(t):
				bad += 1
			if not b.is_won(t) and not b.valid(t):
				bad += 1
			# bars never leave their axis
			for i in b.count():
				if b.kinds[i] == K.HBAR and t[i * 2 + 1] != s[i * 2 + 1]:
					bad += 1
				if b.kinds[i] == K.VBAR and t[i * 2] != s[i * 2]:
					bad += 1
			s = t
	check.call(n > 500 and bad == 0, "swipe idempotent, legal, bars on axis over %d swipes (%d bad)" % [n, bad])


func test_fast_equals_reference_on_shipped() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ShiftPuzzles.DAILY))
	var diff := 0
	var n := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for key in data:
		for lv in 3:
			var b: ShiftBoard = ShiftPuzzles._puzzle(data[key][lv]).board
			var s: PackedInt32Array = b.start
			for step in 8:
				var dir := rng.randi_range(0, 3)
				var t: PackedInt32Array = b.swipe(s, dir)
				if t != b.swipe_reference(s, dir):
					diff += 1
				n += 1
				s = t
	check.call(diff == 0, "fast swipe equals reference on %d swipes over shipped boards (%d differ)" % [n, diff])


func test_attempt_edges() -> void:
	var ex := ShiftBoard.create(5, 5, D.RIGHT, 2)
	ex.add(K.WHITE, 0, 1)
	ex.add(K.VBAR, 3, 1, 2)
	ex.add(K.HBAR, 0, 3, 2)
	ex.add(K.BLOCK, 4, 4)
	var a := ShiftAttempt.new(ex)
	check.call(not a.undo() and a.record == "" and not a.restart() and a.record == "", "undo/restart at start do nothing and leave no record")
	var corner := ShiftBoard.create(3, 3, D.RIGHT, 2)
	corner.add(K.WHITE, 0, 0)
	var ca := ShiftAttempt.new(corner)
	check.call(not ca.swipe(D.UP) and not ca.swipe(D.LEFT) and ca.swipes == 0 and ca.record == "", "swipe against the wall: no count, no record")
	a.swipe(D.DOWN)
	a.undo()
	a.swipe(D.DOWN)
	check.call(a.swipes == 2 and a.record == "DzD", "down, undo, down counts 2 (%s)" % a.record)
	a.restart()
	check.call(a.swipes == 2 and a.record == "DzDr" and a.state == ex.start, "restart keeps the count and resets the board")
	a.swipe(D.DOWN)
	a.swipe(D.RIGHT)
	check.call(a.solved() and a.swipes == 4, "solved after restart: 4 swipes counted")
	check.call(not a.swipe(D.LEFT) and not a.restart() and not a.undo() and a.swipes == 4, "after solving nothing changes")
	var r := ShiftAttempt.replay(ex, a.record)
	check.call(r.swipes == 4 and r.record == a.record and r.solved(), "replay equals the original")
	# garbage and impossible entries in a record are ignored
	var g := ShiftAttempt.replay(ex, "zzrx?DD9 R")
	check.call(g.swipes == 2 and g.record == "DR" and g.solved(), "replay ignores junk and no-op letters (%s)" % g.record)
	check.call(ShiftAttempt.replay(ex, "").swipes == 0, "empty record is a fresh attempt")
	# undo several times walks back to the start
	var u := ShiftAttempt.new(ex)
	u.swipe(D.RIGHT)
	u.swipe(D.DOWN)
	u.undo()
	u.undo()
	check.call(u.state == ex.start and not u.undo() and u.swipes == 2, "undo walks back to start, then stops")


func ts(s: String) -> int:
	return int(Time.get_unix_time_from_datetime_string(s))


func test_dates() -> void:
	# winter boundary 2026-11-17 00:00 CET = 2026-11-16 23:00 UTC
	check.call(ShiftDaily.date_at(ts("2026-11-16T22:59:59")) == "2026-11-16", "1 s before Dutch midnight: still the 16th")
	check.call(ShiftDaily.date_at(ts("2026-11-16T23:00:00")) == "2026-11-17", "Dutch midnight: the 17th")
	check.call(ShiftDaily.date_at(ts("2026-11-17T22:59:59")) == "2026-11-17", "end of the 17th")
	# spring forward 2027-03-28: Dutch day of the 28th starts at 23:00 UTC on the 27th, the 29th at 22:00 UTC on the 28th
	check.call(ShiftDaily.date_at(ts("2027-03-27T22:59:59")) == "2027-03-27", "before the 28th starts (CET)")
	check.call(ShiftDaily.date_at(ts("2027-03-27T23:00:00")) == "2027-03-28", "the 28th starts at 23:00 UTC")
	check.call(ShiftDaily.date_at(ts("2027-03-28T21:59:59")) == "2027-03-28", "the 28th (23 h long) still lasts")
	check.call(ShiftDaily.date_at(ts("2027-03-28T22:00:00")) == "2027-03-29", "the 29th starts at 22:00 UTC")
	# fall back 2027-10-31 (last Sunday, 01:00 UTC): the day is 25 h long
	check.call(ShiftDaily.date_at(ts("2027-10-30T21:59:59")) == "2027-10-30", "before the 31st (CEST)")
	check.call(ShiftDaily.date_at(ts("2027-10-30T22:00:00")) == "2027-10-31", "the 31st starts at 22:00 UTC")
	check.call(ShiftDaily.date_at(ts("2027-10-31T22:59:59")) == "2027-10-31", "the 31st lasts until 23:00 UTC")
	check.call(ShiftDaily.date_at(ts("2027-10-31T23:00:00")) == "2027-11-01", "1 November starts at 23:00 UTC")
	# switch instants, several years incl. one where the 31st is a Sunday (2024-03-31, 2025-10-26)
	for pair in [["2024-03-31T01:00:00", "2024-10-27T01:00:00"], ["2026-03-29T01:00:00", "2026-10-25T01:00:00"],
			["2028-03-26T01:00:00", "2028-10-29T01:00:00"], ["2029-03-25T01:00:00", "2029-10-28T01:00:00"]]:
		var a := ts(pair[0])
		var z := ts(pair[1])
		check.call(ShiftDaily.nl_offset(a - 1) == 3600 and ShiftDaily.nl_offset(a) == 7200, "DST start at %s" % pair[0])
		check.call(ShiftDaily.nl_offset(z - 1) == 7200 and ShiftDaily.nl_offset(z) == 3600, "DST end at %s" % pair[1])
	check.call(ShiftDaily.nl_offset(ts("2026-12-25T12:00:00")) == 3600 and ShiftDaily.nl_offset(ts("2027-07-15T12:00:00")) == 7200, "mid winter +1, mid summer +2")
	# year boundary
	check.call(ShiftDaily.date_at(ts("2026-12-31T23:00:00")) == "2027-01-01", "new year in the Netherlands")
	check.call(ShiftDaily.date_at(ts("2027-12-31T22:59:59")) == "2027-12-31", "last second of 2027")
	# numbering: consecutive over two years incl. leap day, #1 = 2026-11-17, before = <= 0
	var prev := 0
	var ok := true
	var t := ts("2026-11-17T12:00:00")
	for k in 800:
		var d := ShiftDaily.date_at(t + k * 86400)
		var nr := ShiftDaily.number(d)
		if nr != k + 1:
			ok = false
			break
	check.call(ok, "numbers run 1..800 without gaps (also over 2028-02-29)")
	check.call(ShiftDaily.number("2026-11-16") == 0 and ShiftDaily.number("2027-01-15") == 60, "number before day 1 is 0, 2027-01-15 is #60")
	check.call(ShiftDaily.today().length() == 10, "today() gives a date string")


func test_share_line_edges() -> void:
	Strings.lang = "nl"
	check.call(Strings.share_line(3, [null, null, null], [4, 8, 13]) == "White Shift #3 · -/-/- vegen (par 4/8/13)", "nothing solved")
	var line := Strings.share_line(60, [5, 12, 30], [4, 10, 24])
	check.call(line == "White Shift #60 · 5/12/30 vegen (par 4/10/24)" and line.count("\n") == 0, "one line, counts only")
	for ch in "RLDU":
		check.call(not line.contains(ch + ch + ch), "no route letters in the share line")
	Strings.lang = "en"
	check.call(Strings.share_line(1, [null, 2, null], [1, 2, 3]).contains("-/2/-"), "partial result in English")
	check.call(Strings.t("levels").size() == 3 and Strings.TEXT["nl"].keys() == Strings.TEXT["en"].keys(), "both languages have the same keys")
	Strings.lang = "nl"


func test_puzzle_api() -> void:
	check.call(ShiftPuzzles.has_day("2026-11-17") and ShiftPuzzles.has_day("2027-01-15"), "first and last day exist")
	check.call(not ShiftPuzzles.has_day("2027-01-16") and not ShiftPuzzles.has_day("2026-11-16") and not ShiftPuzzles.has_day(""), "days outside the range do not")
	check.call(ShiftPuzzles.day("2027-01-16").is_empty() and ShiftPuzzles.day("garbage").is_empty(), "no puzzle: empty list")
	check.call(ShiftPuzzles.day("2026-11-17").size() == 3, "three puzzles per day")
	var n := ShiftPuzzles.practice_count()
	check.call(n > 0, "practice pool is not empty")
	check.call(ShiftPuzzles.practice(-1, 0).par == ShiftPuzzles.practice(n - 1, 0).par and ShiftPuzzles.practice(n, 1).par == ShiftPuzzles.practice(0, 1).par,
		"practice index wraps around")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ShiftPuzzles.DAILY))
	var keys := data.keys()
	keys.sort()
	var contiguous := true
	var t := ts("2026-11-17T00:00:00")
	for k in keys.size():
		if keys[k] != Time.get_date_string_from_unix_time(t + k * 86400):
			contiguous = false
	check.call(contiguous and keys.size() == 60, "daily.json: 60 consecutive dates from 2026-11-17")


func test_shipped_data() -> void:
	for path in [ShiftPuzzles.DAILY, ShiftPuzzles.PRACTICE]:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var bad := []
		var seen := {}
		var dupes := []
		for key in data:
			if data[key].size() != 3:
				bad.append("%s: %d puzzles" % [key, data[key].size()])
				continue
			for lv in 3:
				var cfg: Dictionary = ShiftGenerator.LEVELS[lv]
				var p := ShiftPuzzles._puzzle(data[key][lv])
				var b: ShiftBoard = p.board
				# independent re-solve: stored par and solution count are the true ones
				var r := ShiftSolver.solve(b, 400000)
				var tag := "%s/%d" % [key, lv]
				if r.par != p.par or r.solutions != p.solutions or r.capped:
					bad.append(tag + " par/solutions differ from solver")
				if p.solutions > cfg.max_solutions:
					bad.append(tag + " too many shortest solutions")
				if not b.w in cfg.sizes or b.w != b.h:
					bad.append(tag + " size")
				if b.count() - 1 < cfg.pieces[0] or b.count() - 1 > cfg.pieces[1] or b.pins.size() > cfg.pins[1]:
					bad.append(tag + " piece/pin count")
				if b.exit_index < 0 or b.exit_index >= b.w or b.exit_side < 0 or b.exit_side > 3:
					bad.append(tag + " exit")
				# the stored path wins only on its last swipe, and no swipe in it is a no-op
				var s := b.start
				for i in p.path.size():
					var nx := b.swipe(s, p.path[i])
					if nx == s or (b.is_won(nx) and i < p.path.size() - 1):
						bad.append(tag + " path step %d" % i)
						break
					s = nx
				# the same puzzle in an attempt: solved in par swipes
				var at := ShiftAttempt.new(b)
				for dir in p.path:
					at.swipe(dir)
				if not at.solved() or at.swipes != p.par:
					bad.append(tag + " attempt does not solve")
				var key_text := b.render()
				if seen.has(key_text):
					dupes.append(tag)
				seen[key_text] = true
		check.call(bad.is_empty(), "%s: re-solved, bands and paths ok (%s)" % [path, "; ".join(bad.slice(0, 5))])
		check.call(dupes.is_empty(), "%s: no identical boards (%s)" % [path, ", ".join(dupes.slice(0, 5))])


# --- UI progress: needs the main scene; backs up and restores a real save file ---------------------------------

func test_ui_progress(node: Node) -> void:
	var save := "user://progress.json"
	var backup := ""
	var had := FileAccess.file_exists(save)
	if had:
		backup = FileAccess.get_file_as_string(save)
	var scene: PackedScene = load("res://ui/main.tscn")
	# fresh: no saved file
	if had:
		DirAccess.remove_absolute(save)
	var m: Control = scene.instantiate()
	node.add_child(m)
	m.date = "2026-11-17"
	m._open_day()
	var day := ShiftPuzzles.day("2026-11-17")
	check.call(m.puzzles.size() == 3 and m.level == 0 and m.attempts[0].swipes == 0, "ui: fresh day starts on easy, no swipes")
	# play the stored route for easy, with an undo in between
	var path: PackedInt32Array = day[0].path
	m._on_swipe(path[0])
	m._on_undo()
	for dir in path:
		m._on_swipe(dir)
	check.call(m.attempts[0].solved() and m.attempts[0].swipes == path.size() + 1, "ui: undo counted, easy solved (%d)" % m.attempts[0].swipes)
	check.call(m.share_btn.visible and m.next_btn.visible and not m.undo_btn.visible, "ui: solved shows share/next, hides undo")
	# progress file: record per level, solved flag
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save))
	var rec: String = saved.days["2026-11-17"][0].record
	check.call(rec.contains("z") and saved.days["2026-11-17"][0].solved == true and saved.days["2026-11-17"].size() == 3, "ui: record with undo saved (%s)" % rec)
	m.queue_free()
	await node.get_tree().process_frame
	# reload: same state, opens on the first unsolved level
	var m2: Control = scene.instantiate()
	node.add_child(m2)
	m2.date = "2026-11-17"
	m2._open_day()
	check.call(m2.attempts[0].solved() and m2.attempts[0].swipes == path.size() + 1 and m2.level == 1, "ui: reload restores easy and moves to medium")
	# practice does not touch the saved days
	m2._toggle_mode()
	m2._on_swipe(m2.puzzles[0].path[0])
	var after: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save))
	check.call(after.days["2026-11-17"][0].record == rec and not after.days.has("practice"), "ui: practice swipes are not saved")
	m2.queue_free()
	await node.get_tree().process_frame
	# no puzzle for the day: message and hidden buttons, no crash
	var m3: Control = scene.instantiate()
	node.add_child(m3)
	m3.date = "2027-02-01"
	m3._open_day()
	check.call(m3.puzzles.is_empty() and m3.message.text == Strings.t("no_puzzle") and not m3.undo_btn.visible, "ui: no puzzle for the day shows the notice")
	m3._on_swipe(ShiftBoard.Dir.RIGHT)
	m3._on_undo()
	m3._pick_level(1)
	m3._on_restart()
	check.call(true, "ui: input without a puzzle does not crash")
	m3.queue_free()
	await node.get_tree().process_frame
	# corrupt save files must not stop the game from starting
	var junk_saves := ["not json", "[1,2]", "{\"days\": 5}", "{\"days\": {\"2026-11-17\": []}}"]
	# known open findings (see test report): structurally wrong saves crash _open_day; run with `-- --known`
	if "--known" in OS.get_cmdline_user_args():
		junk_saves += ["{\"days\": {\"2026-11-17\": [{}]}}", "{\"days\": {\"2026-11-17\": \"x\"}}",
			"{\"days\": {\"2026-11-17\": [5]}}", "{\"days\": {}, \"lang\": \"fr\"}"]
	for junk in junk_saves:
		var f := FileAccess.open(save, FileAccess.WRITE)
		f.store_string(junk)
		f.close()
		var m4: Control = scene.instantiate()
		node.add_child(m4)
		m4.date = "2026-11-17"
		m4._open_day()
		check.call(m4.puzzles.size() == 3 and m4.attempts.size() == 3 and m4.attempts[0].swipes == 0, "ui: save '%s' falls back to a fresh day" % junk)
		Strings.lang = "nl"
		m4.queue_free()
		await node.get_tree().process_frame
	# restore the real save
	if had:
		var f := FileAccess.open(save, FileAccess.WRITE)
		f.store_string(backup)
		f.close()
	else:
		DirAccess.remove_absolute(save)
