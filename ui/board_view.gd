class_name BoardView
extends Control
## Draws a board and its pieces, abstract and flat, and turns swipes (touch or mouse drag) into a signal.
## Pieces glide to their new cells all at the same speed, so you can see what pushed what.

signal swiped(dir: int)

const BG_BOARD := Color("252B35")
const GRID := Color("2E3541")
const WALL := Color("3A4250")
const EXIT := Color("FFFFFF")
const WHITE := Color("FFFFFF")
const BLOCK := Color("8A94A6")
const HBAR := Color("5B8DEF")
const VBAR := Color("E8A33D")
const PIN := Color("11141A")
const GROOVE := Color(0, 0, 0, 0.22)
const SPEED := 16.0 ## cells per second
const SWIPE_MIN := 24.0 ## px of drag before it counts as a swipe

var board: ShiftBoard
var state: PackedInt32Array
var _shown: Array[Vector2] = [] ## where each piece is drawn now, in cells
var _white_alpha := 1.0
var _drag_from := Vector2.ZERO
var _dragging := false


func show_board(b: ShiftBoard, s: PackedInt32Array) -> void:
	board = b
	state = s
	_shown.clear()
	for i in b.count():
		_shown.append(_target(i))
	_white_alpha = 0.0 if b.is_won(s) else 1.0
	queue_redraw()


## Moves to a new state with animation.
func set_state(s: PackedInt32Array, animate: bool = true) -> void:
	state = s
	if not animate:
		show_board(board, s)
	queue_redraw()


func busy() -> bool:
	if board == null:
		return false
	for i in board.count():
		if _shown[i] != _target(i):
			return true
	return false


func _target(i: int) -> Vector2:
	var p := Vector2(state[i * 2], state[i * 2 + 1])
	if i == 0 and board.is_won(state):
		p += Vector2(ShiftBoard.STEP[board.exit_side]) * 1.6
	return p


func _process(delta: float) -> void:
	if board == null:
		return
	var moving := false
	for i in board.count():
		var t := _target(i)
		if _shown[i] != t:
			_shown[i] = _shown[i].move_toward(t, SPEED * delta)
			moving = true
	if board.is_won(state) and not moving and _white_alpha > 0.0:
		_white_alpha = maxf(0.0, _white_alpha - delta * 3.0)
		moving = true
	if moving:
		queue_redraw()


func _layout() -> Dictionary:
	var n := maxi(board.w, board.h)
	var cell := floorf(minf(size.x, size.y) / (n + 0.8))
	var origin := (size - Vector2(board.w, board.h) * cell) / 2.0
	return {"cell": cell, "origin": origin}


func _draw() -> void:
	if board == null:
		return
	var l := _layout()
	var cell: float = l.cell
	var o: Vector2 = l.origin
	var rim := maxf(4.0, cell * 0.12)
	var outer := Rect2(o - Vector2(rim, rim), Vector2(board.w, board.h) * cell + Vector2(rim, rim) * 2)
	draw_rect(outer, WALL)
	draw_rect(Rect2(o, Vector2(board.w, board.h) * cell), BG_BOARD)
	for x in range(1, board.w):
		draw_line(o + Vector2(x * cell, 0), o + Vector2(x * cell, board.h * cell), GRID, 2.0)
	for y in range(1, board.h):
		draw_line(o + Vector2(0, y * cell), o + Vector2(board.w * cell, y * cell), GRID, 2.0)
	_draw_exit(o, cell, rim)
	for p in board.pins:
		var c := o + (Vector2(p) + Vector2(0.5, 0.5)) * cell
		draw_circle(c, cell * 0.22, PIN)
		draw_arc(c, cell * 0.22, 0, TAU, 24, WALL, maxf(2.0, cell * 0.05))
	for i in board.count():
		if i == 0:
			continue
		_draw_piece(i, o, cell, 1.0)
	_draw_piece(0, o, cell, _white_alpha)


