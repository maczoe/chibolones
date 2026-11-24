class_name AudioSettings
extends RefCounted
## S9: the persisted audio levels, applied to the buses the project actually
## has. A project without an SFX bus or a zero level is handled explicitly
## (mute instead of a -inf dB write), so a headless run and a bus-less project
## both stay green.


static func apply(save: Node) -> void:
	if save == null:
		return
	_apply_bus(0, clampf(float(save.setting("master_volume", 1.0)), 0.0, 1.0))
	var sfx := AudioServer.get_bus_index("SFX")
	if sfx >= 0:
		_apply_bus(sfx, clampf(float(save.setting("sfx_volume", 1.0)), 0.0, 1.0))


static func _apply_bus(index: int, level: float) -> void:
	AudioServer.set_bus_mute(index, level <= 0.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(level, 0.0001)))
