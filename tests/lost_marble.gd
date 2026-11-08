extends SceneTree
## Lost marble tests (user request, 2026-11-08): embedded marbles must not
## turn into trampolines (low-bounce material), the magnet must damp at
## contact instead of grinding the marble against the embedded one, a stuck
## marble must be lost after ~2 s instead of hanging to the flight timeout,
## and lost marbles (settled or timed out) play the UFO abduction: they rise
## on the world vertical inside a light beam before freeing.
## Run: godot --headless --path . --script res://tests/lost_marble.gd

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
	await _test_embed_material_is_dead()
	await _test_magnet_pulls_at_range()
	await _test_magnet_damps_at_contact()
	await _test_settle_abducts()
	await _test_timeout_abducts()
	await _test_stuck_marble_is_lost_early()
	print("LOST_MARBLE FAIL" if failed else "LOST_MARBLE OK")
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error("LOST_MARBLE FAIL: " + label)
	print("LOST_MARBLE FAIL: " + label)


func _open_board(with_magnet: bool = false) -> Node3D:
	var board: Node3D = (load("res://scenes/board/board.tscn") as PackedScene).instantiate()
	if with_magnet:
		var iman = root.get_node("ContentDB").modifier_def("iman")
		board.modifier_override = [iman] as Array[BoardModifierDef]
	root.add_child(board)
	return board


func _close(board: Node3D) -> void:
	root.remove_child(board)
	board.free()


## A shapeless body: integrates forces and velocity, never collides, so the
## test controls its motion deterministically.
func _ghost_marble(board: Node3D, local: Vector3) -> RigidBody3D:
	var marble := RigidBody3D.new()
	marble.mass = 1.0
	# No gravity: the tests control the motion, the engine must not drift it.
	marble.gravity_scale = 0.0
	board.board.add_child(marble)
	marble.global_position = board.board.to_global(local)
	return marble


# --- (a) An embedded marble is a dead obstacle, not a trampoline -------------

func _test_embed_material_is_dead() -> void:
	var board := _open_board()
	await physics_frame
	var victim := RigidBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	victim.add_child(shape)
	board.board.add_child(victim)
	board._embed(victim, board.holes[0])
	var phys: PhysicsMaterial = victim.physics_material_override
	_check(phys != null, "an embedded marble should carry its own material")
	if phys != null:
		_check(phys.bounce <= 0.2,
				"an embedded marble should barely bounce, got %s" % phys.bounce)
	_close(board)


# --- (b) The magnet pulls at range... ----------------------------------------

func _test_magnet_pulls_at_range() -> void:
	var board := _open_board(true)
	await physics_frame
	var embedded := RigidBody3D.new()
	board.board.add_child(embedded)
	board._embed(embedded, board.holes[0])
	var hole_pos: Vector3 = board.holes[0].pos
	var marble := _ghost_marble(board, hole_pos + Vector3(0.4, 0.1, 0.4))
	board.active_marbles.append(marble)
	board.board_theme._apply_magnet(1.0 / 60.0)
	await physics_frame
	var toward: Vector3 = (board.board.to_global(hole_pos)
			- marble.global_position).normalized()
	_check(marble.linear_velocity.dot(toward) > 0.05,
			"the magnet should pull toward the embedded marble, velocity is %s"
			% marble.linear_velocity)
	_close(board)


# --- (c) ...but damps at contact instead of grinding the marble --------------

func _test_magnet_damps_at_contact() -> void:
	var board := _open_board(true)
	await physics_frame
	var embedded := RigidBody3D.new()
	board.board.add_child(embedded)
	board._embed(embedded, board.holes[0])
	var hole_pos: Vector3 = board.holes[0].pos
	var marble := _ghost_marble(board, hole_pos + Vector3(0.1, 0.05, 0.0))
	board.active_marbles.append(marble)
	marble.linear_velocity = Vector3(0.5, 0, 0)
	board.board_theme._apply_magnet(1.0 / 60.0)
	await physics_frame
	_check(marble.linear_velocity.length() < 0.5,
			"at contact the magnet should damp, velocity is %s"
			% marble.linear_velocity)
	_close(board)


# --- (d) A settled marble is lost with the abduction --------------------------

func _test_settle_abducts() -> void:
	var board := _open_board()
	await physics_frame
	# Keep the capture assist out of the way: this marble rests in the launch
	# band, away from any notch.
	board.board_def.capture_pull = 0.0
	var marble := _ghost_marble(board, Vector3(0.0, 0.05,
			board.board_def.launch_z()))
	board.state = board.ThrowState.FLIGHT
	board.launch_timer = 0.0
	board.active_marbles.append(marble)
	marble.linear_velocity = Vector3.ZERO
	var start_y: float = marble.global_position.y
	# settle_time is 1.2 s: 100 physics frames cover it.
	for i in 110:
		await physics_frame
		if not is_instance_valid(marble):
			break
	_check(not board.active_marbles.has(marble),
			"a settled marble should leave active_marbles at once")
	_check(is_instance_valid(marble),
			"the abduction should keep the marble alive to animate it")
	if is_instance_valid(marble):
		_check(marble.freeze, "an abducted marble should stop simulating")
		var risen_y: float = 0.0
		for i in 20:
			await physics_frame
			risen_y = marble.global_position.y
		_check(risen_y > start_y + 0.2,
				"the marble should rise on the vertical, y %s -> %s"
				% [start_y, risen_y])
	board.board_def.capture_pull = 0.4
	_close(board)


# --- (e) A timed-out volley abducts its leftovers too -------------------------

func _test_timeout_abducts() -> void:
	var board := _open_board()
	await physics_frame
	var marble := _ghost_marble(board, Vector3(0.0, 0.5, 0.0))
	board.state = board.ThrowState.FLIGHT
	board.launch_timer = board.rules.flight_timeout + 0.1
	board.active_marbles.append(marble)
	await physics_frame
	await physics_frame
	_check(board.active_marbles.is_empty(),
			"the timeout should end the volley")
	_check(is_instance_valid(marble),
			"the timeout should abduct the marble, not pop it out of existence")
	if is_instance_valid(marble):
		_check(marble.freeze, "an abducted marble should stop simulating")
	_close(board)


# --- (f) A marble that barely moves is lost after ~2 s, not at the timeout ---

func _test_stuck_marble_is_lost_early() -> void:
	var board := _open_board()
	await physics_frame
	# Above the settle plane so the plain settle rule cannot claim it first:
	# only the stuck detector may resolve this oscillation.
	var marble := _ghost_marble(board, Vector3(0.0, 0.5, 0.0))
	board.state = board.ThrowState.FLIGHT
	board.launch_timer = 0.0
	board.active_marbles.append(marble)
	marble.linear_velocity = Vector3(0.3, 0, 0)
	# ~2.6 s of jitters: the marble wobbles in place faster than the stuck
	# threshold, never settling (velocity keeps reset above settle_speed).
	for i in 155:
		marble.linear_velocity = Vector3(0.3, 0, 0)
		marble.global_position = board.board.to_global(
				Vector3(sin(i * 0.9) * 0.03, 0.5, 0.0))
		await physics_frame
		if not is_instance_valid(marble):
			break
	_check(not board.active_marbles.has(marble),
			"a stuck marble should be lost without waiting for the timeout")
	_check(is_instance_valid(marble),
			"the stuck loss should abduct the marble like any other loss")
	_close(board)
