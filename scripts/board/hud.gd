extends CanvasLayer
## Board HUD: shots left, score, flash messages, the oscillating power bar
## and the round-over overlay. Built in code for now; visual polish lands
## in M6. The board drives it through the small API below.

var label_shots: Label
var label_score: Label
var label_target: Label
var label_money: Label
var label_marble: Label
var label_breakdown: Label
var label_timer: Label
## Board identity (M2.5): the board's name and the bonificadores it carries,
## kept on screen top-center for the whole board.
var label_board_title: Label
var label_board_effects: Label
var prize_box: VBoxContainer
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
	label_shots.text = "Canicas restantes: %d / %d" % [left, total]


func set_score(value: int) -> void:
	label_score.text = "Puntaje: %d" % value


## Run objective for this board, right under the score. Boards played
## without a run (headless tests) pass 0 and show no objective line.
func set_target(value: int) -> void:
	label_target.text = "Objetivo: %d" % value
	label_target.visible = value > 0


func set_money(value: int) -> void:
	label_money.text = "$: %d" % value


## Board identity: the board's own name in candy yellow, and under it the
## rules it carries ("Sin modificadores" when it has none). Called once per
## board from its BoardDef, so the player always knows what they are playing.
func set_board_title(board_name: String, effects: String) -> void:
	label_board_title.text = board_name
	label_board_effects.text = effects


func set_selected_marble(marble_name: String) -> void:
	label_marble.text = "Canica: %s" % marble_name


## Score math line (S4): the breakdown ScoreEngine produced for the last
## embed that a prize or bonificador changed. Empty text hides it, so a
## clean throw shows no arithmetic.
func set_breakdown(line: String) -> void:
	label_breakdown.text = line
	label_breakdown.visible = line != ""


## Cronometrado countdown; a negative value hides the line (the step is not
## on a clock, or the board has no timer rule).
func set_timer(seconds_left: int) -> void:
	label_timer.visible = seconds_left >= 0
	if seconds_left >= 0:
		label_timer.text = "Tiempo: %d" % seconds_left


## Active prizes as stacked badges in the top-right corner: the prize name
## plus the multiplier it applies, in the same candy style as the stat
## labels. Called again replaces the whole list.
func set_prizes(list: Array[PrizeDef]) -> void:
	for badge in prize_box.get_children():
		prize_box.remove_child(badge)
		badge.queue_free()
	for prize in list:
		var badge := _candy_label(24)
		badge.text = "%s %s" % [prize.display_name,
				PrizeDef.format_mult(prize.wall_hit_mult)]
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		prize_box.add_child(badge)


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


## Board lost inside a run: same overlay, the run objective as the measure.
func show_defeat(score: int, objective: int) -> void:
	label_final.text = "Puntaje total: %d de %d necesarios" % [score, objective]
	end_overlay.visible = true
	flash("Te vencio el tablero")


# --- Construction ----------------------------------------------------------


func _stat_label(pos: Vector2) -> Label:
	var label := _candy_label(24)
	label.position = pos
	return label


## Candy-style label: yellow text with a dark outline, the board's stat look.
func _candy_label(font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("ffe066"))
	label.add_theme_color_override("font_outline_color", Color("120b26"))
	label.add_theme_constant_override("outline_size", 6)
	return label


func _build() -> void:
	# Board identity, top-center: the name above, its rules below. Anchored
	# to the middle so it never fights the stats on the left or the prize
	# badges on the right.
	label_board_title = Label.new()
	label_board_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_board_title.anchor_left = 0.5
	label_board_title.anchor_right = 0.5
	label_board_title.offset_left = -400
	label_board_title.offset_right = 400
	label_board_title.offset_top = 8
	label_board_title.offset_bottom = 44
	label_board_title.add_theme_font_size_override("font_size", 28)
	label_board_title.add_theme_color_override("font_color", Color("ffe066"))
	label_board_title.add_theme_color_override("font_outline_color", Color("120b26"))
	label_board_title.add_theme_constant_override("outline_size", 8)
	add_child(label_board_title)

	label_board_effects = Label.new()
	label_board_effects.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_board_effects.anchor_left = 0.5
	label_board_effects.anchor_right = 0.5
	label_board_effects.offset_left = -400
	label_board_effects.offset_right = 400
	label_board_effects.offset_top = 42
	label_board_effects.offset_bottom = 70
	label_board_effects.add_theme_font_size_override("font_size", 18)
	label_board_effects.add_theme_color_override("font_color", Color("fff7ff"))
	label_board_effects.add_theme_color_override("font_outline_color", Color("120b26"))
	label_board_effects.add_theme_constant_override("outline_size", 5)
	add_child(label_board_effects)

	label_shots = _stat_label(Vector2(16, 10))
	add_child(label_shots)

	label_score = _stat_label(Vector2(16, 44))
	add_child(label_score)

	# Run objective and money, stacked under the score: what the board asks
	# and what the player has to spend in the next shop.
	label_target = _candy_label(20)
	label_target.position = Vector2(16, 78)
	label_target.visible = false
	add_child(label_target)

	label_money = _candy_label(20)
	label_money.position = Vector2(16, 110)
	add_child(label_money)

	# Selected marble, under the run stats: small, so the score stays the
	# loudest number on screen.
	label_marble = _candy_label(18)
	label_marble.position = Vector2(16, 142)
	add_child(label_marble)

	# Cronometrado countdown, under the marble line: only the boards with the
	# decision timer rule ever show it.
	label_timer = _candy_label(20)
	label_timer.position = Vector2(16, 174)
	label_timer.visible = false
	add_child(label_timer)

	# Prize badges stack downward from the top-right corner. The container is
	# fixed-width and right-anchored, so long names still hug the edge.
	prize_box = VBoxContainer.new()
	prize_box.anchor_left = 1.0
	prize_box.anchor_right = 1.0
	prize_box.offset_left = -460
	prize_box.offset_right = -16
	prize_box.offset_top = 10
	prize_box.offset_bottom = 140
	add_child(prize_box)

	label_msg = Label.new()
	label_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_msg.anchor_left = 0.0
	label_msg.anchor_right = 1.0
	label_msg.anchor_top = 1.0
	label_msg.anchor_bottom = 1.0
	label_msg.offset_top = -140
	label_msg.offset_bottom = -100
	label_msg.add_theme_font_size_override("font_size", 26)
	label_msg.add_theme_color_override("font_color", Color("120b26"))
	label_msg.add_theme_color_override("font_outline_color", Color("fff7ff"))
	label_msg.add_theme_constant_override("outline_size", 8)
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

	# Score math line, small and chalk-white under the flash messages: it
	# explains the value the marble just scored without stealing the scene.
	label_breakdown = Label.new()
	label_breakdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_breakdown.anchor_left = 0.0
	label_breakdown.anchor_right = 1.0
	label_breakdown.anchor_top = 1.0
	label_breakdown.anchor_bottom = 1.0
	label_breakdown.offset_top = -102
	label_breakdown.offset_bottom = -84
	label_breakdown.add_theme_font_size_override("font_size", 18)
	label_breakdown.add_theme_color_override("font_color", Color(0.93, 0.93, 0.95))
	label_breakdown.add_theme_color_override("font_outline_color", Color("120b26"))
	label_breakdown.add_theme_constant_override("outline_size", 4)
	label_breakdown.visible = false
	add_child(label_breakdown)

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
