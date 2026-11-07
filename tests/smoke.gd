extends SceneTree
## Headless smoke test: drives the real main scene through a full round of
## 5 shots using synthetic input (tilt -> power -> throw), then checks the
## round resolves to a game-over state with a consistent score.
## Run: godot --headless --path . --script res://tests/smoke.gd

var main: Node3D


func _initialize() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	_run()


func _run() -> void:
	await _frames(5)
	# Refunds (marble exits by the player's edge) do not consume the shot,
	# so drive attempts until the round actually spends all 5 shots.
	var attempts := 0
	while main.shots_left > 0 and attempts < 40:
		attempts += 1
		# Move the aim sideways a little on every shot so covers differ.
		Input.action_press("move_right")
		await _frames(10)
		Input.action_release("move_right")
		_tap("shoot")
		await _frames(3)
		if main.state != main.State.TILT:
			return _fail("expected TILT after first space press (attempt %d)" % attempts)
		_tap("shoot")
		await _frames(3)
		if main.state != main.State.POWER:
			return _fail("expected POWER after second space press (attempt %d)" % attempts)
		await _frames(20)  # about 36% power
		_tap("shoot")
		await _frames(3)
		if main.state != main.State.FLIGHT:
			return _fail("expected FLIGHT after third space press (attempt %d)" % attempts)
		if main.active_marbles.size() != 1:
			return _fail("expected 1 active marble after launch (attempt %d)" % attempts)
		var t := 0
		while main.state == main.State.FLIGHT and t < 1200:
			await _frames(1)
			t += 1
			if t % 600 == 0:
				print("  attempt %d t=%d state=%d active=%d launch_timer=%.2f" % [
					attempts, t, main.state, main.active_marbles.size(), main.launch_timer])
		if main.shots_left == 0:
			if main.state != main.State.GAME_OVER:
				return _fail("expected GAME_OVER after the last shot (attempt %d), got state=%d" % [attempts, main.state])
		elif main.state != main.State.AIM:
			return _fail("flight did not resolve back to AIM (attempt %d), state=%d" % [attempts, main.state])
		print("attempt %d done, shots_left = %d, score = %d" % [
			attempts, main.shots_left, main.total_score])
	if main.shots_left != 0:
		return _fail("expected 0 shots left after %d attempts, got %d" % [attempts, main.shots_left])
	if main.state != main.State.GAME_OVER:
		return _fail("expected GAME_OVER, got state %d" % main.state)
	if main.total_score < 0:
		return _fail("negative score")
	print("SMOKE OK: final score = %d (attempts = %d)" % [main.total_score, attempts])
	quit(0)


func _frames(n: int) -> void:
	for i in n:
		if i == 0:
			await physics_frame
			continue
		await physics_frame


func _tap(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)


func _fail(reason: String) -> void:
	push_error("SMOKE FAIL: " + reason)
	print("SMOKE FAIL: " + reason)
	quit(1)
