class_name ShiftAttempt
extends WhiteAttempt
## One player's go at one puzzle: the record of everything they did, which is also the replay a server can check later.
## Record letters: R L D U = a swipe that moved something, z = undo, r = restart.
## Every swipe counts, also the ones taken back: undo and restart are free but do not lower the count.
## The mechanics are WhiteAttempt's (every-move count); this class keeps the White Shift names.

var board: ShiftBoard
var swipes: int: ## every swipe that moved something
	get:
		return count()


func _init(b: ShiftBoard) -> void:
	super(b)
	board = b


## Returns true when the swipe moved something (and so counted).
func swipe(dir: int) -> bool:
	return play(dir)


## Rebuilds an attempt from its record (loading a saved day; later: checking a submitted replay).
static func replay(b: ShiftBoard, rec: String) -> ShiftAttempt:
	var a := ShiftAttempt.new(b)
	a.apply_record(rec)
	return a
