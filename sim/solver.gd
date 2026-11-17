class_name ShiftSolver
extends RefCounted
## Breadth-first search over every reachable state: the exact par (fewest swipes), how many different shortest
## solutions there are, and one of them. Swipes that change nothing are not moves.

const NO_SOLUTION := -1


## Returns {par, solutions, path (PackedInt32Array of Dir), states, capped}.
## par is NO_SOLUTION when the white stone cannot get out (or the search hit max_states first: capped = true).
static func solve(board: ShiftBoard, max_states: int = 200000) -> Dictionary:
	var start := board.start
	var dist := {start: 0}
	var ways := {start: 1}
	var parent := {}
	var frontier: Array[PackedInt32Array] = [start]
	var depth := 0
	var goal: Variant = null
	var goal_ways := 0
	var capped := false
	while not frontier.is_empty() and goal == null:
		var next: Array[PackedInt32Array] = []
		for s in frontier:
			var n_ways: int = ways[s]
			for dir in 4:
				var t := board.swipe(s, dir)
				if t == s:
					continue
				if board.is_won(t):
					goal_ways = mini(goal_ways + n_ways, 1 << 40)
					if goal == null:
						goal = t
						parent[t] = [s, dir]
					continue
				if not dist.has(t):
					dist[t] = depth + 1
					ways[t] = n_ways
					parent[t] = [s, dir]
					next.append(t)
				elif dist[t] == depth + 1:
					ways[t] = mini(ways[t] + n_ways, 1 << 40)
			if dist.size() > max_states:
				capped = true
				break
		if capped:
			break
		frontier = next
		depth += 1
	if goal == null:
		return {"par": NO_SOLUTION, "solutions": 0, "path": PackedInt32Array(), "states": dist.size(), "capped": capped}
	var path := PackedInt32Array()
	var cur: Variant = goal
	while parent.has(cur):
		var p: Array = parent[cur]
		path.insert(0, p[1])
		cur = p[0]
	return {"par": path.size(), "solutions": goal_ways, "path": path, "states": dist.size(), "capped": false}
