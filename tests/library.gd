extends SceneTree
## Library screen test (D11, S3, S8 — W4/M4 T6): the six tabs exist, a fresh
## profile locks the marbles the unlock table has not granted yet, a collected
## entry gains the collection marker on the next rebuild, the empty song/SFX
## tabs carry their placeholder and the header carries the per-tab counts.
## Everything is read through the labels and buttons the screen names while it
## builds itself, never through its private state.
## Run: godot --headless --path . --script res://tests/library.gd

const SCENE := "res://scenes/library/library.tscn"
const SAVE_PATH := "user://test_library.json"
const TAB_TITLES := ["CANICAS", "COMODINES", "CONSUMIBLES", "COSMÉTICOS", "CANCIONES", "EFECTOS"]
## L5 starter pool: what a fresh profile has unlocked before any run.
const STARTER_MARBLES := ["agata", "common", "fire", "rebote", "remolino", "glass"]

var failed := false
var checks_run := 0
var save
var _backs := 0


func _initialize() -> void:
	_ensure_autoloads()
	_run()


## Godot registers the project autoloads even under `--script`, so this guard
## only fills gaps (a suite may also run with a bare tree); the order is the
## dependency order (Game reads Economy, every def read goes through ContentDB,
## the screen reads the profile through SaveGame).
func _ensure_autoloads() -> void:
	var autoloads := [
		["EventBus", "res://autoload/event_bus.gd"],
		["ContentDB", "res://autoload/content_db.gd"],
		["Economy", "res://autoload/economy.gd"],
		["Game", "res://autoload/game.gd"],
		["SaveGame", "res://autoload/save_game.gd"],
	]
	for entry in autoloads:
		if not root.has_node(entry[0]):
			var node: Node = (load(entry[1]) as GDScript).new()
			node.name = entry[0]
			# A test profile, never the player's: the path is set before the
			# node enters the tree so its _ready never touches the real file.
			if entry[0] == "SaveGame":
				node.path = SAVE_PATH
			root.add_child(node)
	save = root.get_node("SaveGame")


func _run() -> void:
	await physics_frame
	save.reset_profile()
	await _test_tabs_exist()
	await _test_fresh_profile_cards()
	await _test_header_counts()
	await _test_placeholder_tabs()
	await _test_collection_marker()
	await _test_back_paths()
	# A GDScript error aborts one test function without touching `failed`, so a
	# suite would print OK with tests that never ran. The count is deterministic,
	# so the exact full-pass total is the guard: one dead test always fails here.
	# Adding a test means bumping this number with it.
	_check(checks_run >= 41, "only %d checks ran: a test died before asserting" % checks_run)
	print("LIBRARY FAIL" if failed else "LIBRARY OK")
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	checks_run += 1
	if condition:
		return
	failed = true
	print("LIBRARY FAIL: " + label)


# --- (a) The six tabs exist ------------------------------------------------


func _test_tabs_exist() -> void:
	var screen := _open()
	if screen == null:
		return
	var titles: Array[String] = []
	for button: Button in screen._tab_buttons:
		titles.append(button.text)
	_check(titles == TAB_TITLES, "tabs should be %s, got %s" % [str(TAB_TITLES), str(titles)])
	_check(
		(
			not screen._tab_buttons.is_empty()
			and screen._tab_buttons[0].focus_mode == Control.FOCUS_ALL
		),
		"tabs should be reachable with keyboard/gamepad focus"
	)
	# Keyboard/gamepad first: the screen opens with a focused control, so the
	# arrows and the stick move between tabs and cards without a mouse.
	await process_frame
	await process_frame
	var focused := root.gui_get_focus_owner()
	_check(
		focused is Button and (focused as Button).text == TAB_TITLES[0],
		"the screen should open focused on the first tab, owner is %s" % focused
	)
	_close(screen)


# --- (b) A fresh profile: starters unlocked, the rest silhouettes ----------


func _test_fresh_profile_cards() -> void:
	var screen := _open()
	if screen == null:
		return
	for id: String in STARTER_MARBLES:
		_check(save.is_unlocked("marbles", id), "%s should start unlocked" % id)
	for id: String in ["espejo", "nitro"]:
		_check(not save.is_unlocked("marbles", id), "%s should start locked" % id)

	# A locked card hides the entry: silhouette art, "???" instead of the
	# name and the unlock hint instead of the lore and the effect.
	_check(_card_text(screen, "espejo", "Name") == "???", "a locked card hides the name")
	_check(
		_card_text(screen, "espejo", "Lore") == "Se desbloquea al limpiar el tablero 20",
		"espejo should hint its milestone board, got %s" % _card_text(screen, "espejo", "Lore")
	)
	_check(
		_card_text(screen, "teledirigida", "Lore") == "Se desbloquea al limpiar el tablero 4",
		"teledirigida should hint board 4, got %s" % _card_text(screen, "teledirigida", "Lore")
	)
	_check(
		_card_text(screen, "nitro", "Lore") == "Aparece en un cofre",
		"a non-milestone unlock should hint a chest, got %s" % _card_text(screen, "nitro", "Lore")
	)
	var art := _card_node(screen, "espejo", "Art") as TextureRect
	_check(art != null and art.modulate != Color.WHITE, "a locked card paints its art dark")
	_check(_card_node(screen, "espejo", "Effect") == null, "a locked card shows no effect text")

	# An unlocked entry shows the whole card, with no collection marker yet.
	_check(_card_text(screen, "agata", "Name") == "Canica Agata", "an unlocked card shows the name")
	_check(_card_text(screen, "agata", "Lore") != "", "an unlocked card shows its lore")
	_check(_card_text(screen, "agata", "Effect") != "", "an unlocked card shows its effect")
	var marker := _card_node(screen, "agata", "Marker") as Label
	_check(marker != null and not marker.visible, "an uncollected card shows no marker")
	_close(screen)


