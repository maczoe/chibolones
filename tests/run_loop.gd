extends SceneTree
## Run-loop test (M1): economy math, the 20-board progression helpers, the
## Game phase machine and the board's run wiring (objective + money in the
## HUD, no double reward). Pure state plus one board instance, no rendering.
## Run: godot --headless --path . --script res://tests/run_loop.gd

var game
var economy
var content
var failed := false


func _initialize() -> void:
	_ensure_autoloads()
	_run()


## In --script mode Godot does not register project autoloads; install the
## ones under test in dependency order (Game reads Economy, both read
## ContentDB for their content ids and shop stock).
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
	content = root.get_node("ContentDB")


func _run() -> void:
	await physics_frame
	_test_economy()
	if failed:
		return quit(1)
	_test_progression()
	if failed:
		return quit(1)
	_test_phase_flow()
	if failed:
		return quit(1)
	_test_board_wiring()
	if failed:
		return quit(1)
	print("RUN LOOP OK")
	quit(0)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	print("RUN LOOP FAIL: " + label)


# --- (a) Economy v1 math (content-plan §2) ----------------------------------


func _test_economy() -> void:
	# base = 3 + block*2, per_marble = 1 + block.
	_check(economy.reward_for_block_win(1, 3, 0) == 11,
			"reward block 1 with 3 marbles should be 11, got %d"
			% economy.reward_for_block_win(1, 3, 0))
	_check(economy.reward_for_block_win(5, 0, 2) == 15,
			"reward block 5 with 0 marbles and bonus 2 should be 15, got %d"
			% economy.reward_for_block_win(5, 0, 2))
	_check(is_equal_approx(economy.price_scale(3), 1.7),
			"price_scale(3) should be 1.7, got %s" % economy.price_scale(3))
	_check(economy.extra_marble_pack_price(1) == 4,
			"extra marble pack at block 1 should cost 4")
	_check(economy.reroll_price() == 2, "reroll should cost 2")
	var stock: Dictionary = economy.shop_stock(1)
	_check(stock["marbles"].size() == 2,
			"shop stock should offer 2 marbles, got %d" % stock["marbles"].size())
	_check(stock["prizes"].size() == 2,
			"shop stock should offer 2 prizes, got %d" % stock["prizes"].size())
	for entry in stock["marbles"] + stock["prizes"]:
		_check(int(entry["price"]) > 0, "stock price must be positive: %s" % str(entry))
	_check(int(stock["extra_pack_price"]) == 4, "stock pack price should be 4 at block 1")
	_check(int(stock["reroll_price"]) == 2, "stock reroll price should be 2")


# --- (b) Progression helpers (5 blocks of 4, boss every 4th) ---------------


func _test_progression() -> void:
	_check(game.block_of(1) == 1, "block_of(1) should be 1")
	_check(game.block_of(4) == 1, "block_of(4) should be 1")
	_check(game.block_of(5) == 2, "block_of(5) should be 2")
	_check(game.block_of(20) == 5, "block_of(20) should be 5")
	for n in [4, 8, 12, 16, 20]:
		_check(game.is_boss(n), "board %d should be a boss board" % n)
	_check(not game.is_boss(5), "board 5 should not be a boss board")
	# Boss boards use the boss base (100) scaled by the block factor.
	_check(game.objective_for_board(4, 60) == 100,
			"boss board 4 objective should be 100, got %d" % game.objective_for_board(4, 60))
	_check(game.objective_for_board(8, 60) == 115,
			"boss board 8 objective should be 115, got %d" % game.objective_for_board(8, 60))
	_check(game.objective_for_board(5, 60) == 69,
			"board 5 objective should be 69, got %d" % game.objective_for_board(5, 60))


# --- (c) Phase machine -----------------------------------------------------


func _test_phase_flow() -> void:
	game.start_run()
	_check(game.run_active, "start_run should mark the run active")
	_check(game.phase == game.Phase.BOARD, "start_run should enter BOARD")
	_check(game.money == 5, "start_run should start with $5, got %d" % game.money)
	_check(game.current_board_in_run == 1, "start_run should start on board 1")
	_check(game.block == 1, "start_run should start on block 1")

	game.board_won(3, 0)
	_check(game.money == 5 + economy.reward_for_block_win(1, 3, 0),
			"winning board 1 with 3 marbles should pay %d, money is %d"
			% [economy.reward_for_block_win(1, 3, 0), game.money])
	_check(game.phase == game.Phase.WIN,
			"a won board should enter the win interstitial, phase is %s" % game.phase)
	_check(game.last_win_stats.get("marbles_left", -1) == 3,
			"the win interstitial should show the marbles left")
	_check(game.boards_cleared == 1, "boards_cleared should be 1 after the first win")

	game.win_screen_continue()
	_check(game.phase == game.Phase.SHOP,
			"CONTINUAR on the win screen should lead to the shop, phase is %s"
			% game.phase)

	game.shop_continue()
	_check(game.current_board_in_run == 2,
			"shop_continue should advance to board 2, got %d" % game.current_board_in_run)
	_check(game.phase == game.Phase.BOARD, "shop_continue should enter BOARD")

	game.current_board_in_run = 20
	game.board_won(0, 0)
	_check(game.phase == game.Phase.WIN,
			"winning board 20 should enter the win interstitial, phase is %s"
			% game.phase)
	_check(game.run_won, "winning board 20 should set run_won")

	game.win_screen_continue()
	_check(game.phase == game.Phase.RESULT,
			"CONTINUAR after the run win should reach the summary, phase is %s"
			% game.phase)

	game.start_endless()
	_check(game.endless_mode, "start_endless should enable endless mode")
	_check(game.phase == game.Phase.SHOP, "start_endless should enter SHOP")

	game.board_lost()
	_check(game.phase == game.Phase.RESULT, "losing should enter RESULT")
	_check(not game.run_active, "losing should end the run")

	game.start_run()
	_check(not game.endless_mode, "a new run should clear endless mode")
	_check(game.boards_cleared == 0, "a new run should clear boards_cleared")
	_check(game.phase == game.Phase.BOARD, "a new run should enter BOARD")
	await _test_win_screen_assets()


