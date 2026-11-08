extends Node3D
## Board scene: one chibolones board built from a BoardDef, with the POC
## throw flow (aim -> tilt -> power -> flight) and physics capture.
## Presentation and physics only: the score lives in a ScoreEngine child,
## cross-cutting events go through the EventBus, and run flow belongs to
## the Game autoload. Behavior matches the POC one to one.

const MarbleFactory := preload("res://scripts/board/marble_factory.gd")
const ScoreEngineScript := preload("res://scripts/scoring/score_engine.gd")
const HudScript := preload("res://scripts/board/hud.gd")
const BoardThemeScript := preload("res://scripts/board/board_theme.gd")
## Seconds between two bonificador announcements at board start.
const ANNOUNCE_DELAY := 1.2

enum ThrowState { AIM, TILT, POWER, FLIGHT, ROUND_OVER, CAMERA }

var board_def: BoardDef
var rules: ShootingRules
## Base marble def: it drives the board geometry (notch size) and is the
## fallback when the run has no ammo yet (headless tests, no start_run).
var marble_def: MarbleDef
## Ammo slot of the marble the next throw uses; Up/Down swaps it while aiming.
var selected_ammo_index := 0
## Walls the marble hit this throw: prizes multiply their own score once per
## wall from this count, inside the hook contract.
var wall_hits := 0
## Bonificador wall multiplier accumulated this throw (Cuerda = x1.2 per
## wall). The pipeline reads it as one mult source, so the total math is the
## same product the M1 board computed inline.
var wall_mult := 1.0
var wall_mult_announced := false
var launched_def: MarbleDef  # def of the marble in flight, for score_mult

var state: ThrowState = ThrowState.AIM
## Throws the board has: the run inventory size at board start (S9), or the
## rules baseline when the board is played outside a run.
var shots_total := 0
var shots_left := 0
## The launched marble was already taken from the ammo: one consumption per
## throw, whatever resolves it.
var throw_consumed := false
var aim_x := 0.0
var aim_limit := 0.0
var shot_tilt := 0.0
## Tilt acceleration (user request, 2026-11-08): how long the current
## direction has been held, and which direction that is. Releasing or
## reversing resets both, so taps and reversals give fine adjustment.
var tilt_hold_time := 0.0
var tilt_last_dir := 0.0
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
## Bonificadores of this board (BoardModifierDef). Tests and future board
## defs inject the list before the node enters the tree; otherwise the run
## asks Game for the board's modifiers.
var modifier_override: Array[BoardModifierDef] = []
var board_theme: BoardTheme
## Parent of the notch visuals: Trapecio sways this node and the hole
## positions together, so capture keeps working in board-local space.
var notch_root: Node3D
var announce_timer: Timer
## Board-start cues waiting for their turn (board number and name, one per
## bonificador), spaced by ANNOUNCE_DELAY.
var announce_queue: Array[String] = []

## Controls guides (the opening controls line and the per-step hints) stay
## hidden during normal play: the tutorial (when it exists) can turn them
## on, and 20 s without any action bring them back on their own (user
## request, 2026-11-08).
const PAUSE_SCENE := "res://scenes/pause/pause_menu.tscn"

