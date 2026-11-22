extends SceneTree
## D10 chests (S5/S6/S12/S13/S14/S15/S16): the fixed and hidden chests a
## board carries, the trigger that opens one while the marble keeps rolling,
## the two-step loot draw on Economy and the grant through the shop's seam.
## Run: godot --headless --path . --script res://tests/chests.gd

var failed := false
var checks_run := 0
var game
var content
var economy


func _initialize() -> void:
	_ensure_autoloads()
	_run()


## In --script mode Godot does not register project autoloads; install the
## ones under test in dependency order (Game reads Economy, every def read
## goes through ContentDB).
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
	economy = root.get_node("Economy")


func _run() -> void:
	await physics_frame
	_test_board_def_defaults()
	_test_draw_determinism()
	_test_draw_skips_owned_and_collected()
	_test_empty_pool_pays_cash()
	await _test_empty_pool_on_a_board_pays_the_fallback()
	await _test_one_fixed_chest_by_default()
	await _test_board_can_opt_out()
	await _test_hidden_chance()
	await _test_chest_opens_and_grants_one_thing()
	await _test_marble_keeps_rolling_through_a_chest()
	await _test_second_check_changes_nothing()
	await _test_full_shelves_pay_cash()
	# A GDScript error aborts one test function without touching `failed`, so a
	# suite would print OK with tests that never ran. This floor is the count a
	# full pass produces, minus headroom: fewer checks means a test died before
	# its assertions.
	_check(checks_run >= 170, "only %d checks ran: a test died before asserting" % checks_run)
	print("CHESTS FAIL" if failed else "CHESTS OK")
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	checks_run += 1
	if condition:
		return
	failed = true
	print("CHESTS FAIL: " + label)


func _open_board() -> Node3D:
	var board: Node3D = (load("res://scenes/board/board.tscn") as PackedScene).instantiate()
	root.add_child(board)
	return board


func _close(board: Node3D) -> void:
	root.remove_child(board)
	board.free()


## BoardDef the board scene renders for the run's current board.
func _run_def() -> BoardDef:
	return content.board_def(game.board_def_index(game.current_board_in_run))


## Everything the run holds right now, one entry per def, so a "exactly one
## thing was granted" check is a plain list diff.
func _shelf_ids() -> Array[String]:
	var ids: Array[String] = []
	for def in game.prizes:
		ids.append("prize:" + def.id)
	for def in game.consumables:
		ids.append("consumable:" + def.id)
	for def in game.cosmetics:
		ids.append("cosmetic:" + def.id)
	return ids


func _shelf_line() -> String:
	return "\n".join(_shelf_ids())


## Count collision nodes under one subtree: a chest must carry none (S12),
## or the marble would be deflected by a decorative box.
func _count_colliders(node: Node) -> int:
	var count := 0
	if node is CollisionObject3D or node is CollisionShape3D:
		count += 1
	for child in node.get_children():
		count += _count_colliders(child)
	return count


## A body without shape or gravity: the test decides where it is, so the
## chest trigger can be driven one physics frame at a time.
func _ghost_marble(board: Node3D, local: Vector3) -> RigidBody3D:
	var marble := RigidBody3D.new()
	marble.mass = 1.0
	marble.gravity_scale = 0.0
	board.board.add_child(marble)
	marble.global_position = board.board.to_global(local)
	return marble


# --- (a) BoardDef defaults: every board carries its chests, no data edit ----


## S13: the chests are BoardDef defaults, so the 25 existing boards spawn
## them without a single .tres edit.
func _test_board_def_defaults() -> void:
	for i in content.board_count():
		var def: BoardDef = content.board_def(i)
		_check(def.chest_fixed, "%s should carry its fixed chest by default" % def.theme_name)
		_check(
			is_equal_approx(def.chest_hidden_chance, 0.25),
			(
				"%s should roll a hidden chest at 0.25, got %s"
				% [def.theme_name, def.chest_hidden_chance]
			)
		)
		_check(
			def.chest_cash_fallback == 3,
			"%s should fall back to $3, got $%d" % [def.theme_name, def.chest_cash_fallback]
		)
		# The documented chest band must land on the deck for every board, not
		# only for the one a run happens to render: a board too short for its own
		# grid would otherwise spawn its chest past the back wall.
		var chest_z := def.first_row_z + (def.rows - 1) * def.spacing_z + def.spacing_z * 0.9
		_check(
			absf(chest_z) < def.length / 2.0,
			(
				"%s should keep its chest on the deck, z %s of %s"
				% [def.theme_name, chest_z, def.length]
			)
		)


