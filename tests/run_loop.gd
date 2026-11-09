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
	_test_item_pricing()
	if failed:
		return quit(1)
	_test_purchases()
	if failed:
		return quit(1)
	_test_stock_draw()
	if failed:
		return quit(1)
	_test_rescue_sales()
	if failed:
		return quit(1)
	_test_board_order()
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


# --- (a2) Item-owned base prices and rarity (W3, spec S2/S3) ---------------


## W3: prices live in each def (.tres), Economy only scales them by block.
## The hard-coded DEF_BASE_PRICES table is retired; glass breaks 20%.
func _test_item_pricing() -> void:
	# Every marble def carries a price and a valid rarity.
	for def in content.marbles():
		_check(def.price > 0, "marble %s must own a positive base price" % def.id)
		_check(["common", "uncommon", "rare"].has(def.rarity),
				"marble %s must have a valid rarity, got '%s'" % [def.id, def.rarity])
	# Every prize def carries a price and a valid rarity.
	for def in content.prizes():
		_check(def.price > 0, "prize %s must own a positive base price" % def.id)
		_check(["common", "uncommon", "rare"].has(def.rarity),
				"prize %s must have a valid rarity, got '%s'" % [def.id, def.rarity])
	# Economy prices from the def, scaled by block, floored at 1.
	var common: Resource = content.marble_def("common")
	_check(economy.marble_price(common.price, 1) == common.price,
			"block 1 must not scale the def price, got %d"
			% economy.marble_price(common.price, 1))
	_check(economy.marble_price(common.price, 3) == roundi(common.price * 1.7),
			"block 3 must scale the def price by 1.7")
	_check(economy.marble_price(common.price, 3) == int(common.price * 1.7 + 0.5),
			"def-price scaling must round to nearest")
	_check(economy.marble_price(0, 1) == 0,
			"a zero def price must stay 0 (missing price is a data bug, not $1)")
	# Known ids price through their defs; unknown ids price 0.
	_check(economy.base_price_for("common") == common.price,
			"base_price_for must read the def's own price")
	_check(economy.base_price_for("no-existe") == 0,
			"base_price_for of an unknown id should be 0")
	# Glass pin: score x2 and break 20% (content-plan §4.1).
	var glass: Resource = content.marble_def("glass")
	_check(is_equal_approx(glass.break_chance, 0.20),
			"glass break chance must be 0.20, got %s" % glass.break_chance)
	_check(is_equal_approx(glass.score_mult, 2.0), "glass score mult must stay x2")
	# Rarity bands (S3): commons $2-3, uncommons $4-5, rares $7.
	for def in content.marbles() + content.prizes():
		var band: Array = {"common": [2, 3], "uncommon": [4, 5], "rare": [7, 7]}[def.rarity]
		_check(def.price >= band[0] and def.price <= band[1],
				"%s ($%d) must fit its rarity band %s" % [def.id, def.price, band])
	# Stock entries price straight from their defs at block 1.
	var stock: Dictionary = economy.shop_stock(1)
	for entry in stock["marbles"] + stock["prizes"]:
		_check(int(entry["price"]) > 0, "stock price must be positive: %s" % str(entry))


# --- (a3) Bag caps and purchase APIs (W3, spec S6) -------------------------


