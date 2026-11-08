extends SceneTree
## Marble inventory test (S4, S5, S6, S7, S9, S10): what a run owns, the
## per-board ammo and its throw budget, consumption when a throw resolves,
## the refund that keeps it, the board-start restore, the permanent loss of
## a broken marble and the defeat when the ammo empties under the objective.
## Run: godot --headless --path . --script res://tests/inventory.gd

var game
var content
var failed := false
var removed: Array = []      # [def_id, reason] pairs from marble_removed
var ended: Array = []        # throw_ended outcomes


func _initialize() -> void:
	_ensure_autoloads()
	_run()


## In --script mode Godot does not register project autoloads; install the
## ones under test in dependency order (Game reads Economy, both read
## ContentDB for their content ids).
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
	content = root.get_node("ContentDB")


func _run() -> void:
	await physics_frame
	_connect_bus()
	if not _api_present():
		return quit(1)
	_test_run_starts_with_five_commons()
	if failed:
		return quit(1)
	await _test_board_ammo_is_the_throw_budget()
	if failed:
		return quit(1)
	await _test_consume_on_embed()
	if failed:
		return quit(1)
	await _test_consume_on_settled()
	if failed:
		return quit(1)
	await _test_refund_keeps_the_marble()
	if failed:
		return quit(1)
	await _test_ammo_restored_next_board()
	if failed:
		return quit(1)
	await _test_break_is_permanent()
	if failed:
		return quit(1)
	await _test_empty_ammo_is_defeat()
	print("INVENTORY OK")
	quit(0)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	print("INVENTORY FAIL: " + label)


## The inventory API every check below relies on: red without it, instead
## of a wall of property errors that never fails the suite.
func _api_present() -> bool:
	var missing: Array[String] = []
	for prop in ["inventory", "ammo"]:
		if not (prop in game):
			missing.append("Game." + prop)
	if not missing.is_empty():
		print("INVENTORY FAIL: missing %s" % ", ".join(missing))
		return false
	return true


func _connect_bus() -> void:
	var bus := root.get_node("EventBus")
	bus.marble_removed.connect(func(def_id, reason): removed.append([def_id, reason]))
	bus.throw_ended.connect(func(outcome): ended.append(outcome))


# --- (a) A normal run owns five commons (S10) ------------------------------


func _test_run_starts_with_five_commons() -> void:
	game.start_run()
	_check(game.inventory.size() == 5,
			"a run should own 5 marbles, owns %d" % game.inventory.size())
	for def in game.inventory:
		_check(def.id == "common",
				"a run should start with commons only, got '%s'" % def.id)


# --- (b) The board ammo is the throw budget (S5, S9) -----------------------


func _test_board_ammo_is_the_throw_budget() -> void:
	game.start_run()
	var board := _open_board()
	await physics_frame
	_check(game.ammo.size() == game.inventory.size(),
			"the board ammo should be the whole inventory (%d), got %d"
			% [game.inventory.size(), game.ammo.size()])
	_check(board.shots_left == game.ammo.size(),
			"throws should equal the ammo size (%d), got %d"
			% [game.ammo.size(), board.shots_left])
	_check(board.shots_total == game.ammo.size(),
			"the HUD total should be the ammo size (%d), got %d"
			% [game.ammo.size(), board.shots_total])
	_check(board.hud.label_shots.text == "Canicas restantes: 5 / 5",
			"the HUD should read the ammo, got '%s'" % board.hud.label_shots.text)
	_check(board.rules.shots_per_board == 5,
			"the rules resource keeps shots_per_board, got %d"
			% board.rules.shots_per_board)
	board.queue_free()
	await physics_frame

	# A bigger loadout raises the budget: the ammo, not the rules, decides.
	game.inventory.append(content.marble_def("fire"))
	game.inventory.append(content.marble_def("glass"))
	var bigger := _open_board()
	await physics_frame
	_check(bigger.shots_total == 7,
			"a 7-marble inventory should give 7 throws, got %d" % bigger.shots_total)
	_check(bigger.hud.label_shots.text == "Canicas restantes: 7 / 7",
			"the HUD should read '7 / 7', got '%s'" % bigger.hud.label_shots.text)
	bigger.queue_free()
	await physics_frame


# --- (c) A thrown marble leaves the ammo when it resolves (S4) -------------


