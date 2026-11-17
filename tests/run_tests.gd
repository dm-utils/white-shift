extends WhiteTestRunner
## Test runner: godot --headless --path . res://tests/run_tests.tscn
## Prints "tests: N passed, M failed" and exits with 1 when anything failed.


func _run() -> void:
	test_example_from_design()
	test_rules()
	test_fast_swipe_matches_reference()
	test_solver()
	test_generator_deterministic()
	test_board_roundtrip()
	test_attempt()
	test_daily_dates()
	test_share_line()
	test_puzzle_data()
	await preload("res://tests/extra_tests.gd").new().run(check, self)
	await preload("res://tests/regression_tests.gd").new().run(check, self)


func example() -> ShiftBoard:
	var b := ShiftBoard.create(5, 5, ShiftBoard.Dir.RIGHT, 2)
	b.add(ShiftBoard.Kind.WHITE, 0, 1)
	b.add(ShiftBoard.Kind.VBAR, 3, 1, 2)
	b.add(ShiftBoard.Kind.HBAR, 0, 3, 2)
	b.add(ShiftBoard.Kind.BLOCK, 4, 4)
	return b


func test_example_from_design() -> void:
	var b := example()
	check(b.valid(), "example board is valid")
	var s := b.swipe(b.start, ShiftBoard.Dir.DOWN)
	check(b.render(s) == ".....\n.....\nW....\nHH.V.\n...Vo\nexit R2", "down: white stops on the bar, the post drops out of the way")
	s = b.swipe(s, ShiftBoard.Dir.RIGHT)
	check(b.is_won(s), "right: the white stone leaves through the exit")
	var wrong := b.swipe(b.start, ShiftBoard.Dir.RIGHT)
	check(b.render(wrong).begins_with(".....\n..WV.\n...V.\n...HH"), "right first: white stops against the post, the bar slides to the wall")


func test_rules() -> void:
	# a bar never moves across its axis
	var b := ShiftBoard.create(4, 4, ShiftBoard.Dir.UP, 0)
	b.add(ShiftBoard.Kind.WHITE, 3, 3)
	b.add(ShiftBoard.Kind.HBAR, 0, 1, 2)
	b.add(ShiftBoard.Kind.VBAR, 2, 0, 2)
	var s := b.swipe(b.start, ShiftBoard.Dir.DOWN)
	check(s[2] == 0 and s[3] == 1, "a horizontal bar stays put on a down swipe")
	check(s[4] == 2 and s[5] == 2, "a vertical bar drops to the floor")
	s = b.swipe(b.start, ShiftBoard.Dir.RIGHT)
	check(s[2] == 0 and s[3] == 1, "a horizontal bar stops against a vertical bar that may not move")
	# only white uses the exit; other pieces treat it as wall
	var e := ShiftBoard.create(3, 1, ShiftBoard.Dir.RIGHT, 0)
	e.add(ShiftBoard.Kind.WHITE, 0, 0)
	e.add(ShiftBoard.Kind.BLOCK, 1, 0)
	var t := e.swipe(e.start, ShiftBoard.Dir.RIGHT)
	check(not e.is_won(t) and t[2] == 2 and t[0] == 1, "a block stops at the exit, the white stone behind it")
	# pins stop everything
	var p := ShiftBoard.create(3, 1, ShiftBoard.Dir.LEFT, 0)
	p.pins.append(Vector2i(1, 0))
	p.add(ShiftBoard.Kind.WHITE, 2, 0)
	check(p.swipe(p.start, ShiftBoard.Dir.LEFT) == p.start, "a pin blocks; a swipe that moves nothing returns the same state")
	check(ShiftBoard.from_dict(p.to_dict()).valid(), "a board with pins round-trips and stays valid")


func test_fast_swipe_matches_reference() -> void:
	var rng := WhiteRng.new(7)
	var mismatches := 0
	var checked := 0
	for k in 300:
		var b := ShiftGenerator.random_board(rng, ShiftGenerator.LEVELS[k % 3])
		if b == null or not b.valid():
			continue
		var s := b.start
		for step in 12:
			var dir := rng.range_int(0, 3)
			var fast := b.swipe(s, dir)
			if fast != b.swipe_reference(s, dir):
				mismatches += 1
			s = fast
			checked += 1
	check(checked > 1000 and mismatches == 0, "fast swipe equals the reference on %d random swipes (%d differ)" % [checked, mismatches])


func test_solver() -> void:
	var r := ShiftSolver.solve(example())
	check(r.par == 2 and ShiftBoard.moves_to_text(r.path) == "DR" and r.solutions == 1, "example: par 2, only DR")
	var stuck := ShiftBoard.create(3, 3, ShiftBoard.Dir.RIGHT, 0)
	stuck.pins.append(Vector2i(2, 0))
	stuck.pins.append(Vector2i(1, 1))
	stuck.add(ShiftBoard.Kind.WHITE, 0, 0)
	stuck.add(ShiftBoard.Kind.VBAR, 1, 0, 1)
	check(ShiftSolver.solve(stuck).par == ShiftSolver.NO_SOLUTION, "a sealed exit has no solution")