# --- (d) Board run wiring --------------------------------------------------


## The win interstitial's placeholder fanfare must be imported and loaded:
## a missing .import file made the first win silent (fixed 2026-11-08).
func _test_win_screen_assets() -> void:
	var stream: AudioStream = load("res://data/audio/fanfare.wav")
	_check(stream != null and stream.get_length() > 0.5,
			"the fanfare placeholder should load as an audio stream")
	var win: Node = (load("res://scenes/run/win.tscn") as PackedScene).instantiate()
	root.add_child(win)
	await physics_frame
	var players := win.find_children("*", "AudioStreamPlayer", true, false)
	_check(players.size() == 1 and players[0].stream != null,
			"the win screen should carry a fanfare player with a stream")
	win.queue_free()
	await physics_frame


func _test_board_wiring() -> void:
	game.start_run()
	var board = _open_board()
	await physics_frame
	var expected_objective: int = game.objective_for_board(game.current_board_in_run, 60)
	_check(board.run_objective == expected_objective,
			"board objective should be %d, got %d" % [expected_objective, board.run_objective])
	_check(board.hud.label_target.text == "Objetivo: %d" % expected_objective,
			"HUD objective line should read 'Objetivo: %d', got '%s'"
			% [expected_objective, board.hud.label_target.text])
	_check(board.hud.label_money.text == "$: %d" % game.money,
			"HUD money line should read '$: %d', got '%s'"
			% [game.money, board.hud.label_money.text])

	# The win path is deferred by one frame in the board; Game guards it by
	# phase so a duplicate call never pays twice.
	var money_before: int = game.money
	game.board_won(2, 0)
	var after_first: int = game.money
	_check(after_first > money_before, "a board win should pay the reward")
	game.board_won(2, 0)
	_check(game.money == after_first,
			"a repeated board_won should pay nothing, money is %d" % game.money)
	board.queue_free()
	await physics_frame
	await _test_board_win()
	if failed:
		return
	await _test_board_loss()


## A board that reaches its run objective reports the win to Game and the
## run moves to the shop, paying base + per_marble * marbles_left.
func _test_board_win() -> void:
	game.start_run()
	var board = _open_board()
	await physics_frame
	# Score exactly the objective through the real scoring seam (EventBus
	# embed -> ScoreEngine), with a marble resting mid-board in flight.
	root.get_node("EventBus").embed.emit(0, board.run_objective)
	_check(board.score_engine.total >= board.run_objective,
			"embed event should reach the board score engine")
	board.state = board.ThrowState.FLIGHT
	board.launch_timer = 0.0
	board.active_marbles.append(_resting_marble(board))
	await physics_frame
	await physics_frame
	_check(board.board_result_sent, "reaching the objective should report the board result")
	_check(board.state == board.ThrowState.ROUND_OVER,
			"a won board should end in ROUND_OVER, got %s" % board.state)
	_check(game.phase == game.Phase.WIN,
			"a won board should move the run to the win interstitial, phase is %s"
			% game.phase)
	_check(game.last_win_stats.get("score", -1) == board.score_engine.total
					and game.last_win_stats.get("marbles_left", -1) == 5,
			"the interstitial stats should carry the board score and marbles left")
	_check(game.money == game.START_MONEY + economy.reward_for_block_win(1, 5, 0),
			"the run should be paid %d for the won board, money is %d"
			% [economy.reward_for_block_win(1, 5, 0), game.money])
	_check(game.boards_cleared == 1, "the won board should count as cleared")
	board.queue_free()
	await physics_frame


## A board that runs out of shots under its objective ends the run.
func _test_board_loss() -> void:
	game.start_run()
	var board = _open_board()
	await physics_frame
	board.shots_left = 0
	board.state = board.ThrowState.FLIGHT
	board.launch_timer = board.rules.flight_timeout
	await physics_frame
	await physics_frame
	_check(board.state == board.ThrowState.ROUND_OVER,
			"a lost board should end in ROUND_OVER, got %s" % board.state)
	_check(board.hud.label_final.text.contains(str(board.run_objective)),
			"the defeat overlay should show the objective, got '%s'"
			% board.hud.label_final.text)
	_check(game.phase == game.Phase.RESULT,
			"a lost board should move the run to the result screen, phase is %s" % game.phase)
	_check(not game.run_active, "a lost board should end the run")
	_check(not game.run_won, "a lost board should not mark the run as won")
	board.queue_free()
	await physics_frame


func _open_board() -> Node3D:
	var board: Node3D = (load("res://scenes/board/board.tscn") as PackedScene).instantiate()
	root.add_child(board)
	return board


## A marble at rest on the board surface, away from every notch: the volley
## resolves through it so the board's flight update can be driven by one
## physics frame in the test.
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