func _test_consume_on_embed() -> void:
	game.start_run()
	var board := _open_board()
	await physics_frame
	removed.clear()
	ended.clear()
	_check(_throw_into_hole(board), "the board should have a free notch to embed into")
	_check(ended.size() == 1 and ended[0] == &"embedded",
			"the throw should resolve embedded, got %s" % str(ended))
	_check(game.ammo.size() == 4,
			"an embedded marble should leave the ammo (5 -> %d)" % game.ammo.size())
	_check(game.inventory.size() == 5,
			"the run inventory keeps the thrown marble, has %d" % game.inventory.size())
	_check(board.shots_left == 4,
			"the board should have 4 throws left, got %d" % board.shots_left)
	_check(removed.size() == 1 and removed[0][0] == "common"
			and removed[0][1] == &"thrown",
			"the consume should emit marble_removed ('common', 'thrown'), got %s"
			% str(removed))
	_check(board.hud.label_shots.text == "Canicas restantes: 4 / 5",
			"the HUD should count down, got '%s'" % board.hud.label_shots.text)
	board.queue_free()
	await physics_frame


func _test_consume_on_settled() -> void:
	game.start_run()
	var board := _open_board()
	await physics_frame
	removed.clear()
	ended.clear()
	_settle_throw(board)
	_check(ended.size() == 1 and ended[0] == &"settled",
			"the throw should resolve settled, got %s" % str(ended))
	_check(game.ammo.size() == 4,
			"a settled marble should leave the ammo, got %d" % game.ammo.size())
	_check(board.shots_left == 4,
			"a settled throw spends one throw, got %d" % board.shots_left)
	_check(removed.size() == 1 and removed[0][1] == &"thrown",
			"a settled throw should emit marble_removed 'thrown', got %s" % str(removed))
	board.queue_free()
	await physics_frame


# --- (d) A refunded marble stays in the ammo (S7) --------------------------


func _test_refund_keeps_the_marble() -> void:
	game.start_run()
	var board := _open_board()
	await physics_frame
	removed.clear()
	ended.clear()
	# A marble that already crossed the forgiving player edge of the board.
	var marble := _launch_throw(board)
	_check(marble != null, "the throw should launch a marble")
	if marble == null:
		return
	marble.position = Vector3(0.0, 0.09, -board.board_def.length / 2.0 - 0.5)
	board._update_flight(1.0 / 60.0)
	_check(ended.size() == 1 and ended[0] == &"refunded",
			"the throw should resolve refunded, got %s" % str(ended))
	_check(game.ammo.size() == 5,
			"a refunded marble stays in the ammo, ammo is %d" % game.ammo.size())
	_check(board.shots_left == 5,
			"a refund should not spend a throw, throws left %d" % board.shots_left)
	_check(removed.is_empty(),
			"a refund should not consume a marble, got %s" % str(removed))
	_check(board.hud.label_shots.text == "Canicas restantes: 5 / 5",
			"the HUD should keep the count, got '%s'" % board.hud.label_shots.text)
	_clear_marbles(board)
	board.queue_free()
	await physics_frame


# --- (e) The next board restores the inventory as ammo (S5) ----------------


func _test_ammo_restored_next_board() -> void:
	game.start_run()
	var board := _open_board()
	await physics_frame
	_check(_throw_into_hole(board), "the board should have a free notch")
	_check(_throw_into_hole(board), "the board should have a second free notch")
	_check(game.ammo.size() == 3,
			"two throws should leave 3 in the ammo, got %d" % game.ammo.size())
	board.queue_free()
	await physics_frame
	var next_board := _open_board()
	await physics_frame
	_check(game.ammo.size() == 5,
			"the next board should restore the 5 owned marbles, got %d"
			% game.ammo.size())
	_check(next_board.shots_left == 5,
			"the next board should get 5 throws again, got %d" % next_board.shots_left)
	next_board.queue_free()
	await physics_frame


# --- (f) A broken marble is lost for the rest of the run (S5) --------------


