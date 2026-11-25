extends Control
## Library (D11, S3, S8; M4): the fair's index of what the player can own.
## Six tabs, one per family D11 names: marbles, the three prize classes and
## the song/SFX families the game does not have yet, which keep their slot
## empty with a "próximamente" card so the information structure is fixed now
## (S8). Each entry is one card with a rarity chip, the name, the lore and the
## effect text; the art is the generated orb the shop already uses, tinted
## with the entry's palette (S3 allows tinted placeholders until real art).
## Locked entries are silhouettes that hide the name behind "???" and swap the
## lore for the unlock hint (D3: fair catalog style), collected ones carry a
## marker. Every tab and card is a real Button, so keyboard, gamepad and touch
## all drive the same focus. Built in code in the board's candy style.

## Where "back" lands: the opener sets it before the screen enters the tree.
## "menu" changes to the title screen; anything else (the pause menu) means
## "close me and give control back", so the caller keeps its live board.
signal back_requested

const MENU_SCENE := "res://scenes/menu/menu.tscn"
const LOCKED_NAME := "???"
const COLLECTED_MARK := "en la colección"
const COME_SOON := "próximamente"
const HINTS := "Flechas para moverte  |  ESC / B para volver"
## Silhouette tint of a locked entry's art.
const LOCKED_ART := Color(0.16, 0.1, 0.26)
## Placeholder color of a prize with no palette of its own.
const PRIZE_ART := Color("2a9d8f")
const RARITY_COLORS := {
	"common": Color("cdb8ff"),
	"uncommon": Color("4deeea"),
	"rare": Color("ff6fb5"),
	"legendary": Color("ffe066"),
}

var return_to := "menu"

var _label_header: Label
var _cards: GridContainer
var _back_button: Button
var _tab_buttons: Array[Button] = []
var _tab_group := ButtonGroup.new()
var _current_tab := 0
var _orb_cache := {}
## One tab per family: `key` is the profile kind the collection is stored
## under, `prize_class` the D8 class a prize tab filters to. A key the game has
## no content for yet (songs, sfx) lists nothing and shows the placeholder.
var _tabs: Array[Dictionary] = [
	{"key": "marbles", "title": "CANICAS"},
	{"key": "prizes", "title": "COMODINES", "prize_class": PrizeDef.PrizeClass.PERMANENT},
	{"key": "prizes", "title": "CONSUMIBLES", "prize_class": PrizeDef.PrizeClass.CONSUMABLE},
	{"key": "prizes", "title": "COSMÉTICOS", "prize_class": PrizeDef.PrizeClass.COSMETIC},
	{"key": "songs", "title": "CANCIONES"},
	{"key": "sfx", "title": "EFECTOS"},
]


func _ready() -> void:
	# The pause menu opens this screen as a child overlay while the tree is
	# paused: the buttons must keep reacting or the library is dead there.
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	select_tab(0)
	# Keyboard/gamepad navigation lands on the first tab: without a focused
	# control the arrows and the stick reach nothing (the same fix the menu and
	# the shop got).
	if not _tab_buttons.is_empty():
		_tab_buttons[0].grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cancel") or event.is_action_pressed("pause"):
		_back()
		get_viewport().set_input_as_handled()


