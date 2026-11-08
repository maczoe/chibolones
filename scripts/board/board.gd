extends Node3D
## Board scene: one chibolones board built from a BoardDef, with the POC
## throw flow (aim -> tilt -> power -> flight) and physics capture.
## Presentation and physics only: the score lives in a ScoreEngine child,
## cross-cutting events go through the EventBus, and run flow belongs to
## the Game autoload. Behavior matches the POC one to one.

const MarbleFactory := preload("res://scripts/board/marble_factory.gd")
const ScoreEngineScript := preload("res://scripts/scoring/score_engine.gd")
const HudScript := preload("res://scripts/board/hud.gd")

enum ThrowState { AIM, TILT, POWER, FLIGHT, ROUND_OVER, CAMERA }

var board_def: BoardDef
var rules: ShootingRules
var marble_def: MarbleDef

var state: ThrowState = ThrowState.AIM
var shots_left := 0
var aim_x := 0.0
var aim_limit := 0.0
var shot_tilt := 0.0
var tilt_max_left := 0.0    # per-side aim limits, so the guide cannot point
var tilt_max_right := 0.0   # past the side walls from this launch spot
var power := 0.0
var power_dir := 1.0
var pending_result := ""   # resolution message flashed when the volley ends
var launch_timer := 0.0
var throw_index := 0

var board: Node3D
var score_engine: ScoreEngine
var hud: CanvasLayer
var launch_marker: MeshInstance3D
var shot_guide: Node3D
var skirt: MeshInstance3D
var cam: Camera3D
var cam_look_target: Vector3
var cam_orbit_radius := 8.0
var cam_azimuth_deg := 0.0   # 0 = in front of the player edge
var cam_elev_deg := 0.0      # elevation over the surface plane
var cam_default_elev_deg := 0.0
var holes: Array[Dictionary] = []          # {pos, score, occupied}
var active_marbles: Array[RigidBody3D] = []
var settle_times := {}                     # marble -> seconds under slow speed


func _ready() -> void:
	board_def = ContentDB.board_def(Game.board_index)
	rules = ContentDB.rules()
	marble_def = ContentDB.marble_def("common")
	shots_left = rules.shots_per_board
	aim_limit = board_def.width / 2.0 - board_def.aim_limit_margin
	_build_environment()
	_build_board()
	score_engine = ScoreEngineScript.new()
	add_child(score_engine)
	hud = HudScript.new()
	add_child(hud)
	score_engine.score_changed.connect(hud.set_score)
	add_child(preload("res://scripts/board/juice.gd").new())
	hud.set_shots(shots_left, rules.shots_per_board)
	hud.flash("Movi con <- -> y apreta ESPACIO para elegir la posicion")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		Game.restart_board()
		return
	if event.is_action_pressed("camera_mode"):
		# Camera mode: free the view to read the whole board; only from AIM
		# so a throw flow is never interrupted mid-decision.
		if state == ThrowState.AIM:
			state = ThrowState.CAMERA
			launch_marker.visible = false
			hud.flash("Modo camara: flechas recorren el tablero, Z para volver")
		elif state == ThrowState.CAMERA:
			# Keep the camera where the player left it: the throw can be
			# made from any angle they chose. Restart resets the board.
			state = ThrowState.AIM
			launch_marker.visible = true
			hud.flash("Movi con <- -> y apreta ESPACIO para elegir la posicion")
		return
	if event.is_action_pressed("shoot"):
		match state:
			ThrowState.AIM:
				if shots_left > 0:
					state = ThrowState.TILT
					shot_tilt = 0.0
					_update_tilt_limits()
					shot_guide.visible = true
					hud.flash("Inclina con <- -> y apreta ESPACIO para fijar")
			ThrowState.TILT:
				state = ThrowState.POWER
				power = 0.0
				power_dir = 1.0
				hud.set_power_visible(true)
				hud.flash("Apreta ESPACIO para disparar con esta potencia")
			ThrowState.POWER:
				hud.set_power_visible(false)
				shot_guide.visible = false
				_launch(shot_tilt, power)
			_:
				pass


