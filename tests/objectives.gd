extends SceneTree
## D9+D12 test: objective kinds as data (BoardDef + ObjectiveState), the
## board scene wiring (win / overshoot / defeat per kind), per-hole value
## matrices with trap holes, and the winnability checker.
## Run: godot --headless --path . --script res://tests/objectives.gd

var failed := false
var game
var content


func _initialize() -> void:
	_ensure_autoloads()
	_run()


## In --script mode Godot does not register project autoloads; install the
## ones under test in dependency order (Game reads Economy, both read
## ContentDB for their content ids).
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
	_test_objective_defaults()
	_test_objective_evaluation()
	await _test_board_wiring()
	await _test_matrix_and_traps()
	_test_winnability_checker()
	_finish()


func _finish() -> void:
	print("OBJECTIVES FAIL" if failed else "OBJECTIVES OK")
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	print("OBJECTIVES FAIL: " + label)


# --- (a) Objective kinds as BoardDef data (D9, S1) --------------------------


func _test_objective_defaults() -> void:
	# Existing boards carry no objective_kind key: they must keep today's
	# semantics (threshold over objective_target) untouched.
	var def := BoardDef.new()
	_check(def.objective_kind == BoardDef.ObjectiveKind.THRESHOLD,
			"a fresh BoardDef should default to THRESHOLD, got %s" % def.objective_kind)
	_check(def.objective_target == 0,
			"a fresh BoardDef should default to objective_target 0")
	_check(def.objective_goals.is_empty(),
			"a fresh BoardDef should default to no goal list")
	_check(def.objective_rule == &"even",
			"a fresh BoardDef should default to the 'even' math rule")
	# D12 defaults: no matrix, no trap holes.
	_check(def.hole_values.is_empty(),
			"a fresh BoardDef should default to no per-hole matrix")
	_check(def.hole_value(2, 3) == def.row_scores[2],
			"without a matrix, hole_value(row, col) should fall back to row_scores")


# --- (b) Objective evaluation per kind (S1, S3, S8) -------------------------


func _test_objective_evaluation() -> void:
	# THRESHOLD: today's behavior, total >= target.
	var threshold := _state(_def(BoardDef.ObjectiveKind.THRESHOLD, 100))
	_check(not threshold.evaluate(99), "threshold 99 should not satisfy target 100")
	_check(threshold.evaluate(100), "threshold 100 should satisfy target 100")
	_check(threshold.evaluate(140), "threshold 140 should satisfy target 100")

	# EXACT: total == target; overshoot is NOT satisfied (but never loses
	# instantly — that lives in the board wiring, tested below).
	var exact := _state(_def(BoardDef.ObjectiveKind.EXACT, 100))
	_check(not exact.evaluate(99), "exact 99 should not satisfy =100")
	_check(exact.evaluate(100), "exact 100 should satisfy =100")
	_check(not exact.evaluate(101), "exact 101 should not satisfy =100")

	# RANGE: inclusive bounds (D9 open question resolved as an exact variant).
	var range_def := _def(BoardDef.ObjectiveKind.RANGE, 100)
	range_def.objective_range_min = 90
	range_def.objective_range_max = 110
	var range := _state(range_def)
	_check(not range.evaluate(89), "range 89 should not satisfy 90-110")
	_check(range.evaluate(90), "range 90 should satisfy 90-110")
	_check(range.evaluate(110), "range 110 should satisfy 90-110")
	_check(not range.evaluate(111), "range 111 should not satisfy 90-110")

	# LIST: cumulative totals hit in order; skipping a goal blocks progress.
	var list := _state(_def(BoardDef.ObjectiveKind.LIST, 0, [50, 80, 120]))
	_check(not list.evaluate(60), "list 60 should not hit goal =50")
	_check(not list.evaluate(50), "list =50 alone should not win the board")
	_check(not list.evaluate(80), "list =80 after =50 should not win yet")
	_check(list.evaluate(120), "list =120 after =50,=80 should win")
	var skipped := _state(_def(BoardDef.ObjectiveKind.LIST, 0, [50, 80]))
	_check(not skipped.evaluate(80), "list jumping to =80 without =50 should not count the goal")
	_check(not skipped.evaluate(50), "list hitting =50 late should still count once")
	_check(skipped.evaluate(80), "list =50 then =80 should win")

	# MATH: rule holds once the minimum (target) is reached.
	var even := _state(_def(BoardDef.ObjectiveKind.MATH, 100, [], &"even"))
	_check(not even.evaluate(98), "even 98 below minimum 100 should not win")
	_check(not even.evaluate(101), "even 101 odd should not win")
	_check(even.evaluate(100), "even 100 should win")
	var odd := _state(_def(BoardDef.ObjectiveKind.MATH, 100, [], &"odd"))
	_check(odd.evaluate(101), "odd 101 should win")
	_check(not odd.evaluate(102), "odd 102 even should not win")
	var prime := _state(_def(BoardDef.ObjectiveKind.MATH, 70, [], &"prime"))
	_check(prime.evaluate(71), "prime 71 >= 70 should win")
	_check(not prime.evaluate(72), "prime 72 composite should not win")
	_check(not prime.evaluate(70), "prime 70 composite should not win")

	# Invalid objective data falls back to threshold, never crashes.
	var bad_range := _state(_def(BoardDef.ObjectiveKind.RANGE, 60))
	# No bounds set: a range without min/max is an exact variant of target.
	_check(bad_range.evaluate(60), "range without bounds should fall back to exact of target")
	_check(not bad_range.evaluate(61), "range fallback should reject 61 for target 60")
	var bad_rule := _state(_def(BoardDef.ObjectiveKind.MATH, 60, [], &"fibonacci"))
	_check(bad_rule.evaluate(60), "unknown math rule should fall back to threshold")
	var bad_list := _state(_def(BoardDef.ObjectiveKind.LIST, 60, []))
	_check(bad_list.evaluate(60), "empty goal list should fall back to threshold")


