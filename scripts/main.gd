extends Node3D
## Chibolones - proof of concept (Godot 4.7)
## Traditional Guatemalan fair game: throw 5 marbles ("cincos") at a wooden
## board with numbered holes. Each marble that sinks into a hole scores the
## number painted on it; after 5 throws the total is summed.
##
## Controls (all directions match what you see on screen):
##   Left/Right arrows (or A/D): pick the horizontal launch position.
##   Space (1st): start the shot tilt guide; the line leans left/right
##     automatically and the captured angle sets the sideways component.
##   Space (2nd): lock the tilt and start the power bar. It fills up and
##     reverses automatically; press Space again to lock it and throw.
##   R: restart the round.
##
## The board tilts toward the player: every marble either sinks into a hole
## or rolls back off the player's edge, which returns the throw (it is not
## consumed). Marbles that leave through the back or the sides lose the shot.
##
## Future note: this scene is intentionally kept as one self-contained file so
## the scoring table and marble flow can later be extracted and rewritten as
## roguelike mechanics (modifiers, jokers, score multipliers) the way Balatro
## layers rules on top of a base poker hand.

# --- Board layout ---
const COLS := 5
const ROWS := 4
const HOLE_RADIUS := 0.18
const SPACING_X := 0.5
const FIRST_ROW_Z := -0.4
const SPACING_Z := 0.8
const BOARD_W := 3.0
const BOARD_L := 5.0
const BOARD_THICK := 0.12
const TILT_DEG := 6.0

# --- Marbles & shooting ---
const MARBLE_RADIUS := 0.09
const CATCH_RADIUS := 0.14
const SKIP_SPEED := 5.5      # faster than this, the marble skips over holes
const LAUNCH_Z := -2.0
const MIN_SPEED := 2.2
const MAX_SPEED := 9.0
const POWER_SPEED := 110.0   # percent per second of the oscillating bar
const SHOT_TILT_MAX_DEG := 25.0  # the guide leans this far to each side
const SHOT_TILT_SPEED := 120.0   # degrees per second of the oscillating guide
const EDGE_MARGIN := 0.25        # past an edge plus this margin = off board
const SHOT_COUNT := 5

# --- Settling ---
const SETTLE_SPEED := 0.15
const SETTLE_TIME := 1.2
const FLIGHT_TIMEOUT := 7.0

# Scores from the row nearest the player to the farthest row.
const ROW_SCORES := [10, 20, 30, 50]
const MARBLE_COLORS := [Color(0.275, 0.694, 0.882), Color(0.882, 0.357, 0.392), Color(0.478, 0.78, 0.31), Color(0.949, 0.757, 0.306), Color(0.608, 0.365, 0.898)]
const AIM_LIMIT := BOARD_W / 2.0 - 0.2


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


enum State { AIM, TILT, POWER, FLIGHT, GAME_OVER }

var state: State = State.AIM
var shots_left := SHOT_COUNT
var total_score := 0
var aim_x := 0.0
var shot_tilt := 0.0
var tilt_dir := 1.0
var power := 0.0
var power_dir := 1.0
var pending_result := ""   # resolution message flashed when the volley ends
var launch_timer := 0.0
var msg_tween: Tween

var board: Node3D
var launch_marker: MeshInstance3D
var shot_guide: Node3D
var holes: Array[Dictionary] = []          # {pos: Vector3, score: int}
var active_marbles: Array[RigidBody3D] = []
var settle_times := {}                     # marble -> seconds under slow speed

var label_shots: Label
var label_score: Label
var label_msg: Label
var power_bar: PowerBar
var end_overlay: ColorRect
var label_final: Label


func _ready() -> void:
	_build_environment()
	_build_board()
	_build_ui()
	_update_hud()
	_flash_message("Movi con <- -> y apreta ESPACIO para elegir la inclinacion")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("shoot"):
		match state:
			State.AIM:
				if shots_left > 0:
					state = State.TILT
					shot_tilt = 0.0
					tilt_dir = 1.0
					shot_guide.visible = true
					_flash_message("Apreta ESPACIO para fijar esta inclinacion")
			State.TILT:
				state = State.POWER
				power = 0.0
				power_dir = 1.0
				power_bar.visible = true
				_flash_message("Apreta ESPACIO para disparar con esta potencia")
			State.POWER:
				power_bar.visible = false
				shot_guide.visible = false
				_launch(shot_tilt, power)
			_:
				pass
	elif event.is_action_pressed("restart"):
		get_tree().reload_current_scene()


