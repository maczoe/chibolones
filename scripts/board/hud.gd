extends CanvasLayer
## Board HUD, W3c: the sidebar layout of design/shop-hud-planning/
## 02-hud-sidebar.html (artboard B, Balatro/Slay the Spire reference).
## Left sidebar owns the run state (objective with progress, score,
## money, chibolones, the marble in hand and a scrollable bag); the top
## right rail lists the active prizes with their effect text; top center
## announces the board's rule; bottom center carries the helper and
## resolution messages; bottom left reserves the bonus slot. Colors and
## proportions follow the artboard at x1.2 (1600x900 -> 1920x1080).
## Sprites are generated placeholders: colored orbs from the def palette.
## The board drives it through the small API below.

signal bag_selected(index: int)

## Sidebar stat value labels (kept as public names for the tests).
var label_shots: Label
var label_score: Label
var label_target: Label
var label_money: Label
var label_breakdown: Label
var label_timer: Label
## Board identity: the name lives in the sidebar title, the rule text in
## the top-center cue.
var label_board_title: Label
var label_board_effects: Label
var cue_panel: PanelContainer
var prize_box: VBoxContainer
var label_msg: Label
var power_bar: PowerBar
var end_overlay: ColorRect
var label_final: Label
var msg_tween: Tween
## Sidebar extras (W3c).
var label_shots_sub: Label
var hand_orb: TextureRect
var hand_name: Label
var hand_desc: Label
var bag_list: VBoxContainer
var bonus_box: HBoxContainer
var strip_panel: PanelContainer
## Objective progress (artboard bar under the target value).
var progress_bar: ProgressBar
var _objective := 0
var _score := 0
## Generated orb placeholder textures, cached by color string.
var _orb_cache := {}


class PowerBar extends Control:
	var power := 0.0

	func set_power(value: float) -> void:
		power = clampf(value, 0.0, 100.0)
		queue_redraw()

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		draw_rect(rect, Color(0.08, 0.06, 0.16, 0.85))
		var frac := power / 100.0
		if frac > 0.0:
			# Candy stripes: cyan and pink, circus style.
			var stripe := 14.0
			var x := 3.0
			var right := 3.0 + (size.x - 6.0) * frac
			var flip := false
			while x < right:
				var w := minf(stripe, right - x)
				var col := Color("4deeea") if flip else Color("ff6fb5")
				draw_rect(Rect2(Vector2(x, 3), Vector2(w, size.y - 6.0)), col)
				x += w
				flip = not flip
		draw_rect(rect, Color(1, 1, 1, 0.9), false, 2.0)


func _ready() -> void:
	_build()


func set_shots(left: int, total: int) -> void:
	label_shots.text = "%d/%d" % [left, total]
	var missing := maxi(total - left, 0)
	label_shots_sub.text = "quedan %d tiros" % missing if missing != 1 \
			else "queda 1 tiro"


func set_score(value: int) -> void:
	_score = value
	label_score.text = str(value)
	_update_objective()


## Run objective for this board. Boards played without a run (headless
## tests) pass 0 and show no objective stat.
func set_target(value: int) -> void:
	_objective = value
	progress_bar.max_value = maxi(value, 1)
	_update_objective()
	var card := label_target.get_parent().get_parent()
	card.visible = value > 0


func _update_objective() -> void:
	label_target.text = "%d / %d" % [_score, _objective]
	progress_bar.value = _score


func set_money(value: int) -> void:
	label_money.text = "$%d" % value


## Board identity: the name in the sidebar title, the rules in the
## top-center cue (hidden when the board carries no rule).
func set_board_title(board_name: String, effects: String, subtitle: String = "") -> void:
	label_board_title.text = board_name
	label_board_effects.text = effects
	cue_panel.visible = effects != ""


func set_selected_marble(def: MarbleDef) -> void:
	if def == null:
		hand_name.text = "-"
		hand_desc.text = ""
		return
	hand_name.text = def.display_name
	hand_desc.text = def.effect_description()
	hand_orb.texture = orb_for(_marble_color(def))


