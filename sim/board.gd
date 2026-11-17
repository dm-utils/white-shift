class_name ShiftBoard
extends RefCounted
## The White Shift rules, without any scene: a walled board with one exit in the rim and pieces that slide.
##
## A swipe moves every piece that may move in that direction as far as it can, starting with the piece nearest to the
## wall it moves towards. Bars only move along their own axis; a piece that may not move is an obstacle.
## Only the white stone can leave through the exit; for every other piece the exit is wall.
##
## A state is a PackedInt32Array [x0, y0, x1, y1, ..., won]: the top-left cell of every piece in piece order, and 1 in
## the last slot once the white stone has left (its position is then the exit cell it left from).

enum Kind { WHITE, BLOCK, HBAR, VBAR }
enum Dir { RIGHT, LEFT, DOWN, UP }

const STEP: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const LETTERS := "RLDU"

const EMPTY := -1
const PIN := -2

var w: int
var h: int
var exit_side: int ## a Dir: the wall the exit is in (RIGHT = the right-hand wall)
var exit_index: int ## the row (left/right wall) or column (top/bottom wall) of the exit
var kinds := PackedInt32Array()
var lens := PackedInt32Array()
var pins: Array[Vector2i] = []
var start := PackedInt32Array()


static func create(width: int, height: int, side: int, index: int) -> ShiftBoard:
	var b := ShiftBoard.new()
	b.w = width
	b.h = height
	b.exit_side = side
	b.exit_index = index
	b.start.append(0) # the won flag; pieces are inserted before it
	return b


## Adds a piece at (x, y) and returns its index. The white stone must be the first piece.
func add(kind: int, x: int, y: int, length: int = 1) -> int:
	kinds.append(kind)
	lens.append(length if kind == Kind.HBAR or kind == Kind.VBAR else 1)
	start.insert(start.size() - 1, x)
	start.insert(start.size() - 1, y)
	return kinds.size() - 1


func count() -> int:
	return kinds.size()


static func can_move(kind: int, dir: int) -> bool:
	match kind:
		Kind.HBAR:
			return dir == Dir.RIGHT or dir == Dir.LEFT
		Kind.VBAR:
			return dir == Dir.DOWN or dir == Dir.UP
	return true


