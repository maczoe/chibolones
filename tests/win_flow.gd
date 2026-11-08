extends SceneTree
## Win-over-board test (user request, 2026-11-08): winning a board must keep
## the live board on screen — GANADOR over the game, then the stats resumen
## over the game — instead of switching to a menu-like full screen, and the
## win overlay must ignore the restart key.
## Run: godot --headless --path . --script res://tests/win_flow.gd

var game
var economy
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
	game = root.get_node("Game")
	economy = root.get_node("Economy")


func _run() -> void:
	await process_frame
	await _test_win_hosts_overlay_on_board()
	await _test_restart_blocked_during_win()
	await _test_restart_still_works_in_play()
	await _test_win_screen_is_translucent()
	print("WIN_FLOW FAIL" if failed else "WIN_FLOW OK")
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error("WIN_FLOW FAIL: " + label)
	print("WIN_FLOW FAIL: " + label)


func _start_run() -> Node3D:
	game.start_run()
	# Headless --script mode has no current scene; the real game runs with
	# the board as current_scene, so the test mirrors that.
	var board: Node3D = (load("res://scenes/board/board.tscn") as PackedScene).instantiate()
	root.add_child(board)
	current_scene = board
	return board


## Win the board through the real seam (embed event -> ScoreEngine ->
## resting marble in flight -> _run_win_reached), like tests/run_loop.gd.
func _win_the_board() -> Node3D:
	var board := _start_run()
	await physics_frame
	root.get_node("EventBus").embed.emit(0, board.run_objective)
	board.state = board.ThrowState.FLIGHT
	board.launch_timer = 0.0
	board.active_marbles.append(_resting_marble(board))
	await physics_frame
	await physics_frame
	return board


func _resting_marble(board: Node3D) -> RigidBody3D:
	var marble := RigidBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	marble.add_child(shape)
	marble.freeze = true
	board.board.add_child(marble)
	marble.global_position = board.board.to_global(
			Vector3(0.0, 0.09, board.board_def.launch_z() + 0.4))
	return marble


func _find_win_screen(node: Node) -> Control:
	var script: Script = node.get_script()
	if script != null and str(script.resource_path).ends_with("win_screen.gd"):
		return node
	for child in node.get_children():
		var found := _find_win_screen(child)
		if found != null:
			return found
	return null


func _discard(board: Node3D) -> void:
	current_scene = null
	board.queue_free()
	await process_frame
	game.run_active = false


# --- (a) Winning keeps the board and hosts the overlay on it -----------------

func _test_win_hosts_overlay_on_board() -> void:
	var board := await _win_the_board()
	_check(game.phase == game.Phase.WIN,
			"a won board should enter the win phase, phase is %s" % game.phase)
	_check(is_instance_valid(board) and board.is_inside_tree(),
			"the board should stay in the tree behind the win overlay")
	var overlay := _find_win_screen(board)
	_check(overlay != null,
			"the board should host the win screen as an overlay")
	if overlay != null:
		_check(overlay.get_parent() is CanvasLayer,
				"the overlay should sit in its own CanvasLayer over the HUD")
		# TITLE_DELAY is 2.5 s: after it the resumen shows over the game.
		await create_timer(2.7).timeout
		_check(overlay.stats_box.visible,
				"the resumen should appear over the live board after the title beat")
		_check(root.gui_get_focus_owner() == overlay.continue_button,
				"the resumen should hand focus to CONTINUAR")
	_check(current_scene == board,
			"the scene must not switch while the overlay plays")
	await _discard(board)


# --- (b) No controls behind the overlay: R must not reload the board ---------

func _test_restart_blocked_during_win() -> void:
	var board := await _win_the_board()
	var restart := InputEventAction.new()
	restart.action = "restart"
	restart.pressed = true
	board._unhandled_input(restart)
	await process_frame
	_check(current_scene == board and board.is_inside_tree(),
			"restart must not reload the board during the win overlay")
	await _discard(board)


# --- (b2) The restart key keeps working outside the win overlay --------------

func _test_restart_still_works_in_play() -> void:
	# Shared-path pin: the win gate must only silence R while the win overlay
	# plays. Normal play reloads the board, exactly as before the change.
	var board := _start_run()
	await physics_frame
	_check(game.phase == game.Phase.BOARD,
			"the run should start in the board phase, got %s" % game.phase)
	var restart := InputEventAction.new()
	restart.action = "restart"
	restart.pressed = true
	board._unhandled_input(restart)
	await process_frame
	await process_frame
	_check(current_scene != board or not is_instance_valid(board),
			"restart during normal play should still reload the board")
	current_scene = null
	game.run_active = false


# --- (c) The win screen shows the game behind it ------------------------------

func _test_win_screen_is_translucent() -> void:
	var win: Control = (load("res://scenes/run/win.tscn") as PackedScene).instantiate()
	root.add_child(win)
	await process_frame
	var background: ColorRect = null
	for child in win.get_children():
		if child is ColorRect:
			background = child
	_check(background != null, "the win screen should keep a dim background")
	if background != null:
		_check(background.color.a < 0.7,
				"the win background must let the live board read through, "
				+ "alpha is %s" % background.color.a)
	win.queue_free()
	await process_frame
