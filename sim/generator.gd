class_name ShiftGenerator
extends RefCounted
## Builds puzzles from a seed: random layouts, each checked by the solver, the first one that fits the level wins.
## Fully deterministic: the same seed and level always give the same puzzle on every device.

enum Level { EASY, MEDIUM, HARD }

## Per level: board sizes, how many pieces (besides the white stone), pins, the par band, the most shortest
## solutions allowed (more = too easy to stumble on), and how many layouts to try before taking the best so far.
const LEVELS := [
	{"sizes": [5], "pieces": [4, 7], "pins": [0, 1], "par": [4, 7], "max_solutions": 6, "tries": 600},
	{"sizes": [6], "pieces": [7, 11], "pins": [0, 2], "par": [8, 12], "max_solutions": 4, "tries": 900},
	{"sizes": [6, 7], "pieces": [9, 14], "pins": [0, 2], "par": [13, 24], "max_solutions": 4, "tries": 1500},
]

## Share of each kind among the other pieces: blocks, horizontal bars, vertical bars.
const MIX := [0.3, 0.35, 0.35]


static func seed_for(text: String) -> int:
	return WhiteSeed.fnv1a64(text)


## Returns {board, par, solutions, path, tries}.
static func generate(seed_value: int, level: int) -> Dictionary:
	var cfg: Dictionary = LEVELS[level]
	var rng := WhiteRng.new(seed_value)
	var best := {}
	var best_score := -1000000000
	for attempt in int(cfg.tries):
		var board := random_board(rng, cfg)
		if board == null or not (ShiftBoard.Kind.HBAR in board.kinds and ShiftBoard.Kind.VBAR in board.kinds):
			continue # every level teaches the core rule: bars only move along their own axis
		var r := ShiftSolver.solve(board, 60000)
		var par: int = r.par
		if par < 2:
			continue
		var lo: int = cfg.par[0]
		var hi: int = cfg.par[1]
		var fits: bool = par >= lo and par <= hi and r.solutions <= cfg.max_solutions
		if fits:
			return {"board": board, "par": par, "solutions": r.solutions, "path": r.path, "tries": attempt + 1}
		# fallback: nearest to the band, fewer shortest solutions as tie-break
		var score := -absi(par - clampi(par, lo, hi)) * 100 - int(r.solutions)
		if score > best_score:
			best_score = score
			best = {"board": board, "par": par, "solutions": r.solutions, "path": r.path, "tries": attempt + 1}
	best.tries = int(cfg.tries)
	return best


static func random_board(rng: WhiteRng, cfg: Dictionary) -> ShiftBoard:
	var sizes: Array = cfg.sizes
	var n: int = sizes[rng.range_int(0, sizes.size() - 1)]
	var side := rng.range_int(0, 3)
	var board := ShiftBoard.create(n, n, side, rng.range_int(0, n - 1))
	var used := {}
	var pin_count := rng.range_int(cfg.pins[0], cfg.pins[1])
	for k in pin_count:
		var p := Vector2i(rng.range_int(0, n - 1), rng.range_int(0, n - 1))
		if not used.has(p):
			used[p] = true
			board.pins.append(p)
	var white := _free_cell(rng, n, used)
	if white.x < 0:
		return null
	used[white] = true
	board.add(ShiftBoard.Kind.WHITE, white.x, white.y)
	var want := rng.range_int(cfg.pieces[0], cfg.pieces[1])
	var placed := 0
	var guard := 0
	while placed < want and guard < 200:
		guard += 1
		var roll := rng.next_float()
		var kind := ShiftBoard.Kind.BLOCK if roll < MIX[0] else ShiftBoard.Kind.HBAR if roll < MIX[0] + MIX[1] else ShiftBoard.Kind.VBAR
		var length := 1 if kind == ShiftBoard.Kind.BLOCK else (2 if rng.next_float() < 0.65 else 3)
		var x := rng.range_int(0, n - (length if kind == ShiftBoard.Kind.HBAR else 1))
		var y := rng.range_int(0, n - (length if kind == ShiftBoard.Kind.VBAR else 1))
		var mine: Array[Vector2i] = []
		for k in length:
			mine.append(Vector2i(x + k, y) if kind == ShiftBoard.Kind.HBAR else Vector2i(x, y + k))
		if mine.any(func(c: Vector2i) -> bool: return used.has(c)):
			continue
		for c in mine:
			used[c] = true
		board.add(kind, x, y, length)
		placed += 1
	return board


static func _free_cell(rng: WhiteRng, n: int, used: Dictionary) -> Vector2i:
	for k in 50:
		var c := Vector2i(rng.range_int(0, n - 1), rng.range_int(0, n - 1))
		if not used.has(c):
			return c
	return Vector2i(-1, -1)
