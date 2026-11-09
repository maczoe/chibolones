extends SceneTree
## M2.5 board identity test: the 20 boards as data (filenames, unique names,
## palette/backdrop/emblem), the modifier mapping of the run resolved through
## its BoardDef, and the board scene + HUD wiring that tells the player which
## board is on screen and which rules it carries.
## Run: godot --headless --path . --script res://tests/themes.gd

## Board number (1..20) -> bonificador ids of that board (M2.5 table).
const EXPECTED_MODIFIERS := {
	1: [],
	2: [&"cuerda"],
	3: [&"mojado"],
	4: [&"borracho"],
	5: [&"espejo"],
	6: [&"ventoso"],
	7: [&"mochila"],
	8: [&"ventoso", &"espejo"],
	9: [&"fantasma"],
	10: [&"iman"],
	11: [&"trapecio"],
	12: [&"fantasma", &"iman"],
	13: [&"mojado"],
	14: [&"cuerda"],
	15: [&"mojado", &"cuerda"],
	16: [&"mojado", &"cuerda"],
	17: [&"ventoso", &"cuerda"],
	18: [&"cronometrado"],
	19: [&"fantasma"],
	20: [&"trapecio", &"cronometrado"],
}
const BACKDROP_STYLES := [&"waves", &"spiral", &"rays"]

var game
var content
var failed := false


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
	_test_board_defs()
	_test_modifier_mapping()
	_test_objective_semantics()
	if failed:
		return _finish()
	await _test_board_scene()
	_finish()


func _finish() -> void:
	print("THEMES FAIL" if failed else "THEMES OK")
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	print("THEMES FAIL: " + label)


# --- (a) The 20 BoardDefs as data (S2, S3) ---------------------------------


func _test_board_defs() -> void:
	_check(content.board_count() == 20,
			"ContentDB should index 20 boards, got %d" % content.board_count())
	var names := {}
	var paths := {}
	var styles := {}
	for i in content.board_count():
		var def: BoardDef = content.board_def(i)
		_check(def != null, "board %d should load a BoardDef" % (i + 1))
		if def == null:
			continue
		var path: String = def.resource_path
		var wanted := "board_%02d" % (i + 1)
		_check(path.get_file().begins_with(wanted),
				"board %d should live in a %s*.tres file, got '%s'" % [i + 1, wanted, path])
		_check(not paths.has(path), "board file '%s' is duplicated" % path)
		paths[path] = true
		_check(def.theme_name != "",
				"board %d needs a theme_name" % (i + 1))
		_check(not names.has(def.theme_name),
				"theme_name '%s' is duplicated" % def.theme_name)
		names[def.theme_name] = true
		_check(def.emblem != null,
				"board '%s' needs an emblem texture" % def.theme_name)
		if def.emblem != null:
			_check(def.emblem.get_width() > 0 and def.emblem.get_height() > 0,
					"board '%s' emblem should be a loadable texture" % def.theme_name)
		_check(BACKDROP_STYLES.has(def.backdrop_style),
				"board '%s' backdrop_style should be one of %s, got '%s'"
				% [def.theme_name, str(BACKDROP_STYLES), def.backdrop_style])
		styles[def.backdrop_style] = true
		_check(ResourceLoader.exists(def.backdrop_shader_path()),
				"board '%s' backdrop shader '%s' should exist"
				% [def.theme_name, def.backdrop_shader_path()])
		# Palette sanity: a board is a whole theme, not a copy of the void.
		_check(def.board_color != def.frame_color,
				"board '%s' should paint its surface and frame differently" % def.theme_name)
		_check(def.ambient_energy >= 0.35 and def.ambient_energy <= 0.7,
				"board '%s' ambient_energy should stay in 0.35..0.7, got %s"
				% [def.theme_name, def.ambient_energy])
		_check(def.backdrop_scale >= 8.0 and def.backdrop_scale <= 16.0,
				"board '%s' backdrop_scale should stay in 8..16, got %s"
				% [def.theme_name, def.backdrop_scale])
		_check(def.backdrop_speed >= 0.4 and def.backdrop_speed <= 1.0,
				"board '%s' backdrop_speed should stay in 0.4..1.0, got %s"
				% [def.theme_name, def.backdrop_speed])
	# The three backdrop variants are all in use: variants, not one shader
	# per board and not a single look for the whole run.
	for style in BACKDROP_STYLES:
		_check(styles.has(style),
				"at least one board should use the '%s' backdrop" % style)


# --- (b) Modifier mapping of the run (S3) ----------------------------------


