extends Control
## Debug match setup (S1, S2, S3, S8): one board played with a custom
## loadout. The screen owns the three pickers (board with its gimmick,
## active prizes, starting marbles) and hands the config to
## Game.start_debug_run(); the board itself returns here when the match ends.
## Built in code in the menu/shop candy style, so it stays one file.

const MENU_SCENE := "res://scenes/menu/menu.tscn"
## Marbles a debug match starts with: the five starting marbles of a run
## (S3). Fewer picks are topped up with commons in build_config().
const MARBLE_SLOTS := 5
## A match always starts with at least one marble: an empty loadout has
## nothing to throw, so the launch is blocked.
const MIN_MARBLES := 1

## BoardDef index being picked (0..ContentDB.board_count() - 1).
var board_cursor := 0
## Marbles the match starts with, in pick order (at most MARBLE_SLOTS).
var picked_marbles: Array[MarbleDef] = []
## Prizes active in the match. The picker starts with none active, so a
## debug match is bare until the player asks for a prize.
var selected_prizes: Array[PrizeDef] = []

var label_board_name: Label
var label_gimmick: Label
var label_marbles: Label
var label_prizes: Label
var label_hint: Label
var start_button: Button
var back_button: Button

var _marble_labels: Dictionary = {}   # marble id -> counter label
var _prize_buttons: Dictionary = {}   # prize id -> toggle button

## Last launched setup (board index, prize ids, marble ids): coming back
## from a finished debug match restores it, so tweaking one pick and
## replaying is two presses instead of a full rebuild (user request,
## 2026-11-08). Static: it must survive the scene being freed.
static var last_config := {}


func _ready() -> void:
	if last_config.is_empty():
		_seed_defaults()
	else:
		_restore_last_config()
	_build()
	_refresh()
	# Keyboard/gamepad navigation starts on the launch button, like the menu
	# starts on JUGAR.
	start_button.grab_focus()


## The defaults of a fresh debug match: the first board, no active prize and
## five commons, i.e. the same loadout a normal run owns (S10).
func _seed_defaults() -> void:
	board_cursor = 0
	selected_prizes.clear()
	picked_marbles.clear()
	var common: MarbleDef = ContentDB.marble_def(ContentDB.DEFAULT_MARBLE)
	if common == null:
		return
	for i in MARBLE_SLOTS:
		picked_marbles.append(common)


# --- Pickers ---------------------------------------------------------------


func board_def() -> BoardDef:
	return ContentDB.board_def(board_cursor)


## The board's rules, exactly what the board announces at start: one
## "Display name: description" line per bonificador, or "Sin reglas
## especiales" when it has none (user request: the debug picker shows what
## the board does, not just the gimmick names).
func board_rules_text() -> String:
	var def := board_def()
	if def == null:
		return "Sin reglas especiales"
	var lines: Array[String] = []
	for id in def.modifiers:
		var modifier: BoardModifierDef = ContentDB.modifier_def(id)
		if modifier != null:
			lines.append("%s: %s" % [modifier.display_name, modifier.description])
	return "\n".join(lines) if not lines.is_empty() else "Sin reglas especiales"


func select_board(index: int) -> void:
	board_cursor = wrapi(index, 0, maxi(ContentDB.board_count(), 1))
	_refresh()


func cycle_board(step: int) -> void:
	select_board(board_cursor + step)


func toggle_prize(def: PrizeDef) -> void:
	if def == null:
		return
	if selected_prizes.has(def):
		selected_prizes.erase(def)
	else:
		selected_prizes.append(def)
	_refresh()


## Marbles of one def in the loadout.
func marble_count(def: MarbleDef) -> int:
	if def == null:
		return 0
	var count := 0
	for marble in picked_marbles:
		if marble.id == def.id:
			count += 1
	return count


## Add (delta > 0) or remove (delta < 0) one marble of this def. The loadout
## never grows past MARBLE_SLOTS; removing the last marble is allowed and
## only blocks the launch.
func change_marble(def: MarbleDef, delta: int) -> void:
	if def == null or delta == 0:
		return
	if delta > 0:
		if picked_marbles.size() >= MARBLE_SLOTS:
			return
		picked_marbles.append(def)
	else:
		for i in range(picked_marbles.size() - 1, -1, -1):
			if picked_marbles[i].id == def.id:
				picked_marbles.remove_at(i)
				break
	_refresh()


