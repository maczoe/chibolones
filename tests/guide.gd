extends SceneTree
## Controls-guide gating test: the board no longer announces the controls
## guide at start and the per-step hints stay hidden during normal play;
## they come back after 20 s of idle (or for the tutorial flag).
## Run: godot --headless --path . --script res://tests/guide.gd

var content
var failed := false


func _initialize() -> void:
	_ensure_autoloads()
	_run()


## In --script mode Godot does not register project autoloads; install the
## ones under test in dependency order (same as tests/hooks.gd).
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
	content = root.get_node("ContentDB")


func _run() -> void:
	await physics_frame
	await _test_no_opening_controls_hint()
	await _test_idle_brings_guide_back()
	await _test_step_hints_stay_hidden()
	print("GUIDE FAIL" if failed else "GUIDE OK")
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error("GUIDE FAIL: " + label)
	print("GUIDE FAIL: " + label)


func _open_board() -> Node3D:
	var board: Node3D = (load("res://scenes/board/board.tscn") as PackedScene).instantiate()
	root.add_child(board)
	return board


func _close(board: Node3D) -> void:
	root.remove_child(board)
	board.free()


# --- (a) The opening announcements never carry the controls line -----------

func _test_no_opening_controls_hint() -> void:
	var board := _open_board()
	await physics_frame
	# The announcement queue drains 1.2 s per line, so collect every text
	# that reaches the HUD until it is done (~2.7 s) and audit them all.
	var seen := {}
	for i in 160:
		seen[board.hud.label_msg.text] = true
		await physics_frame
	var texts: Array = seen.keys()
	_check(texts.any(func(t): return t.contains("Tablero")),
			"the board should still announce its name, saw %s" % [texts])
	for text in texts:
		_check(not text.contains("ESPACIO"),
				"no opening cue should teach controls, found '%s'" % text)
	_close(board)


# --- (b) 20 idle seconds in AIM show the controls guide once ----------------

func _test_idle_brings_guide_back() -> void:
	var board := _open_board()
	await physics_frame
	var hud = board.hud
	hud.label_msg.text = ""
	# Simulate the idle clock directly: 20 s in AIM without actions.
	board.idle_time = board.GUIDE_IDLE_SECONDS
	board._tick_idle(0.016)
	_check(board.idle_guide_shown,
			"20 idle seconds should mark the guide as shown")
	_check(hud.label_msg.text.contains("ESPACIO"),
			"the idle guide should show the controls, shows '%s'"
			% hud.label_msg.text)
	# One guide per idle episode: a second tick does not repeat the flash.
	hud.label_msg.text = ""
	board._tick_idle(0.016)
	_check(hud.label_msg.text == "",
			"the idle guide should not repeat until the next input")
	# Any action resets the episode: the guide hides again for 20 s.
	Input.action_press("shoot")
	board._tick_idle(0.016)
	Input.action_release("shoot")
	_check(not board.idle_guide_shown and is_equal_approx(board.idle_time, 0.0),
			"an active input should reset the idle episode")
	_close(board)


# --- (c) Per-step hints stay hidden during normal play -----------------------

func _test_step_hints_stay_hidden() -> void:
	var board := _open_board()
	await physics_frame
	var hud = board.hud
	# Normal play: no idle episode yet, no tutorial -> the tilt hint is silent.
	hud.label_msg.text = ""
	board.shots_left = 3
	board._begin_tilt()
	_check(hud.label_msg.text == "",
			"the tilt hint should stay hidden during normal play")
	# The tutorial flag turns the same hint on.
	board.tutorial_mode = true
	board.state = board.ThrowState.AIM
	board.shots_left = 3
	board._begin_tilt()
	_check(hud.label_msg.text.contains("Inclina"),
			"tutorial mode should show the tilt hint, shows '%s'"
			% hud.label_msg.text)
	_close(board)