# --- (c) The header counts per tab -----------------------------------------


func _test_header_counts() -> void:
	var screen := _open()
	if screen == null:
		return
	_check(
		screen._label_header.text == "CANICAS 6/10",
		"the marbles header should count 6/10, got %s" % screen._label_header.text
	)
	screen._tab_buttons[1].pressed.emit()
	_check(
		screen._label_header.text.begins_with("COMODINES 4/"),
		"the permanent prizes header should count the starters, got %s" % screen._label_header.text
	)
	# COMODINES lists the permanent prizes only (D8): no consumable card.
	_check(_card_node(screen, "muneco", "Name") == null, "COMODINES should skip consumables")
	_check(_card_node(screen, "osito", "Name") != null, "COMODINES should list permanent prizes")
	_close(screen)


# --- (d) The empty song and SFX tabs --------------------------------------


func _test_placeholder_tabs() -> void:
	var screen := _open()
	if screen == null:
		return
	for index: int in [4, 5]:
		var title: String = TAB_TITLES[index]
		screen._tab_buttons[index].pressed.emit()
		_check(screen._label_header.text == title, "%s header should be its title" % title)
		_check(
			_find_text(screen, "próximamente", "EmptyText") != null,
			"%s should show its placeholder" % title
		)
		_check(
			screen._cards.get_child_count() == 1, "%s should hold the placeholder card only" % title
		)
	_close(screen)


# --- (e) Collecting flips the marker on the next rebuild ------------------


func _test_collection_marker() -> void:
	var screen := _open()
	if screen == null:
		return
	var marker := _card_node(screen, "glass", "Marker") as Label
	_check(marker != null and not marker.visible, "glass starts unlocked but not collected")
	_check(_card_text(screen, "glass", "Lore") != "", "an unlocked card keeps its lore")

	save.collect("marbles", "glass")
	_check(save.is_collected("marbles", "glass"), "glass should be collected in the profile")
	screen.refresh()

	marker = _card_node(screen, "glass", "Marker") as Label
	_check(marker != null and marker.visible, "a collected card shows the marker")
	_check(
		marker != null and marker.text == "en la colección", "the marker should name the collection"
	)
	var other := _card_node(screen, "agata", "Marker") as Label
	_check(other != null and not other.visible, "collecting one entry leaves the rest unmarked")
	_check(screen._label_header.text == "CANICAS 6/10", "collecting does not change the count")
	_close(screen)


# --- (f) Back: the pause caller keeps its live scene ----------------------


func _test_back_paths() -> void:
	var screen := _open()
	if screen == null:
		return
	_check(screen.return_to == "menu", "the back target should default to the menu")
	_close(screen)

	_backs = 0
	var paused_screen := _open("pause")
	if paused_screen == null:
		return
	paused_screen.back_requested.connect(_on_back)
	var event := InputEventAction.new()
	event.action = "cancel"
	event.pressed = true
	paused_screen._unhandled_input(event)
	_check(_backs == 1, "Escape/B should ask the caller to go back, got %d" % _backs)
	_check(current_scene == null, "a pause caller keeps its own scene (no scene change)")
	_close(paused_screen)


func _on_back() -> void:
	_backs += 1


# --- Helpers --------------------------------------------------------------


## Instantiate the screen with its back target already set, as the menu and
## the pause menu do.
func _open(return_to := "menu") -> Node:
	if not ResourceLoader.exists(SCENE):
		_check(false, "the library scene %s should exist" % SCENE)
		return null
	var screen: Node = (load(SCENE) as PackedScene).instantiate()
	screen.return_to = return_to
	root.add_child(screen)
	return screen


func _close(screen: Node) -> void:
	root.remove_child(screen)
	screen.free()


## One card by def id; the screen names each card "Card_<id>".
func _card(screen: Node, id: String) -> Control:
	return screen.find_child("Card_" + id, true, false) as Control


func _card_node(screen: Node, id: String, node_name: String) -> Node:
	var card := _card(screen, id)
	if card == null:
		return null
	return card.find_child(node_name, true, false)


func _card_text(screen: Node, id: String, node_name: String) -> String:
	var node := _card_node(screen, id, node_name) as Label
	if node == null:
		return ""
	return node.text


## The placeholder of an empty tab, found by the text it must carry.
func _find_text(screen: Node, text: String, node_name: String) -> Label:
	var node := screen.find_child(node_name, true, false) as Label
	if node == null or not node.text.contains(text):
		return null
	return node
