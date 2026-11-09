extends SceneTree
## Debug mode test (S1, S2, S3, S8): the new menu entry, the setup screen
## (board picker with the board name and its gimmick, the prize toggles and
## the five starting marbles), the single-board launch through
## Game.start_debug_run(), the block-factor-x1 objective and the return to
## the menu when the board ends. The normal run flow is checked last so a
## debug change can never leak into JUGAR.
## Run: godot --headless --path . --script res://tests/debug_mode.gd

const MENU_SCENE := "res://scenes/menu/menu.tscn"
const DEBUG_SCENE := "res://scenes/debug/debug_setup.tscn"
## Def index 7 is La Barraca Sellada (board 8): two gimmicks and a 100 base
## target, which a normal run scales to 115 (boss board on block 2). Debug
## mode must ask exactly 100, so this def proves the x1 factor.
const PICKED_BOARD := 7

var game
var content
var failed := false
var screen


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
	if not _api_present():
		return quit(1)
	await _test_menu_entry()
	if failed:
		return quit(1)
	await _test_setup_screen_defaults()
	if failed:
		return quit(1)
	await _test_board_picker_shows_name_and_gimmick()
	if failed:
		return quit(1)
	await _test_empty_loadout_is_guarded()
	if failed:
		return quit(1)
	await _test_launch_single_board()
	if failed:
		return quit(1)
	await _test_board_end_returns_to_menu()
	if failed:
		return quit(1)
	await _test_normal_run_untouched()
	if failed:
		return quit(1)
	print("DEBUG MODE OK")
	quit(0)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	print("DEBUG MODE FAIL: " + label)


## The API and screens every check below relies on: red without them, instead
## of a wall of property errors that never fails the suite.
func _api_present() -> bool:
	var missing: Array[String] = []
	if not game.has_method("start_debug_run"):
		missing.append("Game.start_debug_run")
	for prop in ["debug_mode", "debug_board_index"]:
		if not (prop in game):
			missing.append("Game." + prop)
	for path in [MENU_SCENE, DEBUG_SCENE]:
		if not ResourceLoader.exists(path):
			missing.append(path)
	if not missing.is_empty():
		print("DEBUG MODE FAIL: missing %s" % ", ".join(missing))
		return false
	return true


func _open_screen() -> Node:
	if screen == null:
		var scene: PackedScene = load(DEBUG_SCENE)
		screen = scene.instantiate()
		root.add_child(screen)
	return screen


func _free_screen() -> void:
	if screen == null:
		return
	screen.queue_free()
	screen = null
	await physics_frame


# --- (a) The menu offers the new entry (S1) --------------------------------


func _test_menu_entry() -> void:
	var menu: Node = (load(MENU_SCENE) as PackedScene).instantiate()
	root.add_child(menu)
	var texts: Array[String] = []
	for node in menu.find_children("*", "Button", true, false):
		texts.append((node as Button).text)
	var debug_index := texts.find("MODO DEBUG")
	_check(debug_index >= 0,
			"the menu should offer a MODO DEBUG button, has %s" % str(texts))
	var play_index := texts.find("JUGAR")
	_check(play_index >= 0, "the menu should keep JUGAR, has %s" % str(texts))
	_check(debug_index > play_index,
			"MODO DEBUG should sit below JUGAR (JUGAR %d, DEBUG %d)"
			% [play_index, debug_index])
	menu.queue_free()
	await physics_frame


# --- (b) The setup screen defaults (S3) ------------------------------------


