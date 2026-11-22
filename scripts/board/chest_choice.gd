extends CanvasLayer
## S17/S18 (D8/D10) chest reveal: the wheel. A chest that opens on the board
## pauses the flight and shows a row of icon slots that cycle the real loot
## pool fast, decelerate and stop on the drawn prize (S17 supersedes S16: the
## pause is the point, the tension is the reveal). When the reveal ends the
## panel either grants (its owner does, through Game.add_prize) or, when the
## drawn prize's class shelf is full, offers one button per owned prize of that
## class to drop PLUS a decline button that takes the board's cash fallback and
## leaves the shelf alone (S18: no mandatory trade).
##
## Built in code in the board's card style (scripts/board/hud.gd set_prizes) and
## PROCESS_MODE_ALWAYS, because everything else is paused while it is up.
##
## The board owns every state change; this node only shows the wheel and
## reports what the player decided. A headless test drives the whole flow
## through present() / settle() / pick() / decline() / is_open() with no
## simulated clicks and no real time: settle() runs the spin to its end.

## The owned prize the player chose to drop (S11/S18). Emitted before the panel
## closes, so the owner can still read `drawn` and `options` while handling it.
signal picked(old_prize: PrizeDef)
## The player kept the shelf and took the cash (S18). Carries the amount the
## panel showed on its button, i.e. the board's `chest_cash_fallback`.
signal declined(cash: int)
## The wheel stopped on a prize whose class has room: the owner grants it now.
## Emitted before the panel closes, like `picked`.
signal revealed

enum Stage { SPIN, HOLD, CHOICE, DONE }

## Chests are a pending reward, not a slot machine: the whole reveal stays well
## inside the 2-3 s the throw loop can afford (S6).
const SPIN_TIME := 1.0
const REVEAL_HOLD := 0.6
## Slots in the row and how far the window sweeps before it stops on the
## winner, so the row visibly travels and then lands centered.
const SLOT_COUNT := 5
const SWEEP_STEPS := 22

const TITLE := "Cofre: %s"
const SPIN_TITLE := "Cofre"
const SPIN_HINT := "La ruleta gira..."
const CHOICE_HINT := "Elegi que premio soltar, o dejalo y cobra $%d"
## Rarity tint of the slot orbs, so the row reads as loot and not as text.
const RARITY_COLORS := {
	"common": Color("cdb8ff"), "uncommon": Color("4deeea"), "rare": Color("ffe066")
}
const GLYPH_COLOR := Color("120b26")

## The prize the chest drew (the slot the wheel stops on).
var drawn: PrizeDef = null
## The owned prizes of the drawn prize's class, in shelf order: exactly what
## the player may drop. Empty means the reveal grants on its own.
var options: Array[PrizeDef] = []
## The loot pool the slots cycle: everything the run can still find.
var pool: Array[PrizeDef] = []
## Cash the decline button takes (the board's chest_cash_fallback).
var cash_fallback := 0
## Test-facing nodes: the title and hint, the slot row (each slot carries its
## current `def`, its name `label` and its `card`) and the decision buttons.
var title_label: Label = null
var hint_label: Label = null
var slots: Array[Dictionary] = []
var winner_slot := -1
## One button per option (the drop side of the decision), in option order.
var buttons: Array[Button] = []
## The other side of the decision: keep the shelf and take the cash (S18).
var decline_button: Button = null
## Seconds the slots have travelled: 0 until present() and SPIN_TIME when the
## wheel has stopped. Public because the reveal is time-driven and a test
## proves it advances under the paused tree instead of waiting out the spin.
var spin_elapsed := 0.0

var _open := false
var _stage: Stage = Stage.DONE
## Window the row was last painted for, so a spinning wheel does not rebuild
## its styleboxes 60 times a second.
var _rendered_origin := 0
var _rendered_winner := -1
var _hold_elapsed := 0.0
var _column: VBoxContainer = null
var _choice_box: VBoxContainer = null


func _init() -> void:
	# The tree is paused while this panel shows, so it must keep running.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Over the HUD (1) and the board's own overlays (2).
	layer = 3


func _process(delta: float) -> void:
	tick(delta)


## Show the wheel for one drawn prize over the loot pool it came from.
## `choices` is the drop list (empty when the prize fits) and `cash` what the
## decline button pays. Pauses the tree: the board stays frozen until the
## reveal resolves.
func present(
	drawn_prize: PrizeDef, choices: Array[PrizeDef], loot_pool: Array[PrizeDef], cash: int = 0
) -> void:
	if drawn_prize == null:
		# A wheel with no winner would pause the board on nothing: never open.
		return
	drawn = drawn_prize
	options.assign(choices)
	pool.assign(loot_pool)
	if not pool.has(drawn):
		# The wheel always has its winner to stop on, even if the caller hands
		# a pool the draw took the prize from (or an empty one).
		pool.insert(0, drawn)
	cash_fallback = cash
	_build()
	_open = true
	_stage = Stage.SPIN
	spin_elapsed = 0.0
	_hold_elapsed = 0.0
	_render_slots()
	var tree := get_tree()
	if tree != null:
		tree.paused = true