func _physics_process(delta: float) -> void:
	match state:
		State.AIM:
			var move := 0.0
			if Input.is_action_pressed("move_left"):
				move -= 1.0
			if Input.is_action_pressed("move_right"):
				move += 1.0
			# Screen directions: the camera looks down +Z, so world +X shows on
			# the player's LEFT. Invert the sign so each key moves the marker
			# the way its arrow points on screen.
			aim_x = clampf(aim_x - move * 1.2 * delta, -AIM_LIMIT, AIM_LIMIT)
			launch_marker.position.x = aim_x
			shot_guide.position.x = aim_x
		State.TILT:
			shot_tilt += tilt_dir * SHOT_TILT_SPEED * delta
			if shot_tilt >= SHOT_TILT_MAX_DEG:
				shot_tilt = SHOT_TILT_MAX_DEG
				tilt_dir = -1.0
			elif shot_tilt <= -SHOT_TILT_MAX_DEG:
				shot_tilt = -SHOT_TILT_MAX_DEG
				tilt_dir = 1.0
			shot_guide.rotation.y = deg_to_rad(shot_tilt)
		State.POWER:
			power += power_dir * POWER_SPEED * delta
			if power >= 100.0:
				power = 100.0
				power_dir = -1.0
			elif power <= 0.0:
				power = 0.0
				power_dir = 1.0
			power_bar.set_power(power)
		State.FLIGHT:
			launch_timer += delta
			_update_flight(delta)


# --- Shooting ----------------------------------------------------------------


func _launch(tilt_deg: float, power_value: float) -> void:
	var shot_index := SHOT_COUNT - shots_left
	var marble := _make_marble(shot_index)
	# Marble is a child of the tilted board so local coordinates stay handy.
	# Spawn clear of the surface: a marble born intersecting the board can
	# escape through it in the physics engine.
	marble.position = Vector3(aim_x, MARBLE_RADIUS + 0.05, LAUNCH_Z)
	board.add_child(marble)
	var tilt_rad := deg_to_rad(tilt_deg)
	# Direction includes the locked shot tilt: positive tilts toward the
	# player's left on screen, exactly like the guide line showed.
	var dir := (board.global_transform.basis * Vector3(sin(tilt_rad), 0.0, 1.0)).normalized()
	var speed := lerpf(MIN_SPEED, MAX_SPEED, power_value / 100.0)
	marble.apply_central_impulse(dir * speed)
	active_marbles.append(marble)
	settle_times.clear()
	pending_result = ""
	launch_timer = 0.0
	launch_marker.visible = false
	shots_left -= 1
	state = State.FLIGHT
	_update_hud()


func _update_flight(delta: float) -> void:
	for marble in active_marbles.duplicate():
		if not is_instance_valid(marble):
			active_marbles.erase(marble)
			continue
		var speed: float = marble.linear_velocity.length()
		var local: Vector3 = board.to_local(marble.global_position)
		# Off-board exits. Only the player-side edge forgives: the throw is
		# returned so it can be thrown again. Back and side exits lose it.
		if local.z < -BOARD_L / 2.0 - EDGE_MARGIN:
			_discard_marble(marble)
			pending_result = "Salio por el borde del jugador: se puede volver a tirar"
			continue
		if local.z > BOARD_L / 2.0 + EDGE_MARGIN \
				or absf(local.x) > BOARD_W / 2.0 + EDGE_MARGIN \
				or local.y < -0.05:
			_discard_marble(marble)
			pending_result = "La canica salio del tablero: 0 puntos"
			continue
		# A fast marble hops over the holes, a slow one falls in when its
		# center crosses the capture circle.
		if speed >= SKIP_SPEED:
			continue
		# Only capture when the marble is actually rolling on the surface: a
		# body that fell through the board must never score.
		if local.y > MARBLE_RADIUS + 0.25:
			continue
		var reach: float = CATCH_RADIUS + speed * delta * 0.5
		for hole in holes:
			var d := Vector2(local.x - hole.pos.x, local.z - hole.pos.z).length()
			if d <= reach:
				_sink(marble, hole.score)
				break
		if is_instance_valid(marble) and not marble.freeze:
			if speed < SETTLE_SPEED:
				settle_times[marble] = float(settle_times.get(marble, 0.0)) + delta
			else:
				settle_times[marble] = 0.0
			if float(settle_times.get(marble, 0.0)) >= SETTLE_TIME:
				# Marble came to rest on the board: 0 points.
				marble.freeze = true
				active_marbles.erase(marble)
				pending_result = "La canica se quedo quieta: 0 puntos"
	# End the volley once every marble stopped, sank, or the timeout hit.
	if active_marbles.is_empty() or launch_timer >= FLIGHT_TIMEOUT:
		if launch_timer >= FLIGHT_TIMEOUT and not active_marbles.is_empty():
			# Timed out: the throw is lost, clean the leftovers up.
			for marble in active_marbles:
				if is_instance_valid(marble):
					marble.queue_free()
			active_marbles.clear()
		if shots_left > 0:
			state = State.AIM
			launch_marker.visible = true
			if pending_result != "":
				# Resolution messages would otherwise be overwritten by the
				# next-throw prompt in the same frame, so flash them here.
				_flash_message(pending_result)
				pending_result = ""
			else:
				_flash_message("Tiro %d de %d" % [SHOT_COUNT - shots_left + 1, SHOT_COUNT])
		else:
			_game_over()


