extends SceneTree
## The computation trial: how the generator does per level over many seeds.
##   godot --headless --path . -s res://tools/measure.gd -- --days=30
## Prints per level: fit rate (first layout in the band), par spread, shortest solutions, tries and time per puzzle.


func _init() -> void:
	var days := 30
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--days="):
			days = int(a.get_slice("=", 1))
	for level in 3:
		var pars := {}
		var fits := 0
		var times := PackedFloat64Array()
		var tries := PackedInt32Array()
		var sols := PackedInt32Array()
		for d in days:
			var t0 := Time.get_ticks_usec()
			var r := ShiftGenerator.generate(ShiftGenerator.seed_for("measure|%d|%d" % [d, level]), level)
			times.append((Time.get_ticks_usec() - t0) / 1000.0)
			var cfg: Dictionary = ShiftGenerator.LEVELS[level]
			if r.par >= cfg.par[0] and r.par <= cfg.par[1] and r.solutions <= cfg.max_solutions:
				fits += 1
			pars[r.par] = pars.get(r.par, 0) + 1
			tries.append(r.tries)
			sols.append(r.solutions)
		times.sort()
		var keys := pars.keys()
		keys.sort()
		var spread := PackedStringArray()
		for k in keys:
			spread.append("%d:%d" % [k, pars[k]])
		print("%s  fit %d/%d  par {%s}  ms median %.0f max %.0f  tries median %d  solutions max %d" % [
			["easy", "medium", "hard"][level], fits, days, " ".join(spread), times[times.size() / 2], times[-1],
			_median(tries), _max(sols)])
	quit()


func _median(a: PackedInt32Array) -> int:
	var b := a.duplicate()
	b.sort()
	return b[b.size() / 2]


func _max(a: PackedInt32Array) -> int:
	var m := 0
	for v in a:
		m = maxi(m, v)
	return m