func _physics_process(delta: float) -> void:
	match state:
		ThrowState.AIM:
			var move := 0.0
			if Input.is_action_pressed("move_left"):
				move -= 1.0
			if Input.is_action_pressed("move_right"):
				move += 1.0
			# Screen directions: the camera looks down +Z, so world +X shows on
			# the player's LEFT. Invert the sign so each key moves the marker
			# the way its arrow points on screen.
			aim_x = clampf(aim_x - move * rules.aim_speed * delta, -aim_limit, aim_limit)
			launch_marker.position.x = aim_x
			shot_guide.position.x = aim_x
		ThrowState.TILT:
			var turn := 0.0
			if Input.is_action_pressed("move_left"):
				turn -= 1.0
			if Input.is_action_pressed("move_right"):
				turn += 1.0
			# Screen directions: the camera looks down +Z, so world +X shows on
			# the player's LEFT. Invert the sign so each arrow leans the guide
			# the way it points on screen, clamped so it never aims off-board.
			shot_tilt = clampf(shot_tilt - turn * rules.tilt_speed * delta,
					-tilt_max_left, tilt_max_right)
			shot_guide.rotation.y = deg_to_rad(shot_tilt)
		ThrowState.POWER:
			power += power_dir * rules.power_speed * delta
			if power >= 100.0:
				power = 100.0
				power_dir = -1.0
			elif power <= 0.0:
				power = 0.0
				power_dir = 1.0
			hud.set_power(power)
		ThrowState.FLIGHT:
			launch_timer += delta
			_update_flight(delta)
		ThrowState.CAMERA:
			# Orbit view: horizontal arrows circle the board center (see the
			# side walls), up/down raise or lower the view. Elevation is
			# clamped so the camera never crosses the surface plane: the
			# board can never be seen at more than cam_max_elev from a
			# vertical, i.e. the view can't flip past 90 degrees.
			var orbit := 0.0
			if Input.is_action_pressed("move_left"):
				orbit += 1.0
			if Input.is_action_pressed("move_right"):
				orbit -= 1.0
			var lift := 0.0
			if Input.is_action_pressed("move_up"):
				lift += 1.0
			if Input.is_action_pressed("move_down"):
				lift -= 1.0
			cam_azimuth_deg = clampf(cam_azimuth_deg + orbit * rules.cam_orbit_speed * delta,
					-rules.cam_azimuth_limit_deg, rules.cam_azimuth_limit_deg)
			cam_elev_deg = clampf(cam_elev_deg + lift * rules.cam_orbit_speed * delta,
					rules.cam_min_elev_deg, rules.cam_max_elev_deg)
			_apply_camera()
		_:
			pass


func _apply_camera() -> void:
	var horiz := cam_orbit_radius * cos(deg_to_rad(cam_elev_deg))
	cam.position = cam_look_target + Vector3(
			sin(deg_to_rad(cam_azimuth_deg)) * horiz,
			cam_orbit_radius * sin(deg_to_rad(cam_elev_deg)),
			-cos(deg_to_rad(cam_azimuth_deg)) * horiz)
	cam.look_at(cam_look_target, Vector3.UP)


# --- Shooting ----------------------------------------------------------------


func _update_tilt_limits() -> void:
	# The guide pivots at the launch spot; clamp each side so its far end
	# stays inside the walls even at the far edge of the board.
	var dist_to_far := board_def.length / 2.0 - board_def.launch_z()
	var side_margin := board_def.width / 2.0 - board_def.aim_limit_margin
	tilt_max_left = rad_to_deg(atan(maxf(0.0, side_margin + aim_x) / dist_to_far))
	tilt_max_right = rad_to_deg(atan(maxf(0.0, side_margin - aim_x) / dist_to_far))


