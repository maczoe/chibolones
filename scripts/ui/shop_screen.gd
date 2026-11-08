extends Control
## Shop v1 (W3): the stock Economy draws is now buyable. Every card charges
## through the Game purchase APIs (money + caps validated there), the pack
## buys a common, and the reroll charges the flat price for a fresh draw.
## Stock cards are rebuilt on reroll; disabled buttons leave the focus
## cycle (mouse-free shop, user request 2026-11-08).

const PENDING_TAG := "(en camino, M3)"  # retired: kept for save-game compat reads

## One stock card's buy state, so money/cap changes can re-evaluate it.
var _buy_buttons: Array[Dictionary] = []
var _stock_box: GridContainer
var _label_money: Label
var _label_caps: Label
var _label_msg: Label
var _reroll_button: Button
var _pack_button: Button
var _msg_tween: Tween


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

	_label_money = _candy_label("$: %d" % Game.money, 28, Color("ffe066"))
	_label_money.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_label_money)
	Game.money_changed.connect(_on_money_changed)

	_label_caps = _candy_label(_caps_text(), 20, Color("cdb8ff"))
	_label_caps.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_label_caps)

	_label_msg = _candy_label("", 20, Color("ffe066"))
	_label_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_label_msg)

	_stock_box = GridContainer.new()
	_stock_box.columns = 2
	_stock_box.add_theme_constant_override("h_separation", 16)
	_stock_box.add_theme_constant_override("v_separation", 16)
	column.add_child(_stock_box)
	_refresh_stock()

	_pack_button = _menu_button("Paquete de canica extra (+1 tiro) - $%d"
			% Economy.extra_marble_pack_price(Game.block))
	_pack_button.pressed.connect(_on_pack_pressed)
	column.add_child(_pack_button)

	_reroll_button = _menu_button("Reroll de la tienda - $%d" % Economy.reroll_price())
	_reroll_button.pressed.connect(_on_reroll_pressed)
	column.add_child(_reroll_button)

	var continue_button := _menu_button("CONTINUAR")
	continue_button.pressed.connect(_on_continue_pressed)
	column.add_child(continue_button)
	# Keyboard/gamepad first (user request, 2026-11-08): the shop opens with
	# CONTINUAR focused, the same fix the main menu and the pause menu got.
	continue_button.grab_focus()


## Rebuild the stock cards from a fresh draw (first open or a reroll).
func _refresh_stock() -> void:
	for child in _stock_box.get_children():
		child.queue_free()
	_buy_buttons.clear()
	var stock: Dictionary = Economy.shop_stock(Game.block)
	for entry in stock["marbles"]:
		_stock_box.add_child(_stock_card("Canica", ContentDB.marble_def(entry["def_id"]),
				int(entry["price"])))
	for entry in stock["prizes"]:
		_stock_box.add_child(_stock_card("Premio", ContentDB.prize_def(entry["def_id"]),
				int(entry["price"])))


func _stock_card(kind: String, def: Resource, price: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_style())
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	card.add_child(column)
	column.add_child(_candy_label(kind, 18, Color("4deeea")))
	column.add_child(_candy_label(def.display_name, 26, Color("ffe066")))
	column.add_child(_candy_label("$%d" % price, 24, Color("ff6fb5")))
	var buy := _menu_button("COMPRAR")
	buy.custom_minimum_size = Vector2(240, 48)
	buy.add_theme_font_size_override("font_size", 22)
	buy.pressed.connect(_on_buy_pressed.bind(kind, def, price, buy))
	column.add_child(buy)
	_buy_buttons.append({"button": buy, "kind": kind, "price": price})
	_update_buy_states()
	return card


## One buy: the Game API validates money and cap; the card marks itself
## bought and everything else re-evaluates through money_changed.
func _on_buy_pressed(kind: String, def: Resource, price: int, button: Button) -> void:
	var ok := false
	if kind == "Canica":
		ok = Game.buy_marble(def)
	else:
		ok = Game.buy_prize(def)
	if ok:
		button.text = "COMPRADO"
		flash("Comprado: %s" % def.display_name)
	else:
		flash(_buy_block_reason(kind, price))
	_update_buy_states()


## Why a buy is blocked right now, for the flash message.
func _buy_block_reason(kind: String, price: int) -> String:
	if Game.money < price:
		return "Te falta plata"
	if kind == "Canica" and Game.inventory.size() >= Game.marble_cap():
		return "Bolso lleno"
	if kind != "Canica" and Game.prizes.size() >= Game.prize_cap():
		return "Estanteria llena"
	return "No se puede comprar"


## Re-evaluate every buy row against money and caps; also the pack and the
## reroll. Disabled rows leave the focus cycle. Safe to call mid-build,
## when the pack/reroll buttons do not exist yet.
func _update_buy_states() -> void:
	for entry in _buy_buttons:
		var button: Button = entry["button"]
		var kind: String = entry["kind"]
		var price: int = entry["price"]
		var bought: bool = button.text == "COMPRADO"
		var blocked: bool = bought or Game.money < price \
				or (kind == "Canica" and Game.inventory.size() >= Game.marble_cap()) \
				or (kind != "Canica" and Game.prizes.size() >= Game.prize_cap())
		button.disabled = blocked
		button.focus_mode = Control.FOCUS_NONE if blocked else Control.FOCUS_ALL
	if _pack_button != null:
		_pack_button.disabled = Game.money < Economy.extra_marble_pack_price(Game.block) \
				or Game.inventory.size() >= Game.marble_cap()
		_pack_button.focus_mode = Control.FOCUS_NONE if _pack_button.disabled else Control.FOCUS_ALL
	if _reroll_button != null:
		_reroll_button.disabled = Game.money < Economy.reroll_price()
		_reroll_button.focus_mode = Control.FOCUS_NONE if _reroll_button.disabled else Control.FOCUS_ALL


func _on_money_changed(value: int) -> void:
	if _label_money != null:
		_label_money.text = "$: %d" % value
	_update_buy_states()


func _on_pack_pressed() -> void:
	if Game.buy_extra_pack():
		flash("+1 canica comun para el resto de la run")
	else:
		flash("Te falta plata o el bolso esta lleno")
	_update_buy_states()


func _on_reroll_pressed() -> void:
	if Game.reroll_shop():
		_refresh_stock()
		flash("Stock nuevo de la feria")
	else:
		flash("Te falta plata para el reroll")
	_update_buy_states()


func _on_continue_pressed() -> void:
	# Game advances the run and moves to the next board scene.
	Game.shop_continue()


func _caps_text() -> String:
	return "Bolso: %d/%d   Premios: %d/%d" % [Game.inventory.size(), Game.marble_cap(),
			Game.prizes.size(), Game.prize_cap()]


func flash(text: String) -> void:
	_label_msg.text = text
	_label_caps.text = _caps_text()
	if _msg_tween and _msg_tween.is_valid():
		_msg_tween.kill()
	_label_msg.modulate.a = 1.0
	_msg_tween = create_tween()
	_msg_tween.tween_interval(2.0)
	_msg_tween.tween_property(_label_msg, "modulate:a", 0.0, 1.2)


# --- Construction ----------------------------------------------------------


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