func _discard_marble(marble: RigidBody3D) -> void:
	active_marbles.erase(marble)
	settle_times.erase(marble)
	marble.queue_free()


func _sink(marble: RigidBody3D, score: int) -> void:
	active_marbles.erase(marble)
	settle_times.erase(marble)
	marble.freeze = true
	marble.collision_layer = 0
	marble.collision_mask = 0
	total_score += score
	_update_hud()
	pending_result = "En agujero de %d: +%d" % [score, score]
	var tween := create_tween()
	tween.tween_property(marble, "position:y", marble.position.y - 0.5, 0.35) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(marble.queue_free)


func _game_over() -> void:
	state = State.GAME_OVER
	label_final.text = "Puntaje total: %d de %d posibles" % [total_score, SHOT_COUNT * ROW_SCORES[ROWS - 1]]
	end_overlay.visible = true
	_flash_message("Fin de la ronda")


# --- Construction ------------------------------------------------------------


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.shadow_enabled = true
	add_child(sun)

	var cam := Camera3D.new()
	add_child(cam)
	cam.look_at_from_position(Vector3(0, 3.5, -4.8), Vector3(0, -0.2, 0.9), Vector3.UP)


func _build_board() -> void:
	board = Node3D.new()
	board.name = "Board"
	add_child(board)
	# Negative X rotation lowers the player-side (-Z) end: marbles always
	# roll back downhill toward the player, so none can rest trapped in the
	# middle of the board without reaching a hole or the forgiving edge.
	board.rotation_degrees.x = -TILT_DEG

	var body := StaticBody3D.new()
	body.name = "BoardBody"
	board.add_child(body)

	var box := BoxShape3D.new()
	box.size = Vector3(BOARD_W, BOARD_THICK, BOARD_L)
	var collider := CollisionShape3D.new()
	collider.shape = box
	# Align the collider's top face with the visible surface (y = 0).
	collider.position.y = -BOARD_THICK / 2.0
	body.add_child(collider)

	var surface := MeshInstance3D.new()
	var board_mesh := BoxMesh.new()
	board_mesh.size = box.size
	surface.mesh = board_mesh
	surface.position.y = -BOARD_THICK / 2.0
	surface.material_override = _wood_material(Color(0.52, 0.33, 0.16))
	body.add_child(surface)

	# No walls: the board is tilted toward the player, so every marble either
	# sinks into a hole or rolls back off the player's edge (throw returned).
	# Back and side edges lose the throw instead of trapping the marble.

	for row in ROWS:
		for col in COLS:
			var pos := Vector3(
				-SPACING_X * (COLS - 1) / 2.0 + col * SPACING_X,
				0.0,
				FIRST_ROW_Z + row * SPACING_Z
			)
			_add_hole(pos, ROW_SCORES[row])

	# Aim marker: a slim strip that slides sideways while aiming.
	launch_marker = MeshInstance3D.new()
	var marker_mesh := BoxMesh.new()
	marker_mesh.size = Vector3(0.06, 0.005, 0.3)
	launch_marker.mesh = marker_mesh
	var marker_mat := StandardMaterial3D.new()
	marker_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	marker_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker_mat.albedo_color = Color(1, 1, 1, 0.55)
	launch_marker.material_override = marker_mat
	launch_marker.position = Vector3(0, 0.012, LAUNCH_Z)
	board.add_child(launch_marker)

	# Shot tilt guide: a slim line pivoting at the launch point. It leans
	# left/right while picking the inclination and freezes at the locked
	# angle while the power bar runs.
	shot_guide = Node3D.new()
	shot_guide.position = Vector3(0, 0.014, LAUNCH_Z)
	var guide_stick := MeshInstance3D.new()
	var guide_mesh := BoxMesh.new()
	guide_mesh.size = Vector3(0.05, 0.004, 2.0)
	guide_stick.mesh = guide_mesh
	guide_stick.position = Vector3(0, 0, 1.0)  # extends forward from the pivot
	var guide_mat := StandardMaterial3D.new()
	guide_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	guide_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	guide_mat.albedo_color = Color(0.35, 0.9, 1.0, 0.6)
	guide_stick.material_override = guide_mat
	shot_guide.add_child(guide_stick)
	shot_guide.visible = false
	board.add_child(shot_guide)