func _def(kind: int, target: int, goals: Array = [], rule: StringName = &"even") -> BoardDef:
	var def := BoardDef.new()
	def.objective_kind = kind
	def.objective_target = target
	def.objective_goals.assign(goals.duplicate())
	def.objective_rule = rule
	return def


# --- (c) Board scene wiring per kind (S1, S3, S7) ---------------------------


## Open a board inside a run over a def mutated in memory to carry the
## given objective; the ContentDB cache hands the same instance to the
## board scene, so no test .tres is needed.
func _open_kind_board(kind: int, target: int, goals: Array = [],
			rule: StringName = &"even", range_min := 0, range_max := 0) -> Node:
	game.start_run()
	game.current_board_in_run = 1
	var def: BoardDef = content.board_def(0)
	def.objective_kind = kind
	def.objective_target = target
	def.objective_goals.assign(goals.duplicate())
	def.objective_rule = rule
	def.objective_range_min = range_min
	def.objective_range_max = range_max
	var board: Node3D = (load("res://scenes/board/board.tscn") as PackedScene).instantiate()
	root.add_child(board)
	await physics_frame
	return board


func _reset_def() -> void:
	var def: BoardDef = content.board_def(0)
	def.objective_kind = BoardDef.ObjectiveKind.THRESHOLD
	def.objective_target = 60
	def.objective_goals.clear()
	def.objective_range_min = 0
	def.objective_range_max = 0


func _text(node: Node, label_name: String) -> String:
	if node == null:
		return ""
	var label = node.get(label_name)
	return "" if label == null else str(label.text)


