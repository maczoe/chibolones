class_name ObjectiveState
extends RefCounted
## Runtime view of one board's objective (design-decisions-v2.md D9): the
## board owns one instance and asks it after every score change, the
## winnability checker replays it over simulated throws. Invalid objective
## data degrades to threshold semantics here, so a bad .tres never crashes
## a run — it just plays like today's boards.

## Math rules a MATH objective accepts; anything else falls back to
## threshold.
const RULES: Array[StringName] = [&"even", &"odd", &"prime"]

var _kind: BoardDef.ObjectiveKind = BoardDef.ObjectiveKind.THRESHOLD
var _target := 0
var _range_min := 0
var _range_max := 0
var _goals: Array[int] = []
var _rule := &"even"
## Index of the next goal a LIST objective still has to hit exactly, in
## order. Cumulative totals that skip a goal do not count it; a later
## score change (consumables can bend score) may bring the total back.
var _next_goal := 0


## Build the state from a def, resolving invalid combinations to safe
## fallbacks: a range without sane bounds becomes exact of the target, an
## empty goal list or unknown math rule becomes threshold. `target_override`
## replaces the threshold target (the run scales it by block factor).
static func for_def(def: BoardDef, target_override := -1) -> ObjectiveState:
	var state := ObjectiveState.new()
	state._kind = BoardDef.ObjectiveKind.THRESHOLD
	state._target = def.objective_target
	if target_override >= 0:
		state._target = target_override
	match def.objective_kind:
		BoardDef.ObjectiveKind.EXACT:
			state._kind = BoardDef.ObjectiveKind.EXACT
		BoardDef.ObjectiveKind.RANGE:
			if def.objective_range_min > 0 and def.objective_range_max >= def.objective_range_min:
				state._kind = def.objective_kind
				state._range_min = def.objective_range_min
				state._range_max = def.objective_range_max
			else:
				state._kind = BoardDef.ObjectiveKind.EXACT
		BoardDef.ObjectiveKind.LIST, BoardDef.ObjectiveKind.ANY:
			if not def.objective_goals.is_empty():
				state._kind = def.objective_kind
				state._goals = def.objective_goals.duplicate()
			else:
				state._kind = BoardDef.ObjectiveKind.THRESHOLD
		BoardDef.ObjectiveKind.MATH:
			if RULES.has(def.objective_rule):
				state._kind = def.objective_kind
				state._rule = def.objective_rule
			else:
				state._kind = BoardDef.ObjectiveKind.THRESHOLD
		_:
			state._kind = BoardDef.ObjectiveKind.THRESHOLD
	return state


## The resolved kind (after fallbacks): the board and Game read it to
## decide scaling (only threshold scales, S8) and HUD text.
func kind() -> BoardDef.ObjectiveKind:
	return _kind


## True when the board is won at this cumulative total. THRESHOLD is
## today's `total >= target`; EXACT and RANGE compare bounds; LIST counts
## goals hit exactly and in order; MATH needs the minimum (target) plus
## the rule holding.
func evaluate(total: int) -> bool:
	match _kind:
		BoardDef.ObjectiveKind.EXACT:
			return total == _target
		BoardDef.ObjectiveKind.RANGE:
			return total >= _range_min and total <= _range_max
		BoardDef.ObjectiveKind.LIST:
			if _next_goal < _goals.size() and total == _goals[_next_goal]:
				_next_goal += 1
			return _next_goal >= _goals.size()
		BoardDef.ObjectiveKind.ANY:
			return _goals.has(total)
		BoardDef.ObjectiveKind.MATH:
			return total >= _target and _matches_rule(total)
	return total >= _target


## The objective as the player reads it on the HUD target line:
## "=100" (exact), "90-110" (range), "=80" (next list goal, live),
## "par >=100" (math) or the plain threshold number.
func target_text() -> String:
	match _kind:
		BoardDef.ObjectiveKind.EXACT:
			return "=%d" % _target
		BoardDef.ObjectiveKind.RANGE:
			return "%d-%d" % [_range_min, _range_max]
		BoardDef.ObjectiveKind.LIST:
			if _next_goal < _goals.size():
				return "=%d" % _goals[_next_goal]
			return "LISTO"
		BoardDef.ObjectiveKind.ANY:
			var labels: Array[String] = []
			for goal in _goals:
				labels.append(str(goal))
			return "=%s" % "/".join(labels)
		BoardDef.ObjectiveKind.MATH:
			return "%s >=%d" % [rule_label(), _target]
	return str(_target)


## The objective as the board-start cue announces it (one line, Spanish
## UI convention of this project).
func announce_text() -> String:
	match _kind:
		BoardDef.ObjectiveKind.EXACT:
			return "Objetivo exacto: termina con %d puntos" % _target
		BoardDef.ObjectiveKind.RANGE:
			return "Objetivo rango: termina entre %d y %d puntos" % [_range_min, _range_max]
		BoardDef.ObjectiveKind.LIST:
			var goals: Array[String] = []
			for goal in _goals:
				goals.append("=%d" % goal)
			return "Objetivo lista: suma %s en orden" % " y ".join(goals)
		BoardDef.ObjectiveKind.ANY:
			var any_goals: Array[String] = []
			for goal in _goals:
				any_goals.append(str(goal))
			return "Objetivo cualquiera: termina con %s puntos" % " o ".join(any_goals)
		BoardDef.ObjectiveKind.MATH:
			return "Objetivo %s: puntaje %s de al menos %d" % [rule_label(), rule_label(), _target]
	return ""


func rule_label() -> String:
	match _rule:
		&"even":
			return "par"
		&"odd":
			return "impar"
		&"prime":
			return "primo"
	return ""


## Index of the next goal a LIST objective still has to hit (0 when no
## goal was hit yet); the checker keys its search states on it.
func goal_progress() -> int:
	return _next_goal


## Independent copy of this state (same objective, own list-goal progress)
## so simulations never advance the live board's goal tracking.
func copy_state() -> ObjectiveState:
	var state := ObjectiveState.new()
	state._kind = _kind
	state._target = _target
	state._range_min = _range_min
	state._range_max = _range_max
	state._goals = _goals.duplicate()
	state._rule = _rule
	state._next_goal = _next_goal
	return state


func _matches_rule(total: int) -> bool:
	match _rule:
		&"even":
			return total % 2 == 0
		&"odd":
			return total % 2 == 1
		&"prime":
			return _is_prime(total)
	return false


func _is_prime(n: int) -> bool:
	if n < 2:
		return false
	if n % 2 == 0:
		return n == 2
	var d := 3
	while d * d <= n:
		if n % d == 0:
			return false
		d += 2
	return true