## W3: the bag caps at 10 marble slots and 2 prize slots; Carpa en Miniatura
## adds marble slots; every purchase charges the block-scaled def price and
## is blocked over cap or without money.
func _test_purchases() -> void:
	_check(game.MARBLE_CAP == 10, "the marble bag should cap at 10")
	_check(game.PRIZE_CAP == 2, "the prize shelf should cap at 2")
	game.start_run()
	_check(game.marble_cap() == 10, "a fresh run should have 10 marble slots")
	_check(game.prize_cap() == 2, "a fresh run should have 2 prize slots")
	# Carpa en Miniatura: +1 marble slot per copy owned.
	var carpa := PrizeDef.new()
	carpa.id = "carpa"
	carpa.display_name = "Carpa en Miniatura"
	carpa.effect = &"bag_slots"
	carpa.params = {"slots": 1}
	game.prizes.append(carpa)
	_check(game.marble_cap() == 11, "carpa should add one marble slot, got %d"
			% game.marble_cap())
	_check(game.prize_cap() == 2, "carpa must not change the prize cap")
	# Happy path: affordable, under cap, charges the block-scaled price.
	var fire: Resource = content.marble_def("fire")
	game.money = 10
	var inv_before: int = game.inventory.size()
	_check(game.buy_marble(fire), "an affordable under-cap buy should succeed")
	_check(game.money == 10 - economy.marble_price(fire.price, game.block),
			"the buy should charge the scaled def price")
	_check(game.inventory.size() == inv_before + 1,
			"the bought marble should join the bag")
	_check(game.inventory.back().id == "fire", "the bought def should be the one asked")
	# Unaffordable: rejected, bag untouched.
	game.money = 0
	_check(not game.buy_marble(fire), "an unaffordable buy must fail")
	_check(game.inventory.size() == inv_before + 1, "a failed buy must not touch the bag")
	# Over cap: rejected with money intact.
	game.money = 100
	while game.inventory.size() < game.marble_cap():
		game.inventory.append(content.marble_def("common"))
	_check(not game.buy_marble(fire), "a buy over the marble cap must fail")
	_check(game.money == 100, "a cap-blocked buy must not charge")
	# Null def: rejected.
	game.money = 10
	_check(not game.buy_marble(null), "buying a null def must fail")
	# Prize purchases with their own cap.
	game.start_run()
	var osito := PrizeDef.new()
	osito.id = "osito"
	osito.display_name = "Osito de Peluche"
	osito.price = 3
	game.money = 20
	_check(game.buy_prize(osito), "an affordable under-cap prize buy should succeed")
	_check(game.money == 20 - osito.price, "the prize buy should charge its price")
	_check(game.prizes.size() == 2, "the bought prize should join the shelf")
	game.money = 20
	_check(not game.buy_prize(osito), "a prize buy over the cap must fail")
	_check(game.money == 20, "a cap-blocked prize buy must not charge")
	# Extra-throw pack: one more common for the rest of the run, cap-aware.
	game.start_run()
	game.money = 10
	var pack_price: int = economy.extra_marble_pack_price(game.block)
	_check(game.buy_extra_pack(), "the extra pack should be buyable")
	_check(game.money == 10 - pack_price,
			"the pack should cost extra_marble_pack_price (%d), money is %d"
			% [pack_price, game.money])
	_check(game.inventory.size() == 6, "the pack should add one common marble")
	_check(game.inventory.back().id == "common", "the pack marble should be a common")
	game.money = 10
	while game.inventory.size() < game.marble_cap():
		game.inventory.append(content.marble_def("common"))
	_check(not game.buy_extra_pack(), "the pack must respect the marble cap")
	_check(game.money == 10, "a cap-blocked pack must not charge")


# --- (a4) Weighted random shop stock (W3, spec S5) -------------------------


## W3: the stock is a weighted rarity draw over the unlocked pool, seeded
## so tests are deterministic: no repeats, real defs, positive prices, and
## commons clearly more frequent than rares.
func _test_stock_draw() -> void:
	var combos := {}
	var common_picks := 0
	var rare_picks := 0
	for seed in [1, 2, 3, 7, 42]:
		var stock: Dictionary = economy.shop_stock(1, seed)
		_check(stock["marbles"].size() == 2, "the draw should offer 2 marbles")
		_check(stock["prizes"].size() == 2, "the draw should offer 2 prizes")
		var ids: Array = []
		for entry in stock["marbles"] + stock["prizes"]:
			ids.append(entry["def_id"])
			_check(int(entry["price"]) > 0, "a drawn entry must have a real price")
			_check(economy.base_price_for(entry["def_id"]) > 0,
					"a drawn entry must reference a real def: %s" % entry["def_id"])
		_check(ids.size() == ids.duplicate().size(),
				"one stock must not repeat a def: %s" % str(ids))
		combos[str(ids)] = true
	_check(combos.size() > 1, "different seeds should draw different stock, got %s"
			% str(combos.keys()))
	# Distribution: over many draws, commons outnumber rares.
	for i in 300:
		var stock: Dictionary = economy.shop_stock(1, -1)
		for entry in stock["marbles"]:
			var def = content.find_marble_def(entry["def_id"])
			match def.rarity:
				"common": common_picks += 1
				"rare": rare_picks += 1
		for entry in stock["prizes"]:
			var def = content.find_prize_def(entry["def_id"])
			match def.rarity:
				"common": common_picks += 1
				"rare": rare_picks += 1
	_check(common_picks > rare_picks * 2,
			"weighted draw should favor commons over rares, got %d vs %d"
			% [common_picks, rare_picks])
	# Reroll: charges the flat price; the shop re-rolls from a new seed.
	game.start_run()
	game.money = 10
	_check(game.reroll_shop(), "an affordable reroll should succeed")
	_check(game.money == 10 - economy.reroll_price(),
			"the reroll should charge the flat price")
	game.money = 0
	_check(not game.reroll_shop(), "an unaffordable reroll must fail")
	_check(game.money == 0, "a failed reroll must not charge")


# --- (a5) Rescue sales (W3b, spec S2) --------------------------------------