func _launch(tilt_deg: float, power_value: float) -> void:
	var marble := MarbleFactory.make(marble_def, throw_index)
	throw_index += 1
	# Marble is a child of the tilted board so local coordinates stay handy.
	# Spawn clear of the surface: a marble born intersecting the board can
	# escape through it in the physics engine.
	marble.position = Vector3(aim_x, marble_def.radius + 0.05, board_def.launch_z())
	marble.body_entered.connect(_on_marble_body_entered.bind(marble))
	board.add_child(marble)
	var tilt_rad := deg_to_rad(tilt_deg)
	# Direction includes the locked shot tilt: positive tilts toward the
	# player's left on screen, exactly like the guide line showed.
	var dir := (board.global_transform.basis * Vector3(sin(tilt_rad), 0.0, 1.0)).normalized()
	var speed := lerpf(rules.min_speed, rules.max_speed, power_value / 100.0) \
			* marble_def.speed_mult
	marble.apply_central_impulse(dir * speed * marble.mass)
	active_marbles.append(marble)
	settle_times.clear()
	pending_result = ""
	launch_timer = 0.0
	launch_marker.visible = false
	shots_left -= 1
	state = ThrowState.FLIGHT
	hud.set_shots(shots_left, rules.shots_per_board)
	EventBus.throw_started.emit(marble_def.id)


func _update_flight(delta: float) -> void:
	for marble in active_marbles.duplicate():
		if not is_instance_valid(marble):
			active_marbles.erase(marble)
			continue
		var speed: float = marble.linear_velocity.length()
		var local: Vector3 = board.to_local(marble.global_position)
		# Off-board exits. Only the player-side edge forgives: the throw is
		# returned so it can be thrown again. Back and side exits lose it.
		if local.z < -board_def.length / 2.0 - rules.edge_margin:
			_discard_marble(marble)
			pending_result = "Salio por el borde del jugador: se puede volver a tirar"
			EventBus.refund.emit()
			EventBus.throw_ended.emit(&"refunded")
			continue
		if local.z > board_def.length / 2.0 + rules.edge_margin \
				or absf(local.x) > board_def.width / 2.0 + rules.edge_margin \
				or local.y < -0.05:
			_discard_marble(marble)
			pending_result = "La canica salio del tablero: 0 puntos"
			EventBus.throw_ended.emit(&"off_board")
			continue
		# A fast marble hops over the notches, a slow one embeds itself when
		# its center crosses the capture circle.
		if speed >= board_def.skip_speed:
			continue
		# Only capture when the marble is actually rolling on the surface: a
		# body that fell through the board must never score.
		if local.y > marble_def.radius + 0.25:
			continue
		var reach: float = board_def.capture_radius
		for hole in holes:
			# An occupied notch already holds an embedded marble: shots can
			# only bounce off it, never fall into the same spot.
			if hole.occupied:
				continue
			var d := Vector2(local.x - hole.pos.x, local.z - hole.pos.z).length()
			if d <= reach:
				_embed(marble, hole)
				break
		if is_instance_valid(marble) and not marble.freeze:
			if speed < rules.settle_speed:
				settle_times[marble] = float(settle_times.get(marble, 0.0)) + delta
			else:
				settle_times[marble] = 0.0
			if float(settle_times.get(marble, 0.0)) >= rules.settle_time:
				# Marble came to rest on the board: 0 points.
				marble.freeze = true
				active_marbles.erase(marble)
				settle_times.erase(marble)
				pending_result = "La canica se quedo quieta: 0 puntos"
				EventBus.throw_ended.emit(&"settled")
	# End the volley once every marble stopped, sank, or the timeout hit.
	if active_marbles.is_empty() or launch_timer >= rules.flight_timeout:
		if launch_timer >= rules.flight_timeout and not active_marbles.is_empty():
			# Timed out: the throw is lost, clean the leftovers up.
			for marble in active_marbles:
				if is_instance_valid(marble):
					marble.queue_free()
			active_marbles.clear()
			EventBus.throw_ended.emit(&"timed_out")
		if shots_left > 0:
			state = ThrowState.AIM
			launch_marker.visible = true
			if pending_result != "":
				# Resolution messages would otherwise be overwritten by the
				# next-throw prompt in the same frame, so flash them here.
				hud.flash(pending_result)
				pending_result = ""
			else:
				hud.flash("Tiro %d de %d" % [rules.shots_per_board - shots_left + 1, rules.shots_per_board])
		else:
			_round_over()


