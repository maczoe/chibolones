class_name BoardChecker
extends RefCounted
## Winnability checker (design-decisions-v2.md D12): every board must be
## winnable with a baseline inventory — 5 common marbles, 5 shots, no
## prizes. The checker proves it by analysis, not by hand runs: it searches
## the sequences of baseline hole values up to the shot budget and asks the
## board's own ObjectiveState whether any sequence wins.
##
## It is intentionally physics-free: values, not trajectories. A hole the
## baseline marble could physically miss still counts as reachable — the
## rule protects against impossible objectives (an exact =95 over
## {10,20,30,50}), not against hard aim.
##
## Content: data/boards/*.tres pass through check_all() in the headless
## CLI (tools/check_boards.gd); new board content must run green there
## before landing.


## One checker verdict for a board def.
class Report extends RefCounted:
	## True when some sequence of <= max shots of baseline hole values
	## satisfies the objective.
	var winnable := false
	## Shots the found example needs (0 when unwinnable).
	var shots_needed := 0
	## One winning sequence of hole values (the devlog's example line).
	var example: Array[int] = []
	## Why the board is unwinnable ("" when winnable).
	var reason := ""


## Baseline inventory (Game.STARTING_MARBLES is 5x common, and the common
## rules grant 5 shots per board): keep in sync with the run skeleton.
const BASELINE_SHOTS := 5


## Check one board def against the baseline marble set. Breadth-first over
## (cumulative total, list-goal progress) states — one state per pair, so
## LIST boards search sequences (goal order matters), not just totals.
static func check(def: BoardDef, max_shots: int = BASELINE_SHOTS) -> Report:
	var report := Report.new()
	var objective := ObjectiveState.for_def(def)
	var values := _hole_pool(def)
	if values.is_empty():
		report.reason = "every hole is a trap or scores 0: no throw can score"
		return report
	if objective.evaluate(0):
		# Degenerate objective already satisfied before the first throw.
		report.winnable = true
		return report
	var frontier: Array = [_node(0, [], objective)]
	var seen := {_state_key(0, objective): true}
	for shot in max_shots:
		var next: Array = []
		for node in frontier:
			for value in values:
				var total: int = node["total"] + value
				var candidate: ObjectiveState = node["obj"].copy_state()
				var line := (node["line"] as Array[int]).duplicate()
				line.append(value)
				if candidate.evaluate(total):
					report.winnable = true
					report.shots_needed = shot + 1
					report.example = line
					return report
				var key := _state_key(total, candidate)
				if not seen.has(key):
					seen[key] = true
					next.append(_node(total, line, candidate))
		frontier = next
		if frontier.is_empty():
			break
	report.reason = "no sequence of up to %d baseline values %s satisfies the objective %s" \
			% [max_shots, str(values), objective.target_text()]
	return report


## Check every indexed board: returns one Report per board, in
## ContentDB order (index == board number - 1).
static func check_all(content: Node) -> Array[Report]:
	var reports: Array[Report] = []
	for i in content.board_count():
		reports.append(check(content.board_def(i)))
	return reports


## Distinct positive values the board's holes carry (matrix entries with
## fallbacks, traps excluded).
static func _node(total: int, line: Array[int], obj: ObjectiveState) -> Dictionary:
	return {"total": total, "line": line, "obj": obj}


static func _state_key(total: int, obj: ObjectiveState) -> String:
	return "%d:%d" % [total, obj.goal_progress()]


static func _hole_pool(def: BoardDef) -> Array[int]:
	var pool := {}
	for row in def.rows:
		for col in def.cols:
			if def.is_trap_hole(row, col):
				continue
			var value := def.hole_value(row, col)
			if value > 0:
				pool[value] = true
	var values: Array[int] = []
	for value in pool:
		values.append(value)
	values.sort()
	return values
