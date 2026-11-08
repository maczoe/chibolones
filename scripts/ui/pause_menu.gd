extends Control
## Pause overlay (user request, 2026-11-08): ESC or gamepad Start during a
## board opens it, the tree pauses, and the player can resume, restart the
## run (normal runs only) or go back to the title screen. Built in code in
## the menu's candy style. PROCESS_MODE_ALWAYS, because everything else is
## paused while this is on screen.

const HINT := "ESC / START reanuda"

## The restart option, exposed for tests and future modes that may toggle it.
var restart_button: Button


func _ready() -> void:
	# The board and the physics are paused; this overlay must keep working.
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	get_tree().paused = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("cancel"):
		_resume()
		get_viewport().set_input_as_handled()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.02, 0.1, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	panel.add_child(column)

	column.add_child(_candy_label("PAUSA", 46, Color("ffe066")))

	var resume := _menu_button("CONTINUAR")
	resume.pressed.connect(_resume)
	column.add_child(resume)

	var restart := _menu_button("REINICIAR RUN")
	# Debug matches are single boards: there is no run to restart, so the
	# option only exists in the normal JUGAR flow.
	restart.visible = not Game.debug_mode
	restart.pressed.connect(_restart_run)
	column.add_child(restart)
	restart_button = restart

	var menu := _menu_button("MENU PRINCIPAL")
	menu.pressed.connect(_go_to_menu)
	column.add_child(menu)

	column.add_child(_candy_label(HINT, 18, Color("a99bc9")))

	# Keyboard/gamepad navigation lands on CONTINUAR first (same fix the
	# main menu got: without a focused control the pad reaches nothing).
	resume.grab_focus()


func _resume() -> void:
	get_tree().paused = false
	queue_free()


func _restart_run() -> void:
	get_tree().paused = false
	# queue_free happens on the deferred scene change; the run restarts from
	# board 1 with the starting loadout.
	Game.start_run()


func _go_to_menu() -> void:
	get_tree().paused = false
	Game.enter_menu()


# --- Candy style (copied from scripts/ui/menu.gd) ---------------------------


func _candy_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("120b26"))
	label.add_theme_constant_override("outline_size", 8)
	return label


func _menu_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(420, 72)
	button.add_theme_font_size_override("font_size", 32)
	button.add_theme_color_override("font_color", Color("120b26"))
	button.add_theme_color_override("font_hover_color", Color("3a1f6e"))
	button.add_theme_color_override("font_disabled_color", Color("a99bc9"))
	button.add_theme_stylebox_override("normal", _button_style(Color("ffe066"), 4.0))
	button.add_theme_stylebox_override("hover", _button_style(Color("ff6fb5"), 4.0))
	button.add_theme_stylebox_override("pressed", _button_style(Color("4deeea"), 4.0))
	button.add_theme_stylebox_override("disabled", _button_style(Color("2e1b58"), 2.0))
	return button


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1d1240")
	style.border_color = Color("ff6fb5")
	style.set_border_width_all(3)
	style.set_corner_radius_all(20)
	style.content_margin_left = 64
	style.content_margin_right = 64
	style.content_margin_top = 48
	style.content_margin_bottom = 48
	return style


func _button_style(color: Color, border: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("120b26")
	style.set_border_width_all(int(border))
	style.set_corner_radius_all(14)
	return style
