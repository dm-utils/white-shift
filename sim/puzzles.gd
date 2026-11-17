class_name ShiftPuzzles
extends RefCounted
## The precomputed puzzles (tools/build_puzzles.gd): data/daily.json by date, data/practice.json as a pool.
## Each puzzle: {board: ShiftBoard, par, solutions, path (PackedInt32Array)}. Loading is done by WhitePuzzleStore.

const DAILY := "res://data/daily.json"
const PRACTICE := "res://data/practice.json"

static var _store: WhitePuzzleStore


static func _puzzle(d: Dictionary) -> Dictionary:
	var path := PackedInt32Array()
	for ch in str(d.path):
		path.append(ShiftBoard.LETTERS.find(ch))
	return {"board": ShiftBoard.from_dict(d.board), "par": int(d.par), "solutions": int(d.solutions), "path": path}


static func _instance() -> WhitePuzzleStore:
	if _store == null:
		_store = WhitePuzzleStore.new(DAILY, PRACTICE, _puzzle)
	return _store


static func has_day(date: String) -> bool:
	return _instance().has_day(date)


## The three puzzles of a day (easy, medium, hard), or [] when that day was not built.
static func day(date: String) -> Array:
	return _instance().day(date)


static func practice_count() -> int:
	return _instance().practice_count()


static func practice(i: int, level: int) -> Dictionary:
	return _instance().practice(i, level)
