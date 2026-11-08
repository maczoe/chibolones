extends SceneTree
## W3 marble effects test: the seven content-plan marbles that need more
## than def fields. Agata (wind steady), Remolino (center pull),
## Teledirigida (aim-picked target + homing), Rebote (side-exit refund),
## Trampa (embeds any speed), Espejo (copies the previous embed score,
## only > 0). Nitro needs no code: its speed_mult is plain def data (T6).
## Run: godot --headless --path . --script res://tests/marbles_w3.gd

var game
var content
var failed := false
var embeds: Array = []
var refunds := 0
var outcomes: Array = []


func _initialize() -> void:
	_ensure_autoloads()
	_run()


func _ensure_autoloads() -> void:
	var autoloads := [
		["EventBus", "res://autoload/event_bus.gd"],
		["ContentDB", "res://autoload/content_db.gd"],
		["Economy", "res://autoload/economy.gd"],
		["Game", "res://autoload/game.gd"],
	]
	for entry in autoloads:
		if not root.has_node(entry[0]):
			var node: Node = (load(entry[1]) as GDScript).new()
			node.name = entry[0]
			root.add_child(node)
	game = root.get_node("Game")
	content = root.get_node("ContentDB")


func _run() -> void:
	await physics_frame
	_connect_bus()
	await _test_agata_wind_steady()
	await _test_remolino_center_pull()
	await _test_teledirigida_target()
	await _test_rebote_side_refund()
	await _test_trampa_any_speed()
	await _test_espejo_copy()
	print("MARBLES W3 FAIL" if failed else "MARBLES W3 OK")
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	print("MARBLES W3 FAIL: " + label)


func _connect_bus() -> void:
	var bus := root.get_node("EventBus")
	bus.embed.connect(func(index, value): embeds.append([index, value]))
	bus.refund.connect(func(): refunds += 1)
	bus.throw_ended.connect(func(outcome): outcomes.append(outcome))


# --- (a) Agata: steady in wind ----------------------------------------------


func _test_agata_wind_steady() -> void:
	var agata: MarbleDef = content.marble_def("agata")
	_check(agata != null and agata.effects.has(&"wind_steady"),
			"agata should carry the wind_steady effect")
	game.start_run()
	var board := _open_board_with(&"ventoso")
	await physics_frame
	_check(is_equal_approx(board.wind_steady_scale(agata), 0.0),
			"agata must feel no wind, got %s" % str(board.wind_steady_scale(agata)))
	var common: MarbleDef = content.marble_def("common")
	_check(is_equal_approx(board.wind_steady_scale(common), 1.0),
			"the common must feel the full wind")
	# Physics drift: same launch, the agata drifts less sideways than the
	# common on a windy board.
	var common_drift := await _drift_with_def(common)
	var agata_drift := await _drift_with_def(agata)
	_check(agata_drift < common_drift,
			"agata should drift less than the common in wind (%s vs %s)"
			% [str(agata_drift), str(common_drift)])
	_clear_marbles(board)
	board.queue_free()
	await physics_frame


## Launch with `def` on a windy board (ventoso): the run inventory carries
## exactly that def, so _launch selects it.
func _drift_with_def(def: MarbleDef) -> float:
	game.start_run()
	game.inventory.clear()
	game.inventory.append(def)
	var board := _open_board_with(&"ventoso")
	await physics_frame
	board._launch(0.0, 20.0)
	var drift := 99999.0
	if not board.active_marbles.is_empty():
		var marble: RigidBody3D = board.active_marbles[0]
		# Friction off: the wind force is the only lateral actor, so the
		# drift comparison is deterministic.
		marble.physics_material_override.friction = 0.0
		var start_x: float = board.board.to_local(marble.global_position).x
		for i in 40:
			await physics_frame
			if not is_instance_valid(marble):
				break
		if is_instance_valid(marble):
			drift = absf(board.board.to_local(marble.global_position).x - start_x)
	_clear_marbles(board)
	board.queue_free()
	await physics_frame
	return drift


# --- (b) Remolino: curves toward the board center ---------------------------


