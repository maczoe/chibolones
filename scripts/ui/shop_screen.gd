extends Control
## Shop v2, W3d: the fair stall of design/shop-hud-planning/06-shop-stall.html
## (artboard C, Dave the Diver / Balatro). Bunting header with the money and
## caps badges, a counter of four stock cards, and a counter-width bottom
## section: services + options (continue / match info / menu / abandon) on
## the left, the run inventory with rescue sales and vertical scroll on the
## right. Keyboard/gamepad arrows drive the focus; every control is a real
## button, so touch works the same. Colors follow the artboard's candy
## palette; sprites are the generated orb placeholders the board HUD uses.

var _label_money: Label
var _label_caps: Label
var _label_msg: Label
var _stock_box: GridContainer
var _inventory_list: VBoxContainer
var _info_panel: PanelContainer
var _abandon_confirm: ConfirmationDialog
var _buy_buttons: Array[Dictionary] = []
var _pack_button: Button
var _reroll_button: Button
var _continue_button: Button
var _msg_tween: Tween
var _orb_cache := {}


func _ready() -> void:
	_build()


func _build() -> void:
	var background := ColorRect.new()
	background.color = Color("120a26")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	# The whole screen scrolls on short windows (mobile portrait); on the
	# full 1920x1080 canvas it fits exactly.
	var outer := ScrollContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(outer)

	var frame := PanelContainer.new()
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color("1a0f33")
	frame_style.content_margin_left = 40.0
	frame_style.content_margin_right = 40.0
	frame_style.content_margin_top = 20.0
	frame_style.content_margin_bottom = 20.0
	frame.add_theme_stylebox_override("panel", frame_style)
	outer.add_child(frame)

	var flow := VBoxContainer.new()
	flow.add_theme_constant_override("separation", 16)
	frame.add_child(flow)

	_build_header(flow)
	_build_counter(flow)
	_build_bottom(flow)
	# Initial gate pass: with the money the shop opened at, buys may already
	# be blocked (broke or full bags) and must render disabled.
	_refresh_bottom()
	# S3: the shop opens keyboard-first — the first enabled buy grabs focus
	# one frame later, when the tree knows the buttons.
	_focus_first.call_deferred()


# --- Header: bunting + title + money/caps badges ---------------------------


