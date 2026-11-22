extends SceneTree
## S11 (D8/D10) full-bag discard choice: a chest whose drawn prize has no room
## on that class's shelf pauses the board and offers the owned prizes of that
## class; the player picks which one to drop and the drawn prize takes the
## freed slot, with no money move (discarding is not selling). The panel is
## driven through its public present()/pick()/is_open() API, no clicks.
## Run: godot --headless --path . --script res://tests/chest_choice.gd

var failed := false
var checks_run := 0
var game
var content


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


func _run() -> void:
	await physics_frame
	_test_discard_pays_nothing_and_rejects_the_unowned()
	await _test_full_shelf_offers_the_owned_permanents()
	await _test_out_of_range_picks_are_rejected()
	await _test_pick_drops_the_chosen_prize()
	await _test_a_spent_chest_offers_no_second_choice()
	# A GDScript error aborts one test function without touching `failed`, so a
	# suite would print OK with tests that never ran. The count is deterministic,
	# so the exact full-pass total is the guard: one dead test always fails here.
	# Adding a test means bumping this number with it.
	_check(checks_run >= 60, "only %d checks ran: a test died before asserting" % checks_run)
	print("CHEST CHOICE FAIL" if failed else "CHEST CHOICE OK")
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	checks_run += 1
	if condition:
		return
	failed = true
	print("CHEST CHOICE FAIL: " + label)


func _open_board() -> Node3D:
	var board: Node3D = (load("res://scenes/board/board.tscn") as PackedScene).instantiate()
	root.add_child(board)
	return board


func _close(board: Node3D) -> void:
	root.remove_child(board)
	board.free()


## Everything the run holds right now, one entry per def, so "the shelves did
## not move" is a plain list comparison.
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


## A run whose prize shelf is full and whose chest pool only holds permanents,
## so every draw needs a permanent dropped. The consumable shelf is filled
## past its cap on purpose (a direct assign: the caps only gate the buy and
## grant seams) because the pool has four consumables and the shelf holds
## three, so otherwise a consumable could win the draw and the panel would
## offer that class instead.
func _full_shelf_board() -> Node3D:
	game.start_run()
	game.prizes.assign([content.prize_def("carpa"), content.prize_def("osito")])
	(
		game
		. consumables
		. assign(
			[
				content.prize_def("globo"),
				content.prize_def("boleto"),
				content.prize_def("billete"),
				content.prize_def("muneco"),
			]
		)
	)
	game.cosmetics.assign(
		[content.prize_def("banderin"), content.prize_def("silbato"), content.prize_def("foto")]
	)
	_check(
		game.prizes.size() == game.prize_cap(),
		"the prize shelf should be full (%d of %d)" % [game.prizes.size(), game.prize_cap()]
	)
	return _open_board()


## The discard panel the board should have presented, or a recorded failure.
func _discard_panel(board: Node3D) -> CanvasLayer:
	var panel: CanvasLayer = board.get_node_or_null("ChestChoice")
	_check(panel != null, "a refused grant should present the discard panel (S11)")
	return panel


# --- (a) The discard seam on Game -------------------------------------------


## S11: discarding is not selling. It pays nothing and it refuses a def the
## run does not own without touching a shelf or the money.
func _test_discard_pays_nothing_and_rejects_the_unowned() -> void:
	game.start_run()
	var carpa: PrizeDef = content.prize_def("carpa")
	game.prizes.assign([carpa])
	var money_before: int = game.money
	_check(game.discard_prize(carpa), "discarding an owned prize should succeed")
	_check(not game.prizes.has(carpa), "the discarded prize should leave the shelf")
	_check(
		game.money == money_before,
		"discarding must not pay rescue value ($%d -> $%d)" % [money_before, game.money]
	)
	var shelf: String = _shelf_line()
	_check(
		not game.discard_prize(carpa), "discarding a prize the run does not own should be refused"
	)
	_check(
		_shelf_line() == shelf,
		"a refused discard must not change a shelf (%s -> %s)" % [shelf, _shelf_line()]
	)
	_check(
		game.money == money_before,
		"a refused discard must not move money ($%d -> $%d)" % [money_before, game.money]
	)
	# The def's own class decides the shelf it leaves, so a consumable never
	# has to be dropped from the prize shelf to be discarded.
	var globo: PrizeDef = content.prize_def("globo")
	game.consumables.assign([globo])
	_check(game.discard_prize(globo), "discarding an owned consumable should succeed")
	_check(game.consumables.is_empty(), "the discarded consumable should leave its own shelf")
	_check(
		game.money == money_before,
		"discarding a consumable must not move money ($%d -> $%d)" % [money_before, game.money]
	)