func _test_board_wiring() -> void:
	# EXACT: the HUD names the kind, the exact total wins, an overshoot
	# does NOT win instantly (S3) and loses only when shots run out.
	var board = await _open_kind_board(BoardDef.ObjectiveKind.EXACT, 50)
	_check(_text(board.hud, "label_target") == "0 / =50",
			"exact HUD should read '0 / =50', got '%s'" % _text(board.hud, "label_target"))
	_check(_text(board.hud, "label_board_effects").contains("exacto"),
			"exact board should announce its objective, got '%s'"
			% _text(board.hud, "label_board_effects"))
	root.get_node("EventBus").embed.emit(0, 50)
	await physics_frame
	_check(board.score_engine.total == 50, "exact embed should score 50, got %d" % board.score_engine.total)
	_check(board.board_result_sent, "exact total 50 should win the board")
	board.queue_free()
	await physics_frame

	board = await _open_kind_board(BoardDef.ObjectiveKind.EXACT, 50)
	root.get_node("EventBus").embed.emit(0, 60)
	await physics_frame
	_check(board.score_engine.total == 60, "overshoot embed should score 60")
	_check(not board.board_result_sent, "overshoot 60 over =50 should NOT win instantly (S3)")
	board.shots_left = 0
	board._round_over()
	await physics_frame
	_check(board.board_result_sent, "overshoot with no shots left should lose the board")
	_check(_text(board.hud, "label_final").contains("=50"),
			"exact defeat should name the missed objective, got '%s'"
			% _text(board.hud, "label_final"))
	board.queue_free()
	await physics_frame

	# RANGE: HUD shows the inclusive bounds.
	board = await _open_kind_board(BoardDef.ObjectiveKind.RANGE, 50, [], &"even", 40, 60)
	_check(_text(board.hud, "label_target") == "0 / 40-60",
			"range HUD should read '0 / 40-60', got '%s'" % _text(board.hud, "label_target"))
	root.get_node("EventBus").embed.emit(0, 55)
	await physics_frame
	_check(board.board_result_sent, "range total 55 inside 40-60 should win")
	board.queue_free()
	await physics_frame

	# LIST: HUD tracks the next goal; hitting all goals in order wins.
	board = await _open_kind_board(BoardDef.ObjectiveKind.LIST, 0, [20, 40])
	_check(_text(board.hud, "label_target") == "0 / =20",
			"list HUD should read '0 / =20', got '%s'" % _text(board.hud, "label_target"))
	root.get_node("EventBus").embed.emit(0, 15)
	await physics_frame
	_check(_text(board.hud, "label_target") == "15 / =20",
			"list HUD should still ask for =20 at 15, got '%s'" % _text(board.hud, "label_target"))
	_check(not board.board_result_sent, "list 15 should not hit =20")
	root.get_node("EventBus").embed.emit(0, 5)
	await physics_frame
	_check(_text(board.hud, "label_target") == "20 / =40",
			"list HUD should advance to =40 after hitting =20, got '%s'"
			% _text(board.hud, "label_target"))
	root.get_node("EventBus").embed.emit(0, 20)
	await physics_frame
	_check(board.board_result_sent, "list =20 then =40 should win")
	board.queue_free()
	await physics_frame

	# MATH: HUD names the rule; even rule wins on an even total past the
	# minimum, never on an odd one.
	board = await _open_kind_board(BoardDef.ObjectiveKind.MATH, 20, [], &"even")
	_check(_text(board.hud, "label_target").contains("par"),
			"math HUD should name the rule, got '%s'" % _text(board.hud, "label_target"))
	root.get_node("EventBus").embed.emit(0, 21)
	await physics_frame
	_check(not board.board_result_sent, "math odd 21 should not win an even board")
	root.get_node("EventBus").embed.emit(0, 1)
	await physics_frame
	_check(board.board_result_sent, "math even 22 past minimum 20 should win")
	board.queue_free()
	await physics_frame

	# THRESHOLD semantics are untouched: scaled target, plain HUD line.
	game.start_run()
	game.current_board_in_run = 1
	var def: BoardDef = content.board_def(0)
	def.objective_kind = BoardDef.ObjectiveKind.THRESHOLD
	def.objective_target = 60
	var plain: Node3D = (load("res://scenes/board/board.tscn") as PackedScene).instantiate()
	root.add_child(plain)
	await physics_frame
	_check(plain.run_objective == 60, "threshold board 1 should keep target 60, got %d" % plain.run_objective)
	_check(_text(plain.hud, "label_target") == "0 / 60",
			"threshold HUD should keep the score/target line, got '%s'" % _text(plain.hud, "label_target"))
	_check(not _text(plain.hud, "label_board_effects").contains("Objetivo"),
			"threshold board should not announce a special objective, got '%s'"
			% _text(plain.hud, "label_board_effects"))
	plain.queue_free()
	await physics_frame
	_reset_def()


