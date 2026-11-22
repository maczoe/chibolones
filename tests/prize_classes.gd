extends SceneTree
## D8 prize classes (S1/S4/S9) and the run consumable shelf (S10): the class
## data on the defs, how the shop routes a def by class, and the four instant
## consumable effects applied from the board.
## Run: godot --headless --path . --script res://tests/prize_classes.gd

var game
var content
var failed := false


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
	_test_class_data()
	_test_shop_routing()
	await _test_extra_throw_consumable()
	await _test_money_consumable()
	await _test_skip_threshold_consumable()
	await _test_replay_rejected_without_throw()
	await _test_debug_loadout_routes_by_class()
	print("PRIZE CLASSES FAIL" if failed else "PRIZE CLASSES OK")
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	print("PRIZE CLASSES FAIL: " + label)


func _open_board() -> Node:
	var board: Node = load("res://scenes/board/board.tscn").instantiate()
	root.add_child(board)
	return board


## S4/S9: the four situational prizes are consumables, the other six stay
## permanent usable. The data decides, not the code.
func _test_class_data() -> void:
	var consumable_ids := ["globo", "boleto", "billete", "muneco"]
	var permanent_ids := ["carpa", "trompo", "rayo", "pelota", "osito", "corona"]
	for id in consumable_ids:
		var def: PrizeDef = content.prize_def(id)
		_check(def != null, "%s should exist in data/prizes" % id)
		if def != null:
			_check(
				def.prize_class == PrizeDef.PrizeClass.CONSUMABLE,
				"%s should be CONSUMABLE, got %d" % [id, def.prize_class]
			)
	for id in permanent_ids:
		var def: PrizeDef = content.prize_def(id)
		_check(def != null, "%s should exist in data/prizes" % id)
		if def != null:
			_check(
				def.prize_class == PrizeDef.PrizeClass.PERMANENT,
				"%s should be PERMANENT, got %d" % [id, def.prize_class]
			)
	# The four consumables carry instant effects, never the old passives.
	var globo: PrizeDef = content.prize_def("globo")
	_check(globo.effect == &"instant_extra_throw", "globo should carry instant_extra_throw")
	var boleto: PrizeDef = content.prize_def("boleto")
	_check(boleto.effect == &"instant_replay", "boleto should carry instant_replay")
	var billete: PrizeDef = content.prize_def("billete")
	_check(billete.effect == &"instant_money", "billete should carry instant_money")
	var muneco: PrizeDef = content.prize_def("muneco")
	_check(muneco.effect == &"instant_skip_scale", "muneco should carry instant_skip_scale")
	# S8: cosmetics exist, cost nothing and carry no effect.
	var cosmetic_ids := ["banderin", "silbato", "foto"]
	for id in cosmetic_ids:
		var def: PrizeDef = content.prize_def(id)
		_check(def != null, "%s should exist in data/prizes" % id)
		if def != null:
			_check(
				def.prize_class == PrizeDef.PrizeClass.COSMETIC,
				"%s should be COSMETIC, got %d" % [id, def.prize_class]
			)
			_check(def.price == 0, "%s should not be priced, got $%d" % [id, def.price])
			_check(def.effect == &"", "%s should carry no effect" % id)


## S10: buying a consumable sends it to the consumable shelf, never the prize
## shelf, and both shelves keep their own cap. A rejected buy changes nothing.
func _test_shop_routing() -> void:
	game.start_run()
	game.money = 100
	var globo: PrizeDef = content.prize_def("globo")
	var before_prizes: int = game.prizes.size()
	_check(game.buy_prize(globo), "buying a consumable should succeed with money")
	_check(game.consumables.has(globo), "the bought consumable should land on the consumable shelf")
	_check(
		game.prizes.size() == before_prizes,
		(
			"a consumable must not take a prize shelf slot (%d -> %d)"
			% [before_prizes, game.prizes.size()]
		)
	)
	# Second and third consumables fit; the fourth is rejected and costs nothing.
	game.buy_prize(content.prize_def("boleto"))
	game.buy_prize(content.prize_def("billete"))
	_check(
		game.consumables.size() == game.CONSUMABLE_CAP,
		(
			"the consumable shelf should hold %d, got %d"
			% [game.CONSUMABLE_CAP, game.consumables.size()]
		)
	)
	var money_before: int = game.money
	_check(
		not game.buy_prize(content.prize_def("muneco")),
		"a consumable over the cap should be rejected"
	)
	_check(game.money == money_before, "a rejected consumable buy must not charge money")
	_check(game.consumables.size() == game.CONSUMABLE_CAP, "a rejected buy must not grow the shelf")
	# The prize shelf keeps its own cap for permanents.
	game.buy_prize(content.prize_def("carpa"))
	var money_full: int = game.money
	_check(
		not game.buy_prize(content.prize_def("corona")),
		"a permanent over the prize cap should be rejected"
	)
	_check(game.money == money_full, "a rejected permanent buy must not charge money")
	# A new run clears the shelf.
	game.start_run()
	_check(game.consumables.is_empty(), "start_run should clear the consumable shelf")
	# S8: cosmetics never take a play slot and never reach the shop.
	var foto: PrizeDef = content.prize_def("foto")
	_check(game.add_prize(foto), "a cosmetic should always fit")
	_check(game.cosmetics.has(foto), "a cosmetic should land in the collection")
	_check(not game.prizes.has(foto), "a cosmetic must not take a prize shelf slot")
	_check(not game.consumables.has(foto), "a cosmetic must not take a consumable slot")
	var stock: Dictionary = game.get_node("/root/Economy").shop_stock(1, 7)
	for entry in stock["prizes"]:
		var def: PrizeDef = content.find_prize_def(entry["def_id"])
		_check(
			def != null and def.prize_class != PrizeDef.PrizeClass.COSMETIC,
			"cosmetics must never be sold: %s" % str(entry)
		)
		_check(int(entry["price"]) > 0, "a sold prize must cost money: %s" % str(entry))