# --- (b) The panel the board presents ---------------------------------------


## S11: the refusal is not a silent cash payout any more: the board pauses and
## the reveal offers exactly the owned permanents, one button each, naming the
## prize and its effect under the drawn prize's title.
func _test_full_shelf_offers_the_owned_permanents() -> void:
	var board := _full_shelf_board()
	await physics_frame
	_check(board.chests.size() >= 1, "the board should carry a chest")
	if board.chests.is_empty():
		_close(board)
		return
	var chest: Dictionary = board.chests[0]
	var shelf: String = _shelf_line()
	var money_before: int = game.money
	board._check_chests(chest.pos)
	_check(chest.opened, "touching a chest should open it")
	var panel := _discard_panel(board)
	if panel != null:
		_check(panel.is_open(), "the discard panel should report itself open")
		_check(paused, "the discard choice should pause the board (S11)")
		_check(panel.drawn != null, "the panel should carry the drawn prize")
		if panel.drawn != null:
			_check(
				panel.drawn.prize_class == PrizeDef.PrizeClass.PERMANENT,
				"the setup should draw a permanent, drew %s" % panel.drawn.display_name
			)
		var expected: Array[PrizeDef] = [content.prize_def("carpa"), content.prize_def("osito")]
		_check(
			panel.options.size() == expected.size(),
			(
				"the panel should offer the %d owned permanents, got %d"
				% [expected.size(), panel.options.size()]
			)
		)
		for def in expected:
			_check(
				panel.options.has(def),
				"the panel should offer the owned permanent %s" % def.display_name
			)
		_check(
			panel.buttons.size() == panel.options.size(),
			(
				"the panel should show one button per option (%d buttons, %d options)"
				% [panel.buttons.size(), panel.options.size()]
			)
		)
		for i in mini(panel.buttons.size(), panel.options.size()):
			var text: String = panel.buttons[i].text
			var prize: PrizeDef = panel.options[i]
			_check(
				text.contains(prize.display_name),
				"the button should name %s, got '%s'" % [prize.display_name, text]
			)
			_check(
				text.contains(prize.effect_description()),
				"the button should carry %s's effect line, got '%s'" % [prize.display_name, text]
			)
		if panel.drawn != null:
			_check(
				(
					panel.title_label != null
					and panel.title_label.text.contains(panel.drawn.display_name)
				),
				(
					"the title should name the drawn prize %s"
					% (panel.drawn.display_name if panel.drawn != null else "?")
				)
			)
	# Nothing is granted or paid while the player decides.
	_check(
		game.money == money_before,
		"a refused grant must not pay the cash fallback ($%d -> $%d)" % [money_before, game.money]
	)
	_check(
		_shelf_line() == shelf,
		"the choice must not touch a shelf before the pick (%s -> %s)" % [shelf, _shelf_line()]
	)
	_close(board)
	_check(not paused, "closing a pending choice must not leave the tree paused")


## S11: a pick outside the offered list is refused: no signal, no shelf change,
## and the board stays paused under the still-open panel.
func _test_out_of_range_picks_are_rejected() -> void:
	var board := _full_shelf_board()
	await physics_frame
	if board.chests.is_empty():
		_check(false, "the board should carry a chest")
		_close(board)
		return
	board._check_chests(board.chests[0].pos)
	var panel := _discard_panel(board)
	if panel == null:
		_close(board)
		return
	var picked: Array[PrizeDef] = []
	panel.picked.connect(func(old_prize: PrizeDef) -> void: picked.append(old_prize))
	var shelf: String = _shelf_line()
	var money_before: int = game.money
	_check(not panel.pick(-1), "pick(-1) should be rejected")
	_check(not panel.pick(99), "pick(99) should be rejected")
	_check(picked.is_empty(), "a rejected pick must not emit picked, got %d" % picked.size())
	_check(panel.is_open(), "a rejected pick must leave the panel open")
	_check(paused, "a rejected pick must leave the board paused")
	_check(
		_shelf_line() == shelf,
		"a rejected pick must not touch a shelf (%s -> %s)" % [shelf, _shelf_line()]
	)
	_check(
		game.money == money_before,
		"a rejected pick must not move money ($%d -> $%d)" % [money_before, game.money]
	)
	_close(board)