## The run bag, one button per owned marble with the active one
## highlighted. Duplicate defs collapse into one row with an x count.
func set_bag(defs: Array[MarbleDef], active_index: int) -> void:
	for child in bag_list.get_children():
		child.queue_free()
	if defs.is_empty():
		return
	var counts := {}
	for def in defs:
		counts[def.id] = int(counts.get(def.id, 0)) + 1
	var shown := {}
	for i in defs.size():
		var def := defs[i]
		if shown.has(def.id):
			continue
		shown[def.id] = true
		var copies := int(counts[def.id])
		var text := def.display_name
		if copies > 1:
			text = "%s x%d" % [text, copies]
		var button := Button.new()
		button.text = text
		button.focus_mode = Control.FOCUS_NONE
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 34)
		button.icon = orb_for(_marble_color(def))
		button.add_theme_font_size_override("font_size", 15)
		button.add_theme_color_override("font_color", Color("cdb8ff"))
		button.add_theme_color_override("font_hover_color", Color("ffe066"))
		button.add_theme_color_override("font_pressed_color", Color("ffe066"))
		button.add_theme_stylebox_override("normal", _bag_style(false))
		button.add_theme_stylebox_override("hover", _bag_style(false))
		button.add_theme_stylebox_override("pressed", _bag_style(false))
		if i == active_index:
			button.add_theme_color_override("font_color", Color("ffe066"))
			button.add_theme_stylebox_override("normal", _bag_style(true))
			button.add_theme_stylebox_override("hover", _bag_style(true))
			button.add_theme_stylebox_override("pressed", _bag_style(true))
		button.pressed.connect(func(): bag_selected.emit(i))
		bag_list.add_child(button)


func _bag_style(active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("2d1a63") if active else Color(0.14, 0.08, 0.32, 0.6)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	if active:
		style.border_color = Color("ffe066")
		style.set_border_width_all(2)
	return style


## Score math line (S4): the breakdown ScoreEngine produced for the last
## embed, as the strip's violet sub-line. Empty text hides it.
func set_breakdown(line: String) -> void:
	label_breakdown.text = line
	label_breakdown.visible = line != ""
	_update_strip()


## Cronometrado countdown; a negative value hides the line.
func set_timer(seconds_left: int) -> void:
	label_timer.visible = seconds_left >= 0
	if seconds_left >= 0:
		label_timer.text = "Tiempo: %d" % seconds_left


## Active prizes as rail cards: orb, name and what the prize does. Called
## again replaces the whole list.
func set_prizes(list: Array[PrizeDef]) -> void:
	for badge in prize_box.get_children():
		prize_box.remove_child(badge)
		badge.queue_free()
	for prize in list:
		var card := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color("241552")
		style.border_color = Color("2e1b58")
		style.set_border_width_all(2)
		style.set_corner_radius_all(10)
		style.content_margin_left = 10.0
		style.content_margin_right = 10.0
		style.content_margin_top = 8.0
		style.content_margin_bottom = 8.0
		card.add_theme_stylebox_override("panel", style)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 9)
		card.add_child(row)
		var orb := TextureRect.new()
		orb.texture = orb_for(Color("4deeea"))
		orb.custom_minimum_size = Vector2(32, 32)
		orb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		orb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(orb)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 2)
		row.add_child(column)
		var name_label := _hud_label(16, Color.WHITE)
		name_label.text = prize.display_name
		column.add_child(name_label)
		var desc := _hud_label(14, Color("cdb8ff"))
		desc.text = prize.effect_description()
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(360, 0)
		column.add_child(desc)
		prize_box.add_child(card)


## Last message flashed, readable by tests and the HUD cue assertions.
var last_flash := ""


func flash(text: String) -> void:
	if msg_tween and msg_tween.is_valid():
		msg_tween.kill()
	last_flash = text
	label_msg.text = text
	label_msg.modulate.a = 1.0
	_update_strip()
	msg_tween = create_tween()
	msg_tween.tween_interval(2.0)
	msg_tween.tween_property(label_msg, "modulate:a", 0.0, 1.2)


func set_power_visible(value: bool) -> void:
	power_bar.visible = value


func set_power(value: float) -> void:
	power_bar.set_power(value)


func show_game_over(score: int, possible: int) -> void:
	label_final.text = "Puntaje total: %d de %d posibles" % [score, possible]
	end_overlay.visible = true
	flash("Fin de la ronda")


## Board lost inside a run: same overlay, the run objective as the measure.
func show_defeat(score: int, objective: int) -> void:
	label_final.text = "Puntaje total: %d de %d necesarios" % [score, objective]
	end_overlay.visible = true
	flash("Te vencio el tablero")


# --- Placeholder sprites ----------------------------------------------------


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
				# A little highlight where the "light" hits.
				if Vector2(x + 0.5, y + 0.5).distance_to(center + Vector2(-4, -4)) < 4.5:
					pixel = pixel.lightened(0.35)
				img.set_pixel(x, y, pixel)
	var tex := ImageTexture.create_from_image(img)
	_orb_cache[key] = tex
	return tex


## Placeholder marble color: the def's first palette color, cyan fallback.
func _marble_color(def: MarbleDef) -> Color:
	if def != null and not def.palette.is_empty():
		return def.palette[0]
	return Color("4deeea")