# --- (b) The two-step loot draw (S14) ---------------------------------------


## A seed makes the draw repeatable, so a chest loot test never flakes.
func _test_draw_determinism() -> void:
	var owned: Array[String] = []
	var collected: Array[String] = []
	var first: Dictionary = economy.chest_draw(owned, collected, 4242)
	var again: Dictionary = economy.chest_draw(owned, collected, 4242)
	_check(
		String(first["def_id"]) == String(again["def_id"]),
		(
			"the same seed should draw the same def, got '%s' and '%s'"
			% [first["def_id"], again["def_id"]]
		)
	)
	_check(
		int(first["cash"]) == int(again["cash"]),
		"the same seed should pay the same cash, got %d and %d" % [first["cash"], again["cash"]]
	)


## S14: an owned or collected def is skipped, so every chest is a new toy.
func _test_draw_skips_owned_and_collected() -> void:
	var owned: Array[String] = []
	var collected: Array[String] = []
	for def in content.prizes():
		if def.id == "trompo":
			continue
		if def.prize_class == PrizeDef.PrizeClass.COSMETIC:
			collected.append(def.id)
		else:
			owned.append(def.id)
	# One permanent left in the pool: every seed must land on it.
	for seed_value in 8:
		var draw: Dictionary = economy.chest_draw(owned, collected, seed_value)
		_check(
			String(draw["def_id"]) == "trompo",
			(
				"a chest should only draw the one new def, got '%s' (seed %d)"
				% [draw["def_id"], seed_value]
			)
		)
	# A mostly-open pool never hands back an owned or collected def.
	var partial_owned: Array[String] = ["trompo"]
	for seed_value in 8:
		var draw: Dictionary = economy.chest_draw(partial_owned, collected, seed_value)
		var drawn := String(draw["def_id"])
		_check(drawn != "", "a non-empty pool should draw a def (seed %d)" % seed_value)
		_check(
			not partial_owned.has(drawn),
			"a chest drew an owned def: '%s' (seed %d)" % [drawn, seed_value]
		)
		_check(
			not collected.has(drawn),
			"a chest drew a collected def: '%s' (seed %d)" % [drawn, seed_value]
		)


## S14: nothing new left to give, so the chest still pays instead of opening
## an empty box. The draw hands the choice over; the board owns the amount.
func _test_empty_pool_pays_cash() -> void:
	var none: Array[String] = []
	var all_owned: Array[String] = []
	for def in content.prizes():
		all_owned.append(def.id)
	var owned_draw: Dictionary = economy.chest_draw(all_owned, none, 7)
	_check(
		String(owned_draw["def_id"]) == "",
		"an empty pool should draw no def, got '%s'" % owned_draw["def_id"]
	)
	_check(
		int(owned_draw["cash"]) == 0,
		(
			"the draw should hand nothing over and let the board price the cash, got $%d"
			% int(owned_draw["cash"])
		)
	)
	# Collected ids empty the pool the same way owned ids do.
	var collected_draw: Dictionary = economy.chest_draw(none, all_owned, 7)
	_check(
		String(collected_draw["def_id"]) == "",
		"a fully collected pool should draw no def, got '%s'" % collected_draw["def_id"]
	)
	_check(
		int(collected_draw["cash"]) == 0,
		"a fully collected pool should hand nothing over, got $%d" % int(collected_draw["cash"])
	)


