extends SceneTree
## S17/S18 (D8/D10) chest reveal: opening a chest pauses the board and shows
## the wheel — a row of icon slots that cycle the real loot pool, decelerate
## and stop on the drawn prize. When the drawn prize's class shelf has room the
## end of the reveal grants it; when that shelf is full the wheel offers one
## button per owned prize of the class to drop OR declining for the board's
## cash fallback, keeping the shelf as it is (no mandatory trade).
## The panel is driven through its public API: the board calls present(), the
## test calls settle() instead of waiting real time, then pick()/decline() to
## decide. is_open()/picked stay the observable contract.
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
	await _test_the_wheel_presents_on_a_paused_board()
	await _test_the_spin_advances_and_stops_on_the_drawn_prize()
	await _test_a_chest_with_room_grants_at_the_end_of_the_reveal()
	await _test_full_shelf_offers_the_owned_permanents()
	await _test_out_of_range_picks_are_rejected()
	await _test_pick_drops_the_chosen_prize()
	await _test_declining_takes_the_cash_and_keeps_the_shelf()
	await _test_a_spent_chest_offers_no_second_choice()
	# A GDScript error aborts one test function without touching `failed`, so a
	# suite would print OK with tests that never ran. The count is deterministic,
	# so the exact full-pass total is the guard: one dead test always fails here.
	# Adding a test means bumping this number with it.
	_check(checks_run >= 136, "only %d checks ran: a test died before asserting" % checks_run)
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


## The shelf prefix a def of this class must land on (D8 routing).
func _class_prefix(def: PrizeDef) -> String:
	match def.prize_class:
		PrizeDef.PrizeClass.CONSUMABLE:
			return "consumable:"
		PrizeDef.PrizeClass.COSMETIC:
			return "cosmetic:"
		_:
			return "prize:"


## The entries a shelf gained since `before`, one per granted def.
func _added_since(before: Array[String]) -> Array[String]:
	var added: Array[String] = []
	for entry in _shelf_ids():
		if not before.has(entry):
			added.append(entry)
	return added


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


## Touch the board's first chest and return the wheel it must present.
func _open_chest(board: Node3D):
	if board.chests.is_empty():
		_check(false, "the board should carry a chest")
		return null
	board._check_chests(board.chests[0].pos)
	var panel = board.get_node_or_null("ChestChoice")
	_check(panel != null, "opening a chest should present the reveal wheel (S17)")
	return panel


## Every slot's visible text, so "the slots cycle" is a plain comparison.
func _slot_texts(panel) -> String:
	var texts: Array[String] = []
	if panel == null:
		return ""
	for slot in panel.slots:
		texts.append(slot.label.text)
	return " | ".join(texts)


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


# --- (b) The wheel the board presents (S17) ---------------------------------


## S17: opening a chest pauses the board and shows the wheel: a row of slots
## cycling real loot defs, a title that does not spoil the winner yet, and a
## spin short enough for the throw loop.
func _test_the_wheel_presents_on_a_paused_board() -> void:
	var board := _full_shelf_board()
	await physics_frame
	var panel = _open_chest(board)
	if panel == null:
		_close(board)
		return
	_check(panel.is_open(), "the wheel should report itself open")
	_check(paused, "the reveal should pause the board (S17)")
	_check(panel.is_spinning(), "the wheel should start spinning (S17)")
	_check(
		panel.SPIN_TIME >= 0.8 and panel.SPIN_TIME <= 1.2,
		"the spin should last between 0.8 and 1.2 s, it is %s" % panel.SPIN_TIME
	)
	_check(
		panel.slots.size() >= 3, "the wheel should show a row of slots, got %d" % panel.slots.size()
	)
	for slot in panel.slots:
		var def: PrizeDef = slot.get("def")
		_check(def != null, "every slot should carry a loot def while spinning")
		if def != null:
			_check(panel.pool.has(def), "slot %s should come from the loot pool" % def.display_name)
			_check(
				slot.label.text.contains(def.display_name),
				"the slot should show %s, got '%s'" % [def.display_name, slot.label.text]
			)
	# The spin is the reveal: the title must not name the winner before it stops.
	_check(panel.title_label != null, "the wheel should carry a title")
	if panel.title_label != null:
		_check(
			not panel.title_label.text.contains(panel.drawn.display_name),
			(
				"the title must not spoil the drawn prize before the stop, got '%s'"
				% panel.title_label.text
			)
		)
	# The wheel is time-driven and the tree is paused: only PROCESS_MODE_ALWAYS
	# keeps the slots moving, so the panel must animate by itself here.
	var animated := false
	for i in 8:
		await process_frame
		if panel.spin_elapsed > 0.0:
			animated = true
			break
	_check(animated, "the wheel should animate under the paused tree (PROCESS_MODE_ALWAYS)")
	_close(board)
	_check(not paused, "closing a live wheel must not leave the tree paused")


