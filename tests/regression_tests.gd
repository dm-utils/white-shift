extends RefCounted
## Guards for the move to White Kit: published puzzle data stays as shipped, the generator on WhiteRng stays stable.
## Run from run_tests.gd; `check` is the runner's check(ok, what).

# md5 of JSON.stringify of the parsed day or set, taken from the data at the commit before the move to White Kit
const DAILY_MD5 := {
	"2026-11-17": "02a58ce3d4ba624a1bbb8af7ebd1bfda",
	"2026-11-18": "f2dc8d69bc61b5a9f6104623ccbf879a",
	"2026-11-19": "90744ae1e2f78d864576afdbf45c4793",
	"2027-01-15": "ef56eb27c60221cd1b849721f080a48e",
}
const PRACTICE_MD5 := {
	"0": "a24f8380783b752ed250614ba88677ca",
	"1": "6bd3c2f831f03eb579b86495f1103dda",
	"44": "872cfd477641d87714258cfe1aabce05",
}

var check: Callable


func run(checker: Callable, _node: Node) -> void:
	check = checker
	test_published_data()
	test_generator_golden()


func _load(path: String) -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}


func test_published_data() -> void:
	var daily := _load(ShiftPuzzles.DAILY)
	for k in DAILY_MD5:
		check.call(daily.has(k) and JSON.stringify(daily[k]).md5_text() == DAILY_MD5[k], "published day %s is unchanged" % k)
	var practice := _load(ShiftPuzzles.PRACTICE)
	for k in PRACTICE_MD5:
		check.call(practice.has(k) and JSON.stringify(practice[k]).md5_text() == PRACTICE_MD5[k], "practice set %s is unchanged" % k)
	check.call(daily.keys().slice(0, 3) == ["2026-11-17", "2026-11-18", "2026-11-19"], "the first published days are still first")
	# the puzzles the game serves for those days are the ones in the file
	for k in ["2026-11-17", "2026-11-19"]:
		var served := ShiftPuzzles.day(k)
		var ok := served.size() == 3
		for i in served.size():
			ok = ok and served[i].par == int(daily[k][i].par) and ShiftBoard.moves_to_text(served[i].path) == daily[k][i].path
		check.call(ok, "ShiftPuzzles serves the published puzzles of " + k)


func test_generator_golden() -> void:
	# seeds are fixed by WhiteSeed and the moves by WhiteRng (both frozen); a change here means the output changed
	var want := [
		[4, "URUL", 1, "7e8e6c527553e6c4c14261cf05d66b46"],
		[10, "RURDRDLDRU", 4, "5b0541217fc1f85dc768d5b2ca1a8f4d"],
	]
	for l in want.size():
		var r := ShiftGenerator.generate(ShiftGenerator.seed_for("white-shift|2026-11-17|%d" % l), l)
		var w: Array = want[l]
		check.call(r.par == w[0] and ShiftBoard.moves_to_text(r.path) == w[1] and r.solutions == w[2], "generator golden puzzle, level %d" % l)
		check.call(JSON.stringify(r.board.to_dict()).md5_text() == w[3], "generator golden board, level %d" % l)
	check.call(ShiftGenerator.seed_for("white-shift|2026-11-17|0") == WhiteSeed.daily("white-shift", "2026-11-17", 0), "seed_for is WhiteSeed")
