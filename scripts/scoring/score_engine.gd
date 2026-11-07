class_name ScoreEngine
extends Node
## Board-scoped score keeper. Pure logic: subscribes to gameplay events on
## the EventBus and totals embed values. M2 plugs prize/modifier hooks into
## the same flow; nothing else computes score.

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