## S17: the slots move while the spin lasts (a tick advances them), the wheel
## decelerates onto the drawn prize and stops there — the winner slot is the
## marked one and the panel does not resolve twice.
func _test_the_spin_advances_and_stops_on_the_drawn_prize() -> void:
	var board := _full_shelf_board()
	await physics_frame
	var panel = _open_chest(board)
	if panel == null:
		_close(board)
		return
	var before: String = _slot_texts(panel)
	panel.tick(0.3)
	_check(panel.is_spinning(), "a partial tick must not end the spin")
	_check(_slot_texts(panel) != before, "the slots should cycle while the wheel spins")
	_check(paused, "the spin keeps the board paused (S17)")
	_check(panel.settle(), "settle() should finish the reveal")
	_check(not panel.is_spinning(), "the wheel should stop after settle()")
	if panel.winner_slot < 0 or panel.winner_slot >= panel.slots.size():
		_check(false, "the wheel should mark a winning slot, got %d" % panel.winner_slot)
	else:
		var winner: Dictionary = panel.slots[panel.winner_slot]
		_check(
			winner.get("def") == panel.drawn,
			"the wheel should stop on the drawn prize, it stopped on %s" % str(winner.get("def"))
		)
		_check(winner.get("winner", false), "the winning slot should be marked as the winner")
		_check(
			winner.label.text.contains(panel.drawn.display_name),
			(
				"the winning slot should show %s, got '%s'"
				% [panel.drawn.display_name, winner.label.text]
			)
		)
	_check(
		panel.title_label != null and panel.title_label.text.contains(panel.drawn.display_name),
		"the title should name the prize once the wheel stops"
	)
	# A second settle on the resolved wheel must not resolve a second time.
	var shelf: String = _shelf_line()
	var money: int = game.money
	_check(not panel.settle(), "a resolved wheel should refuse a second settle()")
	_check(
		_shelf_line() == shelf,
		"a second settle must not touch a shelf (%s -> %s)" % [shelf, _shelf_line()]
	)
	_check(
		game.money == money,
		"a second settle must not move money ($%d -> $%d)" % [money, game.money]
	)
	_close(board)


## S15/S17: a drawn prize whose class still has room needs no decision: the
## wheel grants it when the reveal ends, never during the spin, and the board
## resumes with the new shelf on the rails.
func _test_a_chest_with_room_grants_at_the_end_of_the_reveal() -> void:
	game.start_run()
	var board := _open_board()
	await physics_frame
	var shelf: Array[String] = _shelf_ids()
	var money_before: int = game.money
	var panel = _open_chest(board)
	if panel == null:
		_close(board)
		return
	var drawn: PrizeDef = panel.drawn
	_check(drawn != null, "the wheel should carry the drawn prize")
	_check(
		not panel.has_choice(),
		"a prize that fits its class should need no decision, stage offers one"
	)
	_check(
		panel.buttons.is_empty() and panel.decline_button == null,
		"the wheel should offer no buttons when the drawn prize fits"
	)
	_check(
		_added_since(shelf).is_empty(),
		"nothing should be granted while the wheel still spins, got %s" % str(_added_since(shelf))
	)
	_check(not panel.pick(0), "pick() should be inert while the wheel spins")
	_check(not panel.decline(), "decline() should be inert while the wheel spins")
	_check(panel.is_open(), "a rejected decision must leave the wheel up")
	_check(paused, "a rejected decision must leave the board paused")
	var reveals: Array[int] = []
	panel.revealed.connect(func() -> void: reveals.append(1))
	_check(panel.settle(), "settle() should finish the reveal")
	_check(reveals.size() == 1, "the reveal should be reported once, got %d" % reveals.size())
	_check(not panel.is_open(), "a granted chest should close the wheel")
	_check(not paused, "a granted chest should resume the board")
	var added: Array[String] = _added_since(shelf)
	_check(
		added.size() == 1,
		"the reveal should grant exactly one thing, got %d (%s)" % [added.size(), ", ".join(added)]
	)
	if drawn != null:
		_check(
			added.has(_class_prefix(drawn) + drawn.id),
			(
				"the drawn %s should land on its own class shelf, added %s"
				% [drawn.display_name, str(added)]
			)
		)
		_check(
			board.hud.last_flash.contains(drawn.display_name),
			"the cue should name %s, got '%s'" % [drawn.display_name, board.hud.last_flash]
		)
		_check(
			board.hud.last_flash.contains(drawn.class_name_text()),
			"the cue should name the class, got '%s'" % board.hud.last_flash
		)
	_check(
		game.money == money_before,
		"a granted prize must not also pay cash ($%d -> $%d)" % [money_before, game.money]
	)
	_close(board)


# --- (c) Full shelf: the decision (S18) -------------------------------------