func _discard_marble(marble: RigidBody3D) -> void:
	active_marbles.erase(marble)
	settle_times.erase(marble)
	marble.queue_free()


func _embed(marble: RigidBody3D, hole: Dictionary) -> void:
	active_marbles.erase(marble)
	settle_times.erase(marble)
	hole.occupied = true
	# Like the carved notches of the real board: the marble stays stuck with
	# its center at surface level, so half its circumference is exposed. It
	# freezes in place (immovable) but keeps colliding, so later shots
	# bounce off it instead of falling into the same notch.
	marble.freeze = true
	marble.position = Vector3(hole.pos.x, 0.0, hole.pos.z)
	marble.add_to_group("embedded")
	marble.set_meta("notch_index", hole.index)
	pending_result = "Incrustada en muesca de %d: +%d" % [hole.score, hole.score]
	EventBus.embed.emit(hole.index, hole.score)
	EventBus.throw_ended.emit(&"embedded")


func _round_over() -> void:
	state = ThrowState.ROUND_OVER
	var possible: int = rules.shots_per_board * board_def.row_scores[board_def.rows - 1]
	hud.show_game_over(score_engine.total, possible)
	EventBus.board_ended.emit(score_engine.total)


func _on_marble_body_entered(other: Node, marble: RigidBody3D) -> void:
	# Physics contact -> domain events. Impact speed is the marble speed at
	# contact time; M2 modifiers react to these.
	var impact := marble.linear_velocity.length()
	if other.is_in_group("walls"):
		EventBus.wall_hit.emit(other.get_meta("side"), impact)
	elif other.is_in_group("embedded"):
		EventBus.embedded_marble_hit.emit(other.get_meta("notch_index"), impact)


# --- Construction ------------------------------------------------------------


func _build_environment() -> void:
	# Circus void: dark violet, themed ambient, dim key light and a tinted
	# spotlight over the cabinet. Every color comes from the BoardDef so a
	# board theme can relight the whole scene.
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("14102a")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("3a1f6e")
	env.ambient_light_energy = board_def.ambient_energy
	env.fog_enabled = true
	env.fog_light_color = Color("2e1b58")
	env.fog_density = 0.012
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-55, -35, 0)
	key.light_color = Color(0.8, 0.85, 1.0)
	key.light_energy = 0.35
	key.shadow_enabled = true
	add_child(key)

	var spot := OmniLight3D.new()
	spot.position = Vector3(0, 4.5, 0.5)
	spot.light_color = board_def.light_color
	spot.light_energy = 2.3
	spot.omni_range = 13.0
	add_child(spot)

	_build_room()
	_build_floor()

	cam = Camera3D.new()
	add_child(cam)
	var length := board_def.length
	# Cenital-leaning default: high and steep enough that even the far row's
	# numbers read at a glance, while keeping some diagonal drama. The orbit
	# parameters derive from the framing, so camera mode starts here.
	cam_look_target = Vector3(0, -0.2, rules.cam_look_z)
	var back := length / 2.0 - rules.cam_back + rules.cam_look_z
	var up := rules.cam_height - cam_look_target.y
	cam_orbit_radius = sqrt(up * up + back * back)
	cam_default_elev_deg = rad_to_deg(atan2(up, back))
	cam_elev_deg = cam_default_elev_deg
	_apply_camera()