## S14/S15: with every def owned the board's pool is empty, so the chest pays
## the board's fallback rather than granting nothing.
func _test_empty_pool_on_a_board_pays_the_fallback() -> void:
	game.start_run()
	game.prizes.clear()
	game.consumables.clear()
	game.cosmetics.clear()
	for def in content.prizes():
		game.prizes.append(def)
	var board := _open_board()
	await physics_frame
	_check(board.chests.size() >= 1, "the board should carry a chest")
	if board.chests.is_empty():
		_close(board)
		return
	var chest: Dictionary = board.chests[0]
	var shelf: String = _shelf_line()
	var money_before: int = game.money
	var fallback: int = board.board_def.chest_cash_fallback
	board._check_chests(chest.pos)
	await physics_frame
	_check(
		game.money == money_before + fallback,
		(
			"an empty pool should pay the board's $%d fallback, $%d -> $%d"
			% [fallback, money_before, game.money]
		)
	)
	_check(_shelf_line() == shelf, "an empty pool must not change a shelf")
	_check(
		board.hud.last_flash.contains("$%d" % fallback),
		"the reveal should pay the cash amount, got '%s'" % board.hud.last_flash
	)
	_close(board)


# --- (c) The chests on the deck (S5/S12/S13) --------------------------------


## S5/S13: the default board carries one fixed chest, resting on the deck
## behind the notch rows, and it is a trigger volume, never an obstacle.
func _test_one_fixed_chest_by_default() -> void:
	game.start_run()
	var board := _open_board()
	await physics_frame
	var def := _run_def()
	var expected_z := def.first_row_z + (def.rows - 1) * def.spacing_z + def.spacing_z * 0.9
	var fixed_count := 0
	var fixed_chest: Dictionary = {}
	for chest in board.chests:
		if is_equal_approx(chest.pos.x, 0.0):
			fixed_count += 1
			if fixed_chest.is_empty():
				fixed_chest = chest
	_check(
		board.chests.size() >= 1,
		"a board should spawn at least its fixed chest, got %d" % board.chests.size()
	)
	_check(fixed_count == 1, "a board should spawn exactly one fixed chest, got %d" % fixed_count)
	if not fixed_chest.is_empty():
		_check(
			is_equal_approx(fixed_chest.pos.z, expected_z),
			(
				"the fixed chest should rest behind the notch rows at z %s, got %s"
				% [expected_z, fixed_chest.pos.z]
			)
		)
		_check(
			absf(fixed_chest.pos.z) < def.length / 2.0,
			"the fixed chest should rest on the deck, z %s" % fixed_chest.pos.z
		)
		_check(
			_count_colliders(fixed_chest.node) == 0,
			"a chest must carry no collision body, or it would deflect the marble"
		)
	_close(board)


## S13: a board can still opt out of both chests.
func _test_board_can_opt_out() -> void:
	game.start_run()
	var def := _run_def()
	var fixed_before: bool = def.chest_fixed
	var chance_before: float = def.chest_hidden_chance
	def.chest_fixed = false
	def.chest_hidden_chance = 0.0
	var board := _open_board()
	await physics_frame
	_check(
		board.chests.is_empty(),
		"a board that opts out should spawn no chest, got %d" % board.chests.size()
	)
	_close(board)
	def.chest_fixed = fixed_before
	def.chest_hidden_chance = chance_before


## S5: the hidden chest is a BoardDef chance: 0 leaves the fixed one alone,
## 1 always adds a second chest clear of it.
func _test_hidden_chance() -> void:
	game.start_run()
	var def := _run_def()
	var chance_before: float = def.chest_hidden_chance
	_check(def.chest_fixed, "the hidden chest test needs the fixed chest on")
	def.chest_hidden_chance = 0.0
	var alone := _open_board()
	await physics_frame
	_check(
		alone.chests.size() == 1,
		"with chance 0 the board should carry only the fixed chest, got %d" % alone.chests.size()
	)
	if alone.chests.size() == 1:
		_check(
			is_equal_approx(alone.chests[0].pos.x, 0.0),
			"the only chest should be the fixed one, x %s" % alone.chests[0].pos.x
		)
	_close(alone)
	def.chest_hidden_chance = 1.0
	var both := _open_board()
	await physics_frame
	_check(
		both.chests.size() == 2,
		(
			"with chance 1 the board should carry the fixed and a hidden chest, got %d"
			% both.chests.size()
		)
	)
	var hidden: Dictionary = {}
	for chest in both.chests:
		if not is_equal_approx(chest.pos.x, 0.0):
			hidden = chest
	if not hidden.is_empty():
		var limit: float = def.width * 0.35
		_check(
			absf(hidden.pos.x) <= limit,
			"the hidden chest should stay inside x +-%s, got %s" % [limit, hidden.pos.x]
		)
		_check(
			absf(hidden.pos.x) >= 0.6,
			"the hidden chest should roll clear of the fixed one, got x %s" % hidden.pos.x
		)
	_close(both)
	def.chest_hidden_chance = chance_before