func _test_setup_screen_defaults() -> void:
	var setup := _open_screen()
	await physics_frame
	_check(setup.board_cursor == 0, "the setup should open on the first board")
	_check(setup.selected_prizes.is_empty(),
			"the setup should start with no active prize, has %d"
			% setup.selected_prizes.size())
	_check(setup.picked_marbles.size() == 5,
			"the setup should start with 5 marbles, has %d"
			% setup.picked_marbles.size())
	for def in setup.picked_marbles:
		_check(def.id == "common",
				"the default loadout should be commons, got '%s'" % def.id)
	_check(setup.can_start(), "a 5-common loadout should be startable")
	_check(not setup.start_button.disabled,
			"the start button should be enabled with 5 marbles")
	# The project renders on a fixed 1920x1080 canvas: the panel must fit it
	# whole, or the launch buttons would be clipped.
	var panels := setup.find_children("*", "PanelContainer", true, false)
	_check(not panels.is_empty(), "the setup should build its candy panel")
	if not panels.is_empty():
		var needed: Vector2 = (panels[0] as Control).get_combined_minimum_size()
		_check(needed.x <= 1920.0 and needed.y <= 1080.0,
				"the setup should fit the 1920x1080 canvas, needs %s" % str(needed))
	var config: Dictionary = setup.build_config()
	_check(config["board_index"] == 0, "the config should carry the board index")
	_check(int(config["board_index"]) == setup.board_cursor,
			"the config board index should be the cursor, got %d"
			% int(config["board_index"]))
	_check((config["marbles"] as Array).size() == 5,
			"the config should carry 5 marbles, has %d"
			% (config["marbles"] as Array).size())
	_check((config["prizes"] as Array).is_empty(),
			"the config should carry no prize by default")
	# A short loadout is topped up with commons, and the picked marbles stay
	# in front so the player's choice is what the board starts with.
	for i in 5:
		setup.change_marble(content.marble_def("common"), -1)
	_check(setup.picked_marbles.is_empty(),
			"removing every common should empty the loadout")
	setup.change_marble(content.marble_def("fire"), 1)
	var short_config: Dictionary = setup.build_config()
	var short_marbles: Array = short_config["marbles"]
	_check(short_marbles.size() == 5,
			"a 1-marble loadout should fill up to 5, has %d" % short_marbles.size())
	_check((short_marbles[0] as MarbleDef).id == "fire",
			"the picked marble should come first, got '%s'"
			% (short_marbles[0] as MarbleDef).id)
	for i in range(1, short_marbles.size()):
		_check((short_marbles[i] as MarbleDef).id == "common",
				"the fill should be commons, got '%s'"
				% (short_marbles[i] as MarbleDef).id)
	# The prize toggle carries the pick into the config.
	for prize in content.prizes():
		setup.toggle_prize(prize)
	_check(setup.selected_prizes.size() == content.prizes().size(),
			"toggling every prize should activate them all, active %d"
			% setup.selected_prizes.size())
	_check((setup.build_config()["prizes"] as Array).size() == setup.selected_prizes.size(),
			"the config should carry the active prizes")
	for prize in content.prizes():
		setup.toggle_prize(prize)
	_check(setup.selected_prizes.is_empty(),
			"toggling again should deactivate the prizes")
	await _free_screen()


# --- (c) The board picker shows the name and the gimmick (S2) --------------


func _test_board_picker_shows_name_and_gimmick() -> void:
	var setup := _open_screen()
	await physics_frame
	var count: int = content.board_count()
	_check(count == 20, "content should have 20 boards, has %d" % count)
	for i in count:
		setup.select_board(i)
		var def: BoardDef = content.board_def(i)
		_check(setup.board_def() == def,
				"the setup should pick BoardDef %d, got '%s'"
				% [i, setup.board_def().theme_name])
		_check(setup.label_board_name.text.contains(def.theme_name),
				"the picker should show '%s', shows '%s'"
				% [def.theme_name, setup.label_board_name.text])
		var rules: String = setup.board_rules_text()
		if def.modifiers.is_empty():
			_check(rules == "Sin reglas especiales",
					"board %d has no gimmick, the picker says '%s'" % [i, rules])
			continue
		for id in def.modifiers:
			var modifier: BoardModifierDef = content.modifier_def(id)
			_check(rules.contains(modifier.description),
					"board %d rules should describe '%s', says '%s'"
					% [i, modifier.description, rules])
	# The arrows wrap around the whole list.
	setup.select_board(0)
	setup.cycle_board(-1)
	_check(setup.board_cursor == count - 1,
			"cycling back from the first board should wrap to %d, got %d"
			% [count - 1, setup.board_cursor])
	setup.cycle_board(1)
	_check(setup.board_cursor == 0,
			"cycling forward from the last board should wrap to 0, got %d"
			% setup.board_cursor)
	await _free_screen()


# --- (d) A loadout without marbles never starts (S3) -----------------------


