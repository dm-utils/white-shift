class_name ShiftAttempt
extends RefCounted
## One player's go at one puzzle: the record of everything they did, which is also the replay a server can check later.
## Record letters: R L D U = a swipe that moved something, z = undo, r = restart.
## Every swipe counts, also the ones taken back: undo and restart are free but do not lower the count.

var board: ShiftBoard
var record := ""
var history: Array[PackedInt32Array] = []
var state: PackedInt32Array
var swipes := 0
var time_ms := 0 ## from the first swipe until solved


func _init(b: ShiftBoard) -> void:
	board = b
	state = b.start


func solved() -> bool:
	return board.is_won(state)


## Returns true when the swipe moved something (and so counted).
func swipe(dir: int) -> bool:
	if solved():
		return false
	var next := board.swipe(state, dir)
	if next == state:
		return false
	history.append(state)
	state = next
	swipes += 1
	record += ShiftBoard.LETTERS[dir]
	return true


func undo() -> bool:
	if history.is_empty() or solved():
		return false
	state = history.pop_back()
	record += "z"
	return true


func restart() -> bool:
	if history.is_empty() or solved():
		return false
	history.clear()
	state = board.start
	record += "r"
	return true


## Rebuilds an attempt from its record (loading a saved day; later: checking a submitted replay).
static func replay(b: ShiftBoard, rec: String) -> ShiftAttempt:
	var a := ShiftAttempt.new(b)
	for ch in rec:
		match ch:
			"z":
				a.undo()
			"r":
				a.restart()
			_:
				var dir := ShiftBoard.LETTERS.find(ch)
				if dir >= 0:
					a.swipe(dir)
	return a