func _draw_exit(o: Vector2, cell: float, rim: float) -> void:
	var e := board.exit_cell()
	var r := Rect2()
	match board.exit_side:
		ShiftBoard.Dir.RIGHT:
			r = Rect2(o + Vector2(board.w * cell, e.y * cell), Vector2(rim, cell))
		ShiftBoard.Dir.LEFT:
			r = Rect2(o + Vector2(-rim, e.y * cell), Vector2(rim, cell))
		ShiftBoard.Dir.DOWN:
			r = Rect2(o + Vector2(e.x * cell, board.h * cell), Vector2(cell, rim))
		_:
			r = Rect2(o + Vector2(e.x * cell, -rim), Vector2(cell, rim))
	draw_rect(r, BG_BOARD)
	# a short bright mark just outside the opening
	var step := Vector2(ShiftBoard.STEP[board.exit_side])
	var mid := r.get_center() + step * rim * 1.2
	var across := Vector2(-step.y, step.x)
	draw_line(mid - across * cell * 0.3, mid + across * cell * 0.3, EXIT, maxf(2.0, rim * 0.5))


func _draw_piece(i: int, o: Vector2, cell: float, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var kind := board.kinds[i]
	var length := board.lens[i]
	var sz := Vector2(length, 1) if kind == ShiftBoard.Kind.HBAR else Vector2(1, length) if kind == ShiftBoard.Kind.VBAR else Vector2.ONE
	var pad := cell * 0.08
	var r := Rect2(o + _shown[i] * cell + Vector2(pad, pad), sz * cell - Vector2(pad, pad) * 2)
	var col: Color = [WHITE, BLOCK, HBAR, VBAR][kind]
	col.a = alpha
	var box := StyleBoxFlat.new()
	box.bg_color = col
	box.set_corner_radius_all(int(cell * 0.16))
	box.anti_aliasing = true
	if kind == ShiftBoard.Kind.WHITE:
		box.shadow_color = Color(1, 1, 1, 0.25 * alpha)
		box.shadow_size = int(cell * 0.12)
	draw_style_box(box, r)
	var g := GROOVE
	g.a *= alpha
	var wgt := maxf(2.0, cell * 0.05)
	match kind:
		ShiftBoard.Kind.HBAR: # grooves along its length: it slides left and right
			for k in [0.38, 0.62]:
				var y: float = r.position.y + r.size.y * k
				draw_line(Vector2(r.position.x + cell * 0.25, y), Vector2(r.end.x - cell * 0.25, y), g, wgt)
		ShiftBoard.Kind.VBAR:
			for k in [0.38, 0.62]:
				var x: float = r.position.x + r.size.x * k
				draw_line(Vector2(x, r.position.y + cell * 0.25), Vector2(x, r.end.y - cell * 0.25), g, wgt)
		ShiftBoard.Kind.BLOCK: # a small cross: it slides every way
			var c := r.get_center()
			draw_line(c - Vector2(cell * 0.14, 0), c + Vector2(cell * 0.14, 0), g, wgt)
			draw_line(c - Vector2(0, cell * 0.14), c + Vector2(0, cell * 0.14), g, wgt)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_drag_from = event.position
			_dragging = true
		elif _dragging:
			_dragging = false
			_finish_drag(event.position)
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		# fire as soon as the drag is long enough, so a quick flick feels immediate
		if (event.position - _drag_from).length() >= SWIPE_MIN * 2.0:
			_dragging = false
			_finish_drag(event.position)
		accept_event()


func _finish_drag(to: Vector2) -> void:
	var d := to - _drag_from
	if d.length() < SWIPE_MIN:
		return
	if absf(d.x) > absf(d.y):
		swiped.emit(ShiftBoard.Dir.RIGHT if d.x > 0 else ShiftBoard.Dir.LEFT)
	else:
		swiped.emit(ShiftBoard.Dir.DOWN if d.y > 0 else ShiftBoard.Dir.UP)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
