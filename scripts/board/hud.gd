extends CanvasLayer
## Board HUD: shots left, score, flash messages, the oscillating power bar
## and the round-over overlay. Built in code for now; visual polish lands
## in M6. The board drives it through the small API below.

var label_shots: Label
var label_score: Label
var label_msg: Label
var power_bar: PowerBar
var end_overlay: ColorRect
var label_final: Label
var msg_tween: Tween


class PowerBar extends Control:
	var power := 0.0

	func set_power(value: float) -> void:
		power = clampf(value, 0.0, 100.0)
		queue_redraw()

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		draw_rect(rect, Color(0.0, 0.0, 0.0, 0.6))
		var frac := power / 100.0
		if frac > 0.0:
			var col := Color.from_hsv(lerpf(0.05, 0.33, frac), 0.85, 0.95)
			draw_rect(Rect2(Vector2(3, 3), Vector2((size.x - 6.0) * frac, size.y - 6.0)), col)
		draw_rect(rect, Color(1, 1, 1, 0.9), false, 2.0)


func _ready() -> void:
	_build()


func set_shots(left: int, total: int) -> void:
	label_shots.text = "Canicas restantes: %d / %d" % [left, total]


func set_score(value: int) -> void:
	label_score.text = "Puntaje: %d" % value


func flash(text: String) -> void:
	if msg_tween and msg_tween.is_valid():
		msg_tween.kill()
	label_msg.text = text
	label_msg.modulate.a = 1.0
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


# --- Construction ----------------------------------------------------------


func _build() -> void:
	label_shots = Label.new()
	label_shots.position = Vector2(16, 10)
	label_shots.add_theme_font_size_override("font_size", 24)
	add_child(label_shots)

	label_score = Label.new()
	label_score.position = Vector2(16, 44)
	label_score.add_theme_font_size_override("font_size", 24)
	add_child(label_score)

	label_msg = Label.new()
	label_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_msg.anchor_left = 0.0
	label_msg.anchor_right = 1.0
	label_msg.anchor_top = 1.0
	label_msg.anchor_bottom = 1.0
	label_msg.offset_top = -140
	label_msg.offset_bottom = -100
	label_msg.add_theme_font_size_override("font_size", 26)
	add_child(label_msg)

	power_bar = PowerBar.new()
	power_bar.anchor_left = 0.5
	power_bar.anchor_right = 0.5
	power_bar.anchor_top = 1.0
	power_bar.anchor_bottom = 1.0
	power_bar.offset_left = -160
	power_bar.offset_right = 160
	power_bar.offset_top = -76
	power_bar.offset_bottom = -46
	power_bar.visible = false
	add_child(power_bar)

	end_overlay = ColorRect.new()
	end_overlay.color = Color(0, 0, 0, 0.6)
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
	vbox.add_child(title)

	label_final = Label.new()
	label_final.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_final.add_theme_font_size_override("font_size", 30)
	vbox.add_child(label_final)

	var hint := Label.new()
	hint.text = "Apreta R para reiniciar"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 22)
	vbox.add_child(hint)