func can_start() -> bool:
	return picked_marbles.size() >= MIN_MARBLES


## The config Game.start_debug_run() takes: the picked board index, the
## active prizes and the starting loadout. A short loadout is topped up with
## commons up to MARBLE_SLOTS, keeping the player's picks in front; an empty
## one stays empty so the launch can be rejected.
func build_config() -> Dictionary:
	var marbles: Array[MarbleDef] = []
	if can_start():
		marbles.assign(picked_marbles)
		var common: MarbleDef = ContentDB.marble_def(ContentDB.DEFAULT_MARBLE)
		while marbles.size() < MARBLE_SLOTS and common != null:
			marbles.append(common)
	return {
		"board_index": board_cursor,
		"prizes": selected_prizes.duplicate(),
		"marbles": marbles,
	}


# --- Launch and exit -------------------------------------------------------


func start_match() -> void:
	if not can_start():
		return
	# Remember the setup for the next visit (see last_config).
	last_config = {
		"board_index": board_cursor,
		"prize_ids": selected_prizes.map(func(def): return def.id),
		"marble_ids": picked_marbles.map(func(def): return def.id),
	}
	# Game launches the match and moves to the board scene; the board already
	# runs the marble inventory (S4).
	Game.start_debug_run(build_config())


## Bring back the last launched setup: resolve the stored ids through
## ContentDB so a content change can never crash the restore, and keep the
## picks-first/top-up rule of build_config() intact.
func _restore_last_config() -> void:
	board_cursor = clampi(int(last_config.get("board_index", 0)), 0,
			ContentDB.board_count() - 1)
	selected_prizes.clear()
	for id in last_config.get("prize_ids", []):
		var prize: PrizeDef = ContentDB.prize_def(id)
		if prize != null and not selected_prizes.has(prize):
			selected_prizes.append(prize)
	picked_marbles.clear()
	for id in last_config.get("marble_ids", []):
		var marble: MarbleDef = ContentDB.marble_def(id)
		if marble != null and picked_marbles.size() < MARBLE_SLOTS:
			picked_marbles.append(marble)
	while picked_marbles.size() < MARBLE_SLOTS:
		var common: MarbleDef = ContentDB.marble_def(ContentDB.DEFAULT_MARBLE)
		if common == null:
			break
		picked_marbles.append(common)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	# X / B leaves the setup without starting a match.
	if event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()


# --- Construction ----------------------------------------------------------


func _build() -> void:
	var background := ColorRect.new()
	background.color = Color("120a26")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)

	var title := _candy_label("MODO DEBUG", 64, Color("ffe066"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	var subtitle := _candy_label("Una partida de un solo tablero", 24, Color("ff6fb5"))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)

	# Board picker: arrows cycle through every BoardDef; the name and the
	# gimmick always stay on screen (S2).
	column.add_child(_candy_label("Tablero", 26, Color("4deeea")))
	var board_row := HBoxContainer.new()
	board_row.add_theme_constant_override("separation", 12)
	column.add_child(board_row)
	var previous := _menu_button("<")
	previous.custom_minimum_size = Vector2(80, 56)
	previous.pressed.connect(cycle_board.bind(-1))
	board_row.add_child(previous)
	label_board_name = _candy_label("", 32, Color("ffe066"))
	label_board_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_board_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_row.add_child(label_board_name)
	var next := _menu_button(">")
	next.custom_minimum_size = Vector2(80, 56)
	next.pressed.connect(cycle_board.bind(1))
	board_row.add_child(next)
	label_gimmick = _candy_label("", 20, Color("ff6fb5"))
	label_gimmick.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_gimmick.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label_gimmick.custom_minimum_size = Vector2(0, 56)
	column.add_child(label_gimmick)

	# Prize picker: one toggle per PrizeDef, all off at the start.
	column.add_child(_candy_label("Premios activos", 26, Color("4deeea")))
	label_prizes = _candy_label("", 20, Color("cdb8ff"))
	label_prizes.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(label_prizes)
	var prize_row := HBoxContainer.new()
	prize_row.alignment = BoxContainer.ALIGNMENT_CENTER
	prize_row.add_theme_constant_override("separation", 12)
	column.add_child(prize_row)
	for prize in ContentDB.prizes():
		var button := _small_button("")
		button.toggle_mode = true
		button.pressed.connect(toggle_prize.bind(prize))
		prize_row.add_child(button)
		_prize_buttons[prize.id] = button

	# Marble picker: a counter per MarbleDef, five slots in total (S3).
	column.add_child(_candy_label("Canicas iniciales", 26, Color("4deeea")))
	label_marbles = _candy_label("", 20, Color("cdb8ff"))
	label_marbles.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(label_marbles)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 6)
	column.add_child(grid)
	for marble in ContentDB.marbles():
		var minus := _small_button("-")
		minus.pressed.connect(change_marble.bind(marble, -1))
		grid.add_child(minus)
		var count := _candy_label("", 22, Color("fff7ff"))
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count.custom_minimum_size = Vector2(260, 0)
		grid.add_child(count)
		_marble_labels[marble.id] = count
		var plus := _small_button("+")
		plus.pressed.connect(change_marble.bind(marble, 1))
		grid.add_child(plus)

	label_hint = _candy_label("", 20, Color("ffe066"))
	label_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(label_hint)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 16)
	column.add_child(actions)
	back_button = _menu_button("VOLVER AL MENU")
	back_button.custom_minimum_size = Vector2(300, 64)
	back_button.pressed.connect(_on_back_pressed)
	actions.add_child(back_button)
	start_button = _menu_button("JUGAR")
	start_button.custom_minimum_size = Vector2(300, 64)
	start_button.pressed.connect(start_match)
	actions.add_child(start_button)


