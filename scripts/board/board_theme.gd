class_name BoardTheme
extends Node
## Board-scoped runtime for the bonificadores (BoardModifierDef). The board
## of the run loads its modifiers here; this node owns the rule state those
## modifiers keep between frames (which side the wind blows from, the covered
## notch, the phase clock, the grid sway, the decision timer) and applies the
## physics edits. Scoring stays in ScoreEngine: the board reports the wall
## accumulation and hands the defs to the pipeline.
##
## Every rule is opt-in: a neutral field leaves the board exactly as the POC
## board, which is what keeps a board played outside a run identical to M1.

## Trapecio: sideways travel of the notch grid, in board units.
const SWING_AMPLITUDE := 0.5
## Fantasma: seconds each half of the hide/show cycle lasts.
const PHASE_PERIOD := 2.0
## Iman: attraction only reaches this far from an embedded marble.
const MAGNET_RANGE := 1.0
## Inside this distance of an embedded marble the pull would only grind the
## rolling one against the obstacle: the magnet damps it instead (user
## request, 2026-11-08). Slightly over two marble radii of contact.
const MAGNET_CONTACT_RADIUS := 0.2
## How fast the contact damping drains speed, in units per second.
const MAGNET_CONTACT_DAMP := 3.0
## Iman: force scale, so a design value of 1.5 reads as a mild pull.
const MAGNET_FORCE_SCALE := 4.0
## Ventoso: force scale applied on top of the design wind strength.
const WIND_FORCE_SCALE := 1.0

var board: Node3D
## Active bonificadores, in announcement order.
var modifiers: Array[BoardModifierDef] = []

## Rule values merged from every active modifier (each rule is one number).
var friction_scale := 1.0
var wall_bounciness := 0.0
var wall_hit_mult := 1.0
var wind_strength := 0.0
var magnet_strength := 0.0
var value_shuffle := false
var cover_notch := false
var phase_notch := false
var grid_swing_speed := 0.0
var center_mult := 1.0
var decision_timer_sec := 0.0
## Source name of the wall multiplier, for the score breakdown line.
var wall_source: StringName = &""

## Cross wind side for this throw: +1 pushes right, -1 pushes left.
var wind_direction := 1.0
## Notch the Mochila covers this throw (-1 = none).
var covered_index := -1
## Notch the Fantasma phases this throw (-1 = none) and its clock.
var phase_index := -1
var phase_time := 0.0
var phase_hidden := false
## Sway clock of the Trapecio grid.
var swing_time := 0.0
## Cronometrado: seconds left in the current step and the last tick shown.
var decision_left := 0.0
var decision_tick := -1


## Wire the board and merge the rule values of its modifiers. The board calls
## this before it builds geometry, so wall bounce is already in place.
func setup(owner_board: Node3D, defs: Array[BoardModifierDef]) -> void:
	board = owner_board
	for def in defs:
		if def == null:
			continue
		modifiers.append(def)
		friction_scale *= def.friction_scale
		wall_bounciness = maxf(wall_bounciness, def.wall_bounciness)
		wind_strength = maxf(wind_strength, def.wind_strength)
		magnet_strength = maxf(magnet_strength, def.magnet_strength)
		grid_swing_speed = maxf(grid_swing_speed, def.grid_swing_speed)
		decision_timer_sec = maxf(decision_timer_sec, def.decision_timer_sec)
		value_shuffle = value_shuffle or def.value_shuffle
		cover_notch = cover_notch or def.cover_notch
		phase_notch = phase_notch or def.phase_notch
		center_mult *= def.center_mult
		if not is_equal_approx(def.wall_hit_mult, 1.0):
			wall_hit_mult *= def.wall_hit_mult
			wall_source = StringName(def.display_name)


func active() -> bool:
	return not modifiers.is_empty()


func has(id: StringName) -> bool:
	for def in modifiers:
		if def.id == id:
			return true
	return false


func modifier_by_id(id: StringName) -> BoardModifierDef:
	for def in modifiers:
		if def.id == id:
			return def
	return null


## Board start: the HUD announces each bonificador once, in board order.
func announce() -> void:
	for def in modifiers:
		EventBus.modifier_active.emit(def.id)


func has_decision_timer() -> bool:
	return decision_timer_sec > 0.0


# --- Per-throw rules --------------------------------------------------------


## A throw is starting: reset the per-throw rule state (wind side, covered
## notch, phasing notch, decision clock). Called by the board before the
## marble spawns, so the marble already carries the friction rule.
func on_throw_started() -> void:
	if value_shuffle:
		shuffle_values()
	if wind_strength > 0.0:
		wind_direction = -wind_direction
		EventBus.wind_changed.emit(wind_direction)
	if cover_notch:
		cover_previous_restore()
		cover_random_notch()
	if phase_notch:
		start_phase_notch()
	reset_decision()


## Mojado: the spawned marble rolls on the board's friction.
func apply_marble(marble: RigidBody3D) -> void:
	if is_equal_approx(friction_scale, 1.0) or marble == null:
		return
	var physics := marble.physics_material_override
	if physics != null:
		physics.friction *= friction_scale


## Per-wall multiplier the board accumulates for the current throw (Cuerda).
func wall_step() -> float:
	return wall_hit_mult


# --- Decision clock (Cronometrado) -----------------------------------------


func reset_decision() -> void:
	if not has_decision_timer():
		return
	decision_left = decision_timer_sec
	decision_tick = int(ceil(decision_left))
	EventBus.throw_timer_tick.emit(decision_tick)