func _build() -> void:
	var background := ColorRect.new()
	background.color = Color("120a26")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)

	var flow := VBoxContainer.new()
	flow.add_theme_constant_override("separation", 12)
	margin.add_child(flow)

	var top := HBoxContainer.new()
	flow.add_child(top)
	var title := _candy_label("BIBLIOTECA", 44, Color("ffe066"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	# Touch players have no Escape key: the header carries the way out.
	_back_button = _small_button("VOLVER")
	_back_button.pressed.connect(_back)
	top.add_child(_back_button)

	_build_tabs(flow)

	_label_header = _candy_label("", 26, Color("4deeea"))
	_label_header.name = "Header"
	flow.add_child(_label_header)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	flow.add_child(scroll)

	_cards = GridContainer.new()
	_cards.name = "Cards"
	_cards.columns = 3
	_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards.add_theme_constant_override("h_separation", 16)
	_cards.add_theme_constant_override("v_separation", 16)
	scroll.add_child(_cards)

	flow.add_child(_candy_label(HINTS, 16, Color("a99bc9")))


func _build_tabs(parent: Control) -> void:
	var bar := HBoxContainer.new()
	bar.name = "TabBar"
	bar.add_theme_constant_override("separation", 10)
	parent.add_child(bar)
	_tab_buttons.clear()
	for index in _tabs.size():
		var button := Button.new()
		button.name = "Tab%d" % index
		button.text = str(_tabs[index]["title"])
		button.toggle_mode = true
		button.button_group = _tab_group
		button.custom_minimum_size = Vector2(0, 54)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 22)
		button.add_theme_color_override("font_color", Color("120b26"))
		button.add_theme_color_override("font_hover_color", Color("120b26"))
		button.add_theme_color_override("font_pressed_color", Color("120b26"))
		button.add_theme_stylebox_override("normal", _tab_style(Color("2e1b58"), 2))
		button.add_theme_stylebox_override("hover", _tab_style(Color("ff6fb5"), 2))
		button.add_theme_stylebox_override("pressed", _tab_style(Color("ffe066"), 3))
		button.add_theme_stylebox_override("focus", _focus_style())
		button.pressed.connect(_on_tab_pressed.bind(index))
		bar.add_child(button)
		_tab_buttons.append(button)


func _on_tab_pressed(index: int) -> void:
	select_tab(index)


## Show one tab: its cards and its header count.
func select_tab(index: int) -> void:
	if index < 0 or index >= _tabs.size():
		return
	_current_tab = index
	for i in _tab_buttons.size():
		_tab_buttons[i].button_pressed = i == index
	refresh()


## Rebuild the visible tab from the profile. Called on every tab switch and by
## whatever changes the collection while the library is open.
func refresh() -> void:
	if _cards == null or _label_header == null:
		return
	var tab: Dictionary = _tabs[_current_tab]
	var title := str(tab["title"])
	var kind := str(tab["key"])
	_clear_cards()
	var unlocked := 0
	var total := 0
	for def in _defs_for(tab):
		var info := _card_info(def)
		total += 1
		if SaveGame.is_unlocked(kind, str(info["id"])):
			unlocked += 1
		_cards.add_child(_card_for(kind, info))
	if total == 0:
		# A family the game has no content for yet (S8): keep the slot.
		_label_header.text = title
		_cards.add_child(_empty_card())
		return
	_label_header.text = "%s %d/%d" % [title, unlocked, total]


## The defs one tab lists: every marble, or the prizes of its class. A family
## the game has no content for yet lists nothing (S8).
func _defs_for(tab: Dictionary) -> Array[Resource]:
	var out: Array[Resource] = []
	var kind := str(tab["key"])
	if kind == "marbles":
		for def in ContentDB.marbles():
			out.append(def)
		return out
	if kind != "prizes":
		return out
	var wanted := int(tab["prize_class"])
	for def in ContentDB.prizes():
		if int(def.prize_class) == wanted:
			out.append(def)
	return out


## The card fields, read through the concrete def type (both carry
## `effect_description()`, the single readable line the shop also shows).
func _card_info(def: Resource) -> Dictionary:
	if def is MarbleDef:
		var marble := def as MarbleDef
		return {
			"id": marble.id,
			"name": marble.display_name,
			"rarity": marble.rarity,
			"flavor": marble.flavor,
			"effect": marble.effect_description(),
			"color": PRIZE_ART if marble.palette.is_empty() else marble.palette[0],
		}
	if def is PrizeDef:
		var prize := def as PrizeDef
		return {
			"id": prize.id,
			"name": prize.display_name,
			"rarity": prize.rarity,
			"flavor": prize.flavor,
			"effect": prize.effect_description(),
			"color": PRIZE_ART,
		}
	return {}


## Where a locked entry comes from: the milestone board that grants it, or a
## chest when no achievement does (S6).
func _hint_for(kind: String, id: String) -> String:
	var table := ContentDB.unlock_table()
	if table != null:
		for entry in table.milestones:
			var granted: Array = entry.get(kind, [])
			if granted.has(id):
				return "Se desbloquea al limpiar el tablero %d" % int(entry.get("board", 0))
	return "Aparece en un cofre"


func _card_for(kind: String, info: Dictionary) -> Button:
	var id := str(info["id"])
	var unlocked := SaveGame.is_unlocked(kind, id)
	var collected := SaveGame.is_collected(kind, id)
	var card := Button.new()
	card.name = "Card_" + id
	card.custom_minimum_size = Vector2(0, 214)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.focus_mode = Control.FOCUS_ALL
	card.add_theme_stylebox_override("normal", _card_style(not unlocked, false))
	card.add_theme_stylebox_override("hover", _card_style(not unlocked, true))
	card.add_theme_stylebox_override("pressed", _card_style(not unlocked, true))
	card.add_theme_stylebox_override("focus", _focus_style())

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	card.add_child(margin)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	margin.add_child(row)

	var art := TextureRect.new()
	art.name = "Art"
	art.texture = orb_for(info["color"])
	art.custom_minimum_size = Vector2(96, 96)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not unlocked:
		# The silhouette keeps the shape of the placeholder art and hides its
		# colors: D3 wants the locked slot visible, the entry not.
		art.modulate = LOCKED_ART
	row.add_child(art)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 6)
	row.add_child(column)

	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 10)
	column.add_child(top)

	var chip := PanelContainer.new()
	chip.name = "RarityChip"
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_theme_stylebox_override("panel", _chip_style(_rarity_color(info["rarity"])))
	top.add_child(chip)
	var rarity := _candy_label(str(info["rarity"]).to_upper(), 13, Color("120b26"))
	rarity.name = "Rarity"
	chip.add_child(rarity)

	var marker := _candy_label(COLLECTED_MARK, 13, Color("4deeea"))
	marker.name = "Marker"
	marker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	marker.visible = collected
	top.add_child(marker)

	var name_label := _candy_label(
		str(info["name"]) if unlocked else LOCKED_NAME, 24, Color("ffe066")
	)
	name_label.name = "Name"
	column.add_child(name_label)

	var lore := _candy_label(
		str(info["flavor"]) if unlocked else _hint_for(kind, id), 15, Color("cdb8ff")
	)
	lore.name = "Lore"
	lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(lore)

	if unlocked:
		var effect := _candy_label(str(info["effect"]), 15, Color("4deeea"))
		effect.name = "Effect"
		effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(effect)
	return card


