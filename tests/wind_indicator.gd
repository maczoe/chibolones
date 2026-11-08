extends SceneTree
## Wind indicator test (user request, 2026-11-08): on Ventoso boards the
## backdrop shader shows flowing chevron arrows that appear at the start of
## every turn pointing where the marble will drift, and fade out at launch.
## Run: godot --headless --path . --script res://tests/wind_indicator.gd

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
	await _test_wind_board_shows_arrows_at_start()
	await _test_plain_board_stays_quiet()
	await _test_arrows_fade_at_launch_and_flip_next_turn()
	await _test_upcoming_direction_flips_with_the_throw()
	print("WIND_INDICATOR FAIL" if failed else "WIND_INDICATOR OK")
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error("WIND_INDICATOR FAIL: " + label)
	print("WIND_INDICATOR FAIL: " + label)


func _open_board(modifier_id: String = "") -> Node3D:
	var board: Node3D = (load("res://scenes/board/board.tscn") as PackedScene).instantiate()
	if modifier_id != "":
		var def = root.get_node("ContentDB").modifier_def(modifier_id)
		board.modifier_override = [def] as Array[BoardModifierDef]
	root.add_child(board)
	return board


func _close(board: Node3D) -> void:
	root.remove_child(board)
	board.free()


func _arrow_param(board: Node3D, param: StringName) -> float:
	# get_shader_parameter returns null until the material sets the param;
	# an unset param means the shader default (arrows off = 0.0).
	var value: Variant = board.backdrop_arrows_mat.get_shader_parameter(param)
	return 0.0 if value == null else float(value)


# --- (a) A wind board opens its first turn with the arrows on ----------------

func _test_wind_board_shows_arrows_at_start() -> void:
	var board := _open_board("ventoso")
	await physics_frame
	_check(board.backdrop_arrows_mat != null,
			"the board should expose the backdrop arrow material")
	if board.backdrop_arrows_mat != null:
		_check(_arrow_param(board, "wind_arrow") > 0.5,
				"turn start should show the arrows, intensity is %s"
				% _arrow_param(board, "wind_arrow"))
		# The upcoming throw flips the stored side: at board start the stored
		# side is +1, so the first throw drifts toward -1.
		_check(_arrow_param(board, "wind_dir")
						== board.board_theme.upcoming_wind_direction(),
				"the arrows should point where the next throw will drift")
	_close(board)


# --- (b) Boards without wind never show arrows -------------------------------

func _test_plain_board_stays_quiet() -> void:
	var board := _open_board()
	await physics_frame
	_check(_arrow_param(board, "wind_arrow") == 0.0,
			"a board without wind should keep the arrows off, got %s"
			% _arrow_param(board, "wind_arrow"))
	_close(board)


# --- (c) Launching fades the arrows; the next turn flips their direction -----

func _test_arrows_fade_at_launch_and_flip_next_turn() -> void:
	var board := _open_board("ventoso")
	await physics_frame
	var dir_before: float = _arrow_param(board, "wind_dir")
	board._launch(0.0, 50.0)
	# Tweens tick on process frames, not physics frames.
	for i in 8:
		await process_frame
		await physics_frame
	_check(_arrow_param(board, "wind_arrow") < 1.0,
			"launching should fade the arrows out, intensity is %s"
			% _arrow_param(board, "wind_arrow"))
	# Resolve the volley: free the flying marble so the board returns to AIM.
	for marble in board.active_marbles.duplicate():
		board._discard_marble(marble)
	await physics_frame
	await physics_frame
	_check(board.state == board.ThrowState.AIM,
			"the board should be back to AIM, state is %s" % board.state)
	_check(_arrow_param(board, "wind_arrow") > 0.5,
			"the next turn should show the arrows again, intensity is %s"
			% _arrow_param(board, "wind_arrow"))
	_check(_arrow_param(board, "wind_dir") == -dir_before,
			"the next turn should flip the arrow direction, %s -> %s"
			% [dir_before, _arrow_param(board, "wind_dir")])
	_close(board)


# --- (d) The upcoming direction is the flip of the stored side ----------------

func _test_upcoming_direction_flips_with_the_throw() -> void:
	var board := _open_board("ventoso")
	await physics_frame
	var stored: float = board.board_theme.wind_direction
	_check(board.board_theme.upcoming_wind_direction() == -stored,
			"the upcoming throw should drift opposite to the stored side")
	board.board_theme.on_throw_started()
	_check(board.board_theme.wind_direction == -stored,
			"the launch should flip the stored side")
	_check(board.board_theme.upcoming_wind_direction() == stored,
			"the following throw should drift back")
	_close(board)