var tutorial_mode := false
const GUIDE_IDLE_SECONDS := 20.0
const CONTROLS_HINT := "Movi con <- -> y apreta ESPACIO para elegir la posicion"
var idle_time := 0.0
var idle_guide_shown := false
## Run objective for this board: 0 when the board is played outside a run
## (headless tests, --script mode), which keeps the plain POC round over.
var run_objective := 0
## The win/loss of this board was already reported to the Game run flow.
var board_result_sent := false
var launch_marker: MeshInstance3D
## Base capture assist range: only notches closer than this pull (see
## BoardDef.capture_pull); beyond it the throw flies untouched.
const CAPTURE_PULL_RANGE := 0.5
## Force scale, matching the Iman magnet's convention (design 1.0 reads as
## a mild pull; the base assist uses 0.4).
const CAPTURE_PULL_FORCE_SCALE := 4.0
var shot_guide: Node3D
var skirt: MeshInstance3D
var bulbs: Array[MeshInstance3D] = []
var bulb_on_mat: StandardMaterial3D
var bulb_off_mat: StandardMaterial3D
var bulb_clock := 0.0
var celebrate_left := 0.0
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
	board_def = ContentDB.board_def(_board_def_index())
	rules = ContentDB.rules()
	marble_def = ContentDB.marble_def("common")
	# Run context: a board played inside a run aims at that board's objective,
	# spends the marble inventory and reports its result to Game. A board
	# opened without a run (headless tests) has no objective and keeps the
	# plain round-over overlay.
	if _inventory_mode():
		run_objective = Game.objective_for_board(Game.current_board_in_run,
				board_def.objective_target if board_def.objective_target > 0 else 60)
		# S5: the ammo is the whole run inventory again. The ammo is the throw
		# budget (S9), so rules.shots_per_board stays untouched for the boards
		# played without a run.
		Game.begin_board()
		shots_total = Game.ammo.size()
	else:
		shots_total = rules.shots_per_board
	selected_ammo_index = _common_ammo_index()
	shots_left = shots_total
	aim_limit = board_def.width / 2.0 - board_def.aim_limit_margin
	# Bonificadores first: the wall bounce rule must be in place before the
	# walls are built, and every other rule reads the same state later.
	board_theme = BoardThemeScript.new()
	board_theme.name = "BoardTheme"
	add_child(board_theme)
	board_theme.setup(self, _board_modifiers())
	_build_environment()
	_build_board()
	score_engine = ScoreEngineScript.new()
	add_child(score_engine)
	hud = HudScript.new()
	add_child(hud)
	score_engine.score_changed.connect(hud.set_score)
	EventBus.embed.connect(_on_embed_celebrate)
	EventBus.wall_hit.connect(_on_wall_hit)
	add_child(preload("res://scripts/board/juice.gd").new())
	hud.set_shots(shots_left, shots_total)
	hud.set_target(run_objective)
	hud.set_money(Game.money)
	Game.money_changed.connect(hud.set_money)
	hud.set_prizes(Game.prizes)
	hud.set_selected_marble(_selected_marble_def().display_name)
	# Board identity (M2.5): the name and rules stay on screen top-center for
	# the whole board, so the player always knows which board they are on.
	hud.set_board_title(board_def.theme_name, _effects_line())
	# Bonificador announcements: one cue per modifier, queued so a boss board
	# with two rules still reads (the board emits modifier_active once each).
	announce_timer = Timer.new()
	announce_timer.one_shot = true
	announce_timer.wait_time = ANNOUNCE_DELAY
	announce_timer.timeout.connect(_on_announce_timeout)
	add_child(announce_timer)
	EventBus.modifier_active.connect(_on_modifier_active)
	EventBus.throw_timer_tick.connect(hud.set_timer)
	# Opening cues: which board this is and its rules. The controls guide
	# stays quiet until the tutorial asks for it or idle brings it back
	# (_tick_idle).
	_queue_announcement("Tablero %d: %s" % [_board_number(), board_def.theme_name])
	board_theme.announce()
	# The board opens in AIM, so the Cronometrado clock starts with it (boards
	# without the rule ignore this).
	_reset_step_timer()


## The board was won inside a run: the win screen plays as a translucent
## overlay ON this board (user request, 2026-11-08), so the game stays
## visible and alive behind GANADOR and the stats resumen. Game calls this
## when it enters the WIN phase; CONTINUAR routes on from there.
const WIN_SCENE := "res://scenes/run/win.tscn"
var win_overlay: Control


func host_win_overlay() -> void:
	if win_overlay != null or state != ThrowState.ROUND_OVER:
		return
	# The board keeps rendering and its bulbs keep chasing: only the player
	# controls go quiet (state ROUND_OVER gates every action below).
	var layer := CanvasLayer.new()
	layer.layer = 2  # over the HUD layer, under nothing else
	add_child(layer)
	win_overlay = (load(WIN_SCENE) as PackedScene).instantiate()
	layer.add_child(win_overlay)


func _unhandled_input(event: InputEvent) -> void:
	# Pause first: any state except the round-over overlay (which already
	# offers its own choices) can open the pause menu (ESC / Start).
	if event.is_action_pressed("pause"):
		_toggle_pause()
		return
	if event.is_action_pressed("restart"):
		# The win overlay plays over the live board with no controls (user
		# request, 2026-11-08): R must not reload the board out from under it.
		if Game.phase != Game.Phase.WIN:
			Game.restart_board()
		return
	if event.is_action_pressed("cancel"):
		# X / B: step back one stage of the throw flow.
		match state:
			ThrowState.TILT:
				state = ThrowState.AIM
				shot_tilt = 0.0
				shot_guide.visible = false
				hud.flash("Tiro cancelado: movi y apreta ESPACIO de nuevo")
			ThrowState.POWER:
				state = ThrowState.TILT
				power = 0.0
				power_dir = 1.0
				hud.set_power_visible(false)
				_reset_step_timer()
				hud.flash("Inclina con <- ->; X vuelve atras")
			ThrowState.CAMERA:
				state = ThrowState.AIM
				launch_marker.visible = true
				_show_guide(CONTROLS_HINT)
			_:
				pass
		return
	# Marble selection over the board ammo: edge-triggered on the vertical
	# arrows while aiming, so holding a direction never cycles (the sideways
	# arrows are held for aiming; these two are taps instead).
	if state == ThrowState.AIM:
		if event.is_action_pressed("move_up"):
			_cycle_ammo(-1)
			return
		if event.is_action_pressed("move_down"):
			_cycle_ammo(1)
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
			_show_guide(CONTROLS_HINT)
		return
	if event.is_action_pressed("shoot"):
		match state:
			ThrowState.AIM:
				_begin_tilt()
			ThrowState.TILT:
				_begin_power()
			ThrowState.POWER:
				_fire()
			_:
				pass