# --- (d) Opening a chest (S12/S15/S16) --------------------------------------


## S15/S16: one draw, one grant through the shop's seam, one cue naming the
## prize and its class. S6: the score and the throw budget never move.
func _test_chest_opens_and_grants_one_thing() -> void:
	game.start_run()
	var board := _open_board()
	await physics_frame
	_check(board.chests.size() >= 1, "the board should carry a chest")
	if board.chests.is_empty():
		_close(board)
		return
	var chest: Dictionary = board.chests[0]
	var before: Array[String] = _shelf_ids()
	var money_before: int = game.money
	var total_before: int = board.score_engine.total
	var shots_before: int = board.shots_left
	var ammo_before: int = game.ammo.size()
	var marbles_before: int = board.active_marbles.size()
	board._check_chests(chest.pos)
	await physics_frame
	_check(chest.opened, "touching a chest should open it")
	var added: Array[String] = []
	for entry in _shelf_ids():
		if not before.has(entry):
			added.append(entry)
	_check(
		added.size() == 1,
		"a chest should grant exactly one thing, got %d (%s)" % [added.size(), ", ".join(added)]
	)
	_check(game.money == money_before, "a granted prize must not also pay cash")
	if added.size() == 1:
		var def: PrizeDef = content.find_prize_def(String(added[0].split(":")[1]))
		_check(def != null, "the granted entry should name a content def: %s" % added[0])
		if def != null:
			_check(
				board.hud.last_flash.begins_with("Cofre"),
				"the reveal should be the chest cue, got '%s'" % board.hud.last_flash
			)
			_check(
				board.hud.last_flash.contains(def.display_name),
				"the reveal should name %s, got '%s'" % [def.display_name, board.hud.last_flash]
			)
			_check(
				board.hud.last_flash.contains(def.class_name_text()),
				(
					"the reveal should name the class %s, got '%s'"
					% [def.class_name_text(), board.hud.last_flash]
				)
			)
	_check(
		board.score_engine.total == total_before,
		"a chest must not change the score (%d -> %d)" % [total_before, board.score_engine.total]
	)
	_check(
		board.shots_left == shots_before,
		"a chest must not spend a throw (%d -> %d)" % [shots_before, board.shots_left]
	)
	_check(
		game.ammo.size() == ammo_before,
		"a chest must not touch the run ammo (%d -> %d)" % [ammo_before, game.ammo.size()]
	)
	_check(
		board.active_marbles.size() == marbles_before,
		(
			"a chest must not touch the marble list (%d -> %d)"
			% [marbles_before, board.active_marbles.size()]
		)
	)
	_close(board)


