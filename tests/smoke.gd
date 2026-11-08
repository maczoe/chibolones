extends SceneTree
## Headless smoke test: drives the real board scene through a full round of
## 5 shots using synthetic input (aim -> tilt -> power -> throw), checks the
## round resolves to a round-over state with a consistent score, and that
## the EventBus embed events match the ScoreEngine total and the occupied
## notches.
## Run: godot --headless --path . --script res://tests/smoke.gd

var board: Node3D
var embeds: Array = []           # [notch_index, value] pairs seen on the bus
var ended_outcomes: Array = []


func _initialize() -> void:
	_ensure_autoloads()
	board = (load("res://scenes/board/board.tscn") as PackedScene).instantiate()
	root.add_child(board)
	var bus := root.get_node("EventBus")
	bus.embed.connect(func(index, value): embeds.append([index, value]))
	bus.throw_ended.connect(func(outcome): ended_outcomes.append(outcome))
	_run()


## In --script mode Godot does not register project autoloads; install the
## ones the board scene expects, in dependency order.
func _ensure_autoloads() -> void:
	var autoloads := {
		"EventBus": "res://autoload/event_bus.gd",
		"ContentDB": "res://autoload/content_db.gd",
		"Game": "res://autoload/game.gd",
	}
	for name in autoloads:
		if not root.has_node(name):
			var node: Node = (load(autoloads[name]) as GDScript).new()
			node.name = name
			root.add_child(node)


func _run() -> void:
	await _frames(5)
	# Refunds (marble exits by the player's edge) do not consume the shot,
	# so drive attempts until the round actually spends all 5 shots.
	var attempts := 0
	while board.shots_left > 0 and attempts < 40:
		attempts += 1
		# Exercise camera mode once: enter, pan, exit, and confirm the
		# camera returns to its base spot and the round still flows.
		if attempts == 2:
			_tap("camera_mode")
			await _frames(3)
			if board.state != board.ThrowState.CAMERA:
				return _fail("expected CAMERA after Z press")
			Input.action_press("move_right")
			Input.action_press("move_up")
			await _frames(10)
			Input.action_release("move_right")
			Input.action_release("move_up")
			if board.cam_offset == Vector2.ZERO:
				return _fail("camera mode pan did not move the camera")
			_tap("camera_mode")
			await _frames(3)
			if board.state != board.ThrowState.AIM:
				return _fail("expected AIM after leaving camera mode")
			if board.cam_offset != Vector2.ZERO or board.cam.position != board.cam_base_pos:
				return _fail("camera did not return to its base spot")
		# Move the aim sideways a little on every shot so covers differ.
		Input.action_press("move_right")
		await _frames(10)
		Input.action_release("move_right")
		_tap("shoot")
		await _frames(3)
		if board.state != board.ThrowState.TILT:
			return _fail("expected TILT after first space press (attempt %d)" % attempts)
		_tap("shoot")
		await _frames(3)
		if board.state != board.ThrowState.POWER:
			return _fail("expected POWER after second space press (attempt %d)" % attempts)
		await _frames(20)  # about 36% power
		_tap("shoot")
		await _frames(3)
		if board.state != board.ThrowState.FLIGHT:
			return _fail("expected FLIGHT after third space press (attempt %d)" % attempts)
		# Wait for the throw to resolve (back to AIM or round over).
		var waited := 0
		while board.state == board.ThrowState.FLIGHT and waited < 1200:
			await _frames(1)
			waited += 1
		if board.state == board.ThrowState.FLIGHT:
			return _fail("throw never resolved (attempt %d)" % attempts)
	if board.shots_left != 0:
		return _fail("round did not spend all shots (attempts=%d, shots_left=%d)" % [attempts, board.shots_left])
	if board.state != board.ThrowState.ROUND_OVER:
		return _fail("expected ROUND_OVER at the end, got %s" % board.state)
	# Score consistency: engine total == sum of embed events on the bus,
	# and every embed occupied a distinct notch.
	var engine_total: int = board.score_engine.total
	var bus_total := 0
	for e in embeds:
		bus_total += e[1]
	if engine_total != bus_total:
		return _fail("score engine total %d != event bus embed sum %d" % [engine_total, bus_total])
	var occupied := 0
	for h in board.holes:
		if h.occupied:
			occupied += 1
	if occupied != embeds.size():
		return _fail("occupied notches %d != embed events %d" % [occupied, embeds.size()])
	print("SMOKE OK: score=%d, embeds=%d, outcomes=%s, attempts=%d" % [
			engine_total, embeds.size(), str(ended_outcomes), attempts])
	quit(0)


func _tap(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _fail(msg: String) -> void:
	print("SMOKE FAIL: " + msg)
	quit(1)