# --- (c) The pick itself ----------------------------------------------------


## S11: the pick drops that prize, the drawn one takes the freed slot, nothing
## is paid, both rails refresh, one cue names the trade, and the board resumes.
func _test_pick_drops_the_chosen_prize() -> void:
	var board := _full_shelf_board()
	await physics_frame
	if board.chests.is_empty():
		_check(false, "the board should carry a chest")
		_close(board)
		return
	board._check_chests(board.chests[0].pos)
	var panel := _discard_panel(board)
	if panel == null:
		_close(board)
		return
	var drawn: PrizeDef = panel.drawn
	var dropped: PrizeDef = panel.options[0] if not panel.options.is_empty() else null
	var shelf_size: int = game.prizes.size()
	var money_before: int = game.money
	var picked: Array[PrizeDef] = []
	panel.picked.connect(func(old_prize: PrizeDef) -> void: picked.append(old_prize))
	_check(panel.pick(0), "a pick inside the offered list should be accepted")
	_check(
		picked.size() == 1 and picked[0] == dropped,
		"the panel should report the dropped prize, got %d entries" % picked.size()
	)
	_check(dropped != null, "the panel should have offered a first prize")
	if dropped != null:
		_check(not game.prizes.has(dropped), "%s should leave the shelf" % dropped.display_name)
	_check(drawn != null, "the chest should have drawn a prize")
	if drawn != null:
		_check(
			game.prizes.has(drawn), "the drawn %s should take the freed slot" % drawn.display_name
		)
	_check(
		game.prizes.size() == shelf_size,
		"the prize shelf should keep its size (%d -> %d)" % [shelf_size, game.prizes.size()]
	)
	_check(
		game.money == money_before,
		"a discard must not pay cash ($%d -> $%d)" % [money_before, game.money]
	)
	_check(not panel.is_open(), "a valid pick should close the panel")
	_check(not paused, "a valid pick should resume the tree")
	if dropped != null:
		_check(
			board.hud.last_flash.contains(dropped.display_name),
			(
				"the cue should name what was dropped (%s), got '%s'"
				% [dropped.display_name, board.hud.last_flash]
			)
		)
	if drawn != null:
		_check(
			board.hud.last_flash.contains(drawn.display_name),
			(
				"the cue should name what arrived (%s), got '%s'"
				% [drawn.display_name, board.hud.last_flash]
			)
		)
	_check(
		board.hud.prize_box.get_child_count() == game.prizes.size(),
		(
			"the prize rail should show the new shelf (%d cards for %d prizes)"
			% [board.hud.prize_box.get_child_count(), game.prizes.size()]
		)
	)
	_close(board)


## S16/S11: the chest was marked opened before the choice, so a second pass
## over it neither offers the panel again nor grants a second prize.
func _test_a_spent_chest_offers_no_second_choice() -> void:
	var board := _full_shelf_board()
	await physics_frame
	if board.chests.is_empty():
		_check(false, "the board should carry a chest")
		_close(board)
		return
	var chest: Dictionary = board.chests[0]
	board._check_chests(chest.pos)
	var panel := _discard_panel(board)
	if panel == null:
		_close(board)
		return
	panel.pick(0)
	await physics_frame
	var shelf: String = _shelf_line()
	var money: int = game.money
	var flash: String = board.hud.last_flash
	board._check_chests(chest.pos)
	await physics_frame
	var again: CanvasLayer = board.get_node_or_null("ChestChoice")
	_check(
		again == null or not again.is_open(),
		"an opened chest must not offer the discard choice a second time"
	)
	_check(
		_shelf_line() == shelf,
		"a second pass must not grant a second prize (%s -> %s)" % [shelf, _shelf_line()]
	)
	_check(
		game.money == money, "a second pass must not move money ($%d -> $%d)" % [money, game.money]
	)
	_check(
		board.hud.last_flash == flash,
		"a second pass must not flash a second cue ('%s' -> '%s')" % [flash, board.hud.last_flash]
	)
	_check(not paused, "the board should stay resumed after a spent chest")
	_close(board)