func test_generator_deterministic() -> void:
	var a := ShiftGenerator.generate(ShiftGenerator.seed_for("test|1|0"), ShiftGenerator.Level.EASY)
	var b := ShiftGenerator.generate(ShiftGenerator.seed_for("test|1|0"), ShiftGenerator.Level.EASY)
	check(a.board.render() == b.board.render() and a.par == b.par, "same seed, same puzzle")
	check(a.par >= 4 and a.par <= 7, "easy puzzle has par 4-7 (got %d)" % a.par)
	check(ShiftGenerator.seed_for("white-shift|2026-11-17|0") == ShiftGenerator.seed_for("white-shift|2026-11-17|0")
		and ShiftGenerator.seed_for("a") != ShiftGenerator.seed_for("b"), "seed hash is stable and spreads")


func test_board_roundtrip() -> void:
	var b := example()
	var c := ShiftBoard.from_dict(JSON.parse_string(JSON.stringify(b.to_dict())))
	check(c.render() == b.render() and c.start == b.start, "board survives JSON")


func test_attempt() -> void:
	var a := ShiftAttempt.new(example())
	check(not a.swipe(ShiftBoard.Dir.LEFT) or a.swipes == 1, "a swipe that moves nothing does not count")
	var before := a.swipes
	a.swipe(ShiftBoard.Dir.RIGHT)
	a.undo()
	check(a.swipes == before + 1, "an undone swipe still counts")
	a.restart()
	a.swipe(ShiftBoard.Dir.DOWN)
	a.swipe(ShiftBoard.Dir.RIGHT)
	check(a.solved(), "solved after restart and DR")
	var again := ShiftAttempt.replay(example(), a.record)
	check(again.solved() and again.swipes == a.swipes and again.record == a.record, "a record replays to the same result (%s)" % a.record)
	check(not a.undo(), "no undo after solving")


func test_daily_dates() -> void:
	# 2026-11-16 23:30 UTC is 00:30 on the 17th in the Netherlands (winter, +1)
	var t := Time.get_unix_time_from_datetime_string("2026-11-16T23:30:00")
	check(ShiftDaily.date_at(t) == "2026-11-17", "winter: Dutch midnight is 23:00 UTC")
	# summer: 2027-07-01 22:30 UTC is 00:30 on the 2nd (+2)
	t = Time.get_unix_time_from_datetime_string("2027-07-01T22:30:00")
	check(ShiftDaily.date_at(t) == "2027-07-02", "summer: Dutch midnight is 22:00 UTC")
	t = Time.get_unix_time_from_datetime_string("2027-07-01T21:30:00")
	check(ShiftDaily.date_at(t) == "2027-07-01", "summer: 23:30 Dutch time is still the same day")
	# DST switch 2027: last Sunday of March = 28th, 01:00 UTC
	check(ShiftDaily.nl_offset(Time.get_unix_time_from_datetime_string("2027-03-28T00:59:00")) == 3600
		and ShiftDaily.nl_offset(Time.get_unix_time_from_datetime_string("2027-03-28T01:00:00")) == 7200, "summer time starts on the last Sunday of March")
	check(ShiftDaily.number("2026-11-17") == 1 and ShiftDaily.number("2026-12-17") == 31, "puzzle numbers count days from #1")


func test_share_line() -> void:
	Strings.lang = "nl"
	check(Strings.share_line(12, [6, 9, null], [5, 9, 13]) == "White Shift #12 · 6/9/- vegen (par 5/9/13)", "share line, no solution in it")
	Strings.lang = "en"
	check(Strings.share_line(1, [4, 8, 14], [4, 8, 13]).ends_with("4/8/14 swipes (par 4/8/13)"), "share line in English")
	Strings.lang = "nl"


func test_puzzle_data() -> void:
	var levels := ShiftGenerator.LEVELS
	for path in [ShiftPuzzles.DAILY, ShiftPuzzles.PRACTICE]:
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		check(data is Dictionary and data.size() > 0, "%s has puzzles" % path)
		if not data is Dictionary:
			continue
		var bad := []
		var checked := 0
		for key in data:
			for level in 3:
				var p := ShiftPuzzles._puzzle(data[key][level])
				var b: ShiftBoard = p.board
				var s := b.start
				for dir in p.path:
					s = b.swipe(s, dir)
				var band: Array = levels[level].par
				# the stored best route really solves it, in exactly par swipes, within the level's band
				var has_bars := ShiftBoard.Kind.HBAR in b.kinds and ShiftBoard.Kind.VBAR in b.kinds
				if not b.valid() or not has_bars or not b.is_won(s) or p.path.size() != p.par or p.par < band[0] or p.par > band[1]:
					bad.append("%s/%d" % [key, level])
				checked += 1
		check(bad.is_empty(), "%s: all %d puzzles valid, with both bar kinds, solved by their route in par, in band (bad: %s)" % [path, checked, ", ".join(bad)])
