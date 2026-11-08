extends Control
## Title screen (M1): the fair is open, one button plays the run. The library
## is a disabled placeholder until M4 ships the save/unlock wave. UI is built
## in code in the board's candy style: yellow labels with a dark outline over
## dark violet panels.

const TITLE := "CHIBOLONES"
const SUBTITLE := "una noche de feria"
const HINTS := "Flechas para mover e inclinar  |  ESPACIO para tirar  |  Z camara"


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
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 18)
	panel.add_child(column)

	var title := _candy_label(TITLE, 96, Color("ffe066"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	var subtitle := _candy_label(SUBTITLE, 30, Color("ff6fb5"))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)

	var play := _menu_button("JUGAR")
	play.pressed.connect(_on_play_pressed)
	column.add_child(play)

	var library := _menu_button("BIBLIOTECA (M4)")
	library.disabled = true
	column.add_child(library)

	var hints := _candy_label(HINTS, 18, Color("cdb8ff"))
	hints.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hints)


func _on_play_pressed() -> void:
	# Game starts the run and moves to the board scene.
	Game.start_run()


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
