class_name ShiftPuzzles
extends RefCounted
## The precomputed puzzles (tools/build_puzzles.gd): data/daily.json by date, data/practice.json as a pool.
## Each puzzle: {board: ShiftBoard, par, solutions, path (PackedInt32Array)}.

const DAILY := "res://data/daily.json"
const PRACTICE := "res://data/practice.json"

static var _cache := {}


static func _load(path: String) -> Dictionary:
	if not _cache.has(path):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		_cache[path] = data if data is Dictionary else {}
	return _cache[path]


static func _puzzle(d: Dictionary) -> Dictionary:
	var path := PackedInt32Array()
	for ch in str(d.path):
		path.append(ShiftBoard.LETTERS.find(ch))
	return {"board": ShiftBoard.from_dict(d.board), "par": int(d.par), "solutions": int(d.solutions), "path": path}


static func has_day(date: String) -> bool:
	return _load(DAILY).has(date)


## The three puzzles of a day (easy, medium, hard), or [] when that day was not built.
static func day(date: String) -> Array:
	var list: Variant = _load(DAILY).get(date)
	return [] if list == null else (list as Array).map(_puzzle)


static func practice_count() -> int:
	return _load(PRACTICE).size()


static func practice(i: int, level: int) -> Dictionary:
	var pool := _load(PRACTICE)
	var keys := pool.keys()
	return _puzzle(pool[keys[posmod(i, keys.size())]][level])
