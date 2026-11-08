extends Node
## Seed juice layer (M0.5): subscribes to EventBus and adds immediate
## feedback — embed thunk sound and a floating score popup. Formal juice
## (particles, camera shake, music) lands in M6 on these same events.
## Audio is synthesized in-project (data/audio/thunk.wav): no licensed
## assets, public-domain-equivalent.

const POPUP_RISE := 0.8
const POPUP_LIFE := 0.8

var board: Node3D
var thunk: AudioStreamPlayer3D


func _ready() -> void:
	board = get_parent()
	thunk = AudioStreamPlayer3D.new()
	thunk.stream = load("res://data/audio/thunk.wav")
	thunk.volume_db = 2.0
	board.add_child(thunk)
	EventBus.embed.connect(_on_embed)


func _on_embed(notch_index: int, value: int) -> void:
	thunk.play()
	_popup(notch_index, value)


func _popup(notch_index: int, value: int) -> void:
	var pos: Vector3 = board.holes[notch_index].pos
	var label := Label3D.new()
	label.text = "+%d" % value
	label.font_size = 140
	label.pixel_size = 0.0025
	label.modulate = Color("ffe066")
	label.outline_size = 24
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = pos + Vector3(0, 0.45, 0)
	board.add_child(label)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y + POPUP_RISE, POPUP_LIFE) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(label, "modulate:a", 0.0, POPUP_LIFE).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)