## Advance the wheel by `delta` seconds. The spin is time-driven so the real
## board animates by itself; tests call settle() instead of waiting.
func tick(delta: float) -> void:
	if not _open:
		return
	var left := delta
	while left > 0.0 and _open:
		match _stage:
			Stage.SPIN:
				var spin_left := SPIN_TIME - spin_elapsed
				var spin_step := minf(left, spin_left)
				spin_elapsed += spin_step
				left -= spin_step
				_render_slots()
				if spin_elapsed >= SPIN_TIME:
					_stop_on_winner()
			Stage.HOLD:
				var hold_left := REVEAL_HOLD - _hold_elapsed
				var hold_step := minf(left, hold_left)
				_hold_elapsed += hold_step
				left -= hold_step
				if _hold_elapsed >= REVEAL_HOLD:
					_resolve()
			_:
				return


## Finish the reveal right now: the spin lands on the drawn prize, the winner
## is shown and the panel resolves (grants through `revealed`, or offers the
## decision). Returns false when there is nothing left to finish, so a test can
## prove the wheel never resolves twice.
func settle() -> bool:
	if not _open:
		return false
	match _stage:
		Stage.SPIN:
			_stop_on_winner()
			_hold_elapsed = REVEAL_HOLD
			_resolve()
			return true
		Stage.HOLD:
			_hold_elapsed = REVEAL_HOLD
			_resolve()
			return true
	return false


## Decide for the player, i.e. the same thing a drop button does. An index
## outside the offered list is refused and changes nothing: the panel stays
## open and the board stays paused. Refused while the wheel still spins, when
## there is no decision to make.
func pick(index: int) -> bool:
	if not _open or _stage != Stage.CHOICE or index < 0 or index >= options.size():
		return false
	var old_prize: PrizeDef = options[index]
	# Closed before the signal: the owner's handler can never be re-entered
	# into a second pick, and the chest grants once.
	_open = false
	_stage = Stage.DONE
	picked.emit(old_prize)
	_close()
	return true


## Keep the shelf and take the cash (S18): the other side of the decision.
## Refused outside the decision stage, so a fit prize can never be declined.
func decline() -> bool:
	if not _open or _stage != Stage.CHOICE:
		return false
	_open = false
	_stage = Stage.DONE
	declined.emit(cash_fallback)
	_close()
	return true


func is_open() -> bool:
	return _open


## True while the slots still travel: nothing can be decided yet.
func is_spinning() -> bool:
	return _open and _stage == Stage.SPIN


## True once the wheel stopped with a decision to make (S18).
func has_choice() -> bool:
	return _open and _stage == Stage.CHOICE


func _close() -> void:
	_open = false
	_stage = Stage.DONE
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


# --- The spin ---------------------------------------------------------------


## Index of the slot the row is centered on: what the wheel "stops" on.
func _center_slot() -> int:
	return SLOT_COUNT / 2


## Pool index of the drawn prize, i.e. where the sweep must land.
func _winner_index() -> int:
	return maxi(pool.find(drawn), 0)


## Window origin of the row right now. The sweep travels SWEEP_STEPS entries
## and decelerates onto the winner (ease-out: fast at the start, zero speed
## where it lands), so the stop never looks like a jump.
func _origin_index() -> int:
	if _stage != Stage.SPIN:
		return _winner_index()
	var progress := clampf(spin_elapsed / SPIN_TIME, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - progress, 2.0)
	return _winner_index() - SWEEP_STEPS + int(round(float(SWEEP_STEPS) * eased))


## The pool index a slot shows, wrapped so a short pool still fills the row.
func _pool_at(index: int) -> PrizeDef:
	if pool.is_empty():
		return drawn
	var size := pool.size()
	return pool[((index % size) + size) % size]


## Land on the winner: freeze the row centered on it, mark that slot as the
## winner and name the prize in the title (the spin kept it secret until now).
func _stop_on_winner() -> void:
	_stage = Stage.HOLD
	spin_elapsed = SPIN_TIME
	winner_slot = _center_slot()
	_render_slots(true)
	if title_label != null:
		title_label.text = TITLE % drawn.display_name
	if hint_label != null:
		hint_label.text = drawn.class_name_text()


