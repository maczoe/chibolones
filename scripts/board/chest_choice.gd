extends CanvasLayer
## S11 (D8/D10): the full-bag discard choice. A chest that draws a prize whose
## class shelf is full pauses the board and asks which owned prize of that
## class to drop, instead of paying the cash fallback. Built in code in the
## board's card style (scripts/board/hud.gd set_prizes) and
## PROCESS_MODE_ALWAYS, because everything else is paused while it is up.
##
## The board owns the state change (Game.discard_prize + Game.add_prize); this
## node only shows the options and reports which one was picked, so a headless
## test drives the whole flow through present() / pick() / is_open() with no
## simulated clicks.

## The owned prize the player chose to drop. Emitted before the panel closes,
## so the owner can still read `drawn` and `options` while handling it.
signal picked(old_prize: PrizeDef)

const TITLE := "Cofre: %s"
const HINT := "Elegi que premio soltar"

## The prize the chest drew (the one that needs the freed slot).
var drawn: PrizeDef = null
## The owned prizes of the drawn prize's class, in shelf order: exactly what
## the player may drop.
var options: Array[PrizeDef] = []
## Test-facing nodes: the title already names the drawn prize and every button
## already carries its option's name and effect line.
var title_label: Label = null
var buttons: Array[Button] = []

var _open := false


func _init() -> void:
	# The tree is paused while this panel decides, so it must keep running.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Over the HUD (1) and the board's own overlays (2).
	layer = 3


## Show the choice for one drawn prize over the owned prizes it may replace.
## Pauses the tree: the board stays frozen until a pick closes the panel.
func present(drawn_prize: PrizeDef, choices: Array[PrizeDef]) -> void:
	drawn = drawn_prize
	options.assign(choices)
	if options.is_empty():
		# Unreachable by construction (a class only refuses a grant when its
		# shelf is at its cap), but a paused panel with nothing to pick would
		# deadlock the board: close instead of pausing on an empty choice.
		_close()
		return
	_build()
	_open = true
	var tree := get_tree()
	if tree != null:
		tree.paused = true


## Decide for the player, i.e. the same thing a button click does. An index
## outside the offered list is refused and changes nothing: the panel stays
## open and the board stays paused.
func pick(index: int) -> bool:
	if not _open or index < 0 or index >= options.size():
		return false
	var old_prize: PrizeDef = options[index]
	# Closed before the signal: the owner's handler can never be re-entered
	# into a second pick, and the chest grants once.
	_open = false
	picked.emit(old_prize)
	_close()
	return true


func is_open() -> bool:
	return _open


func _close() -> void:
	var tree := get_tree()
	if tree != null:
		tree.paused = false
	queue_free()


## Safety net: a panel freed while it is still up (board teardown, a scene
## change) must never leave the tree paused with nothing to unpause it.
func _exit_tree() -> void:
	if not _open:
		return
	_open = false
	var tree := get_tree()
	if tree != null:
		tree.paused = false


func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	buttons.clear()
	var screen := Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.02, 0.1, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var name_text: String = drawn.display_name if drawn != null else "?"
	title_label = _label(TITLE % name_text, 30, Color("ffe066"))
	column.add_child(title_label)
	column.add_child(_label(HINT, 18, Color("cdb8ff")))
	for i in options.size():
		var prize: PrizeDef = options[i]
		if prize == null:
			continue
		var button := _prize_button("%s: %s" % [prize.display_name, prize.effect_description()])
		button.pressed.connect(pick.bind(i))
		column.add_child(button)
		buttons.append(button)
	if not buttons.is_empty():
		buttons[0].grab_focus()


# --- Card style (scripts/board/hud.gd set_prizes colors) --------------------


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("120b26"))
	label.add_theme_constant_override("outline_size", 6)
	return label


func _prize_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(760, 58)
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color("ffe066"))
	button.add_theme_color_override("font_focus_color", Color("ffe066"))
	button.add_theme_stylebox_override("normal", _card_style(Color("2e1b58")))
	button.add_theme_stylebox_override("hover", _card_style(Color("4deeea")))
	button.add_theme_stylebox_override("focus", _card_style(Color("4deeea")))
	button.add_theme_stylebox_override("pressed", _card_style(Color("ffe066")))
	return button


func _panel_style() -> StyleBoxFlat:
	var style := _card_style(Color("ff6fb5"))
	style.set_corner_radius_all(20)
	style.content_margin_left = 40
	style.content_margin_right = 40
	style.content_margin_top = 32
	style.content_margin_bottom = 32
	return style


func _card_style(border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("241552")
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style