# --- (d) Per-hole value matrix + trap holes (D12, S4, S5) -------------------


func _open_matrix_board() -> Node:
	game.start_run()
	game.current_board_in_run = 1
	var def: BoardDef = content.board_def(0)
	def.objective_kind = BoardDef.ObjectiveKind.THRESHOLD
	def.objective_target = 60
	# Row-major matrix over the default 5x4 grid: first 7 entries custom,
	# the rest fall back to row_scores. Traps: hole 0 (row 0, col 0) and
	# hole 7 (row 1, col 2).
	def.hole_values.assign([5, 10, 5, 10, 5, 10, 20])
	def.trap_holes.assign([true, false, false, false, false, false, false, true])
	var board: Node3D = (load("res://scenes/board/board.tscn") as PackedScene).instantiate()
	root.add_child(board)
	await physics_frame
	return board


func _reset_matrix_def() -> void:
	var def: BoardDef = content.board_def(0)
	def.hole_values.clear()
	def.trap_holes.clear()


func _test_matrix_and_traps() -> void:
	var board = await _open_matrix_board()
	# Matrix values land on the holes and their painted labels.
	_check(int(board.holes[1].score) == 10, "hole 1 should carry matrix value 10, got %d" % board.holes[1].score)
	_check(int(board.holes[6].score) == 20, "hole 6 should carry matrix value 20, got %d" % board.holes[6].score)
	_check(str(board.holes[6].label.text) == "20", "hole 6 label should read '20', got '%s'" % board.holes[6].label.text)
	# Entries beyond the matrix fall back to the row default.
	_check(int(board.holes[8].score) == board_def_row_score(1),
			"hole 8 should fall back to its row score, got %d" % board.holes[8].score)
	_check(int(board.holes[19].score) == board_def_row_score(3),
			"hole 19 should fall back to its row score, got %d" % board.holes[19].score)

	# Trap holes: flagged in the dict, painted as X, not counted as values.
	_check(bool(board.holes[0].trap), "hole 0 should be a trap")
	_check(bool(board.holes[7].trap), "hole 7 should be a trap")
	_check(not bool(board.holes[1].trap), "hole 1 should not be a trap")
	_check(str(board.holes[0].label.text) == "X", "trap label should read 'X', got '%s'" % board.holes[0].label.text)
	_check(int(board.holes[0].score) == 0, "a trap hole should score 0, got %d" % board.holes[0].score)

	# Embedding into a trap voids the throw (S5): no score, no ammo spent,
	# the marble leaves the board and can be thrown again.
	var ammo_before: int = game.ammo.size()
	var marble := RigidBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	marble.add_child(shape)
	board.board.add_child(marble)
	marble.global_position = board.board.to_global(board.holes[0].pos)
	board.active_marbles.append(marble)
	board._embed(marble, board.holes[0], 0.0)
	await physics_frame
	_check(board.score_engine.total == 0, "a trap embed should not score, got %d" % board.score_engine.total)
	_check(game.ammo.size() == ammo_before,
			"a trap embed should not spend ammo (tiro anulado), got %d of %d"
			% [game.ammo.size(), ammo_before])
	_check(not marble in board.active_marbles, "the trapped marble should leave the board")
	_check(str(board.pending_result).contains("trampa"),
			"the trap should tell the player, got '%s'" % str(board.pending_result))
	_check(not bool(board.holes[0].occupied), "a trap hole should stay open for repeat danger")

	# A normal hole on the same board still scores through the matrix.
	var normal := RigidBody3D.new()
	var nshape := CollisionShape3D.new()
	nshape.shape = SphereShape3D.new()
	normal.add_child(nshape)
	board.board.add_child(normal)
	normal.global_position = board.board.to_global(board.holes[6].pos)
	board.active_marbles.append(normal)
	board._embed(normal, board.holes[6], 0.0)
	await physics_frame
	_check(board.score_engine.total == 20, "matrix hole 6 should score 20, got %d" % board.score_engine.total)

	# Borracho's value shuffle never touches traps: the X stays an X and
	# the 0 stays out of the shuffle pool.
	board.board_theme.shuffle_values()
	_check(str(board.holes[0].label.text) == "X",
			"shuffle should keep the trap X, got '%s'" % board.holes[0].label.text)
	_check(int(board.holes[0].score) == 0,
			"shuffle should keep the trap score 0, got %d" % board.holes[0].score)
	board.queue_free()
	await physics_frame
	_reset_matrix_def()