## Repaint the row for the current window. The spin runs every frame, so the
## repaint only happens when the window actually moved (or on demand, for the
## winner highlight).
func _render_slots(force := false) -> void:
	var origin := _origin_index()
	if not force and origin == _rendered_origin and winner_slot == _rendered_winner:
		return
	_rendered_origin = origin
	_rendered_winner = winner_slot
	var center := _center_slot()
	for i in slots.size():
		var def: PrizeDef = _pool_at(origin + i - center)
		var slot: Dictionary = slots[i]
		slot["def"] = def
		var label: Label = slot["label"]
		label.text = def.display_name if def != null else "?"
		var glyph: Label = slot["glyph"]
		glyph.text = _glyph(def)
		var is_winner := _stage != Stage.SPIN and winner_slot == i
		slot["winner"] = is_winner
		var card: Control = slot["card"]
		card.add_theme_stylebox_override("panel", _slot_style(is_winner))
		var orb: Control = slot["orb"]
		orb.add_theme_stylebox_override("panel", _orb_style(def))


func _resolve() -> void:
	if options.is_empty():
		# Nothing to decide: the prize fits, the owner grants it now.
		_stage = Stage.DONE
		revealed.emit()
		_close()
		return
	_stage = Stage.CHOICE
	_render_choice()


# --- The decision (S18) -----------------------------------------------------


func _render_choice() -> void:
	if hint_label != null:
		hint_label.text = CHOICE_HINT % cash_fallback
	if _choice_box == null:
		return
	_choice_box.show()
	for i in options.size():
		var prize: PrizeDef = options[i]
		if prize == null:
			continue
		var button := _prize_button("%s: %s" % [prize.display_name, prize.effect_description()])
		button.pressed.connect(pick.bind(i))
		_choice_box.add_child(button)
		buttons.append(button)
	decline_button = _prize_button("Dejarlo y cobrar $%d" % cash_fallback)
	decline_button.pressed.connect(decline)
	_choice_box.add_child(decline_button)
	if not buttons.is_empty():
		buttons[0].grab_focus()
	else:
		decline_button.grab_focus()


# --- Build ------------------------------------------------------------------


func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	slots.clear()
	buttons.clear()
	decline_button = null
	winner_slot = -1
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
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 12)
	panel.add_child(_column)
	title_label = _label(SPIN_TITLE, 30, Color("ffe066"))
	_column.add_child(title_label)
	hint_label = _label(SPIN_HINT, 18, Color("cdb8ff"))
	_column.add_child(hint_label)
	_column.add_child(_slot_row())
	_choice_box = VBoxContainer.new()
	_choice_box.add_theme_constant_override("separation", 10)
	_choice_box.hide()
	_column.add_child(_choice_box)


## The row of icon slots: one card per slot, an orb tinted by the loot rarity
## and the prize name under it. Built once; _render_slots only repaints them.
func _slot_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in SLOT_COUNT:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(118, 104)
		card.add_theme_stylebox_override("panel", _slot_style(false))
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 6)
		column.alignment = BoxContainer.ALIGNMENT_CENTER
		card.add_child(column)
		var orb := Panel.new()
		orb.custom_minimum_size = Vector2(52, 52)
		orb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		orb.add_theme_stylebox_override("panel", _orb_style(null))
		column.add_child(orb)
		var glyph := _label("?", 24, GLYPH_COLOR)
		glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		orb.add_child(glyph)
		var name_label := _label("?", 13, Color.WHITE)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(name_label)
		row.add_child(card)
		(
			slots
			. append(
				{
					"def": null,
					"card": card,
					"orb": orb,
					"glyph": glyph,
					"label": name_label,
					"winner": false,
				}
			)
		)
	return row


## The letter inside the orb: the prize name's initial, so two orbs of the same
## rarity still read differently while the row spins.
func _glyph(def: PrizeDef) -> String:
	if def == null or def.display_name.is_empty():
		return "?"
	return def.display_name.substr(0, 1).to_upper()


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


## One slot card: the winner is the lit one, gold and thicker.
func _slot_style(is_winner: bool) -> StyleBoxFlat:
	var style := _card_style(Color("ffe066") if is_winner else Color("3a2a6b"))
	style.bg_color = Color("3b2470") if is_winner else Color("1b1038")
	style.set_corner_radius_all(12)
	if is_winner:
		style.set_border_width_all(3)
	return style


## The slot icon: a round orb in the loot's rarity color.
func _orb_style(def: PrizeDef) -> StyleBoxFlat:
	var rarity := def.rarity if def != null else ""
	var style := StyleBoxFlat.new()
	style.bg_color = RARITY_COLORS.get(rarity, Color("cdb8ff"))
	style.set_corner_radius_all(26)
	return style


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