func _add_hole(pos: Vector3, score: int) -> void:
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = HOLE_RADIUS
	cyl.bottom_radius = HOLE_RADIUS
	cyl.height = 0.012
	cyl.radial_segments = 24
	disc.mesh = cyl
	disc.position = pos + Vector3(0, 0.008, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.05, 0.04, 0.03)
	mat.roughness = 1.0
	disc.material_override = mat
	board.add_child(disc)

	var label := Label3D.new()
	label.text = str(score)
	label.font_size = 96
	label.pixel_size = 0.002
	label.modulate = Color(0.95, 0.9, 0.75)
	label.position = pos + Vector3(0, 0.02, 0)
	# Lay the number flat, readable from the player's camera: the -90 X
	# lay-down alone points the text top toward the player (reads upside
	# down on screen); the 180 Y turn points it away so it reads normally.
	label.rotation_degrees = Vector3(-90, 180, 0)
	board.add_child(label)

	holes.append({"pos": pos, "score": score})


func _make_marble(shot_index: int) -> RigidBody3D:
	var marble := RigidBody3D.new()
	marble.mass = 1.0
	var mat := PhysicsMaterial.new()
	mat.bounce = 0.2
	mat.friction = 0.6
	marble.physics_material_override = mat

	var collider := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = MARBLE_RADIUS
	collider.shape = shape
	marble.add_child(collider)

	var mesh_i := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = MARBLE_RADIUS
	mesh.height = MARBLE_RADIUS * 2.0
	mesh_i.mesh = mesh
	var mat3d := StandardMaterial3D.new()
	mat3d.albedo_color = MARBLE_COLORS[shot_index % MARBLE_COLORS.size()]
	mat3d.metallic = 0.1
	mat3d.roughness = 0.25
	mesh_i.material_override = mat3d
	marble.add_child(mesh_i)
	return marble


func _wood_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	return mat


# --- UI ----------------------------------------------------------------------


func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	label_shots = Label.new()
	label_shots.position = Vector2(16, 10)
	label_shots.add_theme_font_size_override("font_size", 24)
	canvas.add_child(label_shots)

	label_score = Label.new()
	label_score.position = Vector2(16, 44)
	label_score.add_theme_font_size_override("font_size", 24)
	canvas.add_child(label_score)

	label_msg = Label.new()
	label_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_msg.anchor_left = 0.0
	label_msg.anchor_right = 1.0
	label_msg.anchor_top = 1.0
	label_msg.anchor_bottom = 1.0
	label_msg.offset_top = -140
	label_msg.offset_bottom = -100
	label_msg.add_theme_font_size_override("font_size", 26)
	canvas.add_child(label_msg)

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
	canvas.add_child(power_bar)

	end_overlay = ColorRect.new()
	end_overlay.color = Color(0, 0, 0, 0.6)
	end_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	end_overlay.visible = false
	canvas.add_child(end_overlay)

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


func _make_label(font_size: int, position: Vector2) -> Label:
	var label := Label.new()
	label.position = position
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _update_hud() -> void:
	label_shots.text = "Canicas restantes: %d / %d" % [shots_left, SHOT_COUNT]
	label_score.text = "Puntaje: %d" % total_score


func _flash_message(text: String) -> void:
	if msg_tween and msg_tween.is_valid():
		msg_tween.kill()
	label_msg.text = text
	label_msg.modulate.a = 1.0
	msg_tween = create_tween()
	msg_tween.tween_interval(2.0)
	msg_tween.tween_property(label_msg, "modulate:a", 0.0, 1.2)