# --- (e) Winnability checker (D12, S6) --------------------------------------


func _test_winnability_checker() -> void:
	# Classic def, threshold 60, five 10/20/30/50 rows: winnable with 5
	# baseline shots (e.g. 10+50 or 20+20+20).
	var def: BoardDef = content.board_def(0)
	def.objective_kind = BoardDef.ObjectiveKind.THRESHOLD
	def.objective_target = 60
	def.hole_values.clear()
	def.trap_holes.clear()
	var report := BoardChecker.check(def)
	_check(report.winnable, "classic threshold 60 should be winnable")
	_check(report.shots_needed <= 5,
			"classic board should win within 5 baseline shots, needs %d" % report.shots_needed)
	_check(report.example.size() > 0 and _sum(report.example) >= 60,
			"the example line should reach the objective, got %s" % str(report.example))

	# The hole pool excludes traps (they void the throw, they never score).
	def.trap_holes.assign([true, true, true, true, true, true, true, true, true, true,
			true, true, true, true, true, true, true, true, true, true])
	report = BoardChecker.check(def)
	_check(not report.winnable, "a board of only traps is not winnable")
	def.trap_holes.clear()

	# Unreachable exact target: no hole combination hits =95.
	def.objective_kind = BoardDef.ObjectiveKind.EXACT
	def.objective_target = 95
	report = BoardChecker.check(def)
	_check(not report.winnable, "exact =95 over {10,20,30,50} should be unwinnable")
	_check(report.reason != "", "an unwinnable board should explain why")

	# Reachable exact target with a reachable-by-2 example.
	def.objective_target = 100
	report = BoardChecker.check(def)
	_check(report.winnable, "exact =100 over {10,20,30,50} should be winnable")
	_check(_sum(report.example) == 100,
			"exact example should sum exactly 100, got %d" % _sum(report.example))

	# Goal list: goals must be hit in order by cumulative totals.
	def.objective_kind = BoardDef.ObjectiveKind.LIST
	def.objective_goals.assign([20, 50])
	report = BoardChecker.check(def)
	_check(report.winnable, "list =20 then =50 over {10,20,30,50} should be winnable")
	_check(_sum(report.example) == 50, "list example should end at 50, got %d" % _sum(report.example))

	# Math rule: even target reachable.
	def.objective_kind = BoardDef.ObjectiveKind.MATH
	def.objective_rule = &"even"
	def.objective_target = 20
	report = BoardChecker.check(def)
	_check(report.winnable, "math even >=20 should be winnable")

	# Range bounds reachable.
	def.objective_kind = BoardDef.ObjectiveKind.RANGE
	def.objective_range_min = 90
	def.objective_range_max = 110
	report = BoardChecker.check(def)
	_check(report.winnable, "range 90-110 over {10,20,30,50} should be winnable")
	_reset_def()


## Row score of the classic def (data accessor for the fallback checks).
func board_def_row_score(row: int) -> int:
	return content.board_def(0).row_scores[row]


func _state(def: BoardDef) -> ObjectiveState:
	return ObjectiveState.for_def(def)


func _sum(values: Array[int]) -> int:
	var total := 0
	for value in values:
		total += value
	return total