func _test_empty_loadout_is_guarded() -> void:
	var setup := _open_screen()
	await physics_frame
	for i in 5:
		setup.change_marble(content.marble_def("common"), -1)
	_check(not setup.can_start(), "an empty loadout should not be startable")
	_check(setup.start_button.disabled,
			"the start button should be disabled with no marbles")
	_check((setup.build_config()["marbles"] as Array).is_empty(),
			"an empty loadout should build an empty config")
	game.enter_menu()
	setup.start_match()
	_check(game.phase == game.Phase.MENU,
			"starting with no marbles should leave the phase at MENU, phase is %s"
			% game.phase)
	_check(not game.run_active, "starting with no marbles should not open a run")
	_check(not game.debug_mode, "starting with no marbles should not enter debug mode")
	await _free_screen()

	# The Game entry point guards the same rule, whatever calls it.
	game.enter_menu()
	var started: bool = game.start_debug_run({
		"board_index": PICKED_BOARD, "prizes": [], "marbles": [],
	})
	_check(not started, "start_debug_run should reject an empty loadout")
	_check(game.phase == game.Phase.MENU,
			"a rejected debug launch should stay at MENU, phase is %s" % game.phase)
	_check(not game.debug_mode, "a rejected debug launch should not enter debug mode")
	_check(not game.run_active, "a rejected debug launch should not open a run")


# --- (e) The launch: one board, the picked loadout (S1, S3, S8) ------------


func _test_launch_single_board() -> void:
	var setup := _open_screen()
	await physics_frame
	setup.select_board(PICKED_BOARD)
	for prize in content.prizes():
		setup.toggle_prize(prize)
	var config: Dictionary = setup.build_config()
	var config_marbles: Array = config["marbles"]
	var config_ids: Array[String] = []
	for def in config_marbles:
		config_ids.append((def as MarbleDef).id)
	var picked_prizes: int = (config["prizes"] as Array).size()
	await _free_screen()

	var started: bool = game.start_debug_run(config)
	_check(started, "start_debug_run should accept a 5-marble loadout")
	_check(game.phase == game.Phase.BOARD,
			"a debug launch should enter BOARD, phase is %s" % game.phase)
	_check(game.run_active, "a debug launch should mark the run active")
	_check(game.debug_mode, "a debug launch should switch debug mode on")
	_check(game.debug_board_index == PICKED_BOARD,
			"debug mode should remember board %d, has %d"
			% [PICKED_BOARD, game.debug_board_index])
	_check(game.current_board_in_run == 1,
			"a debug match is a single board, run board is %d"
			% game.current_board_in_run)
	_check(game.block == 1, "a debug match plays on block 1, block is %d" % game.block)
	_check(game.money == 0,
			"a debug match has no money economy, money is %d" % game.money)
	_check(_ids(game.ammo) == config_ids,
			"the board ammo should be the picked marbles %s, ammo is %s"
			% [str(config_ids), str(_ids(game.ammo))])
	_check(game.inventory.size() == config_marbles.size(),
			"the debug inventory should be the loadout (%d), has %d"
			% [config_marbles.size(), game.inventory.size()])
	_check(game.prizes.size() == picked_prizes,
			"the debug prizes should be the picked ones (%d), has %d"
			% [picked_prizes, game.prizes.size()])

	var board: Node3D = _open_board()
	await physics_frame
	var picked_def: BoardDef = content.board_def(PICKED_BOARD)
	_check(board.board_def == picked_def,
			"the debug board should render '%s', renders '%s'"
			% [picked_def.theme_name, board.board_def.theme_name])
	_check(picked_def.objective_target == 100,
			"the picked board should have a 100 base target, has %d"
			% picked_def.objective_target)
	_check(board.run_objective == picked_def.objective_target,
			"a debug board should ask its own base target (%d), asks %d"
			% [picked_def.objective_target, board.run_objective])
	_check(board.hud.label_board_title.text == picked_def.theme_name,
			"the HUD should name the picked board, shows '%s'"
			% board.hud.label_board_title.text)
	# Throws = picked marbles + every picked extra_throw prize (Globo), the
	# same budget math a run board uses.
	var expected_throws: int = config_marbles.size()
	for prize in config["prizes"]:
		if (prize as PrizeDef).effect == &"extra_throw":
			expected_throws += int((prize as PrizeDef).params.get("per_board", 1))
	_check(board.shots_total == expected_throws,
			"throws should equal picked marbles + extra-throw prizes (%d), got %d"
			% [expected_throws, board.shots_total])
	_check(board.hud.label_shots.text == "%d/%d"
			% [expected_throws, expected_throws],
			"the HUD should count the picked marbles, shows '%s'"
			% board.hud.label_shots.text)
	_check(board.hud.label_money.text == "$0",
			"a debug board should show no money, shows '%s'"
			% board.hud.label_money.text)
	board.queue_free()
	await physics_frame