func _test_remolino_center_pull() -> void:
	var remolino: MarbleDef = content.marble_def("remolino")
	_check(remolino != null and remolino.effects.has(&"center_pull"),
			"remolino should carry the center_pull effect")
	game.start_run()
	var board := _open_board()
	await physics_frame
	board.launched_def = remolino
	# The force points toward the board's center line and vanishes there.
	var marble := _flying_marble(board, Vector3(0.6, 0.0, 0.0))
	var pull: Vector3 = board.marble_force(marble, Vector3(0.6, 0.0, 0.0))
	_check(pull.x < 0.0, "a marble right of center should be pulled left, got %s" % str(pull))
	var centered := _flying_marble(board, Vector3(0.0, 0.0, 0.0))
	var none: Vector3 = board.marble_force(centered, Vector3(0.0, 0.0, 0.0))
	_check(is_equal_approx(none.x, 0.0),
			"a centered marble should feel no pull, got %s" % str(none))
	# A common feels nothing.
	var common_def: MarbleDef = content.marble_def("common")
	board.launched_def = common_def
	var common_marble := _flying_marble(board, Vector3(0.6, 0.0, 0.0))
	var common_pull: Vector3 = board.marble_force(common_marble, Vector3(0.6, 0.0, 0.0))
	_check(common_pull.length() < 0.001, "the common must feel no center pull")
	_clear_marbles(board)
	board.queue_free()
	await physics_frame


## A frozen marble standing at `local`, so the force math can be probed.
func _flying_marble(board: Node3D, local: Vector3) -> RigidBody3D:
	var marble := RigidBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	marble.add_child(shape)
	marble.freeze = true
	board.board.add_child(marble)
	marble.global_position = board.board.to_global(local)
	board.active_marbles.append(marble)
	return marble


# --- (c) Teledirigida: aim-picked target, gentle homing ---------------------


func _test_teledirigida_target() -> void:
	var teledi: MarbleDef = content.marble_def("teledirigida")
	_check(teledi != null and teledi.effects.has(&"homing"),
			"teledirigida should carry the homing effect")
	game.start_run()
	game.inventory.clear()
	game.inventory.append(teledi)
	var board := _open_board()
	await physics_frame
	# Aim at a column: the target is the nearest free hole to that aim line.
	var aim_x: float = board.holes[2].pos.x
	board.aim_x = aim_x
	board._launch(0.0, 20.0)
	_check(board.homing_target != null and not board.homing_target.is_empty(),
			"the launch should pick a homing target")
	if board.homing_target != null and not board.homing_target.is_empty():
		var best_dist := INF
		for hole in board.holes:
			if hole.occupied or hole.covered or hole.phase_hidden:
				continue
			best_dist = minf(best_dist, absf(hole.pos.x - aim_x))
		_check(is_equal_approx(absf(board.homing_target.pos.x - aim_x), best_dist),
				"the target should be the free hole nearest to the aim")
		_check(board.hud.last_flash.contains("Teledirigida"),
				"the HUD should announce the homing target, got '%s'"
				% board.hud.last_flash)
		# The steering force points at the target.
		var marble: RigidBody3D = board.active_marbles[0]
		var local: Vector3 = board.board.to_local(marble.global_position)
		var steer: Vector3 = board.marble_force(marble, local)
		var to_target: Vector3 = board.homing_target.pos - local
		_check(steer.normalized().dot(to_target.normalized()) > 0.9,
				"the homing force should point at the target, got %s vs %s"
				% [str(steer), str(to_target)])
	_clear_marbles(board)
	board.queue_free()
	await physics_frame
	# A common launch picks no target.
	game.start_run()
	var plain := _open_board()
	await physics_frame
	plain.launched_def = content.marble_def("common")
	plain._launch(0.0, 20.0)
	_check(plain.homing_target == null or plain.homing_target.is_empty(),
			"a common launch must not pick a homing target")
	_clear_marbles(plain)
	plain.queue_free()
	await physics_frame


# --- (d) Rebote: side exits refund ------------------------------------------


func _test_rebote_side_refund() -> void:
	game.start_run()
	game.inventory.clear()
	game.inventory.append(content.marble_def("rebote"))
	var board := _open_board()
	await physics_frame
	board._launch(0.0, 20.0)
	await physics_frame
	var ammo_before: int = game.ammo.size()
	embeds.clear()
	refunds = 0
	outcomes.clear()
	if not board.active_marbles.is_empty():
		var marble: RigidBody3D = board.active_marbles[0]
		var out_x: float = board.board_def.width / 2.0 + board.rules.edge_margin + 0.5
		marble.global_position = board.board.to_global(Vector3(out_x, 0.09, 0.0))
		for i in 8:
			await physics_frame
			if not outcomes.is_empty():
				break
	_check(outcomes.has(&"refunded"),
			"a rebote side exit should refund, got %s" % str(outcomes))
	_check(refunds == 1, "the rebote refund should emit once, got %d" % refunds)
	_check(game.ammo.size() == ammo_before,
			"the refunded rebote must not spend the marble (%d -> %d)"
			% [ammo_before, game.ammo.size()])
	_clear_marbles(board)
	board.queue_free()
	await physics_frame
	# A common side exit still loses the marble.
	game.start_run()
	var plain := _open_board()
	await physics_frame
	plain._launch(0.0, 20.0)
	await physics_frame
	var plain_ammo: int = game.ammo.size()
	outcomes.clear()
	if not plain.active_marbles.is_empty():
		var plain_marble: RigidBody3D = plain.active_marbles[0]
		var out_x: float = plain.board_def.width / 2.0 + plain.rules.edge_margin + 0.5
		plain_marble.global_position = plain.board.to_global(Vector3(out_x, 0.09, 0.0))
		for i in 8:
			await physics_frame
			if not outcomes.is_empty():
				break
	_check(outcomes.has(&"off_board"),
			"a common side exit should still lose the marble, got %s" % str(outcomes))
	_check(game.ammo.size() == plain_ammo - 1,
			"the common side exit should spend the marble")
	_clear_marbles(plain)
	plain.queue_free()
	await physics_frame