## W3b: rescue value = half the CURRENT list price, rounded up. The last
## marble in the bag cannot be sold; prizes sell freely.
func _test_rescue_sales() -> void:
	# Price math: block scale applies, then half, then ceil.
	_check(economy.rescue_price(2, 1) == 1,
			"rescue of $2 at block 1 should be 1, got %d" % economy.rescue_price(2, 1))
	_check(economy.rescue_price(3, 1) == 2,
			"rescue of $3 at block 1 should be ceil(1.5) = 2, got %d" % economy.rescue_price(3, 1))
	_check(economy.rescue_price(7, 5) == 9,
			"rescue of $7 at block 5 should be ceil(8.4) = 9, got %d" % economy.rescue_price(7, 5))
	# The last marble guard.
	game.start_run()
	while game.inventory.size() > 1:
		game.inventory.remove_at(game.inventory.size() - 1)
	game.money = 0
	_check(not game.sell_marble(game.inventory[0]),
			"the last marble in the bag cannot be sold")
	_check(game.money == 0, "a blocked sale must not pay")
	_check(game.inventory.size() == 1, "a blocked sale must keep the marble")
	# Selling one copy of a def: pays the rescue, removes exactly one copy.
	game.inventory.append(content.marble_def("fire"))
	var money_before: int = game.money
	_check(game.sell_marble(content.marble_def("fire")),
			"selling a non-last marble should succeed")
	_check(game.money == money_before + economy.rescue_price(3, 1),
			"the sale should pay the rescue value")
	var fire_copies := 0
	for def in game.inventory:
		if def.id == "fire":
			fire_copies += 1
	_check(fire_copies == 0, "the sale should remove the fire copy")
	_check(game.inventory.size() == 1, "the sale should remove exactly one marble")
	_check(not game.sell_marble(null), "selling null must fail")
	# Prizes sell freely, at their own rescue.
	game.start_run()
	game.money = 0
	_check(game.sell_prize(content.prize_def("trompo")),
			"a prize sells freely (no last-guard)")
	_check(game.money == economy.rescue_price(4, 1),
			"the prize sale should pay its rescue, money is %d" % game.money)
	_check(game.prizes.is_empty(), "the sold prize should leave the shelf")
	_check(not game.sell_prize(null), "selling a null prize must fail")


# --- (a6) Random board order (W3b, spec S5) ---------------------------------


## W3b: board 1 is always the basic board, bosses keep their def and tier,
## the other boards shuffle within their block without repeats.
func _test_board_order() -> void:
	var block1_orders := {}
	for trial in 6:
		game.start_run()
		_check(game.board_def_index(1) == 0,
				"board 1 must always render the basic board, got %d"
				% game.board_def_index(1))
		for n in [4, 8, 12, 16, 20]:
			_check(game.board_def_index(n) == n - 1,
					"boss board %d must keep its def, got %d"
					% [n, game.board_def_index(n)])
		# Every block's normal boards are a permutation of that block's
		# non-boss defs (no repeats, nothing foreign).
		for block in range(1, game.BLOCKS + 1):
			var first: int = (block - 1) * game.BOARDS_PER_BLOCK + 1
			var idxs: Array = []
			for n in range(first, first + game.BOARDS_PER_BLOCK):
				if not game.is_boss(n):
					idxs.append(game.board_def_index(n))
			idxs.sort()
			var expected: Array = []
			for n in range(first, first + game.BOARDS_PER_BLOCK):
				if not game.is_boss(n):
					expected.append(n - 1)
			_check(idxs == expected,
					"block %d normal boards should be a permutation of %s, got %s"
					% [block, str(expected), str(idxs)])
		var order := str([game.board_def_index(2), game.board_def_index(3)])
		block1_orders[order] = true
	_check(block1_orders.size() > 1,
			"the block-1 order should vary across runs, got %s" % str(block1_orders.keys()))
	# Endless boards roll random boss-tier defs (3, 7, 11, 15, 19).
	game.start_run()
	game.current_board_in_run = 20
	game.board_won(0, 0)
	game.win_screen_continue()
	game.start_endless()
	game.current_board_in_run = 21
	var endless: int = game.board_def_index(21)
	_check([3, 7, 11, 15, 19].has(endless),
			"an endless board should render a boss-tier def, got %d" % endless)
	# Debug keeps its picked board, no randomness.
	game.start_debug_run({"board_index": 2, "prizes": [], "marbles": [
			content.marble_def("common")]})
	_check(game.board_def_index(1) == 2,
			"debug mode must render the picked board, got %d" % game.board_def_index(1))
	# Leave a clean state: the sections after this one run plain math.
	game.start_run()


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
	_check(board.hud.label_money.text == "$%d" % game.money,
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