## Push the picker state into the labels and buttons: one place that decides
## what the screen shows, so a click, an arrow and a refresh never disagree.
func _refresh() -> void:
	var def := board_def()
	if def != null:
		label_board_name.text = "%s  (%d/%d)" % [def.theme_name,
				board_cursor + 1, ContentDB.board_count()]
	label_gimmick.text = board_rules_text()
	label_marbles.text = "Canicas: %d / %d" % [picked_marbles.size(), MARBLE_SLOTS]
	label_prizes.text = "Premios: %d activos" % selected_prizes.size()
	for marble in ContentDB.marbles():
		var count: Label = _marble_labels.get(marble.id)
		if count != null:
			count.text = "%s x%d" % [marble.display_name, marble_count(marble)]
	for prize in ContentDB.prizes():
		var button: Button = _prize_buttons.get(prize.id)
		if button != null:
			var active: bool = selected_prizes.has(prize)
			button.text = "%s %s" % ["ACTIVO" if active else "INACTIVO",
					prize.display_name]
			button.set_pressed_no_signal(active)
	label_hint.text = "" if can_start() else "Elegi al menos %d canica para jugar" % MIN_MARBLES
	start_button.disabled = not can_start()


func _candy_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("120b26"))
	label.add_theme_constant_override("outline_size", 6)
	return label


func _menu_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 72)
	button.add_theme_font_size_override("font_size", 30)
	button.add_theme_color_override("font_color", Color("120b26"))
	button.add_theme_color_override("font_hover_color", Color("3a1f6e"))
	button.add_theme_color_override("font_pressed_color", Color("120b26"))
	button.add_theme_color_override("font_disabled_color", Color("cdb8ff"))
	button.add_theme_stylebox_override("normal", _button_style(Color("ffe066")))
	button.add_theme_stylebox_override("hover", _button_style(Color("ff6fb5")))
	button.add_theme_stylebox_override("pressed", _button_style(Color("4deeea")))
	button.add_theme_stylebox_override("disabled", _button_style(Color("2e1b58")))
	return button


## Compact button for the pickers: same candy look, a size that fits the
## rows and the keyboard focus frame of every other menu control.
func _small_button(text: String) -> Button:
	var button := _menu_button(text)
	button.custom_minimum_size = Vector2(64, 52)
	button.add_theme_font_size_override("font_size", 24)
	return button


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1d1240")
	style.border_color = Color("ff6fb5")
	style.set_border_width_all(3)
	style.set_corner_radius_all(20)
	style.content_margin_left = 56
	style.content_margin_right = 56
	style.content_margin_top = 36
	style.content_margin_bottom = 36
	return style


func _button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("120b26")
	style.set_border_width_all(4)
	style.set_corner_radius_all(14)
	return style
