extends SceneTree
## Run-board endings: a run board must always reach a verdict. Winning shows
## the win sequence over the live board; running out of marbles under the
## objective shows the run summary. Neither may leave the board waiting.
## Run: godot --headless --path . --script res://tests/run_end.gd

var game
var failed := false
var checks_run := 0


func _initialize() -> void:
	_ensure_autoloads()
	_run()


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
	await _test_winning_a_run_board_shows_the_win_sequence()
	await _test_win_survives_the_throw_ending_right_after_it()
	await _test_losing_a_run_board_shows_the_summary()
	await _test_the_board_can_explain_why_it_did_not_report()
	# A GDScript error aborts one test function without touching `failed`, so a
	# suite would print OK with tests that never ran. The count is deterministic,
	# so the exact full-pass total is the guard: one dead test always fails here.
	# Adding a test means bumping this number with it.
	_check(checks_run >= 24, "only %d checks ran: a test died before asserting" % checks_run)
	print("RUN END FAIL" if failed else "RUN END OK")
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	checks_run += 1
	if condition:
		return
	failed = true
	print("RUN END FAIL: " + label)


## The board the run renders, hosted as the current scene like the real game
## (tests/win_flow.gd does the same).
func _open_run_board() -> Node3D:
	game.start_run()
	var board: Node3D = load("res://scenes/board/board.tscn").instantiate()
	root.add_child(board)
	current_scene = board
	return board


## Reaching the objective mid-flight wins: the win sequence plays over the live
## board and the phase leaves BOARD. A win the game forgets to show is the
## softlock the player sees as "I can't win and I can't lose".
func _test_winning_a_run_board_shows_the_win_sequence() -> void:
	var board := _open_run_board()
	await physics_frame
	_check(board._inventory_mode(), "a run board runs in inventory mode")
	_check(board.objective_state != null, "a run board must carry an objective")
	var target: int = board.run_objective
	board.score_engine.total = target
	board._on_score_changed(target)
	await physics_frame
	await physics_frame
	_check(board.board_result_sent, "reaching the objective should report the board result")
	_check(
		board.state == board.ThrowState.ROUND_OVER,
		"a won board stops taking throws, state is %s" % board.state
	)
	_check(
		game.phase == game.Phase.WIN,
		"a won run board enters the WIN phase, phase is %s" % game.phase
	)
	_check(board.win_overlay != null, "the win sequence must be on screen over the board")
	board.queue_free()
	current_scene = null
	await physics_frame
	game.enter_menu()
	await physics_frame


## Running out of marbles under the objective ends the run: the phase moves to
## RESULT and the summary is on screen. This is the other half of "I can't win
## and I can't lose".
func _test_losing_a_run_board_shows_the_summary() -> void:
	var board := _open_run_board()
	await physics_frame
	board.score_engine.total = 0
	board.shots_left = 0
	board._round_over()
	await physics_frame
	await physics_frame
	_check(board.board_result_sent, "a lost board should report its result")
	_check(
		game.phase == game.Phase.RESULT,
		"a lost run board enters the RESULT phase, phase is %s" % game.phase
	)
	_check(not game.run_active, "a lost run board closes the run")
	_check(
		board.result_overlay != null,
		"the run summary must be on screen over the board (or the scene switched)"
	)
	board.queue_free()
	current_scene = null
	await physics_frame
	game.enter_menu()
	await physics_frame


## S21: the playtest report "en la run ahora no se puede ganar ni perder" lives
## in state no test reproduces, so the board prints one diagnostic line at its
## start and one when the round ends (debug builds only). The line carries every
## condition that decides whether the board reports its result: the run phase,
## the run flag, the throw mode, the objective, the shot counters, the ammo and
## whether the result was already sent. No behavior depends on it.
func _test_the_board_can_explain_why_it_did_not_report() -> void:
	var board := _open_run_board()
	await physics_frame
	var line: String = board._diag_line("start")
	for field in [
		"phase=",
		"run_active=",
		"inventory_mode=",
		"objective=",
		"shots=",
		"ammo=",
		"result_sent=",
	]:
		_check(line.contains(field), "the diagnostic should carry '%s', got '%s'" % [field, line])
	_check(
		line.contains("run_active=true"),
		"a run board should report run_active=true, got '%s'" % line
	)
	_check(
		line.contains("inventory_mode=true"),
		"a run board should report inventory_mode=true, got '%s'" % line
	)
	_check(
		line.contains("objective=set"),
		"a run board should report its objective as set, got '%s'" % line
	)
	_check(
		line.contains("shots=%d/%d" % [board.shots_left, board.shots_total]),
		"the diagnostic should carry the live throw counters, got '%s'" % line
	)
	_check(
		line.contains("ammo=%d" % game.ammo.size()),
		"the diagnostic should carry the live ammo, got '%s'" % line
	)
	_check(
		line.contains("result_sent=false"),
		"a fresh board should report no result yet, got '%s'" % line
	)
	board.board_result_sent = true
	_check(
		board._diag_line("end").contains("result_sent=true"),
		"the round-end line should name an already reported result"
	)
	board.board_result_sent = false
	board.queue_free()
	current_scene = null
	await physics_frame
	game.enter_menu()
	await physics_frame


## The reported softlock (user playtest, 2026-11-21): the win fires on the
## scoring embed, the same throw then resolves and the board returns to AIM
## before the deferred board_won runs, so the overlay host sees a board that is
## no longer ROUND_OVER, refuses, and the phase still moves to WIN. The result
## is a live board, the WIN phase, and nothing on screen.
func _test_win_survives_the_throw_ending_right_after_it() -> void:
	var board := _open_run_board()
	await physics_frame
	var target: int = board.run_objective
	board.score_engine.total = target
	board._on_score_changed(target)
	# Same frame: the flight loop keeps running with no marble left, and its
	# tail used to hand the turn back to the player (the log's score 60 -> 130).
	board.state = board.ThrowState.FLIGHT
	await physics_frame
	await physics_frame
	_check(game.phase == game.Phase.WIN, "the phase should be WIN, is %s" % game.phase)
	_check(
		board.state == board.ThrowState.ROUND_OVER,
		"a won board must not hand the turn back, state is %s" % board.state
	)
	_check(
		board.win_overlay != null or current_scene != board,
		"the win sequence must reach the screen even when the throw ended after the win"
	)
	board.queue_free()
	current_scene = null
	await physics_frame
	game.enter_menu()
	await physics_frame
