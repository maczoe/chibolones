extends Control
## Win interstitial (user request, 2026-11-08): when a board is won the run
## plays a placeholder fanfare, shows a big GANADOR for a few seconds, then
## the board stats (puntuación, canicas restantes, dinero — all placeholder
## layout until the juice pass) and a CONTINUAR button that routes back into
## the run flow (Game.win_screen_continue: shop, or the run summary after
## board 20). Built in code in the candy style, like the other screens.

## Seconds the big GANADOR stays alone before the stats appear.
const TITLE_DELAY := 2.5

var stats_box: VBoxContainer
var label_score: Label
var label_marbles: Label
var label_money: Label
var continue_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	_play_fanfare()
	# A Timer child dies with this scene, so freeing the screen early (a
	# test, or the player leaving) never fires into a dead callable.
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = TITLE_DELAY
	timer.timeout.connect(_show_stats)
	add_child(timer)
	timer.start()


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
	column.add_theme_constant_override("separation", 24)
	panel.add_child(column)

	var title := _candy_label("GANADOR", 84, Color("ffe066"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	stats_box = VBoxContainer.new()
	stats_box.add_theme_constant_override("separation", 12)
	stats_box.visible = false
	column.add_child(stats_box)

	label_score = _stat_label()
	label_marbles = _stat_label()
	label_money = _stat_label()
	stats_box.add_child(label_score)
	stats_box.add_child(label_marbles)
	stats_box.add_child(label_money)

	continue_button = _menu_button("CONTINUAR")
	continue_button.visible = false
	continue_button.pressed.connect(_on_continue)
	column.add_child(continue_button)


## Placeholder fanfare: the stream is a synthesized arpeggio in-project
## (data/audio/fanfare.wav), same approach as the thunk; swap the asset for
## a real fanfare in the juice pass.
func _play_fanfare() -> void:
	var player := AudioStreamPlayer.new()
	player.stream = load("res://data/audio/fanfare.wav")
	add_child(player)
	player.play()


## After the title beat: fill the placeholders from Game.last_win_stats and
## hand the focus to CONTINUAR so keyboard/gamepad reach it right away.
func _show_stats() -> void:
	var stats: Dictionary = Game.last_win_stats
	label_score.text = "Puntuacion: %d" % int(stats.get("score", 0))
	label_marbles.text = "Canicas restantes: %d" % int(stats.get("marbles_left", 0))
	label_money.text = "Dinero: $%d" % int(Game.money)
	stats_box.visible = true
	continue_button.visible = true
	continue_button.grab_focus()


func _on_continue() -> void:
	Game.win_screen_continue()


# --- Candy style (copied from scripts/ui/menu.gd) ---------------------------


func _candy_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("120b26"))
	label.add_theme_constant_override("outline_size", 8)
	return label


func _stat_label() -> Label:
	var label := _candy_label("", 34, Color("4deeea"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
