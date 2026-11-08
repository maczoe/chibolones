extends SceneTree
## Tilt acceleration test (user request, 2026-11-08): the direction step of
## the throw must support fine adjustment without a mouse. Keys accelerate
## by held time, the gamepad axis scales the speed analogically, reversing
## or releasing resets the ramp, and the shot angle reaches a wider range
## than the wall-derived limits.
## Run: godot --headless --path . --script res://tests/shooting_tilt.gd

var failed := false


func _initialize() -> void:
	_ensure_autoloads()
	_run()


## In --script mode Godot does not register project autoloads (same as
## tests/pause.gd).
func _ensure_autoloads() -> void:
	var autoloads := [
		["EventBus", "res://autoload/event_bus.gd"],
		["ContentDB", "res://autoload/content_db.gd"],
		["Economy", "res://autoload/economy.gd"],
		["Game", "res://autoload/game.gd"],
	]
	for entry in autoloads:
		if not root.has_node(entry[0]):
			var node: Node = (load(entry[1]) as GDScript).new()
			node.name = entry[0]
			root.add_child(node)


func _run() -> void:
	await process_frame
	await _test_rules_fields()
	await _test_speed_curve()
	await _test_board_tilt_motion()
	await _test_wider_limits()
	_release_all()
	print("SHOOTING_TILT FAIL" if failed else "SHOOTING_TILT OK")
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error("SHOOTING_TILT FAIL: " + label)
	print("SHOOTING_TILT FAIL: " + label)


func _rules():
	return root.get_node("ContentDB").rules()


func _open_board() -> Node3D:
	var board: Node3D = (load("res://scenes/board/board.tscn") as PackedScene).instantiate()
	root.add_child(board)
	return board


func _close(board: Node3D) -> void:
	root.remove_child(board)
	board.free()


func _release_all() -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")


func _approx(a: float, b: float) -> bool:
	return absf(a - b) <= 0.01


# --- (a) The rules carry the acceleration and range fields -------------------

func _test_rules_fields() -> void:
	var rules = _rules()
	_check(rules.tilt_speed_min > 0.0 and rules.tilt_speed_min < rules.tilt_speed,
			"tilt_speed_min must sit between 0 and tilt_speed, got %s" % rules.tilt_speed_min)
	_check(rules.tilt_accel_time > 0.0,
			"tilt_accel_time must be positive, got %s" % rules.tilt_accel_time)
	_check(rules.tilt_range_mult > 1.0,
			"tilt_range_mult must widen the angle (over 1.0), got %s" % rules.tilt_range_mult)


# --- (b) The speed curve: fine at the start, full speed when held ------------

func _test_speed_curve() -> void:
	var rules = _rules()
	_check(_approx(rules.tilt_frame_speed(1.0, 0.0), rules.tilt_speed_min),
			"a fresh press should move at tilt_speed_min, got %s"
			% rules.tilt_frame_speed(1.0, 0.0))
	_check(_approx(rules.tilt_frame_speed(1.0, 999.0), rules.tilt_speed),
			"a long hold should reach tilt_speed, got %s"
			% rules.tilt_frame_speed(1.0, 999.0))
	var quarter: float = rules.tilt_frame_speed(1.0, rules.tilt_accel_time * 0.25)
	var half: float = rules.tilt_frame_speed(1.0, rules.tilt_accel_time * 0.5)
	_check(quarter > rules.tilt_speed_min and half > quarter and half < rules.tilt_speed,
			"the ramp should grow monotonically: %s < %s < %s" %
			[rules.tilt_speed_min, quarter, half])
	_check(_approx(rules.tilt_frame_speed(0.5, 999.0), rules.tilt_speed * 0.5),
			"a half analog stick should move at half speed, got %s"
			% rules.tilt_frame_speed(0.5, 999.0))


# --- (c) Board behavior: keys ramp, reversing resets the ramp ----------------

func _tilt_board() -> Node3D:
	var board := _open_board()
	await physics_frame
	board._begin_tilt()
	return board


func _test_board_tilt_motion() -> void:
	var board := await _tilt_board()
	_release_all()
	# Screen directions: pressing right leans the guide right (negative
	# tilt), matching the arrows the player sees.
	var step := 1.0 / 60.0
	Input.action_press("move_right")
	var first_tilt: float = board.shot_tilt
	board._physics_process(step)
	var lean_right: float = board.shot_tilt
	_check(lean_right < first_tilt,
			"pressing right should lean the guide right, tilt %s -> %s"
			% [first_tilt, lean_right])
	for i in 30:
		board._physics_process(step)
	# Mid-ramp: 0.5 s of holding must already move a single frame much
	# faster than the fine speed of a fresh press.
	var tilt_late: float = board.shot_tilt
	board._physics_process(step)
	var speed_late: float = absf(board.shot_tilt - tilt_late) / step
	_check(speed_late > _rules().tilt_speed_min * 2.0,
			"holding should accelerate well past tilt_speed_min, got %s deg/s" % speed_late)
	# Reversing must drop the speed back to the fine zone and lean back.
	var tilt_at_reverse: float = board.shot_tilt
	Input.action_release("move_right")
	Input.action_press("move_left")
	board._physics_process(step)
	var lean_left: float = board.shot_tilt
	_check(lean_left > tilt_at_reverse,
			"pressing left should lean the guide back, tilt %s -> %s"
			% [tilt_at_reverse, lean_left])
	var speed_reverse: float = absf(board.shot_tilt - tilt_at_reverse) / step
	_check(speed_reverse <= _rules().tilt_speed_min + 0.01,
			"reversing should restart the ramp at tilt_speed_min, got %s deg/s" % speed_reverse)
	_release_all()
	board._physics_process(step)
	board._physics_process(step)
	_check(is_equal_approx(absf(board.shot_tilt - lean_left), 0.0),
			"releasing should stop the guide")
	_close(board)


# --- (d) The angle range is wider than the wall-derived limits ---------------

func _test_wider_limits() -> void:
	var board := await _tilt_board()
	_release_all()
	var rules = _rules()
	var def = board.board_def
	var dist_to_far: float = def.length / 2.0 - def.launch_z()
	var side_margin: float = def.width / 2.0 - def.aim_limit_margin
	var wall_deg: float = rad_to_deg(atan(side_margin / dist_to_far))
	_check(board.tilt_max_right > wall_deg * 1.2,
			"the tilt range should be clearly wider than the wall angle "
			+ "(%s vs %s)" % [board.tilt_max_right, wall_deg])
	# S5 (user request, 2026-11-08): 120 degrees of total cone, so a fresh
	# aim at the center reaches the full 60 degrees per side.
	var expected_deg: float = rules.tilt_max_deg
	var got := "%s / %s" % [board.tilt_max_left, board.tilt_max_right]
	_check(_approx(board.tilt_max_left, expected_deg)
				and _approx(board.tilt_max_right, expected_deg),
			"the center aim should reach the full %s degrees per side, got %s"
			% [expected_deg, got])
	_check(board.tilt_max_right <= rules.tilt_max_deg,
			"the guide must never exceed the rules cap, got %s"
			% board.tilt_max_right)
	_release_all()
	_close(board)
