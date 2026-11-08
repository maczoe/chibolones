class_name ScoreEngine
extends Node
## Board-scoped score keeper. Pure logic: subscribes to gameplay events on
## the EventBus and totals embed values. Since M2 the per-embed value comes
## from one pipeline (evaluate_embed): prizes and bonificadores declare what
## they react to and edit the breakdown there, so nothing else computes
## score and every rule is readable in one place.

signal score_changed(total: int)

var total := 0


func _ready() -> void:
	EventBus.embed.connect(_on_embed)


func reset() -> void:
	total = 0
	score_changed.emit(total)


func _on_embed(_notch_index: int, value: int) -> void:
	total += value
	score_changed.emit(total)


## The M2 scoring seam: one embed value, every interested party asked once.
## `base_value` is the notch's current painted value (Borracho can have
## reshuffled it); `ctx` carries `board` (the board node) and `throw` (this
## throw's facts: marble, notch, wall_hits, wall_mult, wall_source, center).
## Order is fixed so the HUD line always reads the same way: prizes, board
## bonificadores, the board's wall accumulation, then the marble itself.
func evaluate_embed(base_value: int, ctx: Dictionary = {}) -> ScoreBreakdown:
	var breakdown := ScoreBreakdown.new()
	breakdown.base_value = base_value
	var context := ctx.duplicate()
	context["adds"] = breakdown.adds
	context["mults"] = breakdown.mults
	var throw_ctx: Dictionary = context.get("throw", {})

	# (1) Prizes owned this run (permanent, hook contract).
	for prize in Game.prizes:
		if prize != null and prize.interested_in().has(&"embed"):
			prize.contribute_embed(base_value, context)

	# (2) The board's own bonificadores (board-scoped, same contract).
	var board_ref: Node = context.get("board")
	if board_ref != null and board_ref.has_method("active_modifiers"):
		for modifier in board_ref.active_modifiers():
			if modifier != null and modifier.interested_in().has(&"embed"):
				modifier.contribute_embed(base_value, context)

	# (3) Walls this throw: the board accumulates the bonificador part (each
	# wall hit multiplies, Cuerda), so the total math equals the M1 one.
	var wall_mult: float = float(throw_ctx.get("wall_mult", 1.0))
	if not is_equal_approx(wall_mult, 1.0):
		var wall_source := StringName(str(throw_ctx.get("wall_source", "Paredes")))
		breakdown.mults[wall_source] = wall_mult

	# (4) The launched marble's own scoring multiplier (glass x2).
	var marble: MarbleDef = throw_ctx.get("marble")
	if marble != null and not is_equal_approx(marble.score_mult, 1.0):
		breakdown.mults[StringName(marble.display_name)] = marble.score_mult

	return breakdown