# --- Construction ----------------------------------------------------------


## Text label with the dark candy outline.
func _hud_label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("120b26"))
	label.add_theme_constant_override("outline_size", 5)
	return label


func _stat_card() -> PanelContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("241552")
	style.border_color = Color("2e1b58")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 9.0
	style.content_margin_bottom = 9.0
	card.add_theme_stylebox_override("panel", style)
	return card


func _stat_header(text: String) -> Label:
	var label := _hud_label(13, Color("cdb8ff"))
	label.text = text
	return label


func _build() -> void:
	_build_sidebar()
	_build_prize_rail()
	_build_cue()
	_build_msg_strip()
	_build_power_and_overlay()


func _build_sidebar() -> void:
	var sidebar := PanelContainer.new()
	sidebar.anchor_bottom = 1.0
	sidebar.custom_minimum_size = Vector2(336, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.114, 0.071, 0.251, 0.97)
	style.border_color = Color("ff6fb5")
	style.border_width_right = 3
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 18.0
	style.content_margin_bottom = 18.0
	sidebar.add_theme_stylebox_override("panel", style)
	add_child(sidebar)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	sidebar.add_child(column)

	label_board_title = _hud_label(24, Color("ffe066"))
	label_board_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(label_board_title)

	# Objective card with its progress bar (artboard: yellow border).
	var objective_card := _stat_card()
	objective_card.visible = false
	var obj_style := objective_card.get_theme_stylebox("panel").duplicate()
	obj_style.border_color = Color("ffe066")
	objective_card.add_theme_stylebox_override("panel", obj_style)
	var obj_box := VBoxContainer.new()
	obj_box.add_theme_constant_override("separation", 3)
	objective_card.add_child(obj_box)
	obj_box.add_child(_stat_header("OBJETIVO"))
	label_target = _hud_label(31, Color("ffe066"))
	obj_box.add_child(label_target)
	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(0, 10)
	progress_bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("2e1b58")
	bg.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("ffe066")
	fill.set_corner_radius_all(4)
	progress_bar.add_theme_stylebox_override("background", bg)
	progress_bar.add_theme_stylebox_override("fill", fill)
	obj_box.add_child(progress_bar)
	column.add_child(objective_card)

	# Score.
	var score_card := _stat_card()
	var score_box := VBoxContainer.new()
	score_box.add_theme_constant_override("separation", 3)
	score_card.add_child(score_box)
	score_box.add_child(_stat_header("PUNTOS"))
	label_score = _hud_label(31, Color("4deeea"))
	score_box.add_child(label_score)
	column.add_child(score_card)

	# Money.
	var money_card := _stat_card()
	var money_box := VBoxContainer.new()
	money_box.add_theme_constant_override("separation", 3)
	money_card.add_child(money_box)
	money_box.add_child(_stat_header("DINERO"))
	label_money = _hud_label(31, Color("ffe066"))
	money_box.add_child(label_money)
	column.add_child(money_card)

	# Chibolones: ammo count and the throws left.
	var shots_card := _stat_card()
	var shots_box := VBoxContainer.new()
	shots_box.add_theme_constant_override("separation", 3)
	shots_card.add_child(shots_box)
	shots_box.add_child(_stat_header("CHIBOLONES"))
	label_shots = _hud_label(31, Color("4deeea"))
	shots_box.add_child(label_shots)
	label_shots_sub = _hud_label(14, Color("cdb8ff"))
	shots_box.add_child(label_shots_sub)
	column.add_child(shots_card)

	# The marble in hand: orb, name, what it does.
	column.add_child(_stat_header("EN MANO · ↑↓ CAMBIAR"))
	var hand_card := _stat_card()
	var hand_style := hand_card.get_theme_stylebox("panel").duplicate()
	hand_style.border_color = Color("ff6fb5")
	hand_card.add_theme_stylebox_override("panel", hand_style)
	var hand_row := HBoxContainer.new()
	hand_row.add_theme_constant_override("separation", 10)
	hand_card.add_child(hand_row)
	hand_orb = TextureRect.new()
	hand_orb.custom_minimum_size = Vector2(46, 46)
	hand_orb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hand_orb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hand_row.add_child(hand_orb)
	var hand_text := VBoxContainer.new()
	hand_text.add_theme_constant_override("separation", 2)
	hand_row.add_child(hand_text)
	hand_name = _hud_label(18, Color("ff6fb5"))
	hand_text.add_child(hand_name)
	hand_desc = _hud_label(14, Color("cdb8ff"))
	hand_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hand_desc.custom_minimum_size = Vector2(230, 0)
	hand_text.add_child(hand_desc)
	column.add_child(hand_card)

	# The scrollable bag (W3c): every owned marble, active highlighted.
	column.add_child(_stat_header("BOLSO"))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 190)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	bag_list = VBoxContainer.new()
	bag_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bag_list.add_theme_constant_override("separation", 5)
	scroll.add_child(bag_list)

	# Cronometrado countdown, small and centered under the bag.
	label_timer = _hud_label(18, Color("ffe066"))
	label_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_timer.visible = false
	column.add_child(label_timer)

	# Reserved bonus slot (artboard bottom-left gem row): hidden until the
	# game accumulates board bonuses.
	bonus_box = HBoxContainer.new()
	bonus_box.add_theme_constant_override("separation", 6)
	bonus_box.visible = false
	add_child(bonus_box)
	bonus_box.position = Vector2(16, 1024)
	var bonus_label := _hud_label(13, Color("cdb8ff"))
	bonus_label.text = "BONUS"
	bonus_box.add_child(bonus_label)