func _test_break_is_permanent() -> void:
	game.start_run()
	# The run starts with commons (S10): swap the first one for a marble that
	# always breaks.
	var brittle: MarbleDef = content.marble_def("glass").duplicate()
	brittle.break_chance = 1.0
	game.inventory[0] = brittle
	var board := _open_board()
	await physics_frame
	board.selected_ammo_index = 0
	removed.clear()
	board._launch(0.0, 20.0)
	_check(game.inventory.size() == 4,
			"a broken marble leaves the run inventory (5 -> %d)"
			% game.inventory.size())
	_check(game.ammo.size() == 4,
			"a broken marble leaves the ammo (5 -> %d)" % game.ammo.size())
	_check(removed.size() == 1 and removed[0][0] == "glass"
			and removed[0][1] == &"broke",
			"the break should emit marble_removed ('glass', 'broke'), got %s"
			% str(removed))
	_clear_marbles(board)
	board.queue_free()
	await physics_frame

	var next_board := _open_board()
	await physics_frame
	_check(game.ammo.size() == 4,
			"a broken marble is not restored next board, ammo is %d"
			% game.ammo.size())
	_check(not _has_marble(game.ammo, "glass"),
			"the broken marble should be gone for good, ammo is %s"
			% str(_ids(game.ammo)))
	_check(next_board.shots_left == 4,
			"the next board throws the 4 marbles left, got %d" % next_board.shots_left)
	next_board.queue_free()
	await physics_frame


# --- (g) Empty ammo under the objective is a defeat (S6) -------------------


func _test_empty_ammo_is_defeat() -> void:
	game.start_run()
	var board := _open_board()
	await physics_frame
	for i in 5:
		_settle_throw(board)
	_check(game.ammo.is_empty(),
			"the ammo should be empty after 5 throws, has %d" % game.ammo.size())
	_check(board.shots_left == 0,
			"the board should have no throws left, got %d" % board.shots_left)
	_check(board.state == board.ThrowState.ROUND_OVER,
			"an empty ammo should end the round, state is %s" % board.state)
	await physics_frame
	await physics_frame
	_check(board.board_result_sent, "the lost board should report its result")
	_check(board.hud.label_final.text.contains(str(board.run_objective)),
			"the defeat overlay should show the objective, got '%s'"
			% board.hud.label_final.text)
	_check(game.phase == game.Phase.RESULT,
			"the defeat should end the run at the result screen, phase is %s"
			% game.phase)
	_check(not game.run_active, "the defeat should close the run")
	board.queue_free()
	await physics_frame


# --- Helpers ---------------------------------------------------------------


func _open_board() -> Node3D:
	var board: Node3D = (load("res://scenes/board/board.tscn") as PackedScene).instantiate()
	root.add_child(board)
	return board


## Throw the selected ammo marble straight into the first free notch: the
## flight update captures it, so the throw resolves as embedded.
func _throw_into_hole(board: Node3D) -> bool:
	var hole := _free_hole(board)
	if hole.is_empty():
		return false
	var marble := _launch_throw(board)
	if marble == null:
		return false
	marble.position = Vector3(hole.pos.x, 0.05, hole.pos.z)
	board._update_flight(1.0 / 60.0)
	return true


## Throw a marble that comes to rest away from every notch: the throw
## resolves as settled, worth 0 points.
func _settle_throw(board: Node3D) -> void:
	var marble := _launch_throw(board)
	if marble == null:
		return
	marble.position = Vector3(0.0, 0.14, board.board_def.launch_z() + 0.4)
	# Past settle_time in one update: the marble never moved, so the board
	# resolves it as settled right away.
	board._update_flight(board.rules.settle_time + 0.05)


## One real throw through the board's launch path (so the ammo selection, the
## break roll and the per-throw state run as in play); the spawned marble is
## stopped in place and handed back for the test to place.
func _launch_throw(board: Node3D) -> RigidBody3D:
	board._launch(0.0, 0.0)
	for marble in board.active_marbles:
		if is_instance_valid(marble):
			marble.linear_velocity = Vector3.ZERO
			return marble
	return null


func _free_hole(board: Node3D) -> Dictionary:
	for hole in board.holes:
		if not hole.occupied:
			return hole
	return {}


func _clear_marbles(board: Node3D) -> void:
	for marble in board.active_marbles.duplicate():
		if is_instance_valid(marble):
			marble.queue_free()
	board.active_marbles.clear()
	board.settle_times.clear()


func _has_marble(list: Array, def_id: String) -> bool:
	for def in list:
		if def.id == def_id:
			return true
	return false


func _ids(list: Array) -> Array:
	var ids: Array = []
	for def in list:
		ids.append(def.id)
	return ids
