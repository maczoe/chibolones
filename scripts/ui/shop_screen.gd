extends Control
## Shop placeholder (M1): the stock a real shop sells, all disabled until M3
## wires purchasing. Numbers and stock come from Economy.shop_stock(Game.block),
## names from ContentDB, so the screen already shows the run's real economy.

const PENDING_TAG := "(en camino, M3)"


func _ready() -> void:
	_build()


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
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)

	var header := _candy_label("Tienda de la Feria - Tablero %d" % Game.current_board_in_run,
			48, Color("ffe066"))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(header)

	var info := _candy_label("Bloque %d de %d%s" % [Game.block, Game.BLOCKS,
			" - jefe" if Game.is_boss(Game.current_board_in_run) else ""],
			22, Color("ff6fb5"))
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(info)

	var money := _candy_label("$: %d" % Game.money, 28, Color("ffe066"))
	money.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(money)
	Game.money_changed.connect(func(value: int): money.text = "$: %d" % value)

	var stock: Dictionary = Economy.shop_stock(Game.block)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	column.add_child(grid)
	for entry in stock["marbles"]:
		grid.add_child(_stock_card("Canica", _marble_name(entry["def_id"]),
				int(entry["price"])))
	for entry in stock["prizes"]:
		grid.add_child(_stock_card("Premio", _prize_name(entry["def_id"]),
				int(entry["price"])))

	column.add_child(_disabled_row("Paquete de canica extra (+1 tiro)",
			int(stock["extra_pack_price"])))
	column.add_child(_disabled_row("Reroll de la tienda",
			int(stock["reroll_price"])))

	var continue_button := _menu_button("CONTINUAR")
	continue_button.pressed.connect(_on_continue_pressed)
	column.add_child(continue_button)
	# Keyboard/gamepad first (user request, 2026-11-08): the shop opens with
	# CONTINUAR focused, the same fix the main menu and the pause menu got.
	continue_button.grab_focus()


func _on_continue_pressed() -> void:
	# Game advances the run and moves to the next board scene.
	Game.shop_continue()


func _marble_name(def_id: String) -> String:
	var marble: MarbleDef = ContentDB.marble_def(def_id)
	return marble.display_name if marble != null else def_id


func _prize_name(def_id: String) -> String:
	var prize: PrizeDef = ContentDB.prize_def(def_id)
	return prize.display_name if prize != null else def_id


# --- Construction ----------------------------------------------------------


## Placeholder stock card: name, price and the M3 tag. Not interactive, so it
## can never pretend to sell anything this wave.
func _stock_card(kind: String, display_name: String, price: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_style())
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	card.add_child(column)
	var kind_label := _candy_label(kind, 18, Color("4deeea"))
	column.add_child(kind_label)
	column.add_child(_candy_label(display_name, 26, Color("ffe066")))
	column.add_child(_candy_label("$%d" % price, 24, Color("ff6fb5")))
	column.add_child(_candy_label(PENDING_TAG, 16, Color("a99bc9")))
	return card


## Pack and reroll rows: real prices, disabled buttons until M3.
func _disabled_row(text: String, price: int) -> Button:
	var button := _menu_button("%s - $%d %s" % [text, price, PENDING_TAG])
	button.disabled = true
	# Dead rows must not sit in the focus cycle: nothing can be bought here,
	# so arrows should skip them instead of parking on a button that does
	# nothing (user request, 2026-11-08, mouse-free shop).
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 56)
	button.add_theme_font_size_override("font_size", 22)
	return button


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
	button.add_theme_color_override("font_disabled_color", Color("cdb8ff"))
	button.add_theme_stylebox_override("normal", _button_style(Color("ffe066")))
	button.add_theme_stylebox_override("hover", _button_style(Color("ff6fb5")))
	button.add_theme_stylebox_override("pressed", _button_style(Color("4deeea")))
	button.add_theme_stylebox_override("disabled", _button_style(Color("2e1b58")))
	return button


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1d1240")
	style.border_color = Color("ff6fb5")
	style.set_border_width_all(3)
	style.set_corner_radius_all(20)
	style.content_margin_left = 48
	style.content_margin_right = 48
	style.content_margin_top = 32
	style.content_margin_bottom = 32
	return style


func _card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("241552")
	style.border_color = Color("4deeea")
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style


func _button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("120b26")
	style.set_border_width_all(4)
	style.set_corner_radius_all(14)
	return style