# --- (e) Trampa: embeds any capture zone at any speed -----------------------


func _test_trampa_any_speed() -> void:
	game.start_run()
	var board := _open_board()
	await physics_frame
	board.launched_def = content.marble_def("trampa")
	board.wall_mult = 1.0
	board.wall_hits = 0
	var hole := _free_hole(board)
	# Far beyond the skip threshold: a normal marble would fly over.
	board._embed(_loose_marble(board), hole, 9999.0)
	_check(embeds.size() == 1, "trampa should embed at any speed, embeds=%s" % str(embeds))
	_clear_marbles(board)
	board.queue_free()
	await physics_frame


# --- (f) Espejo: copies the previous embed score, only > 0 ------------------


func _test_espejo_copy() -> void:
	game.start_run()
	var board := _open_board()
	await physics_frame
	# Throw one: a common embeds a 20 notch (wall-neutral).
	board.launched_def = content.marble_def("common")
	board.wall_mult = 1.0
	board.wall_hits = 0
	var hole20 := _free_hole_with_score(board, 20)
	board._embed(_loose_marble(board), hole20)
	_check(board.last_throw_score == 20,
			"the board should remember the embed score, got %d" % board.last_throw_score)
	# Throw two: the espejo embeds a 5 notch and scores the remembered 20.
	embeds.clear()
	var espejo: MarbleDef = content.marble_def("espejo")
	board.launched_def = espejo
	var hole5 := _free_hole_with_score(board, 5)
	board._embed(_loose_marble(board), hole5)
	_check(embeds.size() == 1 and int(embeds[0][1]) == 20,
			"espejo should copy the previous 20, got %s" % str(embeds))
	# After a zero-score throw the espejo scores its own notch.
	board.throw_score = 0
	board.last_throw_score = 0
	embeds.clear()
	board.launched_def = espejo
	var hole7 := _free_hole_with_score(board, 7)
	board._embed(_loose_marble(board), hole7)
	_check(embeds.size() == 1 and int(embeds[0][1]) == int(hole7.score),
			"an espejo after a 0 throw should score its own notch (%d), got %s"
			% [int(hole7.score), str(embeds)])
	_clear_marbles(board)
	board.queue_free()
	await physics_frame


# --- Helpers ----------------------------------------------------------------


func _open_board() -> Node3D:
	var board: Node3D = (load("res://scenes/board/board.tscn") as PackedScene).instantiate()
	root.add_child(board)
	return board


## Board with one bonificador (agata's wind test uses ventoso). The
## override must land before add_child: _ready builds the theme with it.
func _open_board_with(modifier_id: StringName) -> Node3D:
	var board: Node3D = (load("res://scenes/board/board.tscn") as PackedScene).instantiate()
	var mods: Array[BoardModifierDef] = [content.modifier_def(modifier_id)]
	board.modifier_override = mods
	root.add_child(board)
	return board


func _free_hole(board: Node3D) -> Dictionary:
	for hole in board.holes:
		if not hole.occupied and not hole.covered and not hole.phase_hidden:
			return hole
	return board.holes[0]


func _free_hole_with_score(board: Node3D, value: int) -> Dictionary:
	for hole in board.holes:
		if not hole.occupied and not hole.covered and int(hole.score) == value:
			return hole
	return _free_hole(board)


func _clear_marbles(board: Node3D) -> void:
	for marble in board.active_marbles.duplicate():
		if is_instance_valid(marble):
			marble.queue_free()
	board.active_marbles.clear()
	board.settle_times.clear()


## A marble on the board surface, ready to be handed to _embed.
func _loose_marble(board: Node3D) -> RigidBody3D:
	var marble := RigidBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	marble.add_child(shape)
	marble.freeze = true
	board.board.add_child(marble)
	marble.position = Vector3(0.0, 0.0, board.board_def.launch_z())
	return marble