func _build_room() -> void:
	# Compact closed room: back wall plus both side walls share the
	# psychedelic shader, so orbiting the cabinet always shows the same
	# living void with no visible edges. The player side is open.
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/board/shaders/backdrop.gdshader")
	mat.set_shader_parameter("color_a", board_def.backdrop_color_a)
	mat.set_shader_parameter("color_b", board_def.backdrop_color_b)
	mat.set_shader_parameter("color_c", board_def.backdrop_color_c)
	mat.set_shader_parameter("speed", board_def.backdrop_speed)
	mat.set_shader_parameter("pattern_scale", board_def.backdrop_scale)
	var wall_h := 16.0
	var room_half := 14.0
	var back_z := board_def.length / 2.0 + 10.0
	var floor_y := -board_def.skirt_height - 0.1
	for def in [
		# [yaw degrees, position]
		[0.0, Vector3(0, floor_y + wall_h / 2.0, back_z)],                # back
		[90.0, Vector3(-room_half, floor_y + wall_h / 2.0, back_z - room_half)],  # left
		[-90.0, Vector3(room_half, floor_y + wall_h / 2.0, back_z - room_half)],  # right
	]:
		var wall := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.orientation = PlaneMesh.FACE_Z
		plane.size = Vector2(room_half * 2.0 + 8.0, wall_h)
		wall.mesh = plane
		wall.material_override = mat
		wall.rotation_degrees = Vector3(0, def[0], 0)
		wall.position = def[1]
		add_child(wall)


func _build_floor() -> void:
	# Circus checker floor below the cabinet, seen in perspective.
	var mesh_i := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(160, 160)
	mesh_i.mesh = plane
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/board/shaders/checker_floor.gdshader")
	mat.set_shader_parameter("col_a", board_def.floor_checker_a)
	mat.set_shader_parameter("col_b", board_def.floor_checker_b)
	mat.set_shader_parameter("checker_size", board_def.floor_checker_size)
	mesh_i.material_override = mat
	mesh_i.position = Vector3(0, -board_def.skirt_height - 0.1, 2.0)
	add_child(mesh_i)


func _build_board() -> void:
	board = Node3D.new()
	board.name = "Board"
	add_child(board)
	# Negative X rotation lowers the player-side (-Z) end: marbles always
	# roll back downhill toward the player, so none can rest trapped in the
	# middle of the board without reaching a notch or the forgiving edge.
	board.rotation_degrees.x = -board_def.tilt_deg

	var body := StaticBody3D.new()
	body.name = "BoardBody"
	board.add_child(body)

	var box := BoxShape3D.new()
	box.size = Vector3(board_def.width, board_def.thickness, board_def.length)
	var collider := CollisionShape3D.new()
	collider.shape = box
	# Align the collider's top face with the visible surface (y = 0).
	collider.position.y = -board_def.thickness / 2.0
	body.add_child(collider)

	var surface := MeshInstance3D.new()
	var board_mesh := BoxMesh.new()
	board_mesh.size = box.size
	surface.mesh = board_mesh
	surface.position.y = -board_def.thickness / 2.0
	surface.material_override = _paint_material(board_def.board_color)
	body.add_child(surface)

	# Closed cabinet (pinball box without legs): a skirt box drops from the
	# play surface to the floor, visual only, slightly larger than the board.
	skirt = MeshInstance3D.new()
	var skirt_mesh := BoxMesh.new()
	skirt_mesh.size = Vector3(board_def.width + 2.0 * board_def.wall_thickness,
			board_def.skirt_height, board_def.length + 2.0 * board_def.wall_thickness)
	skirt.mesh = skirt_mesh
	skirt.material_override = _paint_material(board_def.frame_color, 0.18)
	skirt.position.y = -board_def.skirt_height / 2.0 - board_def.thickness / 2.0
	body.add_child(skirt)

	# Side and back walls are back. They are low, so a marble with enough
	# inertia from a hard bounce can still hop over and leave the board: the
	# off-board rules stay in charge. Only the player-side edge stays open
	# and forgiving (throw returned).
	for side in [-1.0, 1.0]:
		_add_wall(
				Vector3(side * (board_def.width / 2.0 + board_def.wall_thickness / 2.0),
						board_def.wall_height / 2.0, 0.0),
				Vector3(board_def.wall_thickness, board_def.wall_height, board_def.length),
				"left" if side < 0.0 else "right")
	_add_wall(
			Vector3(0.0, board_def.wall_height / 2.0, board_def.length / 2.0 + board_def.wall_thickness / 2.0),
			Vector3(board_def.width + 2.0 * board_def.wall_thickness, board_def.wall_height, board_def.wall_thickness),
			"back")

	_add_fair_bulbs()
	_add_deck_art()

	for row in board_def.rows:
		for col in board_def.cols:
			var pos := Vector3(
					-board_def.spacing_x * (board_def.cols - 1) / 2.0 + col * board_def.spacing_x,
					0.0,
					board_def.first_row_z + row * board_def.spacing_z)
			_add_hole(pos, board_def.row_scores[row], row * board_def.cols + col)

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
	launch_marker.position = Vector3(0, 0.012, board_def.launch_z())
	board.add_child(launch_marker)

	# Shot tilt guide: a slim line pivoting at the launch point. It leans
	# left/right with the arrows and freezes at the locked angle while the
	# power bar runs.
	shot_guide = Node3D.new()
	shot_guide.position = Vector3(0, 0.014, board_def.launch_z())
	var guide_stick := MeshInstance3D.new()
	var guide_mesh := BoxMesh.new()
	var guide_len := board_def.length * 0.37
	guide_mesh.size = Vector3(0.05, 0.004, guide_len)
	guide_stick.mesh = guide_mesh
	guide_stick.position = Vector3(0, 0.03, guide_len / 2.0)  # extends forward
	var guide_mat := StandardMaterial3D.new()
	guide_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	guide_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	guide_mat.albedo_color = Color(0.35, 0.9, 1.0, 0.6)
	# Overlay: the guide always draws over decals, notches and marbles.
	guide_mat.no_depth_test = true
	guide_mat.render_priority = 10
	guide_stick.material_override = guide_mat
	shot_guide.add_child(guide_stick)
	shot_guide.visible = false
	board.add_child(shot_guide)


