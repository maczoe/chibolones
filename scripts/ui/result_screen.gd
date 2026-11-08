extends Control
## Run summary (M1): the RESULT phase screen. Lost runs show what the player
## reached and offer a fresh run; a run that cleared board 20 offers the
## endless opt-in (GDD D6). State is read from Game, never passed around.
## Like the win screen (user request, 2026-11-08): translucent over the live
## board, the title plays alone for TITLE_DELAY seconds, then the resumen
## and its buttons appear with focus on the first one.

## Seconds the title stays alone before the resumen appears.
const TITLE_DELAY := 2.5

var summary_box: VBoxContainer


func _ready() -> void:
	_build()
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = TITLE_DELAY
	timer.timeout.connect(_show_summary)
	add_child(timer)
	timer.start()


## Test/read seam: the resumen appears after the title beat.
func summary_visible() -> bool:
	return summary_box != null and summary_box.visible


func _build() -> void:
	# Translucent dim: the live board stays visible behind the summary.
	var background := ColorRect.new()
	background.color = Color(0.07, 0.04, 0.15, 0.45)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)

	var title := _candy_label("Run completa!" if Game.run_won else "Fin de la run",
			64, Color("ffe066"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	summary_box = VBoxContainer.new()
	summary_box.alignment = BoxContainer.ALIGNMENT_CENTER
	summary_box.add_theme_constant_override("separation", 14)
	summary_box.visible = false
	column.add_child(summary_box)

	var first_button: Button = null
	for line in _summary_lines():
		var label := _candy_label(line, 28, Color("ff6fb5"))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		summary_box.add_child(label)

	if Game.run_won:
		var keep_going := _menu_button("CONTINUAR (modo infinito)")
		keep_going.pressed.connect(_on_endless_pressed)
		summary_box.add_child(keep_going)
		first_button = keep_going
	else:
		var retry := _menu_button("REINTENTAR")
		retry.pressed.connect(_on_retry_pressed)
		summary_box.add_child(retry)
		first_button = retry

	var back := _menu_button("MENU")
	back.pressed.connect(_on_menu_pressed)
	summary_box.add_child(back)
	# Focus lands when the resumen shows, mirroring the win screen.
	set_meta("first_button", first_button)


## After the title beat: reveal the resumen and hand focus to its first
## button, so keyboard/gamepad reach it right away.
func _show_summary() -> void:
	summary_box.visible = true
	var first_button: Button = get_meta("first_button", null)
	if first_button != null:
		first_button.grab_focus()


## Summary lines: what the run achieved, and how it ended when it was lost.
func _summary_lines() -> Array[String]:
	var lines: Array[String] = []
	if Game.run_won:
		lines.append("Tableros superados: %d de %d" % [Game.BOARDS_PER_RUN, Game.BOARDS_PER_RUN])
	elif Game.endless_mode:
		# Endless loses show the 20 run boards plus the extra ones.
		var extra: int = maxi(0, Game.boards_cleared - Game.BOARDS_PER_RUN)
		lines.append("Tableros superados: %d (%d de la run + %d en infinito)"
				% [Game.boards_cleared, Game.BOARDS_PER_RUN, extra])
	else:
		lines.append("Tableros superados: %d" % Game.boards_cleared)
	lines.append("Dinero: $%d" % Game.money)
	if not Game.run_won:
		lines.append("Te vencio el tablero %d (bloque %d)"
				% [Game.current_board_in_run, Game.block])
	return lines


func _on_retry_pressed() -> void:
	# Game resets the run and moves back to board 1.
	Game.start_run()


func _on_endless_pressed() -> void:
	# Endless opt-in: the run continues past board 20 at the block-5 rate.
	Game.start_endless()


func _on_menu_pressed() -> void:
	Game.enter_menu()


# --- Candy style -----------------------------------------------------------


func _candy_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("120b26"))
	label.add_theme_constant_override("outline_size", 8)
	return label


func _menu_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(520, 68)
	button.add_theme_font_size_override("font_size", 28)
	button.add_theme_color_override("font_color", Color("120b26"))
	button.add_theme_color_override("font_hover_color", Color("3a1f6e"))
	button.add_theme_stylebox_override("normal", _button_style(Color("ffe066")))
	button.add_theme_stylebox_override("hover", _button_style(Color("ff6fb5")))
	button.add_theme_stylebox_override("pressed", _button_style(Color("4deeea")))
	return button


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1d1240")
	style.border_color = Color("ff6fb5")
	style.set_border_width_all(3)
	style.set_corner_radius_all(20)
	style.content_margin_left = 64
	style.content_margin_right = 64
	style.content_margin_top = 44
	style.content_margin_bottom = 44
	return style


func _button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("120b26")
	style.set_border_width_all(4)
	style.set_corner_radius_all(14)
	return style