func _build_header(flow: VBoxContainer) -> void:
	var bunting := HBoxContainer.new()
	bunting.alignment = BoxContainer.ALIGNMENT_CENTER
	bunting.add_theme_constant_override("separation", 4)
	for i in 13:
		var flag := ColorRect.new()
		flag.custom_minimum_size = Vector2(30, 22)
		flag.color = [Color("ff6fb5"), Color("4deeea"), Color("ffe066")][i % 3]
		# Triangle flags: a centered ColorRect column cannot taper, so the
		# bunting reads through the color rhythm alone (M6 adds the real art).
		bunting.add_child(flag)
	flow.add_child(bunting)

	var title := _candy_label("Tienda de la Feria", 40, Color("ffe066"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flow.add_child(title)

	var subtitle := _candy_label(_subtitle_text(), 16, Color("ff6fb5"))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flow.add_child(subtitle)

	# Money + caps badges, right-aligned over the counter (artboard top right).
	var badges := HBoxContainer.new()
	badges.alignment = BoxContainer.ALIGNMENT_END
	badges.add_theme_constant_override("separation", 14)
	_label_money = _candy_label("$%d" % Game.money, 26, Color("ffe066"))
	_label_money.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badges.add_child(_badge(_label_money, Color("ffe066")))
	_label_caps = _candy_label(_caps_text(), 14, Color("cdb8ff"))
	_label_caps.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badges.add_child(_plain(_label_caps))
	flow.add_child(badges)
	Game.money_changed.connect(_on_money_changed)


func _badge(label: Label, border: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("241552")
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	panel.add_theme_stylebox_override("panel", style)
	panel.add_child(label)
	return panel


func _plain(label: Label) -> Label:
	return label


func _subtitle_text() -> String:
	return "TABLERO %d · BLOQUE %d DE %d" % [Game.current_board_in_run,
			Game.block, Game.BLOCKS]


func _caps_text() -> String:
	return "Bolso %d/%d · Premios %d/%d" % [Game.inventory.size(), Game.marble_cap(),
			Game.prizes.size(), Game.prize_cap()]


# --- Counter: the four stock cards -----------------------------------------


func _build_counter(flow: VBoxContainer) -> void:
	_stock_box = GridContainer.new()
	_stock_box.columns = 4
	_stock_box.add_theme_constant_override("h_separation", 16)
	_stock_box.add_theme_constant_override("v_separation", 16)
	_stock_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	flow.add_child(_stock_box)
	_refresh_stock()


func _refresh_stock() -> void:
	for child in _stock_box.get_children():
		child.queue_free()
	_buy_buttons.clear()
	var stock: Dictionary = Economy.shop_stock(Game.block)
	for entry in stock["marbles"]:
		_stock_box.add_child(_stall_card("CHIBOLON",
				ContentDB.marble_def(entry["def_id"]), int(entry["price"])))
	for entry in stock["prizes"]:
		_stock_box.add_child(_stall_card("PREMIO",
				ContentDB.prize_def(entry["def_id"]), int(entry["price"])))


func _stall_card(kind: String, def: Resource, price: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(300, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("241552")
	style.border_color = Color("2e1b58")
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	card.add_theme_stylebox_override("panel", style)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	card.add_child(column)

	column.add_child(_candy_label(kind, 12, Color("4deeea")))

	var orb := TextureRect.new()
	orb.texture = orb_for(_item_color(kind, def))
	orb.custom_minimum_size = Vector2(56, 56)
	orb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	orb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var orb_center := CenterContainer.new()
	orb_center.add_child(orb)
	column.add_child(orb_center)

	column.add_child(_candy_label(def.display_name, 19, Color("ffe066")))

	var desc := _candy_label(def.effect_description(), 14, Color("cdb8ff"))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(270, 56)
	column.add_child(desc)

	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_END
	foot.add_theme_constant_override("separation", 8)
	column.add_child(foot)
	var price_label := _candy_label("$%d" % price, 18, Color("ff6fb5"))
	foot.add_child(price_label)
	var buy := _stall_button("COMPRAR", Color("ffe066"))
	buy.custom_minimum_size = Vector2(96, 0)
	buy.pressed.connect(_on_buy_pressed.bind(kind, def, price, buy))
	foot.add_child(buy)
	_buy_buttons.append({"button": buy, "kind": kind, "price": price})
	return card


func _stall_button(text: String, bg: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", Color("120b26"))
	button.add_theme_color_override("font_hover_color", Color("120b26"))
	button.add_theme_color_override("font_disabled_color", Color("cdb8ff"))
	button.add_theme_stylebox_override("normal", _button_style(bg))
	button.add_theme_stylebox_override("hover", _button_style(Color("ff6fb5")))
	button.add_theme_stylebox_override("pressed", _button_style(Color("4deeea")))
	button.add_theme_stylebox_override("disabled", _button_style(Color("2e1b58")))
	return button


func _on_buy_pressed(kind: String, def: Resource, price: int, button: Button) -> void:
	var ok := false
	if kind == "CHIBOLON":
		ok = Game.buy_marble(def)
	else:
		ok = Game.buy_prize(def)
	if ok:
		button.text = "COMPRADO"
		flash("Comprado: %s" % def.display_name)
	else:
		flash(_buy_block_reason(kind, price))
	_refresh_bottom()
	_restore_focus()


func _buy_block_reason(kind: String, price: int) -> String:
	if Game.money < price:
		return "Te falta dinero"
	if kind == "CHIBOLON" and Game.inventory.size() >= Game.marble_cap():
		return "Bolso lleno"
	return "No se puede comprar"


# --- Bottom: services + options | inventory --------------------------------


func _build_bottom(flow: VBoxContainer) -> void:
	var center := CenterContainer.new()
	flow.add_child(center)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 18)
	center.add_child(columns)

	var services := _shelf()
	columns.add_child(services)
	_build_services(services)

	var inventory := _shelf()
	columns.add_child(inventory)
	_build_inventory(inventory)

	# Bottom-center message strip (artboard pink border, yellow text).
	var strip := PanelContainer.new()
	strip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	strip.offset_top = -64
	strip.offset_bottom = -8
	strip.offset_left = 500
	strip.offset_right = -500
	var strip_style := StyleBoxFlat.new()
	strip_style.bg_color = Color(0.114, 0.071, 0.251, 0.94)
	strip_style.border_color = Color("ff6fb5")
	strip_style.set_border_width_all(2)
	strip_style.set_corner_radius_all(10)
	strip.add_theme_stylebox_override("panel", strip_style)
	_label_msg = _candy_label("", 16, Color("ffe066"))
	_label_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	strip.add_child(_label_msg)
	strip.visible = false
	add_child(strip)


func _shelf() -> PanelContainer:
	var shelf := PanelContainer.new()
	shelf.custom_minimum_size = Vector2(600, 0)
	shelf.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.114, 0.071, 0.251, 0.8)
	style.border_color = Color("2e1b58")
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	shelf.add_theme_stylebox_override("panel", style)
	return shelf


func _shelf_title(text: String) -> Label:
	var title := _candy_label(text, 13, Color("4deeea"))
	return title


func _build_services(shelf: PanelContainer) -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	shelf.add_child(column)

	column.add_child(_shelf_title("SERVICIOS"))
	var pack_price := Economy.extra_marble_pack_price(Game.block)
	var pack_out: Array = []
	column.add_child(_service_row("Canica extra", "+1 comun para la run",
			pack_price, _on_pack_pressed, pack_out))
	if not pack_out.is_empty():
		_pack_button = pack_out[0]
	var reroll_out: Array = []
	var reroll_price := Economy.reroll_price()
	column.add_child(_service_row("Reroll", "stock nuevo", reroll_price,
			_on_reroll_pressed, reroll_out))
	if not reroll_out.is_empty():
		_reroll_button = reroll_out[0]

	var options_title := _shelf_title("OPCIONES")
	column.add_child(options_title)
	_continue_button = _option_button("CONTINUAR →", Color("ff6fb5"), Color("120b26"))
	_continue_button.pressed.connect(_on_continue_pressed)
	column.add_child(_continue_button)
	var info := _option_button("INFORMACIÓN PARTIDA", Color("241552"), Color("cdb8ff"))
	info.pressed.connect(_on_info_pressed)
	column.add_child(info)
	var menu := _option_button("REGRESAR AL MENU", Color("241552"), Color("cdb8ff"))
	menu.pressed.connect(_on_menu_pressed)
	column.add_child(menu)
	var abandon := _option_button("ABANDONAR", Color("241552"), Color("cdb8ff"))
	abandon.pressed.connect(_on_abandon_pressed)
	column.add_child(abandon)

	var hint := _candy_label("← → navegar · ENTER comprar · C continuar", 11, Color("8d7fb8"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)


func _service_row(title_text: String, desc: String, price: int,
		handler: Callable, button_out: Array) -> PanelContainer:
	var row := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("241552")
	style.border_color = Color("2e1b58")
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	row.add_theme_stylebox_override("panel", style)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	row.add_child(line)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 1)
	line.add_child(text)
	var name_label := _candy_label(title_text, 15, Color.WHITE)
	text.add_child(name_label)
	text.add_child(_candy_label(desc, 12, Color("cdb8ff")))
	var price_buy := HBoxContainer.new()
	price_buy.add_theme_constant_override("separation", 8)
	line.add_child(price_buy)
	price_buy.add_child(_candy_label("$%d" % price, 15, Color("ff6fb5")))
	var button := _stall_button("COMPRAR", Color("ffe066"))
	if title_text == "Reroll":
		button.text = "REROLL"
		button.add_theme_stylebox_override("normal", _button_style(Color("4deeea")))
		button.add_theme_stylebox_override("hover", _button_style(Color("ff6fb5")))
		button.add_theme_stylebox_override("pressed", _button_style(Color("ffe066")))
		button.add_theme_stylebox_override("disabled", _button_style(Color("2e1b58")))
	button.custom_minimum_size = Vector2(96, 0)
	button.pressed.connect(handler)
	price_buy.add_child(button)
	button_out.append(button)
	return row


func _option_button(text: String, bg: Color, fg: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", fg)
	button.add_theme_color_override("font_hover_color", Color("fff7ff"))
	button.add_theme_stylebox_override("normal", _button_style(bg))
	button.add_theme_stylebox_override("hover", _button_style(Color("3a2a6e")))
	button.add_theme_stylebox_override("pressed", _button_style(Color("4deeea")))
	return button


func _build_inventory(shelf: PanelContainer) -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	shelf.add_child(column)
	column.add_child(_shelf_title("TU INVENTARIO — RESCATE: MITAD DEL PRECIO"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 220)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_inventory_list = VBoxContainer.new()
	_inventory_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inventory_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_inventory_list)
	_refresh_inventory()


func _refresh_inventory() -> void:
	for child in _inventory_list.get_children():
		child.queue_free()
	var counts := {}
	for def in Game.inventory:
		counts[def.id] = int(counts.get(def.id, 0)) + 1
	var shown := {}
	for def in Game.inventory:
		if shown.has(def.id):
			continue
		shown[def.id] = true
		var copies := int(counts[def.id])
		var name_text := def.display_name
		if copies > 1:
			name_text = "%s x%d" % [name_text, copies]
		_inventory_list.add_child(_inventory_row(def, name_text,
				def.effect_description(), def.price))
	for def in Game.prizes:
		_inventory_list.add_child(_inventory_row(def, def.display_name,
				def.effect_description(), def.price))


func _inventory_row(def: Resource, name_text: String, desc: String,
		base_price: int) -> PanelContainer:
	var row := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("241552")
	style.border_color = Color("2e1b58")
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	row.add_theme_stylebox_override("panel", style)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	row.add_child(line)
	var orb := TextureRect.new()
	orb.texture = orb_for(_item_color("ITEM", def))
	orb.custom_minimum_size = Vector2(22, 22)
	orb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	orb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	line.add_child(orb)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 1)
	line.add_child(text)
	var name_label := _candy_label(name_text, 14, Color.WHITE)
	text.add_child(name_label)
	text.add_child(_candy_label(desc, 12, Color("cdb8ff")))
	var price_buy := HBoxContainer.new()
	price_buy.add_theme_constant_override("separation", 8)
	line.add_child(price_buy)
	var rescue := Economy.rescue_price(base_price, Game.block)
	price_buy.add_child(_candy_label("$%d" % rescue, 14, Color("ff6fb5")))
	var sell := _stall_button("VENDER", Color("2e1b58"))
	sell.custom_minimum_size = Vector2(96, 0)
	sell.add_theme_color_override("font_color", Color("ffe066"))
	sell.add_theme_color_override("font_disabled_color", Color("cdb8ff"))
	sell.add_theme_stylebox_override("normal", _button_style(Color("2e1b58")))
	sell.add_theme_stylebox_override("hover", _button_style(Color("3a2a6e")))
	sell.add_theme_stylebox_override("pressed", _button_style(Color("ff6fb5")))
	sell.pressed.connect(_on_sell_pressed.bind(def))
	line.add_child(sell)
	return row


## One rescue sale: the Game API validates the last-marble guard; the
## inventory and stock gates rebuild and focus returns to the first enabled
## control (artboard S3).
func _on_sell_pressed(def: Resource) -> void:
	var ok := false
	if def is MarbleDef:
		ok = Game.sell_marble(def)
	elif def is PrizeDef:
		ok = Game.sell_prize(def)
	if ok:
		flash("Vendido: %s" % def.display_name)
	else:
		flash("No podes vender tu ultimo chibolon" if def is MarbleDef else "No se puede vender")
	_refresh_inventory()
	_refresh_bottom()
	_restore_focus()


# --- Info / menu / abandon -------------------------------------------------


func _on_info_pressed() -> void:
	if _info_panel != null:
		_info_panel.visible = not _info_panel.visible
		return
	_info_panel = PanelContainer.new()
	_info_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_info_panel.custom_minimum_size = Vector2(480, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1d1240")
	style.border_color = Color("ffe066")
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	style.content_margin_left = 24.0
	style.content_margin_right = 24.0
	style.content_margin_top = 18.0
	style.content_margin_bottom = 18.0
	_info_panel.add_theme_stylebox_override("panel", style)
	add_child(_info_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_info_panel.add_child(column)
	column.add_child(_candy_label("INFORMACIÓN PARTIDA", 24, Color("ffe066")))
	for line in _match_info_lines():
		column.add_child(_candy_label(line, 15, Color("fff7ff")))
	var close := _option_button("CERRAR", Color("241552"), Color("cdb8ff"))
	close.pressed.connect(func(): _info_panel.visible = false)
	column.add_child(close)
	_info_panel.visible = true


func _match_info_lines() -> Array:
	var prizes: Array[String] = []
	for prize in Game.prizes:
		prizes.append(prize.display_name)
	return [
		"Tablero: %d de %d (bloque %d)" % [Game.current_board_in_run, Game.BLOCKS, Game.block],
		"Dinero: $%d" % Game.money,
		"Chibolones: %d/%d" % [Game.inventory.size(), Game.marble_cap()],
		"Tableros superados: %d" % Game.boards_cleared,
		"Premios: %s" % (", ".join(prizes) if not prizes.is_empty() else "ninguno"),
	]


func _on_menu_pressed() -> void:
	Game.enter_menu()


func _on_abandon_pressed() -> void:
	if _abandon_confirm == null:
		_abandon_confirm = ConfirmationDialog.new()
		_abandon_confirm.dialog_text = "Abandonar la run actual y volver al menu?"
		_abandon_confirm.ok_button_text = "ABANDONAR"
		_abandon_confirm.cancel_button_text = "SEGUIR JUGANDO"
		_abandon_confirm.confirmed.connect(Game.enter_menu)
		add_child(_abandon_confirm)
	_abandon_confirm.popup_centered()


# --- Shop services ---------------------------------------------------------


func _on_pack_pressed() -> void:
	if Game.buy_extra_pack():
		flash("+1 chibolon comun para el resto de la run")
	else:
		flash("Te falta dinero o el bolso esta lleno")
	_refresh_bottom()
	_restore_focus()


func _on_reroll_pressed() -> void:
	if Game.reroll_shop():
		_refresh_stock()
		flash("Stock nuevo de la feria")
	else:
		flash("Te falta dinero para el reroll")
	_refresh_bottom()
	_restore_focus()


func _on_continue_pressed() -> void:
	Game.shop_continue()


## Re-evaluate every gated control (buy states, caps, pack, reroll).
func _refresh_bottom() -> void:
	_label_caps.text = _caps_text()
	for entry in _buy_buttons:
		var button: Button = entry["button"]
		var kind: String = entry["kind"]
		var price: int = entry["price"]
		var bought: bool = button.text == "COMPRADO"
		var blocked: bool = bought or Game.money < price \
				or (kind == "CHIBOLON" and Game.inventory.size() >= Game.marble_cap()) \
				or (kind != "CHIBOLON" and Game.prizes.size() >= Game.prize_cap())
		button.disabled = blocked
		button.focus_mode = Control.FOCUS_NONE if blocked else Control.FOCUS_ALL
	var pack_blocked: bool = Game.money < Economy.extra_marble_pack_price(Game.block) \
			or Game.inventory.size() >= Game.marble_cap()
	if _pack_button != null:
		_pack_button.disabled = pack_blocked
		_pack_button.focus_mode = Control.FOCUS_NONE if pack_blocked else Control.FOCUS_ALL
	if _reroll_button != null:
		_reroll_button.disabled = Game.money < Economy.reroll_price()
		_reroll_button.focus_mode = Control.FOCUS_NONE if _reroll_button.disabled else Control.FOCUS_ALL


func _on_money_changed(value: int) -> void:
	if _label_money != null:
		_label_money.text = "$%d" % value
	_refresh_bottom()


## W3b (S4): after any purchase/sale/reroll, focus returns to the first
## enabled control, so the shop stays mouse-free and gamepad-friendly.
func _restore_focus() -> void:
	var owner_node := get_viewport().gui_get_focus_owner()
	if owner_node != null and owner_node is Button and not (owner_node as Button).disabled:
		return
	_focus_first()


## Grab focus on the first enabled button (buy cards first, then services
## and options).
func _focus_first() -> void:
	for button in _find_focusables(self):
		if not button.disabled:
			button.grab_focus()
			return


func _find_focusables(node: Node) -> Array[Button]:
	var out: Array[Button] = []
	if node is Button:
		var button := node as Button
		if not button.disabled:
			out.append(button)
	for child in node.get_children():
		out.append_array(_find_focusables(child))
	return out


func flash(text: String) -> void:
	if _msg_tween and _msg_tween.is_valid():
		_msg_tween.kill()
	_label_msg.text = text
	_label_msg.modulate.a = 1.0
	_label_msg.get_parent().visible = true
	_msg_tween = create_tween()
	_msg_tween.tween_interval(2.0)
	_msg_tween.tween_property(_label_msg, "modulate:a", 0.0, 1.2)

# --- Placeholder sprites ---------------------------------------------------


## A generated orb: filled circle with a darker rim, cached by color.
func orb_for(color: Color) -> ImageTexture:
	var key := color.to_html()
	if _orb_cache.has(key):
		return _orb_cache[key]
	var s := 32
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var center := Vector2(s / 2.0, s / 2.0)
	var radius := s / 2.0 - 1.0
	var rim := color.darkened(0.55)
	for y in s:
		for x in s:
			var dist := Vector2(x + 0.5, y + 0.5).distance_to(center)
			if dist <= radius:
				var pixel := rim if dist > radius - 2.5 else color
				if Vector2(x + 0.5, y + 0.5).distance_to(center + Vector2(-4, -4)) < 4.5:
					pixel = pixel.lightened(0.35)
				img.set_pixel(x, y, pixel)
	var tex := ImageTexture.create_from_image(img)
	_orb_cache[key] = tex
	return tex


## Placeholder item color: marbles use their palette, prizes teal.
func _item_color(kind: String, def: Resource) -> Color:
	if def is MarbleDef and not def.palette.is_empty():
		return def.palette[0]
	return Color("2a9d8f")


# --- Construction ----------------------------------------------------------


func _candy_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("120b26"))
	label.add_theme_constant_override("outline_size", 5)
	return label


func _button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("120b26")
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	return style
