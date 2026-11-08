extends SceneTree
## Shop focus test (user request, 2026-11-08): the shop must open with the
## CONTINUAR button already focused, so the run is playable without a mouse
## (same fix the main menu and the pause menu got).
## Run: godot --headless --path . --script res://tests/shop_focus.gd

var failed := false


func _initialize() -> void:
	_ensure_autoloads()
	_run()


## In --script mode Godot does not register project autoloads (same as
## tests/pause.gd).
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


func _run() -> void:
	await process_frame
	await _test_continue_focus()
	await _test_buttons_keyboard_reachable()
	await _test_buy_flow()
	print("SHOP_FOCUS FAIL" if failed else "SHOP_FOCUS OK")
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error("SHOP_FOCUS FAIL: " + label)
	print("SHOP_FOCUS FAIL: " + label)


func _open_shop() -> Control:
	var shop: Control = (load("res://scenes/shop/shop.tscn") as PackedScene).instantiate()
	root.add_child(shop)
	return shop


func _continue_button(shop: Control) -> Button:
	# The only enabled button named CONTINUAR on the shop.
	var found: Button = null
	for button in _find_buttons(shop):
		if button.text == "CONTINUAR" and not button.disabled:
			found = button
	return found


func _find_buttons(node: Node) -> Array[Button]:
	var out: Array[Button] = []
	if node is Button:
		out.append(node)
	for child in node.get_children():
		out.append_array(_find_buttons(child))
	return out


## W3: buy buttons charge through Game, mark bought, respect money and
## caps, and the reroll charges its price.
func _test_buy_flow() -> void:
	var game := root.get_node("Game")
	game.start_run()
	game.money = 50
	var shop := _open_shop()
	await process_frame
	await process_frame
	var buys := _find_buy_buttons(shop)
	_check(buys.size() >= 4,
			"the shop should offer buy buttons for the stock, got %d" % buys.size())
	var inventory_before: int = game.inventory.size()
	var prizes_before: int = game.prizes.size()
	var money_before: int = game.money
	buys[0].pressed.emit()
	_check(game.inventory.size() + game.prizes.size() == inventory_before + prizes_before + 1,
			"a buy should add exactly one item to the run")
	_check(game.money < money_before, "a buy should charge money")
	_check(buys[0].disabled, "a bought card's buy button should disable")
	# Unaffordable: no money, every buy button disabled.
	game.money = 0
	var shop_broke := _open_shop()
	await process_frame
	await process_frame
	for button in _find_buy_buttons(shop_broke):
		_check(button.disabled, "a buy without money must be disabled")
	shop_broke.queue_free()
	# Reroll: an enabled row that charges the flat price (money restored:
	# the broke-shop leg spent it).
	game.money = 50
	var reroll: Button = null
	for button in _find_buttons(shop):
		if button.text.begins_with("Reroll"):
			reroll = button
	_check(reroll != null, "the shop should have a reroll button")
	if reroll != null:
		_check(not reroll.disabled, "an affordable reroll should be enabled")
		var before: int = game.money
		reroll.pressed.emit()
		_check(game.money == before - 2, "the reroll should charge $2")
	# Over-cap: a full bag disables the marble buys.
	game.money = 50
	while game.inventory.size() < game.marble_cap():
		game.inventory.append(root.get_node("ContentDB").marble_def("common"))
	var shop_full := _open_shop()
	await process_frame
	await process_frame
	_check(_find_buy_buttons(shop_full).any(
					func(b: Button): return b.disabled),
			"a full bag should disable at least one buy")
	shop_full.queue_free()
	shop.queue_free()
	await process_frame


## Buttons labeled COMPRAR, the buy action of a stock card.
func _find_buy_buttons(shop: Control) -> Array[Button]:
	var out: Array[Button] = []
	for button in _find_buttons(shop):
		if button.text == "COMPRAR":
			out.append(button)
	return out


func _test_continue_focus() -> void:
	var shop := _open_shop()
	await process_frame
	await process_frame
	var expected := _continue_button(shop)
	_check(expected != null, "the shop should build an enabled CONTINUAR button")
	var owner_node := root.gui_get_focus_owner()
	_check(owner_node == expected,
			"the shop should open with CONTINUAR focused, owner is %s" % owner_node)
	shop.queue_free()
	await process_frame


func _test_buttons_keyboard_reachable() -> void:
	var shop := _open_shop()
	await process_frame
	for button in _find_buttons(shop):
		if button.disabled:
			_check(button.focus_mode == Control.FOCUS_NONE,
					"a disabled shop row should not grab focus while cycling")
		else:
			_check(button.focus_mode == Control.FOCUS_ALL,
					"an enabled shop button should be keyboard reachable")
	shop.queue_free()
	await process_frame
