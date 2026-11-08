extends SceneTree
## W3 end-to-end: the full acceptance cycle — win a board, the shop opens,
## buy a marble + a prize + the pack, continue, and the next board carries
## everything: ammo from the grown bag, the extra throws of owned prizes and
## the prize badges in the HUD. Run:
## godot --headless --path . --script res://tests/w3_flow.gd

var game
var content
var economy
var failed := false


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
	content = root.get_node("ContentDB")
	economy = root.get_node("Economy")


func _run() -> void:
	await physics_frame
	await _test_full_cycle()
	print("W3 FLOW FAIL" if failed else "W3 FLOW OK")
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	print("W3 FLOW FAIL: " + label)


## The whole W3 acceptance, in order, through the real seams.
func _test_full_cycle() -> void:
	game.start_run()
	var board := _open_board()
	await physics_frame
	# (1) Win board 1: score the objective through the real embed seam with a
	# marble in flight, like run_loop's win test does.
	root.get_node("EventBus").embed.emit(0, board.run_objective)
	board.state = board.ThrowState.FLIGHT
	board.launch_timer = 0.0
	board.active_marbles.append(_resting_marble(board))
	await physics_frame
	await physics_frame
	_check(game.phase == game.Phase.WIN, "winning board 1 should reach WIN, phase is %s" % game.phase)
	var reward: int = economy.reward_for_block_win(1, 5, 0)
	_check(game.money == game.START_MONEY + reward,
			"the win should pay $%d, money is %d" % [reward, game.money])

	# (2) The shop opens; buy from a deterministic draw with enough money.
	game.win_screen_continue()
	_check(game.phase == game.Phase.SHOP, "CONTINUAR should open the shop, phase is %s" % game.phase)
	game.money = 30
	var stock: Dictionary = economy.shop_stock(1, 7)
	var bought_marble_id := ""
	for entry in stock["marbles"]:
		var def: MarbleDef = content.find_marble_def(entry["def_id"])
		if def != null and game.buy_marble(def):
			bought_marble_id = def.id
			break
	_check(bought_marble_id != "", "an affordable marble should be buyable from the stock")
	var bought_prize_id := ""
	for entry in stock["prizes"]:
		var def: PrizeDef = content.find_prize_def(entry["def_id"])
		if def != null and game.buy_prize(def):
			bought_prize_id = def.id
			break
	_check(bought_prize_id != "", "an affordable prize should be buyable from the stock")
	_check(game.buy_extra_pack(), "the extra pack should be buyable with $30")
	_check(game.inventory.size() == 7, "5 commons + marble + pack = 7, got %d"
			% game.inventory.size())
	_check(game.prizes.size() == 2, "trompo + the bought prize = 2, got %d" % game.prizes.size())

	# (3) The next board carries the purchases.
	game.shop_continue()
	_check(game.current_board_in_run == 2, "shop_continue should advance to board 2")
	_check(game.phase == game.Phase.BOARD, "shop_continue should enter BOARD")
	var board2 := _open_board()
	await physics_frame
	var has_bought := false
	for def in game.ammo:
		if def.id == bought_marble_id:
			has_bought = true
	_check(has_bought, "board 2's ammo should carry the bought marble '%s', ammo is %s"
			% [bought_marble_id, _ids(game.ammo)])
	_check(game.ammo.size() == game.inventory.size(),
			"board 2 should restore the whole grown bag (%d), ammo is %d"
			% [game.inventory.size(), game.ammo.size()])
	var extras := 0
	for prize in game.prizes:
		if prize != null and prize.effect == &"extra_throw":
			extras += int(prize.params.get("per_board", 1))
	_check(board2.shots_total == game.ammo.size() + extras,
			"board 2's budget should be ammo + owned extras (%d + %d), got %d"
			% [game.ammo.size(), extras, board2.shots_total])
	# The owned prizes are announced on the HUD badges.
	var badge_text := ""
	for badge in board2.hud.find_children("*", "Label", true, false):
		badge_text += (badge as Label).text + " "
	_check(badge_text.contains("Trompo"),
			"board 2's HUD should badge the starting trompo, badges are '%s'" % badge_text)
	if bought_prize_id != "":
		var bought_name: String = content.find_prize_def(bought_prize_id).display_name
		_check(badge_text.contains(bought_name),
				"board 2's HUD should badge the bought prize, badges are '%s'" % badge_text)
	board.queue_free()
	await physics_frame
	board2.queue_free()
	await physics_frame


func _open_board() -> Node3D:
	var board: Node3D = (load("res://scenes/board/board.tscn") as PackedScene).instantiate()
	root.add_child(board)
	return board


func _ids(defs: Array) -> Array:
	var out: Array = []
	for def in defs:
		out.append(def.id)
	return out


## A marble at rest on the board surface, away from every notch.
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