# --- (f) The board ended: back to the menu, no shop, no result (S8) --------


func _test_board_end_returns_to_menu() -> void:
	# The launch goes through the screen: the start button is what the player
	# presses, so the whole picker -> launch path is what gets checked.
	game.enter_menu()
	var setup := _open_screen()
	await physics_frame
	setup.start_match()
	_check(game.phase == game.Phase.BOARD,
			"the screen's launch should enter BOARD, phase is %s" % game.phase)
	await _free_screen()
	game.board_won(3, 0)
	_check(game.phase == game.Phase.MENU,
			"a won debug board should return to MENU, phase is %s" % game.phase)
	_check(not game.run_active, "a won debug board should end the match")
	_check(not game.debug_mode, "a won debug board should leave debug mode")
	_check(game.money == 0,
			"a won debug board should pay nothing, money is %d" % game.money)
	_check(not game.run_won, "a debug board win is not a run win")
	# A duplicate report (the board defers its call) must not reopen anything.
	game.board_won(3, 0)
	_check(game.phase == game.Phase.MENU, "a repeated debug win should be ignored")

	game.enter_menu()
	_check(game.start_debug_run(_simple_config()), "the debug match should start again")
	game.board_lost()
	_check(game.phase == game.Phase.MENU,
			"a lost debug board should return to MENU, phase is %s" % game.phase)
	_check(not game.run_active, "a lost debug board should end the match")
	_check(not game.debug_mode, "a lost debug board should leave debug mode")
	game.board_lost()
	_check(game.phase == game.Phase.MENU, "a repeated debug loss should be ignored")


# --- (g) The normal run flow is untouched (PRESERVE) ----------------------


func _test_normal_run_untouched() -> void:
	game.start_run()
	_check(not game.debug_mode, "a normal run should not be in debug mode")
	_check(game.phase == game.Phase.BOARD, "a normal run should enter BOARD")
	_check(game.money == game.START_MONEY,
			"a normal run should start with $%d, has %d"
			% [game.START_MONEY, game.money])
	_check(game.current_board_in_run == 1, "a normal run should start on board 1")
	_check(game.block == 1, "a normal run should start on block 1")
	_check(_ids(game.inventory) == ["common", "common", "common", "common", "common"],
			"a normal run should own 5 commons, owns %s" % str(_ids(game.inventory)))
	_check(game.prizes.size() == 1, "a normal run keeps its starting prize")
	# W3b: the board order is random; board 5 rolls among the block-2 defs
	# (4..6) and the debug override still wins inside a debug match.
	_check([4, 5, 6].has(game.board_def_index(5)),
			"outside debug mode board 5 should roll a block-2 def, got %d"
			% game.board_def_index(5))
	_check(game.objective_for_board(5, 60) == 69,
			"outside debug mode board 5 should scale to 69, got %d"
			% game.objective_for_board(5, 60))
	_check(game.objective_for_board(4, 60) == 100,
			"outside debug mode boss board 4 should ask 100, got %d"
			% game.objective_for_board(4, 60))
	game.board_won(2, 0)
	_check(game.phase == game.Phase.WIN,
			"a won normal board should enter the win interstitial, phase is %s"
			% game.phase)
	_check(game.money > game.START_MONEY, "a won normal board should pay a reward")
	game.win_screen_continue()
	_check(game.phase == game.Phase.SHOP,
			"CONTINUAR after a normal win should reach the shop, phase is %s"
			% game.phase)
	game.board_lost()
	_check(game.phase == game.Phase.RESULT,
			"a lost normal board should lead to the result screen, phase is %s"
			% game.phase)
	_check(game.boards_cleared == 1, "the normal run should keep counting cleared boards")
	game.enter_menu()


# --- Helpers ---------------------------------------------------------------


## The smallest accepted debug config: the first board, no prizes and five
## commons, i.e. the setup screen's defaults.
func _simple_config() -> Dictionary:
	var marbles: Array[MarbleDef] = []
	var common: MarbleDef = content.marble_def("common")
	for i in 5:
		marbles.append(common)
	return {"board_index": 0, "prizes": [], "marbles": marbles}


func _open_board() -> Node3D:
	var board: Node3D = (load("res://scenes/board/board.tscn") as PackedScene).instantiate()
	root.add_child(board)
	return board


func _ids(list: Array) -> Array[String]:
	var ids: Array[String] = []
	for def in list:
		ids.append((def as MarbleDef).id)
	return ids