func _physics_process(delta: float) -> void:
	_tick_idle(delta)
	_animate_bulbs(delta)
	# Cronometrado: every decision step runs on a clock; on expiry the board
	# takes the step with whatever the player had chosen so far.
	if board_theme != null and board_theme.has_decision_timer():
		match state:
			ThrowState.AIM, ThrowState.TILT, ThrowState.POWER:
				if board_theme.tick_decision(delta):
					_auto_advance()
			_:
				pass
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
			# Analog-aware: the same actions fire from keys (±1.0) and the
			# gamepad stick (0..1 magnitude), so one path covers both inputs.
			var turn := Input.get_axis("move_left", "move_right")
			# Screen directions: the camera looks down +Z, so world +X shows on
			# the player's LEFT. Invert the sign so each arrow leans the guide
			# the way it points on screen, clamped so it never aims off-board.
			var move_dir := -signf(turn)
			if move_dir != 0.0 and move_dir == tilt_last_dir:
				# Same direction held: keep ramping toward full speed.
				tilt_hold_time += delta
			else:
				# Released or reversed: the next press starts fine again.
				tilt_hold_time = 0.0
				tilt_last_dir = move_dir
			var speed := rules.tilt_frame_speed(turn, tilt_hold_time)
			shot_tilt = clampf(shot_tilt + move_dir * speed * delta,
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


## Throw flow steps as plain methods: the input handler and the Cronometrado
## auto-advance both drive them, so a forced step is never a second code
## path with its own rules.
func _begin_tilt() -> void:
	if shots_left <= 0:
		return
	state = ThrowState.TILT
	shot_tilt = 0.0
	tilt_hold_time = 0.0
	tilt_last_dir = 0.0
	_update_tilt_limits()
	shot_guide.visible = true
	# Starting the next throw cancels any leftover celebration so the bulbs
	# drop to the slow chase right away.
	celebrate_left = 0.0
	_reset_step_timer()
	_show_guide("Inclina con <- -> y apreta ESPACIO para fijar")


func _begin_power() -> void:
	state = ThrowState.POWER
	power = 0.0
	power_dir = 1.0
	hud.set_power_visible(true)
	_reset_step_timer()
	_show_guide("Apreta ESPACIO para disparar con esta potencia")


func _fire() -> void:
	hud.set_power_visible(false)
	hud.set_timer(-1)
	shot_guide.visible = false
	_launch(shot_tilt, power)


## Cronometrado ran out on this step: take it with the current choice.
func _auto_advance() -> void:
	match state:
		ThrowState.AIM:
			_begin_tilt()
		ThrowState.TILT:
			_begin_power()
		ThrowState.POWER:
			_fire()
		_:
			pass


## Restart the decision clock of a step (no-op on boards without the rule).
func _reset_step_timer() -> void:
	if board_theme != null:
		board_theme.reset_decision()


## --- Pause (ESC / Start) ---------------------------------------------------


## Open the pause overlay: it pauses the tree itself once it is on the tree,
## and it owns the unpause, so the board never touches the paused state.
func _toggle_pause() -> void:
	if get_tree().paused or state == ThrowState.ROUND_OVER:
		return
	add_child((load(PAUSE_SCENE) as PackedScene).instantiate())


## --- Controls guides (tutorial / idle) -------------------------------------


## A per-step guide reaches the HUD only when the tutorial asked for it or
## the player has already idled long enough to need it (see _tick_idle);
## normal play keeps the screen clean.
func _show_guide(text: String) -> void:
	if tutorial_mode or idle_guide_shown:
		hud.flash(text)


## One idle tick: any held gameplay action resets the clock; otherwise 20 s
## without actions bring the full controls guide back, once, until the next
## input. Only shown while aiming, where the guide applies.
func _tick_idle(delta: float) -> void:
	if _any_input_active():
		idle_time = 0.0
		idle_guide_shown = false
		return
	if state != ThrowState.AIM:
		return
	idle_time += delta
	if idle_time >= GUIDE_IDLE_SECONDS and not idle_guide_shown:
		idle_guide_shown = true
		hud.flash(CONTROLS_HINT)


## Whether the player is doing something right now: any movement vector or
## a held gameplay action. Edge taps are also caught by the events handled
## in the same frame.
func _any_input_active() -> bool:
	if Input.get_vector("move_left", "move_right", "move_up", "move_down") \
				!= Vector2.ZERO:
		return true
	return Input.is_action_pressed("shoot") \
			or Input.is_action_pressed("cancel") \
			or Input.is_action_pressed("camera_mode") \
			or Input.is_action_pressed("restart")


## Marble the next throw uses: the selected ammo entry, or the base def when
## the run has no ammo (headless tests build the board without a run).
func _selected_marble_def() -> MarbleDef:
	if Game.ammo.is_empty():
		return marble_def
	return Game.ammo[selected_ammo_index % Game.ammo.size()]


## Ammo slot of the common marble: the run always starts on it, so the first
## throw keeps the POC feel.
func _common_ammo_index() -> int:
	for i in Game.ammo.size():
		if Game.ammo[i].id == "common":
			return i
	return 0


func _cycle_ammo(step: int) -> void:
	var count := Game.ammo.size()
	if count > 0:
		selected_ammo_index = (selected_ammo_index + step + count) % count
	var def := _selected_marble_def()
	hud.set_selected_marble(def.display_name)
	hud.flash("%s: %s" % [def.display_name, _marble_hint(def)])


## Keep the selection on a marble that still exists after the ammo shrank.
func _keep_selection_valid() -> void:
	if Game.ammo.is_empty():
		selected_ammo_index = 0
	else:
		selected_ammo_index %= Game.ammo.size()


## One-line effect hint for the ammo flash: the launch speed when the marble
## changes it, otherwise its flavor line.
func _marble_hint(def: MarbleDef) -> String:
	if not is_equal_approx(def.speed_mult, 1.0):
		return "Velocidad x%.2f" % def.speed_mult
	if not is_equal_approx(def.score_mult, 1.0):
		return "Puntos x%s" % PrizeDef.format_mult(def.score_mult)
	return def.flavor if def.flavor != "" else "Sin efecto especial"


func _update_tilt_limits() -> void:
	# The guide pivots at the launch spot; clamp each side so its far end
	# stays inside the walls even at the far edge of the board. tilt_range_mult
	# widens the playable angles past the wall-derived values (user request,
	# 2026-11-08); 80 degrees is the hard ceiling so the guide can never
	# spin backwards.
	var dist_to_far := board_def.length / 2.0 - board_def.launch_z()
	var side_margin := board_def.width / 2.0 - board_def.aim_limit_margin
	tilt_max_left = minf(rad_to_deg(atan(maxf(0.0, side_margin + aim_x) / dist_to_far))
			* rules.tilt_range_mult, 80.0)
	tilt_max_right = minf(rad_to_deg(atan(maxf(0.0, side_margin - aim_x) / dist_to_far))
			* rules.tilt_range_mult, 80.0)


func _launch(tilt_deg: float, power_value: float) -> void:
	# Prize effects are per throw: the wall multiplier starts neutral.
	wall_mult = 1.0
	wall_mult_announced = false
	wall_hits = 0
	# The throw is spent when it resolves (S4), so a refund never spends it.
	throw_consumed = false
	if board_theme != null:
		# Per-throw rules first: Borracho reshuffles the values, Ventoso picks
		# a side, Mochila covers a notch, Cronometrado restarts its clock.
		board_theme.on_throw_started()
	var def := _selected_marble_def()
	# Glass durability (S3): one roll per throw, before the marble exists. A
	# broken marble leaves the ammo and the throw goes on with the next one.
	if _try_break(def):
		def = _selected_marble_def()
	launched_def = def
	var marble := MarbleFactory.make(def, throw_index)
	throw_index += 1
	if board_theme != null:
		# Mojado: the spawned marble rolls with the board's friction.
		board_theme.apply_marble(marble)
	# Marble is a child of the tilted board so local coordinates stay handy.
	# Spawn clear of the surface: a marble born intersecting the board can
	# escape through it in the physics engine.
	marble.position = Vector3(aim_x, def.radius + 0.05, board_def.launch_z())
	marble.body_entered.connect(_on_marble_body_entered.bind(marble))
	board.add_child(marble)
	var tilt_rad := deg_to_rad(tilt_deg)
	# Direction includes the locked shot tilt: positive tilts toward the
	# player's left on screen, exactly like the guide line showed.
	var dir := (board.global_transform.basis * Vector3(sin(tilt_rad), 0.0, 1.0)).normalized()
	var speed := lerpf(rules.min_speed, rules.max_speed, power_value / 100.0) \
			* def.speed_mult
	marble.apply_central_impulse(dir * speed * marble.mass)
	active_marbles.append(marble)
	settle_times.clear()
	pending_result = ""
	launch_timer = 0.0
	launch_marker.visible = false
	# Outside a run the shot is spent at launch, exactly like the POC; a run
	# board spends the marble when the throw resolves instead (S4).
	if not _inventory_mode():
		shots_left -= 1
	state = ThrowState.FLIGHT
	hud.set_shots(shots_left, shots_total)
	EventBus.throw_started.emit(def.id)


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
			_consume_throw()
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
		# Base capture assist (tuning 2026-11-08): a gentle pull toward the
		# nearest open notch helps the drop-in without steering the throw.
		_apply_capture_pull(marble, local)
		var reach: float = board_def.capture_radius
		for hole in holes:
			# An occupied notch already holds an embedded marble: shots can
			# only bounce off it, never fall into the same spot. Mochila
			# covers one notch and Fantasma hides another: neither can take a
			# marble while its rule is on.
			if hole.occupied or hole.covered or hole.phase_hidden:
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
				_consume_throw()
				pending_result = "La canica se quedo quieta: 0 puntos"
				EventBus.throw_ended.emit(&"settled")
		# Run board: reaching the objective wins the board right here, no
		# need to wait for the marble to settle.
		if _run_win_reached():
			return
	# End the volley once every marble stopped, sank, or the timeout hit.
	if active_marbles.is_empty() or launch_timer >= rules.flight_timeout:
		if launch_timer >= rules.flight_timeout and not active_marbles.is_empty():
			# Timed out: the throw is lost, clean the leftovers up.
			for marble in active_marbles:
				if is_instance_valid(marble):
					marble.queue_free()
			active_marbles.clear()
			EventBus.throw_ended.emit(&"timed_out")
			_consume_throw()
		if shots_left > 0:
			state = ThrowState.AIM
			launch_marker.visible = true
			_reset_step_timer()
			if pending_result != "":
				# Resolution messages would otherwise be overwritten by the
				# next-throw prompt in the same frame, so flash them here.
				hud.flash(pending_result)
				pending_result = ""
			else:
				hud.flash("Tiro %d de %d" % [shots_total - shots_left + 1, shots_total])
		else:
			_round_over()


func _discard_marble(marble: RigidBody3D) -> void:
	active_marbles.erase(marble)
	settle_times.erase(marble)
	marble.queue_free()


## Gentle attraction toward the nearest open notch: only below skip speed
## (a fast marble must hop over notches) and inside CAPTURE_PULL_RANGE, so
## it nudges the drop-in instead of bending the whole throw.
func _apply_capture_pull(marble: RigidBody3D, local: Vector3) -> void:
	if board_def.capture_pull <= 0.0 or marble.freeze:
		return
	var best: Dictionary = {}
	var best_d := CAPTURE_PULL_RANGE
	for hole in holes:
		if hole.occupied or hole.covered or hole.phase_hidden:
			continue
		var d := Vector2(local.x - hole.pos.x, local.z - hole.pos.z).length()
		if d < best_d:
			best_d = d
			best = hole
	if best.is_empty():
		return
	var pull := Vector3(best.pos.x - local.x, 0.0, best.pos.z - local.z)
	marble.apply_central_force(board.global_transform.basis \
			* pull.normalized() * board_def.capture_pull \
			* CAPTURE_PULL_FORCE_SCALE * marble.mass)


## A run board spends the marble inventory: the ammo is the throw budget and
## every resolved throw consumes a marble. A board opened without a run
## (headless tests, --script mode) keeps the plain POC round.
func _inventory_mode() -> bool:
	return Game.in_run() and Game.phase == Game.Phase.BOARD


## The throw resolved without a refund: the marble leaves the board ammo
## (S4) and the run is told through marble_removed. The inventory keeps it,
## so the next board restores it (S5).
func _consume_throw() -> void:
	if throw_consumed or not _inventory_mode():
		return
	throw_consumed = true
	if Game.spend_ammo(launched_def) == null:
		return
	shots_left = Game.ammo.size()
	_keep_selection_valid()
	hud.set_shots(shots_left, shots_total)
	hud.set_selected_marble(_selected_marble_def().display_name)


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
	# One seam for every score edit (M2): the pipeline applies flats, then
	# multipliers, then rounds once. The boosted value is what the bus
	# carries, so the HUD message, the popup and the ScoreEngine agree.
	var breakdown := score_engine.evaluate_embed(hole.score, _score_context(hole))
	var boosted := breakdown.final()
	pending_result = "Incrustada en muesca de %d: +%d" % [hole.score, boosted]
	if breakdown.acted():
		hud.set_breakdown(breakdown.describe())
	EventBus.embed.emit(hole.index, boosted)
	_consume_throw()
	EventBus.throw_ended.emit(&"embedded")


## Facts the hook contract reads for one embed: the board node plus this
## throw's state. Every contribution lands in the breakdown, never here.
func _score_context(hole: Dictionary) -> Dictionary:
	return {
		"board": self,
		"throw": {
			"marble": launched_def,
			"notch": hole,
			"wall_hits": wall_hits,
			"wall_mult": wall_mult,
			"wall_source": wall_source_name(),
			"center": _is_center_hole(hole),
			"tilt": shot_tilt,
			"power": power,
		},
	}


func _round_over() -> void:
	state = ThrowState.ROUND_OVER
	hud.set_timer(-1)
	if board_result_sent:
		return
	var possible: int = shots_total * board_def.row_scores[board_def.rows - 1]
	if run_objective > 0 and score_engine.total < run_objective:
		# Run board lost: the shots ran out under the objective, so the run
		# is over. Game owns the run summary screen.
		board_result_sent = true
		hud.show_defeat(score_engine.total, run_objective)
		EventBus.board_ended.emit(score_engine.total)
		Game.board_lost.call_deferred()
		return
	hud.show_game_over(score_engine.total, possible)
	EventBus.board_ended.emit(score_engine.total)


## Run objective reached during the throw. The remaining marbles are frozen
## and freed here, and Game is called one frame later so the physics frame
## finishes before the scene changes to the shop.
func _run_win_reached() -> bool:
	if board_result_sent or run_objective <= 0:
		return false
	if score_engine.total < run_objective:
		return false
	board_result_sent = true
	for marble in active_marbles.duplicate():
		if is_instance_valid(marble):
			marble.freeze = true
			marble.queue_free()
	active_marbles.clear()
	settle_times.clear()
	launch_marker.visible = false
	hud.set_power_visible(false)
	state = ThrowState.ROUND_OVER
	hud.flash("Tablero superado!")
	EventBus.board_ended.emit(score_engine.total)
	Game.board_won.call_deferred(shots_left, 0, score_engine.total)
	return true


func _on_marble_body_entered(other: Node, marble: RigidBody3D) -> void:
	# Physics contact -> domain events. Impact speed is the marble speed at
	# contact time; M2 modifiers react to these.
	var impact := marble.linear_velocity.length()
	if other.is_in_group("walls"):
		EventBus.wall_hit.emit(other.get_meta("side"), impact)
	elif other.is_in_group("embedded"):
		EventBus.embedded_marble_hit.emit(other.get_meta("notch_index"), impact)


func _on_wall_hit(_side: StringName, _impact_speed: float) -> void:
	# Wall rules: prizes multiply once per wall through the hook contract, so
	# only the bonificador part accumulates here (Cuerda x1.2 per wall).
	# Neither rule in play leaves every value at x1.0, exactly like M1.
	wall_hits += 1
	if board_theme != null:
		var step := board_theme.wall_step()
		if not is_equal_approx(step, 1.0):
			wall_mult *= step
	if wall_mult_announced:
		return
	# Announced once per throw, on the first wall: readable feedback without
	# a wall-hit spam of messages.
	var total := wall_total()
	if is_equal_approx(total, 1.0):
		return
	wall_mult_announced = true
	hud.flash("%s %s!" % [wall_source_name(), PrizeDef.format_mult(total)])


## Combined wall multiplier of this throw: the bonificador accumulation the
## board keeps plus each prize's own per-wall factor.
func wall_total() -> float:
	var total := wall_mult
	for prize in Game.prizes:
		total *= pow(prize.wall_hit_mult, wall_hits)
	return total


## Name the HUD credits for a wall multiplier: the active bonificador first,
## then the prize carrying the rule.
func wall_source_name() -> String:
	if board_theme != null and not is_equal_approx(board_theme.wall_hit_mult, 1.0):
		return String(board_theme.wall_source)
	for prize in Game.prizes:
		if not is_equal_approx(prize.wall_hit_mult, 1.0):
			return prize.display_name
	return "Paredes"


# --- Bonificadores (M2 rules) ------------------------------------------------


## Bonificadores of this board: a test/board override wins, otherwise the run
## asks Game. Without a run there are none, which keeps the plain POC round
## (headless tests) untouched.
func _board_modifiers() -> Array[BoardModifierDef]:
	if not modifier_override.is_empty():
		return modifier_override
	if Game.in_run() and Game.phase == Game.Phase.BOARD:
		return Game.board_modifiers(Game.current_board_in_run)
	return []


## BoardDef this scene renders: inside a run it is the run board's own def
## (board N -> def N-1, in filename order); outside a run (headless smoke
## path) it stays on Game.board_index, which is the first def.
func _board_def_index() -> int:
	if Game.in_run() and Game.phase == Game.Phase.BOARD:
		return Game.board_def_index(Game.current_board_in_run)
	return Game.board_index


## Board number shown by the HUD: the run board, or 1 outside a run.
func _board_number() -> int:
	if Game.in_run() and Game.phase == Game.Phase.BOARD:
		return maxi(Game.current_board_in_run, 1)
	return 1


## Identity line of the HUD under the board name: the display names of the
## board's bonificadores, or a plain "Sin modificadores" when it has none.
func _effects_line() -> String:
	var names: Array[String] = []
	for modifier in active_modifiers():
		if modifier != null:
			names.append(modifier.display_name)
	return " + ".join(names) if not names.is_empty() else "Sin modificadores"


## The board's active bonificadores, asked by ScoreEngine for their score
## contributions through the hook contract.
func active_modifiers() -> Array[BoardModifierDef]:
	return board_theme.modifiers if board_theme != null else []


## Center column of an odd grid: Espejo pays it double.
func _is_center_hole(hole: Dictionary) -> bool:
	if board_def.cols % 2 == 0:
		return false
	return int(hole.col) == (board_def.cols - 1) / 2


## Trapecio: move the notch grid sideways in board-local space. Hole
## positions and the marbles already embedded in them follow, so capture and
## rendering keep agreeing while the grid sways.
func apply_grid_offset(offset: float) -> void:
	if notch_root == null:
		return
	notch_root.position.x = offset
	for hole in holes:
		hole.pos = Vector3(hole.base.x + offset, hole.base.y, hole.base.z)
	for child in board.get_children():
		if not (child is RigidBody3D) or not child.is_in_group("embedded"):
			continue
		var notch: int = int(child.get_meta("notch_index", -1))
		if notch < 0 or notch >= holes.size():
			continue
		child.position.x = holes[notch].pos.x


## Notch visuals follow the rule flags: a covered (Mochila) or hidden
## (Fantasma) notch drops its neon rim and fades its number, so the player
## reads at a glance which notch cannot take a marble right now.
func paint_hole(hole: Dictionary) -> void:
	var open: bool = not hole.covered and not hole.phase_hidden
	hole.ring.visible = open
	if open:
		hole.label.modulate = Color(0.95, 0.9, 0.75)
	else:
		hole.label.modulate = Color(0.7, 0.65, 0.55, 0.3)


## Glass durability (S3): one roll per throw, before the marble spawns. A
## broken marble leaves the ammo and the run inventory for good (S5), so the
## next board does not restore it, and the throw goes on with the next ammo
## marble. The last marble never breaks, so a throw always has something to
## launch.
func _try_break(def: MarbleDef) -> bool:
	if def == null or not _inventory_mode():
		return false
	if def.break_chance <= 0.0 or Game.ammo.size() <= 1:
		return false
	if randf() >= def.break_chance:
		return false
	if Game.break_ammo(def) == null:
		return false
	_keep_selection_valid()
	hud.flash("Tu canica de vidrio se rompio!")
	hud.set_selected_marble(_selected_marble_def().display_name)
	return true


## Bonificador banner at board start: queue the cue and let the timer space
## them, so a boss board with two rules still reads (the board emits
## modifier_active once each).
func _on_modifier_active(id: StringName) -> void:
	var def: BoardModifierDef = board_theme.modifier_by_id(id) if board_theme != null else null
	if def == null:
		def = ContentDB.modifier_def(id)
	if def == null:
		return
	_queue_announcement("%s: %s" % [def.display_name, def.description])


## One board-start cue: the first shows right away, the timer spaces the
## rest by ANNOUNCE_DELAY so every line gets read.
func _queue_announcement(text: String) -> void:
	announce_queue.append(text)
	if announce_timer == null:
		hud.flash(text)
		return
	if announce_timer.is_stopped():
		_announce_next()


func _announce_next() -> void:
	if announce_queue.is_empty():
		return
	hud.flash(announce_queue.pop_front())
	announce_timer.start(ANNOUNCE_DELAY)


func _on_announce_timeout() -> void:
	_announce_next()


# --- Construction ------------------------------------------------------------


func _build_environment() -> void:
	# Circus void: dark violet, themed ambient, dim key light and a tinted
	# spotlight over the cabinet. Every color comes from the BoardDef so a
	# board theme can relight the whole scene.
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0d0920")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("3a1f6e")
	env.ambient_light_energy = board_def.ambient_energy
	env.fog_enabled = true
	env.fog_light_color = Color("1d1240")
	env.fog_density = 0.02
	# Neon feel: emissive bulbs and rings bloom into the dark room.
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.0
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
	# Compact closed room: back wall plus both side walls share the board's
	# psychedelic backdrop, so orbiting the cabinet always shows the same
	# living void with no visible edges. The player side is open.
	var mat := _build_backdrop()
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


## Moving backdrop of the room walls. The BoardDef picks the shader variant
## (waves, spiral or rays); every variant takes the same colors, speed and
## scale, so one material covers the three walls of the room.
func _build_backdrop() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load(board_def.backdrop_shader_path())
	mat.set_shader_parameter("color_a", board_def.backdrop_color_a)
	mat.set_shader_parameter("color_b", board_def.backdrop_color_b)
	mat.set_shader_parameter("color_c", board_def.backdrop_color_c)
	mat.set_shader_parameter("speed", board_def.backdrop_speed)
	mat.set_shader_parameter("pattern_scale", board_def.backdrop_scale)
	return mat


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

	# Notch visuals live under one parent so Trapecio can sway the grid as a
	# unit; positions stay board-local (notch_root starts at the origin).
	notch_root = Node3D.new()
	notch_root.name = "NotchRoot"
	board.add_child(notch_root)

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
	# Cuerda: a bonificador raises the wall restitution. Without the rule the
	# walls keep the engine default, exactly like M1.
	if board_theme != null and board_theme.wall_bounciness > 0.0:
		var physics := PhysicsMaterial.new()
		physics.bounce = board_theme.wall_bounciness
		physics.friction = 0.4
		wall.physics_material_override = physics
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
	notch_root.add_child(disc)

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
	ring_mat.emission_energy_multiplier = 2.0
	ring.material_override = ring_mat
	ring.position = pos + Vector3(0, 0.011, 0)
	notch_root.add_child(ring)

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
	notch_root.add_child(label)

	# The hole keeps everything the rules need: its board-local position and
	# the one it was carved at (Trapecio sways the grid), the current value
	# (Borracho rewrites it), the rule flags and the visuals to repaint.
	holes.append({
		"pos": pos,
		"base": pos,
		"score": score,
		"occupied": false,
		"covered": false,
		"phase_hidden": false,
		"index": index,
		"col": index % board_def.cols,
		"row": index / board_def.cols,
		"disc": disc,
		"ring": ring,
		"label": label,
	})


func _add_deck_art() -> void:
	# Theme art (the board's emblem) printed on the play surface, centered on
	# the band between the launch/guide zone and the first notch row. Purely
	# decorative.
	var art := board_def.deck_art_texture()
	if art == null:
		return
	var quad := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(board_def.deck_art_width, board_def.deck_art_width)
	quad.mesh = q
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = art
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
	# The same emblem on both cabinet side faces, centered: visible when the
	# camera orbits to the sides. 0 disables.
	var art := board_def.deck_art_texture()
	if art == null or board_def.deck_art_side_width <= 0.0:
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
		mat.albedo_texture = art
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
	bulb_on_mat = StandardMaterial3D.new()
	bulb_on_mat.albedo_color = board_def.bulb_color
	bulb_on_mat.emission_enabled = true
	bulb_on_mat.emission = board_def.bulb_color
	bulb_on_mat.emission_energy_multiplier = 2.2
	bulb_off_mat = StandardMaterial3D.new()
	bulb_off_mat.albedo_color = board_def.bulb_color.darkened(0.75)
	bulb_off_mat.emission_enabled = true
	bulb_off_mat.emission = board_def.bulb_color
	bulb_off_mat.emission_energy_multiplier = 0.08
	var top_y := board_def.wall_height + 0.05
	var x_edge := board_def.width / 2.0 + board_def.wall_thickness / 2.0
	var z_edge := board_def.length / 2.0 + board_def.wall_thickness / 2.0
	for side in [-1.0, 1.0]:
		var z := -board_def.length / 2.0 + 0.25
		while z <= board_def.length / 2.0:
			_place_bulb(Vector3(side * x_edge, top_y, z), bulb_mesh)
			z += 0.5
	var x := -board_def.width / 2.0 + 0.25
	while x <= board_def.width / 2.0 + 0.01:
		_place_bulb(Vector3(x, top_y, z_edge), bulb_mesh)
		x += 0.5


func _place_bulb(pos: Vector3, mesh: SphereMesh) -> void:
	var bulb := MeshInstance3D.new()
	bulb.mesh = mesh
	bulb.material_override = bulb_on_mat
	bulb.position = pos
	board.add_child(bulb)
	bulbs.append(bulb)


func _on_embed_celebrate(_notch_index: int, _value: int) -> void:
	celebrate_left = 3.0


func _animate_bulbs(delta: float) -> void:
	# Pinball light show, by mode (celebration outranks the throw step):
	# idle/turn start = all off; preparing = slow chase; marble flying =
	# all-bulbs blink; points scored = fast chase for 5 seconds.
	bulb_clock += delta
	if celebrate_left > 0.0:
		celebrate_left -= delta
		_set_chase(board_def.bulb_pattern_speed)
		return
	match state:
		ThrowState.TILT, ThrowState.POWER:
			_set_chase(board_def.bulb_pattern_speed * 0.6)
		ThrowState.FLIGHT:
			var on := fmod(bulb_clock * 2.0, 1.0) < 0.5
			for b in bulbs:
				b.material_override = bulb_on_mat if on else bulb_off_mat
		_:
			_set_all_bulbs(false)


func _set_chase(speed: float) -> void:
	for i in bulbs.size():
		var on := fmod(bulb_clock * speed + float(i) * 0.7, 1.0) < 0.55
		bulbs[i].material_override = bulb_on_mat if on else bulb_off_mat


func _set_all_bulbs(on: bool) -> void:
	for b in bulbs:
		b.material_override = bulb_on_mat if on else bulb_off_mat


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
