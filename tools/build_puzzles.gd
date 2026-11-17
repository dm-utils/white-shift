extends WhitePrecompute
## Precomputes puzzles so a phone never has to search (a hard one can take seconds to minutes).
##   godot --headless --path . -s res://tools/build_puzzles.gd -- --from=2026-11-17 --days=60 --out=build/daily.json
##   godot --headless --path . -s res://tools/build_puzzles.gd -- --practice=40 [--start=0] --out=build/practice.json
##   godot --headless --path . -s res://tools/build_puzzles.gd -- --merge=build/daily.json --into=data/daily.json
## Daily seed: "white-shift|<date>|<level>"; practice seed: "white-shift-practice|<i>|<level>".
## Output: {"<key>": [easy, medium, hard]} with each puzzle {board, par, solutions, path}. Published data is never
## regenerated: new days are added with --merge, which refuses to change an existing key.


func _game_id() -> String:
	return "white-shift"


func _generate(seed_value: int, level: int) -> Dictionary:
	var r := ShiftGenerator.generate(seed_value, level)
	var b: ShiftBoard = r.board
	return {"board": b.to_dict(), "par": r.par, "solutions": r.solutions, "path": ShiftBoard.moves_to_text(r.path)}
