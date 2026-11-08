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