func _add_wall(pos: Vector3, size: Vector3, side: String) -> void:
	var wall := StaticBody3D.new()
	wall.name = "Wall"
	wall.add_to_group("walls")
	wall.set_meta("side", side)
	board.add_child(wall)
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collider.shape = box
	wall.add_child(collider)
	var mesh_i := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_i.mesh = mesh
	mesh_i.material_override = _paint_material(board_def.frame_color)
	wall.add_child(mesh_i)
	wall.position = pos


func _add_hole(pos: Vector3, score: int, index: int) -> void:
	# A notch is carved at marble size: a dark disc slightly wider than a
	# marble marks the carved spot on the wood surface.
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	var notch_radius := marble_def.radius + 0.015
	cyl.top_radius = notch_radius
	cyl.bottom_radius = notch_radius
	cyl.height = 0.012
	cyl.radial_segments = 24
	disc.mesh = cyl
	disc.position = pos + Vector3(0, 0.008, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.05, 0.04, 0.03)
	mat.roughness = 1.0
	disc.material_override = mat
	board.add_child(disc)

	# Emissive rim around the notch: the neon ring of the circus look.
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = notch_radius + 0.01
	torus.outer_radius = notch_radius + 0.05
	ring.mesh = torus
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = board_def.notch_glow_color.darkened(0.4)
	ring_mat.emission_enabled = true
	ring_mat.emission = board_def.notch_glow_color
	ring_mat.emission_energy_multiplier = 1.2
	ring.material_override = ring_mat
	ring.position = pos + Vector3(0, 0.011, 0)
	board.add_child(ring)

	var label := Label3D.new()
	label.text = str(score)
	label.font_size = 96
	label.pixel_size = 0.002
	label.modulate = Color(0.95, 0.9, 0.75)
	# Below the notch (toward the player, -Z reads as screen-down from the
	# diagonal camera), with extra margin so the ring and label never
	# collide; y lifted a hair to avoid z-fighting with the notch disc.
	label.position = pos + Vector3(0, 0.03, -0.28)
	# Lay the number flat, readable from the player's camera: the -90 X
	# lay-down alone points the text top toward the player (reads upside
	# down on screen); the 180 Y turn points it away so it reads normally.
	label.rotation_degrees = Vector3(-90, 180, 0)
	board.add_child(label)

	holes.append({"pos": pos, "score": score, "occupied": false, "index": index})