func cells(i: int, state: PackedInt32Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var x := state[i * 2]
	var y := state[i * 2 + 1]
	for k in lens[i]:
		out.append(Vector2i(x + k, y) if kinds[i] == Kind.HBAR else Vector2i(x, y + k))
	return out


func is_won(state: PackedInt32Array) -> bool:
	return state[state.size() - 1] == 1


func grid(state: PackedInt32Array) -> PackedInt32Array:
	var g := PackedInt32Array()
	g.resize(w * h)
	g.fill(EMPTY)
	for p in pins:
		g[p.y * w + p.x] = PIN
	var won := state[state.size() - 1] == 1
	for i in kinds.size():
		if i == 0 and won:
			continue
		var x := state[i * 2]
		var y := state[i * 2 + 1]
		var vertical := kinds[i] == Kind.VBAR
		for k in lens[i]:
			g[(y + k) * w + x if vertical else y * w + x + k] = i
	return g


## Is the layout legal: everything on the board, nothing overlapping, the white stone first.
func valid(state: PackedInt32Array = start) -> bool:
	if count() == 0 or kinds[0] != Kind.WHITE:
		return false
	var seen := {}
	for p in pins:
		if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h or seen.has(p):
			return false
		seen[p] = true
	for i in count():
		for c in cells(i, state):
			if c.x < 0 or c.y < 0 or c.x >= w or c.y >= h or seen.has(c):
				return false
			seen[c] = true
	return true


## The cell just inside the exit.
func exit_cell() -> Vector2i:
	match exit_side:
		Dir.RIGHT:
			return Vector2i(w - 1, exit_index)
		Dir.LEFT:
			return Vector2i(0, exit_index)
		Dir.DOWN:
			return Vector2i(exit_index, h - 1)
	return Vector2i(exit_index, 0)


## The state after a swipe. Returns the same contents when nothing moves.
## Scans the board from the wall the pieces move towards, so every piece meets the pieces in front of it already
## settled; a piece is handled at its leading cell, which is the first of its cells the scan reaches.
func swipe(state: PackedInt32Array, dir: int) -> PackedInt32Array:
	var out := state.duplicate()
	var n := kinds.size()
	if out[n * 2] == 1:
		return out
	var g := grid(state)
	var dx: int = STEP[dir].x
	var dy: int = STEP[dir].y
	var done := PackedByteArray()
	done.resize(n)
	var horizontal := dir <= Dir.LEFT
	var outer := h if horizontal else w
	var inner := w if horizontal else h
	for a in outer:
		for k in inner:
			# k = 0 is the cell against the target wall
			var b := (inner - 1 - k) if (dx + dy) > 0 else k
			var x := b if horizontal else a
			var y := a if horizontal else b
			var i := g[y * w + x]
			if i < 0 or done[i] == 1:
				continue
			done[i] = 1
			var kind := kinds[i]
			if (kind == Kind.HBAR and not horizontal) or (kind == Kind.VBAR and horizontal):
				continue
			var length := lens[i]
			var px := out[i * 2]
			var py := out[i * 2 + 1]
			var ex := 0 if kind == Kind.VBAR else 1
			var ey := 1 if kind == Kind.VBAR else 0
			# leading cell: (x, y) found by the scan is the one nearest the wall
			var moved := 0
			var exited := false
			while true:
				var lx := x + dx * (moved + 1)
				var ly := y + dy * (moved + 1)
				if lx < 0 or ly < 0 or lx >= w or ly >= h:
					exited = i == 0 and dir == exit_side and (ly if horizontal else lx) == exit_index
					break
				if g[ly * w + lx] != EMPTY:
					break
				moved += 1
			if moved == 0 and not exited:
				continue
			for c in length:
				g[(py + ey * c) * w + px + ex * c] = EMPTY
			px += dx * moved
			py += dy * moved
			out[i * 2] = px
			out[i * 2 + 1] = py
			if exited:
				out[n * 2] = 1
				continue
			for c in length:
				g[(py + ey * c) * w + px + ex * c] = i
	return out


## The plain version of swipe(): easy to read, slow. Tests check that swipe() always gives the same result.
func swipe_reference(state: PackedInt32Array, dir: int) -> PackedInt32Array:
	var out := state.duplicate()
	if is_won(state):
		return out
	var g := grid(state)
	var step := STEP[dir]
	# nearest to the target wall first, so the pieces in front have already settled
	var order: Array[int] = []
	for i in count():
		if can_move(kinds[i], dir):
			order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return _front(a, state, dir) > _front(b, state, dir))
	for i in order:
		var mine := cells(i, out)
		for c in mine:
			g[c.y * w + c.x] = EMPTY
		var moved := 0
		var exited := false
		while true:
			var lead: Vector2i = (mine[mine.size() - 1] if step.x + step.y > 0 else mine[0]) + step * (moved + 1)
			if lead.x < 0 or lead.y < 0 or lead.x >= w or lead.y >= h:
				exited = i == 0 and dir == exit_side and (lead.y if dir <= Dir.LEFT else lead.x) == exit_index
				break
			if g[lead.y * w + lead.x] != EMPTY:
				break
			moved += 1
		out[i * 2] += step.x * moved
		out[i * 2 + 1] += step.y * moved
		if exited:
			out[out.size() - 1] = 1
			continue
		for c in cells(i, out):
			g[c.y * w + c.x] = i
	return out


## How far the piece's leading edge is along the swipe direction (bigger = nearer to the target wall).
func _front(i: int, state: PackedInt32Array, dir: int) -> int:
	var step := STEP[dir]
	var best := -1000000
	for c in cells(i, state):
		best = maxi(best, c.x * step.x + c.y * step.y)
	return best


## A compact, readable form for tests and for the measure tool. W white, o block, H/V bars, # pin, > exit.
func render(state: PackedInt32Array = start) -> String:
	var g := grid(state)
	var lines := PackedStringArray()
	for y in h:
		var row := ""
		for x in w:
			var v := g[y * w + x]
			row += "." if v == EMPTY else "#" if v == PIN else "WoHV"[kinds[v]]
		lines.append(row)
	return "\n".join(lines) + "\nexit %s%d" % [LETTERS[exit_side], exit_index]


## Moves as letters, e.g. "DRUL".
static func moves_to_text(moves: PackedInt32Array) -> String:
	var s := ""
	for m in moves:
		s += LETTERS[m]
	return s


## Plain data for JSON: {n:[w,h], exit:[side,index], pins:[[x,y]], pieces:[[kind,x,y,len]]}.
func to_dict() -> Dictionary:
	var pieces := []
	for i in count():
		pieces.append([kinds[i], start[i * 2], start[i * 2 + 1], lens[i]])
	var p := []
	for c in pins:
		p.append([c.x, c.y])
	return {"n": [w, h], "exit": [exit_side, exit_index], "pins": p, "pieces": pieces}


static func from_dict(d: Dictionary) -> ShiftBoard:
	var b := ShiftBoard.create(int(d.n[0]), int(d.n[1]), int(d.exit[0]), int(d.exit[1]))
	for c in d.pins:
		b.pins.append(Vector2i(int(c[0]), int(c[1])))
	for p in d.pieces:
		b.add(int(p[0]), int(p[1]), int(p[2]), int(p[3]))
	return b