## Advance the step clock; true when the step ran out and the board must
## take the decision with whatever the player had chosen.
func tick_decision(delta: float) -> bool:
	if not has_decision_timer():
		return false
	decision_left -= delta
	var tick := int(ceil(decision_left))
	if tick != decision_tick:
		decision_tick = tick
		EventBus.throw_timer_tick.emit(maxi(tick, 0))
	return decision_left <= 0.0


# --- Per-frame rules -------------------------------------------------------


func _physics_process(delta: float) -> void:
	if board == null or not is_instance_valid(board):
		return
	# Trapecio: the whole notch grid sways sideways. Hole positions and the
	# embedded marbles follow it (the board keeps them in board-local space).
	if grid_swing_speed > 0.0:
		swing_time += delta * grid_swing_speed
		board.apply_grid_offset(sin(swing_time) * SWING_AMPLITUDE)
	if phase_notch:
		_advance_phase(delta)
	if board.state != board.ThrowState.FLIGHT:
		return
	# Ventoso: a gentle sideways force while the marble rolls.
	if wind_strength > 0.0:
		_apply_wind()
	# Iman: embedded marbles pull the rolling one when it comes close.
	if magnet_strength > 0.0:
		_apply_magnet(delta)


func _apply_wind() -> void:
	var force := board.global_transform.basis.x.normalized() \
			* wind_strength * WIND_FORCE_SCALE * wind_direction
	for marble in board.active_marbles:
		if is_instance_valid(marble) and not marble.freeze:
			marble.apply_central_force(force * marble.mass)


func _apply_magnet(delta: float) -> void:
	var basis: Basis = board.board.global_transform.basis
	for marble in board.active_marbles:
		if not is_instance_valid(marble) or marble.freeze:
			continue
		var local: Vector3 = board.board.to_local(marble.global_position)
		for hole in board.holes:
			if not hole.occupied:
				continue
			var pull := Vector3(hole.pos.x - local.x, 0.0, hole.pos.z - local.z)
			var dist := pull.length()
			if dist > MAGNET_RANGE or dist < 0.001:
				continue
			if dist <= MAGNET_CONTACT_RADIUS:
				# Contact ring: the embedded marble blocks the pull target,
				# so force here only feeds the bounce loop. Drain speed
				# instead and let the physics settle the marble.
				marble.linear_velocity = marble.linear_velocity.move_toward(
						Vector3.ZERO, MAGNET_CONTACT_DAMP * delta)
				continue
			marble.apply_central_force(basis * pull.normalized()
					* magnet_strength * MAGNET_FORCE_SCALE * marble.mass)
			# One embedded marble pulls at a time: two opposite pulls would
			# cancel out and read as the magnet doing nothing.
			break
			# One embedded marble pulls at a time: two opposite pulls would
			# cancel out and read as the magnet doing nothing.
			break


# --- Notch rules -----------------------------------------------------------


## Borracho: repaint the notch values from the board's own pool. Only free
## notches shuffle: an embedded marble keeps the value it scored.
func shuffle_values() -> void:
	var free: Array[Dictionary] = []
	for hole in board.holes:
		if not hole.occupied:
			free.append(hole)
	if free.size() < 2:
		return
	var scores: Array[int] = []
	for hole in free:
		scores.append(int(hole.score))
	var seed_value := randi()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var shuffled: Array[int] = scores.duplicate()
	for i in range(shuffled.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap: int = shuffled[i]
		shuffled[i] = shuffled[j]
		shuffled[j] = swap
	if shuffled == scores:
		# Borracho always changes something: an identical order would read as
		# the modifier not firing at all.
		shuffled.append(shuffled.pop_front())
	for i in free.size():
		var hole := free[i]
		hole.score = shuffled[i]
		hole.label.text = str(shuffled[i])
	EventBus.value_shuffled.emit(seed_value)


## Mochila: clear the notch covered last throw before covering a new one.
func cover_previous_restore() -> void:
	if covered_index < 0 or covered_index >= board.holes.size():
		return
	var hole: Dictionary = board.holes[covered_index]
	hole.covered = false
	board.paint_hole(hole)
	covered_index = -1


## Mochila: one free notch cannot take a marble for the whole throw.
func cover_random_notch() -> void:
	var free: Array[int] = []
	for i in board.holes.size():
		var hole: Dictionary = board.holes[i]
		if not hole.occupied:
			free.append(i)
	if free.is_empty():
		return
	covered_index = free[randi_range(0, free.size() - 1)]
	var hole: Dictionary = board.holes[covered_index]
	hole.covered = true
	board.paint_hole(hole)


## Fantasma: pick the notch that phases this throw and start it visible.
func start_phase_notch() -> void:
	if phase_index >= 0 and phase_index < board.holes.size():
		var previous: Dictionary = board.holes[phase_index]
		previous.phase_hidden = false
		board.paint_hole(previous)
	phase_index = -1
	phase_hidden = false
	var free: Array[int] = []
	for i in board.holes.size():
		var hole: Dictionary = board.holes[i]
		if not hole.occupied:
			free.append(i)
	if free.is_empty():
		return
	phase_index = free[randi_range(0, free.size() - 1)]
	phase_time = 0.0
	board.paint_hole(board.holes[phase_index])


func _advance_phase(delta: float) -> void:
	if phase_index < 0 or phase_index >= board.holes.size():
		return
	phase_time += delta
	if phase_time < PHASE_PERIOD:
		return
	phase_time = 0.0
	phase_hidden = not phase_hidden
	var hole: Dictionary = board.holes[phase_index]
	hole.phase_hidden = phase_hidden
	board.paint_hole(hole)