## S12: the chest is a trigger the marble rolls through. The flight loop opens
## it, the marble survives, and the board keeps playing (S16: no pause).
func _test_marble_keeps_rolling_through_a_chest() -> void:
	game.start_run()
	var board := _open_board()
	await physics_frame
	_check(board.chests.size() >= 1, "the board should carry a chest")
	if board.chests.is_empty():
		_close(board)
		return
	var chest: Dictionary = board.chests[0]
	var pull_before: float = board.board_def.capture_pull
	# Keep the notch assist out of the way: this marble only visits the chest.
	board.board_def.capture_pull = 0.0
	var marble := _ghost_marble(board, chest.pos + Vector3(0.0, 0.05, 0.0))
	board.active_marbles.append(marble)
	marble.linear_velocity = Vector3.ZERO
	board.launch_timer = 0.0
	board.state = board.ThrowState.FLIGHT
	var total_before: int = board.score_engine.total
	var shots_before: int = board.shots_left
	var ammo_before: int = game.ammo.size()
	_check(not chest.opened, "the chest should start closed")
	for i in 3:
		await physics_frame
		if chest.opened:
			break
	_check(chest.opened, "the flight loop should open the chest the marble rolls over (S12/S13)")
	_check(
		board.active_marbles.has(marble) and is_instance_valid(marble),
		"the chest must not consume the marble (S6)"
	)
	_check(
		board.score_engine.total == total_before,
		"a chest must not change the score (%d -> %d)" % [total_before, board.score_engine.total]
	)
	_check(
		board.shots_left == shots_before,
		"a chest must not spend a throw (%d -> %d)" % [shots_before, board.shots_left]
	)
	_check(
		game.ammo.size() == ammo_before,
		"a chest must not touch the run ammo (%d -> %d)" % [ammo_before, game.ammo.size()]
	)
	_check(not paused, "the reveal must never pause the board (S16)")
	board.state = board.ThrowState.AIM
	board.active_marbles.erase(marble)
	marble.queue_free()
	board.board_def.capture_pull = pull_before
	_close(board)


## S16/S6: an opened chest is spent — a second pass over it changes nothing.
func _test_second_check_changes_nothing() -> void:
	game.start_run()
	var board := _open_board()
	await physics_frame
	_check(board.chests.size() >= 1, "the board should carry a chest")
	if board.chests.is_empty():
		_close(board)
		return
	var chest: Dictionary = board.chests[0]
	board._check_chests(chest.pos)
	await physics_frame
	var shelf: String = _shelf_line()
	var money: int = game.money
	var flash: String = board.hud.last_flash
	board._check_chests(chest.pos)
	await physics_frame
	_check(chest.opened, "the chest should still be marked opened")
	_check(
		_shelf_line() == shelf,
		"a second check on an opened chest must not grant again (%s -> %s)" % [shelf, _shelf_line()]
	)
	_check(
		game.money == money,
		"a second check on an opened chest must not pay again ($%d -> $%d)" % [money, game.money]
	)
	_check(
		board.hud.last_flash == flash,
		(
			"an opened chest must not flash its reveal twice ('%s' -> '%s')"
			% [flash, board.hud.last_flash]
		)
	)
	_close(board)


## S14/S15: the shelf of the drawn class is full, so the chest pays the
## BoardDef cash fallback and changes nothing else.
func _test_full_shelves_pay_cash() -> void:
	game.start_run()
	# Every shelf full and every consumable/cosmetic owned, so the pool only
	# has permanents left: a refused grant is the only possible outcome.
	game.prizes.assign([content.prize_def("carpa"), content.prize_def("osito")])
	(
		game
		. consumables
		. assign(
			[
				content.prize_def("globo"),
				content.prize_def("boleto"),
				content.prize_def("billete"),
			]
		)
	)
	game.cosmetics.assign(
		[content.prize_def("banderin"), content.prize_def("silbato"), content.prize_def("foto")]
	)
	_check(game.prizes.size() == game.prize_cap(), "the prize shelf should be full")
	_check(game.consumables.size() == game.CONSUMABLE_CAP, "the consumable shelf should be full")
	var board := _open_board()
	await physics_frame
	_check(board.chests.size() >= 1, "the board should carry a chest")
	if board.chests.is_empty():
		_close(board)
		return
	var chest: Dictionary = board.chests[0]
	var shelf: String = _shelf_line()
	var money_before: int = game.money
	var fallback: int = board.board_def.chest_cash_fallback
	board._check_chests(chest.pos)
	await physics_frame
	_check(chest.opened, "touching a chest should open it")
	_check(
		game.money == money_before + fallback,
		(
			"a chest the shelves cannot hold should pay the $%d fallback, $%d -> $%d"
			% [fallback, money_before, game.money]
		)
	)
	_check(
		_shelf_line() == shelf,
		"a refused grant must not touch a shelf (%s -> %s)" % [shelf, _shelf_line()]
	)
	_check(
		board.hud.last_flash.contains("$%d" % fallback),
		"the reveal should pay the cash amount, got '%s'" % board.hud.last_flash
	)
	_close(board)