func _test_modifier_mapping() -> void:
	for n in EXPECTED_MODIFIERS:
		var expected: Array = EXPECTED_MODIFIERS[n]
		var def: BoardDef = content.board_def(n - 1)
		var def_ids: Array[StringName] = def.modifiers if def != null else []
		_check(_same_ids(def_ids, expected),
				"board %d BoardDef modifiers should be %s, got %s"
				% [n, str(expected), str(def_ids)])
		var ids: Array = game.modifier_ids(n)
		_check(_same_ids(ids, expected),
				"game.modifier_ids(%d) should be %s, got %s"
				% [n, str(expected), str(ids)])
		var defs: Array[BoardModifierDef] = game.board_modifiers(n)
		var resolved: Array = []
		for modifier in defs:
			resolved.append(modifier.id if modifier != null else &"null")
		_check(_same_ids(resolved, expected),
				"game.board_modifiers(%d) should resolve %s, got %s"
				% [n, str(expected), str(resolved)])
		for modifier in defs:
			_check(modifier != null,
					"board %d should resolve every modifier through ContentDB" % n)
	# Endless boards keep running: the def index clamps to the last board.
	var endless_ids: Array = game.modifier_ids(24)
	_check(_same_ids(endless_ids, EXPECTED_MODIFIERS[20]),
			"an endless board should reuse board 20 rules, got %s" % str(endless_ids))


# --- (c) Objective semantics unchanged (S3) --------------------------------


func _test_objective_semantics() -> void:
	# Boss boards keep their own base target (100) scaled by the block
	# factor; normal boards use their BoardDef base (60).
	_check(content.board_def(3).objective_target == 100,
			"boss board 4 objective_target should be 100, got %d"
			% content.board_def(3).objective_target)
	_check(content.board_def(4).objective_target == 60,
			"normal board 5 objective_target should be 60, got %d"
			% content.board_def(4).objective_target)
	_check(game.objective_for_board(4, 60) == 100,
			"boss board 4 objective should still be 100, got %d"
			% game.objective_for_board(4, 60))
	_check(game.objective_for_board(5, content.board_def(4).objective_target) == 69,
			"board 5 objective should be 69, got %d"
			% game.objective_for_board(5, content.board_def(4).objective_target))


# --- (d) Board scene + HUD identity (S1) -----------------------------------


func _test_board_scene() -> void:
	# A board played inside a run renders the run board's own def and shows
	# its name plus the rules it carries.
	game.start_run()
	game.current_board_in_run = 4
	var board := _open_board()
	await physics_frame
	_check(board.board_def != null and board.board_def.theme_name == "El Tablero Borracho",
			"board 4 should render the Borracho def, got '%s'"
			% (board.board_def.theme_name if board.board_def != null else "none"))
	_check(_text(board.hud, "label_board_title").contains("El Tablero Borracho"),
			"the HUD should name the board, got '%s'"
			% _text(board.hud, "label_board_title"))
	_check(_text(board.hud, "label_board_effects").contains("Borracho"),
			"the HUD should list the board's effects, got '%s'"
			% _text(board.hud, "label_board_effects"))
	_check(board.board_theme.has(&"borracho"),
			"board 4 should run the borracho rule")
	_check(_text(board.hud, "label_msg").begins_with("Tablero 4:"),
			"the board should flash its number and name, got '%s'"
			% _text(board.hud, "label_msg"))
	_check(board.run_objective == 100,
			"board 4 objective should be 100, got %d" % board.run_objective)
	board.queue_free()
	await physics_frame

	# Without a run (headless smoke path) the board falls back to the first
	# def with no objective, exactly as before M2.5.
	game.run_active = false
	var plain := _open_board()
	await physics_frame
	_check(plain.board_def == content.board_def(0),
			"a board without a run should use def 0, got '%s'"
			% (plain.board_def.resource_path if plain.board_def != null else "none"))
	_check(plain.run_objective == 0,
			"a board without a run should have no objective, got %d" % plain.run_objective)
	_check(not plain.hud.label_target.get_parent().get_parent().visible,
			"a board without a run should hide the objective card")
	_check(_text(plain.hud, "label_board_effects") == "",
			"a board without modifiers should hide the rule cue, got '%s'"
			% _text(plain.hud, "label_board_effects"))
	plain.queue_free()
	await physics_frame


func _open_board() -> Node3D:
	var board: Node3D = (load("res://scenes/board/board.tscn") as PackedScene).instantiate()
	root.add_child(board)
	return board


## Text of a HUD label by name; empty when the HUD does not build it (the
## failure then reads as a missing label, not as a script crash).
func _text(hud: CanvasLayer, label_name: String) -> String:
	if hud == null:
		return ""
	var label = hud.get(label_name)
	return "" if label == null else str(label.text)


func _same_ids(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if StringName(a[i]) != StringName(b[i]):
			return false
	return true