## S9: Globo gives one throw right now, without touching the permanent passives.
func _test_extra_throw_consumable() -> void:
	game.start_run()
	game.consumables.assign([content.prize_def("globo")])
	var board := _open_board()
	await physics_frame
	var total_before: int = board.shots_total
	var left_before: int = board.shots_left
	_check(board.use_consumable(0), "using globo should succeed")
	_check(
		board.shots_total == total_before + 1,
		"globo should add one throw to the budget (%d -> %d)" % [total_before, board.shots_total]
	)
	_check(
		board.shots_left == left_before + 1,
		"globo should leave the extra throw available (%d -> %d)" % [left_before, board.shots_left]
	)
	_check(game.consumables.is_empty(), "using a consumable should remove it from the shelf")
	board.queue_free()
	await physics_frame


## S9: Billete de la Suerte pays 2 dollars now.
func _test_money_consumable() -> void:
	game.start_run()
	game.consumables.assign([content.prize_def("billete")])
	var board := _open_board()
	await physics_frame
	var money_before: int = game.money
	_check(board.use_consumable(0), "using billete should succeed")
	_check(
		game.money == money_before + 2,
		"billete should pay $2 (%d -> %d)" % [money_before, game.money]
	)
	_check(game.consumables.is_empty(), "billete should leave the shelf after use")
	board.queue_free()
	await physics_frame


## S9: Muñeco de Nieve lowers the capture threshold for the current board only.
func _test_skip_threshold_consumable() -> void:
	game.start_run()
	game.consumables.assign([content.prize_def("muneco")])
	var board := _open_board()
	await physics_frame
	var base: float = board.board_def.skip_speed
	_check(
		is_equal_approx(board.effective_skip_speed(), base),
		"without the consumable the threshold is the board's own (%s)" % base
	)
	_check(board.use_consumable(0), "using muneco should succeed")
	_check(
		is_equal_approx(board.effective_skip_speed(), base * 0.5),
		(
			"muneco should halve the threshold for this board (%s -> %s)"
			% [base, board.effective_skip_speed()]
		)
	)
	board.queue_free()
	await physics_frame


## S9/S10: a use that cannot apply (no throw to replay yet) is rejected and
## leaves the shelf untouched.
func _test_replay_rejected_without_throw() -> void:
	game.start_run()
	game.consumables.assign([content.prize_def("boleto")])
	var board := _open_board()
	await physics_frame
	_check(not board.use_consumable(0), "a replay with no resolved throw should be rejected")
	_check(game.consumables.size() == 1, "a rejected use must not consume the consumable")
	board.queue_free()
	await physics_frame


## S1/S10: a debug loadout bypasses the shelf caps (that is the point of picking
## one) but never the class routing.
func _test_debug_loadout_routes_by_class() -> void:
	var config := {
		"board_index": 0,
		"marbles": [content.marble_def("common")],
		"prizes":
		[
			content.prize_def("carpa"),
			content.prize_def("corona"),
			content.prize_def("osito"),
			content.prize_def("globo"),
			content.prize_def("foto"),
		],
	}
	_check(game.start_debug_run(config), "the debug loadout should start")
	_check(
		game.prizes.size() == 3,
		"the loadout should keep three permanents past the shelf cap, got %d" % game.prizes.size()
	)
	_check(
		game.consumables.has(content.prize_def("globo")),
		"the picked consumable should sit on the consumable shelf"
	)
	_check(
		not game.prizes.has(content.prize_def("globo")),
		"the picked consumable must not take a prize shelf slot"
	)
	_check(
		game.cosmetics.has(content.prize_def("foto")),
		"the picked cosmetic should land in the collection"
	)
	game.start_run()