## The card of a family with no content yet: the tab exists, the entries do
## not (S8).
func _empty_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "EmptyCard"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _card_style(true, false))
	var label := _candy_label(COME_SOON, 20, Color("a99bc9"))
	label.name = "EmptyText"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card.add_child(label)
	return card


func _clear_cards() -> void:
	for child in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()


## Back to the opener: the menu is a scene change, the pause menu gets the
## screen closed under it so the paused board survives (see `return_to`).
func _back() -> void:
	if return_to == "pause":
		back_requested.emit()
		return
	get_tree().change_scene_to_file(MENU_SCENE)


# --- Placeholder sprites ---------------------------------------------------


## A generated orb: filled circle with a darker rim, cached by color (the same
## placeholder the shop and the HUD draw).
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
			var pixel_center := Vector2(x + 0.5, y + 0.5)
			var dist := pixel_center.distance_to(center)
			if dist <= radius:
				var pixel := rim if dist > radius - 2.5 else color
				if pixel_center.distance_to(center + Vector2(-4, -4)) < 4.5:
					pixel = pixel.lightened(0.35)
				img.set_pixel(x, y, pixel)
	var tex := ImageTexture.create_from_image(img)
	_orb_cache[key] = tex
	return tex


# --- Candy style (copied from scripts/ui/menu.gd) --------------------------


func _candy_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("120b26"))
	label.add_theme_constant_override("outline_size", 5)
	return label


func _rarity_color(rarity: String) -> Color:
	return RARITY_COLORS.get(rarity, Color("cdb8ff"))


func _small_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(180, 54)
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", Color("120b26"))
	button.add_theme_color_override("font_hover_color", Color("3a1f6e"))
	button.add_theme_stylebox_override("normal", _tab_style(Color("ffe066"), 3))
	button.add_theme_stylebox_override("hover", _tab_style(Color("ff6fb5"), 3))
	button.add_theme_stylebox_override("pressed", _tab_style(Color("4deeea"), 3))
	button.add_theme_stylebox_override("focus", _focus_style())
	return button


func _tab_style(color: Color, border: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("120b26")
	style.set_border_width_all(border)
	style.set_corner_radius_all(12)
	return style


func _card_style(locked: bool, highlight: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("150c2b") if locked else Color("1d1240")
	style.border_color = Color("ff6fb5") if highlight else Color("3a1f6e")
	style.set_border_width_all(3 if highlight else 2)
	style.set_corner_radius_all(16)
	return style


func _chip_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(8)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	return style


func _focus_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color("4deeea")
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	return style