func _add_deck_art() -> void:
	# Theme art printed on the play surface, centered on the band between
	# the launch/guide zone and the first notch row. Purely decorative.
	if board_def.deck_art == null:
		return
	var quad := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(board_def.deck_art_width, board_def.deck_art_width)
	quad.mesh = q
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = board_def.deck_art
	# Decal-like: hugging the surface and drawn early, never fighting the
	# guide or notches for the same pixels.
	mat.render_priority = -1
	quad.material_override = mat
	var band_start := board_def.launch_z() + 0.35
	var band_end := board_def.first_row_z - 0.35
	# Rotate an extra 180 around Z after the lay-down so the art faces the
	# player upright (same correction the number labels use).
	quad.rotation_degrees = Vector3(-90, 0, 180)
	quad.position = Vector3(0, 0.006, (band_start + band_end) / 2.0)
	board.add_child(quad)
	_add_side_deck_art()


func _add_side_deck_art() -> void:
	# The same theme art on both cabinet side faces, centered: visible when
	# the camera orbits to the sides. 0 disables.
	if board_def.deck_art == null or board_def.deck_art_side_width <= 0.0:
		return
	var skirt_y := -board_def.skirt_height / 2.0 - board_def.thickness / 2.0
	var x := board_def.width / 2.0 + board_def.wall_thickness + 0.005
	for side in [-1.0, 1.0]:
		var quad := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(board_def.deck_art_side_width, board_def.deck_art_side_width)
		quad.mesh = q
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_texture = board_def.deck_art
		quad.material_override = mat
		# Face outward: +X normal on the right side, -X on the left.
		quad.rotation_degrees = Vector3(0, 90.0 * side, 0)
		quad.position = Vector3(side * x, skirt_y, 0.0)
		board.add_child(quad)


func _add_fair_bulbs() -> void:
	# Fair bulbs along the top edges of the side and back walls (never the
	# player edge: marbles roll back through it). Visual only, shared mesh.
	var bulb_mesh := SphereMesh.new()
	bulb_mesh.radius = 0.05
	bulb_mesh.height = 0.1
	var bulb_mat := StandardMaterial3D.new()
	bulb_mat.albedo_color = board_def.bulb_color
	bulb_mat.emission_enabled = true
	bulb_mat.emission = board_def.bulb_color
	bulb_mat.emission_energy_multiplier = 1.6
	var top_y := board_def.wall_height + 0.05
	var x_edge := board_def.width / 2.0 + board_def.wall_thickness / 2.0
	var z_edge := board_def.length / 2.0 + board_def.wall_thickness / 2.0
	for side in [-1.0, 1.0]:
		var z := -board_def.length / 2.0 + 0.25
		while z <= board_def.length / 2.0:
			_place_bulb(Vector3(side * x_edge, top_y, z), bulb_mesh, bulb_mat)
			z += 0.5
	var x := -board_def.width / 2.0 + 0.25
	while x <= board_def.width / 2.0 + 0.01:
		_place_bulb(Vector3(x, top_y, z_edge), bulb_mesh, bulb_mat)
		x += 0.5


func _place_bulb(pos: Vector3, mesh: SphereMesh, mat: StandardMaterial3D) -> void:
	var bulb := MeshInstance3D.new()
	bulb.mesh = mesh
	bulb.material_override = mat
	bulb.position = pos
	board.add_child(bulb)


func _paint_material(color: Color, emission := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	if emission > 0.0:
		# Subtle self-glow: keeps tall cabinet faces readable in the dark
		# room without flattening the shading.
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	return mat