func _build_prize_rail() -> void:
	# Active prizes, top right: orb + name + effect description per card.
	prize_box = VBoxContainer.new()
	prize_box.anchor_left = 1.0
	prize_box.anchor_right = 1.0
	prize_box.offset_left = -440
	prize_box.offset_right = -16
	prize_box.offset_top = 12
	prize_box.offset_bottom = 400
	prize_box.add_theme_constant_override("separation", 8)
	add_child(prize_box)


func _build_cue() -> void:
	# Top-center rule chip: pink border, yellow text (artboard W3c).
	cue_panel = PanelContainer.new()
	cue_panel.anchor_left = 0.5
	cue_panel.anchor_right = 0.5
	cue_panel.offset_left = -430
	cue_panel.offset_right = 430
	cue_panel.offset_top = 10
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.114, 0.071, 0.251, 0.92)
	style.border_color = Color("ff6fb5")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 22.0
	style.content_margin_right = 22.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 7.0
	cue_panel.add_theme_stylebox_override("panel", style)
	add_child(cue_panel)
	label_board_effects = _hud_label(17, Color("ffe066"))
	label_board_effects.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cue_panel.add_child(label_board_effects)
	cue_panel.visible = false


func _build_msg_strip() -> void:
	# Bottom-center helper/resolution strip: pink border, yellow main line,
	# violet sub-line (the score breakdown).
	strip_panel = PanelContainer.new()
	strip_panel.anchor_left = 0.5
	strip_panel.anchor_right = 0.5
	strip_panel.anchor_top = 1.0
	strip_panel.anchor_bottom = 1.0
	strip_panel.offset_left = -390
	strip_panel.offset_right = 390
	strip_panel.offset_top = -104
	strip_panel.offset_bottom = -12
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.114, 0.071, 0.251, 0.94)
	style.border_color = Color("ff6fb5")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 26.0
	style.content_margin_right = 26.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	strip_panel.add_theme_stylebox_override("panel", style)
	add_child(strip_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	strip_panel.add_child(column)
	label_msg = _hud_label(18, Color("ffe066"))
	label_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(label_msg)
	label_breakdown = _hud_label(14, Color("cdb8ff"))
	label_breakdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_breakdown.visible = false
	column.add_child(label_breakdown)


func _update_strip() -> void:
	strip_panel.visible = label_msg.text != "" or label_breakdown.visible


func _build_power_and_overlay() -> void:
	power_bar = PowerBar.new()
	power_bar.anchor_left = 0.5
	power_bar.anchor_right = 0.5
	power_bar.anchor_top = 1.0
	power_bar.anchor_bottom = 1.0
	power_bar.offset_left = -190
	power_bar.offset_right = 190
	power_bar.offset_top = -144
	power_bar.offset_bottom = -114
	power_bar.visible = false
	add_child(power_bar)

	end_overlay = ColorRect.new()
	end_overlay.color = Color(0.08, 0.06, 0.16, 0.8)
	end_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	end_overlay.visible = false
	add_child(end_overlay)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	end_overlay.add_child(vbox)

	var title := Label.new()
	title.text = "Fin de la ronda"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color("ffe066"))
	title.add_theme_color_override("font_outline_color", Color("120b26"))
	title.add_theme_constant_override("outline_size", 8)
	vbox.add_child(title)

	label_final = Label.new()
	label_final.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_final.add_theme_font_size_override("font_size", 30)
	label_final.add_theme_color_override("font_color", Color("ff6fb5"))
	label_final.add_theme_color_override("font_outline_color", Color("120b26"))
	label_final.add_theme_constant_override("outline_size", 6)
	vbox.add_child(label_final)

	var hint := Label.new()
	hint.text = "Apreta R para reiniciar"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 22)
	vbox.add_child(hint)