## S18: with the drawn prize's class full, the stopped wheel offers exactly the
## owned prizes of that class, one button each, naming the prize and its effect
## under the drawn prize's title — and nothing is granted or paid until the
## player decides.
func _test_full_shelf_offers_the_owned_permanents() -> void:
	var board := _full_shelf_board()
	await physics_frame
	var panel = _open_chest(board)
	if panel == null:
		_close(board)
		return
	var shelf: String = _shelf_line()
	var money_before: int = game.money
	_check(panel.settle(), "settle() should stop the wheel and offer the decision")
	_check(panel.has_choice(), "a full class shelf should offer a decision (S18)")
	_check(paused, "the decision should keep the board paused (S17/S18)")
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
			"the panel should show one drop button per option (%d buttons, %d options)"
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
	_check(panel.decline_button != null, "the decision should also offer declining for cash (S18)")
	if panel.drawn != null and panel.title_label != null:
		_check(
			panel.title_label.text.contains(panel.drawn.display_name),
			"the title should name the drawn prize %s" % panel.drawn.display_name
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


## S18: a pick outside the offered list is refused: no signal, no shelf change,
## and the board stays paused under the still-open panel.
func _test_out_of_range_picks_are_rejected() -> void:
	var board := _full_shelf_board()
	await physics_frame
	var panel = _open_chest(board)
	if panel == null:
		_close(board)
		return
	panel.settle()
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


## S11/S18: the drop pays nothing (selling pays rescue value; a chest discard
## must never be a money trick), the drawn one takes the freed slot, both rails
## refresh, one cue names the trade and the board resumes.
func _test_pick_drops_the_chosen_prize() -> void:
	var board := _full_shelf_board()
	await physics_frame
	var panel = _open_chest(board)
	if panel == null:
		_close(board)
		return
	panel.settle()
	_check(panel.has_choice(), "a full class shelf should offer the drop decision")
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


## S18: declining is the cash answer, not a second cash trick: the wheel pays
## the board's fallback once, the shelf keeps every prize it had, and the board
## resumes. A closed wheel refuses further decisions.
func _test_declining_takes_the_cash_and_keeps_the_shelf() -> void:
	var board := _full_shelf_board()
	await physics_frame
	var panel = _open_chest(board)
	if panel == null:
		_close(board)
		return
	panel.settle()
	_check(panel.has_choice(), "a full class shelf should offer the decline button")
	var fallback: int = board.board_def.chest_cash_fallback
	_check(panel.decline_button != null, "the choice should offer declining for cash (S18)")
	if panel.decline_button != null:
		_check(
			panel.decline_button.text.contains("$%d" % fallback),
			(
				"the decline button should name the $%d it pays, got '%s'"
				% [fallback, panel.decline_button.text]
			)
		)
	var shelf: String = _shelf_line()
	var money_before: int = game.money
	var picks: Array[PrizeDef] = []
	var declines: Array[int] = []
	panel.picked.connect(func(old_prize: PrizeDef) -> void: picks.append(old_prize))
	panel.declined.connect(func(cash: int) -> void: declines.append(cash))
	_check(panel.decline(), "declining should be accepted")
	_check(
		declines.size() == 1 and declines[0] == fallback,
		"the panel should report the $%d it declined for, got %s" % [fallback, str(declines)]
	)
	_check(picks.is_empty(), "declining must not drop a prize, got %d drops" % picks.size())
	_check(
		game.money == money_before + fallback,
		"declining should pay the $%d fallback ($%d -> $%d)" % [fallback, money_before, game.money]
	)
	_check(
		_shelf_line() == shelf,
		"declining must keep the shelf as it is (%s -> %s)" % [shelf, _shelf_line()]
	)
	_check(not panel.is_open(), "declining should close the wheel")
	_check(not paused, "declining should resume the board")
	_check(
		board.hud.last_flash.contains("$%d" % fallback),
		"the cue should name the cash taken ($%d), got '%s'" % [fallback, board.hud.last_flash]
	)
	_check(not panel.pick(0), "a closed wheel should refuse a pick")
	_check(not panel.decline(), "a closed wheel should refuse a second decline")
	_check(
		_shelf_line() == shelf,
		(
			"a refused decision after the close must not touch a shelf (%s -> %s)"
			% [shelf, _shelf_line()]
		)
	)
	_check(
		game.money == money_before + fallback,
		"a refused decision after the close must not pay twice ($%d)" % (money_before + fallback)
	)
	_close(board)


## S16/S11: the chest was marked opened before the reveal, so a second pass
## over it neither presents the wheel again nor grants a second prize.
func _test_a_spent_chest_offers_no_second_choice() -> void:
	var board := _full_shelf_board()
	await physics_frame
	var panel = _open_chest(board)
	if panel == null:
		_close(board)
		return
	panel.settle()
	panel.pick(0)
	await physics_frame
	var shelf: String = _shelf_line()
	var money: int = game.money
	var flash: String = board.hud.last_flash
	board._check_chests(board.chests[0].pos)
	await physics_frame
	var again = board.get_node_or_null("ChestChoice")
	_check(
		again == null or not again.is_open(),
		"an opened chest must not offer the reveal a second time"
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
