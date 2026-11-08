extends SceneTree
## Pause menu test (user request, 2026-11-08): ESC / Start opens the pause
## overlay and pauses the tree; CONTINUAR unpauses; REINICIAR RUN exists
## only for normal runs and restarts from board 1; MENU PRINCIPAL lands on
## the title. Also pins the input map: Start is pause, not restart.
## Run: godot --headless --path . --script res://tests/pause.gd

var game
var failed := false


func _initialize() -> void:
	_ensure_autoloads()
	_run()


## In --script mode Godot does not register project autoloads (same as
## tests/hooks.gd).
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


func _run() -> void:
	await physics_frame
	await _test_pause_opens_and_resumes()
	await _test_restart_only_in_runs()
	await _test_handlers()
	_test_input_map()
	print("PAUSE FAIL" if failed else "PAUSE OK")
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error("PAUSE FAIL: " + label)
	print("PAUSE FAIL: " + label)


func _open_board() -> Node3D:
	var board: Node3D = (load("res://scenes/board/board.tscn") as PackedScene).instantiate()
	root.add_child(board)
	return board


func _overlay(board: Node3D) -> Node:
	var overlay: Node = board.get_node_or_null("PauseMenu")
	_check(overlay != null, "pausing should add the PauseMenu overlay")
	return overlay


# --- (a) Pause opens the overlay and resumes --------------------------------

func _test_pause_opens_and_resumes() -> void:
	var board := _open_board()
	await physics_frame
	_check(not paused, "the tree should start unpaused")
	board._toggle_pause()
	_check(paused, "pausing should pause the tree")
	var overlay := _overlay(board)
	# A second pause request must not stack a second overlay.
	board._toggle_pause()
	var overlays := 0
	for child in board.get_children():
		if child.name == "PauseMenu":
			overlays += 1
	_check(overlays == 1, "pausing twice should keep one overlay, has %d" % overlays)
	overlay._resume()
	_check(not paused, "CONTINUAR should unpause the tree")
	_check(overlay.is_queued_for_deletion(), "CONTINUAR should close the overlay")
	_close(board)


# --- (b) REINICIAR RUN exists only for normal runs ---------------------------

func _test_restart_only_in_runs() -> void:
	var board := _open_board()
	await physics_frame
	board._toggle_pause()
	var overlay := _overlay(board)
	var restart: Button = overlay.restart_button
	_check(restart != null and restart.visible,
			"a normal run should offer REINICIAR RUN")
	overlay._resume()
	await physics_frame  # let queue_free flush before the next overlay
	# Debug matches are single boards: no run to restart.
	game.debug_mode = true
	board._toggle_pause()
	overlay = _overlay(board)
	_check(not overlay.restart_button.visible,
			"a debug match should hide REINICIAR RUN")
	overlay._resume()
	await physics_frame  # let queue_free flush before the next overlay
	game.debug_mode = false
	_close(board)


# --- (c) Restart goes to board 1 of a fresh run; menu lands on MENU  --------

func _test_handlers() -> void:
	var board := _open_board()
	await physics_frame
	board._toggle_pause()
	var overlay := _overlay(board)
	overlay._restart_run()
	_check(not paused, "restarting should unpause the tree")
	_check(game.phase == game.Phase.BOARD and game.run_active,
			"REINICIAR RUN should start a fresh run, phase is %s" % game.phase)
	_check(game.current_board_in_run == 1,
			"REINICIAR RUN should restart from board 1, got board %d"
			% game.current_board_in_run)
	_check(game.inventory.size() == 5,
			"the restarted run should own the 5 starting marbles")
	overlay._go_to_menu()
	_check(not paused, "going to the menu should unpause the tree")
	_check(game.phase == game.Phase.MENU and not game.run_active,
			"MENU PRINCIPAL should land on the title, phase is %s" % game.phase)
	overlay.queue_free()
	_close(board)


# --- (d) Input map: Start is pause, restart lost the Start button ------------

func _test_input_map() -> void:
	# A finished debug match must route back to the debug setup, not the
	# title (user request, 2026-11-08); headless cannot switch scenes, so
	# pin the routing constant.
	_check(game.DEBUG_SETUP_SCENE == "res://scenes/debug/debug_setup.tscn",
			"a finished debug match should route back to the debug setup")
	var pause_events := InputMap.action_get_events("pause")
	_check(pause_events.size() == 2,
			"pause should bind ESC and Start, has %d events" % pause_events.size())
	var pause_start := false
	for event in pause_events:
		if event is InputEventJoypadButton and event.button_index == 6:
			pause_start = true
	_check(pause_start, "pause should bind the gamepad Start button")
	for event in InputMap.action_get_events("restart"):
		if event is InputEventJoypadButton and event.button_index == 6:
			_check(false, "restart must not keep the Start button; Start pauses now")


func _close(board: Node3D) -> void:
	root.remove_child(board)
	board.free()
