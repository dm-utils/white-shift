extends SceneTree
## Precomputes puzzles so a phone never has to search (a hard one can take seconds to minutes).
##   godot --headless --path . -s res://tools/build_puzzles.gd -- --from=2026-11-17 --days=60 --out=data/daily.json
##   godot --headless --path . -s res://tools/build_puzzles.gd -- --practice=40 [--start=0] --out=data/practice.json
## Daily seed: "white-shift|<date>|<level>"; practice seed: "white-shift-practice|<i>|<level>".
## Output: {"<key>": [easy, medium, hard]} with each puzzle {board, par, solutions, path}.


func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		args[a.get_slice("=", 0).trim_prefix("--")] = a.get_slice("=", 1)
	var out := {}
	var keys := []
	if args.has("practice"):
		for i in range(int(args.get("start", "0")), int(args.get("start", "0")) + int(args.practice)):
			keys.append(["%d" % i, "white-shift-practice|%d|" % i])
	else:
		var t0 := Time.get_unix_time_from_datetime_string(str(args.from) + "T12:00:00")
		for d in int(args.get("days", "1")):
			var date := Time.get_date_string_from_unix_time(t0 + d * 86400)
			keys.append([date, "white-shift|%s|" % date])
	for k in keys:
		var levels := []
		for level in 3:
			var r := ShiftGenerator.generate(ShiftGenerator.seed_for(str(k[1]) + str(level)), level)
			var b: ShiftBoard = r.board
			levels.append({"board": b.to_dict(), "par": r.par, "solutions": r.solutions, "path": ShiftBoard.moves_to_text(r.path)})
		out[k[0]] = levels
		print(k[0], " par ", levels.map(func(l): return l.par))
	var f := FileAccess.open(str(args.out), FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "", false) + "\n")
	f.close()
	quit()
