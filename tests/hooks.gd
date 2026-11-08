extends SceneTree
## M2 hook contract test: the scoring pipeline (ScoreBreakdown + the prize
## and bonificador contributions), the 10 bonificadores as data, and the
## board runtime rules that fight over a throw (Borracho shuffle,
## Cronometrado timer, Espejo center, glass durability).
## Run: godot --headless --path . --script res://tests/hooks.gd

var game
var content
var failed := false
var embeds: Array = []           # [notch_index, value] pairs seen on the bus
var broke: Array = []            # [def_id, reason] pairs from marble_removed
var shuffle_seeds: Array = []    # value_shuffled payloads
var timer_ticks: Array = []      # throw_timer_tick payloads
var wind_directions: Array = []  # wind_changed payloads


func _initialize() -> void:
	_ensure_autoloads()
	_run()


## In --script mode Godot does not register project autoloads; install the
## ones under test in dependency order (Game reads Economy, every def read
## goes through ContentDB).
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
	_test_breakdown_math()
	await _test_throw_lifecycle_events()
	await _test_prize_contribution()
	_test_modifier_defs()
	await _test_value_shuffle()
	await _test_decision_timer()
	await _test_glass_break()
	await _test_center_mult()
	await _test_rule_wiring()
	await _test_wall_mult_preserved()
	await _test_on_event_dispatch()
	await _test_refund_money_effect()
	await _test_board_end_bonus()
	await _test_extra_throw_prize()
	await _test_bounce_prize()
	await _test_fire_speed_prize()
	await _test_skip_speed_prize()
	await _test_global_mult_prize()
	await _test_trompo_migration()
	print("HOOKS FAIL" if failed else "HOOKS OK")
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	print("HOOKS FAIL: " + label)


func _connect_bus() -> void:
	var bus := root.get_node("EventBus")
	bus.embed.connect(func(index, value): embeds.append([index, value]))
	bus.marble_removed.connect(func(def_id, reason): broke.append([def_id, reason]))
	bus.value_shuffled.connect(func(board_seed): shuffle_seeds.append(board_seed))
	bus.throw_timer_tick.connect(func(seconds_left): timer_ticks.append(seconds_left))
	bus.wind_changed.connect(func(direction): wind_directions.append(direction))


# --- (a) ScoreBreakdown math (S1) -------------------------------------------


func _test_breakdown_math() -> void:
	var breakdown := ScoreBreakdown.new()
	breakdown.base_value = 10
	breakdown.adds[&"Peso"] = 5
	breakdown.mults[&"Trompo"] = 1.5
	_check(breakdown.final() == 23,
			"(10 + 5) x 1.5 should be 23, got %d" % breakdown.final())
	var line := breakdown.describe()
	_check(line.contains("Peso") and line.contains("Trompo"),
			"describe should name its sources, got '%s'" % line)
	var empty := ScoreBreakdown.new()
	empty.base_value = 7
	_check(empty.final() == 7,
			"a breakdown with nothing acting should score its base, got %d" % empty.final())
	_check(empty.describe() == "",
			"a breakdown with nothing acting should describe nothing, got '%s'"
			% empty.describe())


# --- (b) Prize contribution through the pipeline (S1) -----------------------


func _test_prize_contribution() -> void:
	game.start_run()
	var board := _open_board()
	await physics_frame
	# One wall hit this throw, one x2 board-side wall multiplier (a modifier
	# like Cuerda): the trompo adds its own x1.5 inside the hook.
	var ctx := {
		"board": board,
		"throw": {
			"marble": null,
			"wall_hits": 1,
			"wall_mult": 2.0,
			"wall_source": &"Paredes",
			"center": false,
		},
	}
	var breakdown: ScoreBreakdown = board.score_engine.evaluate_embed(10, ctx)
	_check(breakdown.final() == 30,
			"trompo x1.5 on a x2 wall board should score 30, got %d" % breakdown.final())
	_check(breakdown.mults.has(StringName("Trompo de Madera")),
			"the breakdown should name the trompo, mults are %s" % str(breakdown.mults))
	board.queue_free()
	await physics_frame


# --- (c) The 10 bonificadores as data (S2) ----------------------------------


func _test_modifier_defs() -> void:
	var expected := {
		&"cuerda": {"wall_bounciness": 0.15, "wall_hit_mult": 1.2},
		&"mojado": {"friction_scale": 0.45},
		&"borracho": {"value_shuffle": true},
		&"espejo": {"center_mult": 2.0},
		&"ventoso": {"wind_strength": 1.2},
		&"mochila": {"cover_notch": true},
		&"fantasma": {"phase_notch": true},
		&"iman": {"magnet_strength": 1.5},
		&"trapecio": {"grid_swing_speed": 1.0},
		&"cronometrado": {"decision_timer_sec": 4.0},
	}
	var seen := {}
	for id in expected:
		var def: BoardModifierDef = content.modifier_def(id)
		_check(def != null, "modifier '%s' should load from data/modifiers" % id)
		if def == null:
			continue
		_check(not seen.has(def.id), "modifier id '%s' is duplicated" % def.id)
		seen[def.id] = true
		_check(def.display_name != "" and def.description != "",
				"modifier '%s' needs a name and a Spanish flavor line" % id)
		for field in expected[id]:
			var want = expected[id][field]
			var got = def.get(field)
			if want is float:
				_check(is_equal_approx(float(got), float(want)),
						"modifier '%s' %s should be %s, got %s"
						% [id, field, want, got])
			else:
				_check(got == want,
						"modifier '%s' %s should be %s, got %s"
						% [id, field, want, got])
	_check(content.modifiers().size() == expected.size(),
			"ContentDB should index 10 modifiers, got %d" % content.modifiers().size())


# --- (d) Borracho value shuffle (S2) ---------------------------------------


func _test_value_shuffle() -> void:
	shuffle_seeds.clear()
	var board := _open_board_with([content.modifier_def(&"borracho")])
	await physics_frame
	var before := _hole_scores(board)
	var changed := false
	for i in 3:
		board._launch(0.0, 20.0)
		await physics_frame
		var after := _hole_scores(board)
		_check(after.size() == before.size(), "shuffle must keep the notch count")
		_check(_same_multiset(before, after),
				"borracho must only shuffle values, %s -> %s" % [str(before), str(after)])
		if after != before:
			changed = true
		before = after
		_clear_marbles(board)
	_check(changed, "borracho should change the value order within 3 throws")
	_check(not shuffle_seeds.is_empty(), "borracho should emit value_shuffled")
	board.queue_free()
	await physics_frame


# --- (e) Cronometrado decision timer (S2) ----------------------------------


func _test_decision_timer() -> void:
	# Load the real def and shorten the clock for test speed: the .tres keeps
	# the design 4 seconds.
	var def: BoardModifierDef = content.modifier_def(&"cronometrado").duplicate()
	def.decision_timer_sec = 0.5
	timer_ticks.clear()
	var board := _open_board_with([def])
	await physics_frame
	_check(board.state == board.ThrowState.AIM, "the board should open in AIM, state is %s" % board.state)
	var waited := 0.0
	while board.state == board.ThrowState.AIM and waited < 1.2:
		await physics_frame
		waited += 1.0 / 60.0
	_check(board.state == board.ThrowState.TILT,
			"cronometrado should auto-advance AIM -> TILT, state is %s" % board.state)
	_check(not timer_ticks.is_empty(),
			"cronometrado should emit throw_timer_tick every second")
	board.queue_free()
	await physics_frame


# --- (f) Glass break (S3) --------------------------------------------------


func _test_glass_break() -> void:
	game.start_run()
	# The .tres keeps break_chance 0.0 until data/ reopens in M3; the test
	# builds the durable glass marble itself.
	var brittle: MarbleDef = content.marble_def("glass").duplicate()
	brittle.break_chance = 1.0
	# A normal run owns five commons (S10): the first one becomes the glass.
	game.inventory[0] = brittle
	var board := _open_board()
	await physics_frame
	var ammo_before: int = game.ammo.size()
	board.selected_ammo_index = 0
	broke.clear()
	board._launch(0.0, 20.0)
	_check(game.ammo.size() == ammo_before - 1,
			"a broken glass marble should leave the ammo (%d -> %d)"
			% [ammo_before, game.ammo.size()])
	_check(broke.size() == 1,
			"a break should emit marble_removed once, got %d" % broke.size())
	if broke.size() == 1:
		_check(broke[0][0] == "glass" and broke[0][1] == &"broke",
				"marble_removed should carry ('glass', 'broke'), got %s" % str(broke[0]))
	_check(board.launched_def != null and board.launched_def.id != "glass",
			"the throw should continue with another marble, got '%s'"
			% (board.launched_def.id if board.launched_def != null else "none"))
	_clear_marbles(board)
	board.queue_free()
	await physics_frame

	# break_chance 0.0 never breaks: nothing leaves the ammo, no event. The
	# .tres glass now carries the approved 25% (content, not mechanic), so
	# the test builds its own durable marble instead of trusting data.
	game.start_run()
	var safe_def: MarbleDef = content.marble_def("glass").duplicate()
	safe_def.break_chance = 0.0
	game.inventory[0] = safe_def
	var safe := _open_board()
	await physics_frame
	var ammo_intact: int = game.ammo.size()
	safe.selected_ammo_index = 0
	broke.clear()
	safe._launch(0.0, 20.0)
	_check(game.ammo.size() == ammo_intact,
			"break_chance 0 should keep the ammo intact (%d -> %d)"
			% [ammo_intact, game.ammo.size()])
	_check(broke.is_empty(), "break_chance 0 should not emit marble_removed")
	_clear_marbles(safe)
	safe.queue_free()
	await physics_frame


# --- (g) Espejo center multiplier (S2) -------------------------------------


func _test_center_mult() -> void:
	var board := _open_board_with([content.modifier_def(&"espejo")])
	await physics_frame
	var center: Dictionary = {}
	for hole in board.holes:
		if hole.col == (board.board_def.cols - 1) / 2:
			center = hole
			break
	_check(not center.is_empty(), "the classic board should have a center column")
	if center.is_empty():
		board.queue_free()
		await physics_frame
		return
	board.launched_def = content.marble_def("common")
	board.wall_mult = 1.0
	board.wall_hits = 0
	embeds.clear()
	var base: int = int(center.score)
	board._embed(_loose_marble(board), center)
	_check(embeds.size() == 1, "the embed should reach the bus")
	if embeds.size() == 1:
		_check(int(embeds[0][1]) == base * 2,
				"espejo should double the %d base, got %d" % [base, embeds[0][1]])
	_check(board.hud.label_breakdown.text.contains("Espejo"),
			"the HUD should show the espejo breakdown, got '%s'"
			% board.hud.label_breakdown.text)
	board.queue_free()
	await physics_frame


# --- (h) Physics rule wiring (S2) -----------------------------------------


func _test_rule_wiring() -> void:
	# The rules that act on physics and on the notch grid: the board must
	# announce the wind side per throw and sway the grid with the holes
	# (capture reads those positions, so they have to move together).
	wind_directions.clear()
	var board := _open_board_with([
		content.modifier_def(&"ventoso"),
		content.modifier_def(&"trapecio"),
		content.modifier_def(&"iman"),
	])
	await physics_frame
	var start_x: float = board.holes[0].pos.x
	board._launch(0.0, 20.0)
	_check(not wind_directions.is_empty() and wind_directions[0] != 0.0,
			"ventoso should announce its wind side every throw, got %s"
			% str(wind_directions))
	if not wind_directions.is_empty():
		_check(board.board_theme.wind_direction == wind_directions[0],
				"the wind side should match the announced one")
	for i in 20:
		await physics_frame
	_check(not is_equal_approx(board.holes[0].pos.x, start_x),
			"trapecio should sway the notch grid")
	_check(is_equal_approx(board.holes[0].pos.x,
			board.holes[0].base.x + board.notch_root.position.x),
			"hole positions must follow the swung grid")
	_clear_marbles(board)
	board.queue_free()
	await physics_frame


# --- (i) PRESERVE: M1 wall-hit math and plain embeds -----------------------


func _test_wall_mult_preserved() -> void:
	# The trompo still multiplies once per wall, and a board with nothing to
	# say about the score still scores the painted value untouched.
	game.start_run()
	game.run_active = false  # run prizes without the run's board modifiers
	var board := _open_board()
	await physics_frame
	board.launched_def = content.marble_def("common")
	board.wall_mult = 1.0
	board.wall_hits = 0
	board._on_wall_hit(&"back", 2.0)
	board._on_wall_hit(&"left", 2.0)
	_check(board.wall_hits == 2, "two walls should be counted, got %d" % board.wall_hits)
	var hole := _hole_with_score(board, 20)
	embeds.clear()
	board._embed(_loose_marble(board), hole)
	var expected := roundi(20.0 * 1.5 * 1.5)
	_check(embeds.size() == 1 and int(embeds[0][1]) == expected,
		"trompo on 20 after two walls should score %d, got %s"
		% [expected, str(embeds)])
	board.queue_free()
	await physics_frame

	# No prize owned: the base value passes through unchanged.
	game.prizes.clear()
	var plain := _open_board()
	await physics_frame
	plain.launched_def = content.marble_def("common")
	plain.wall_mult = 1.0
	plain.wall_hits = 0
	var plain_hole := _hole_with_score(plain, 20)
	embeds.clear()
	plain._embed(_loose_marble(plain), plain_hole)
	_check(embeds.size() == 1 and int(embeds[0][1]) == 20,
		"a prize-less board should score the painted value, got %s" % str(embeds))
	_check(plain.hud.label_breakdown.text == "",
		"a clean embed should show no score math, got '%s'"
		% plain.hud.label_breakdown.text)
	plain.queue_free()
	await physics_frame
	game.start_run()


# --- (j) W3 on_event contract (S4) -----------------------------------------


## Records every event the dispatcher delivers, with a copy of its ctx.
class SpyPrize extends PrizeDef:
	var seen: Array = []

	func interested_in() -> Array[StringName]:
		return [&"refund", &"board_ended", &"marble_spawn", &"throw_started", &"wall_hit", &"throw_ended"]

	func on_event(event: StringName, ctx: Dictionary) -> void:
		seen.append([event, ctx.duplicate()])


## Same spy, for the board-side modifier half of the contract.
class SpyModifier extends BoardModifierDef:
	var seen: Array = []

	func interested_in() -> Array[StringName]:
		return [&"throw_started"]

	func on_event(event: StringName, ctx: Dictionary) -> void:
		seen.append([event, ctx.duplicate()])


## The dispatcher delivers only to interested defs: run prizes and, through
## ctx.board, the board's own bonificadores.
func _test_on_event_dispatch() -> void:
	game.start_run()
	var spy := SpyPrize.new()
	game.prizes.clear()
	game.prizes.append(spy)
	game.dispatch_event(&"refund", {"k": 1})
	_check(spy.seen.size() == 1 and spy.seen[0][0] == &"refund" and spy.seen[0][1]["k"] == 1,
			"dispatch should deliver a refund to the interested prize, got %s" % str(spy.seen))
	game.dispatch_event(&"embed", {})
	_check(spy.seen.size() == 1, "dispatch must skip events the prize did not declare")
	var spy_mod := SpyModifier.new()
	var board := _open_board_with([spy_mod])
	await physics_frame
	game.dispatch_event(&"throw_started", {"board": board})
	_check(spy_mod.seen.size() == 1 and spy_mod.seen[0][0] == &"throw_started",
			"dispatch should reach the board's bonificadores through ctx.board")
	board.queue_free()
	await physics_frame


## The refund event carries a money_delta the prize fills and Game applies
## (Billete de la Suerte in T3): one dispatch per refund, no double count.
func _test_refund_money_effect() -> void:
	game.start_run()
	var billete := PrizeDef.new()
	billete.id = "billete"
	billete.display_name = "Billete de la Suerte"
	billete.effect = &"refund_money"
	billete.params = {"amount": 2}
	game.prizes.clear()
	game.prizes.append(billete)
	var money_before: int = game.money
	root.get_node("EventBus").refund.emit()
	_check(game.money == money_before + 2,
			"a $2 refund prize should add $2 on refund, money %d -> %d"
			% [money_before, game.money])
	var neutral := PrizeDef.new()
	neutral.id = "neutral"
	game.prizes.clear()
	game.prizes.append(neutral)
	money_before = game.money
	root.get_node("EventBus").refund.emit()
	_check(game.money == money_before,
			"a prize-less refund must not change money")


## A board_end_flat prize adds its flat bonus to the final board score
## before anything reads it (Osito de Peluche in T3).
func _test_board_end_bonus() -> void:
	game.start_run()
	var osito := PrizeDef.new()
	osito.id = "osito"
	osito.display_name = "Osito de Peluche"
	osito.effect = &"board_end_flat"
	osito.params = {"flat": 50}
	game.prizes.clear()
	game.prizes.append(osito)
	var board := _open_board()
	await physics_frame
	var objective: int = board.run_objective
	root.get_node("EventBus").embed.emit(0, objective)
	# The win is reported by the volley resolution: a marble must be in
	# flight for the board to reach _run_win_reached (run_loop does the same).
	board.state = board.ThrowState.FLIGHT
	board.launch_timer = 0.0
	board.active_marbles.append(_resting_marble(board))
	await physics_frame
	await physics_frame
	_check(game.last_win_stats.get("score", -1) == objective + 50,
			"the board-end bonus should land in the final score %d + 50, got %s"
			% [objective, str(game.last_win_stats.get("score", -1))])
	board.queue_free()
	await physics_frame


## The board dispatches its lifecycle events with itself in ctx: a launch
## announces throw_started and marble_spawn, a wall hit announces wall_hit,
## and the player-edge refund closes with throw_ended(refunded).
func _test_throw_lifecycle_events() -> void:
	game.start_run()
	var spy := SpyPrize.new()
	game.prizes.clear()
	game.prizes.append(spy)
	var bus := root.get_node("EventBus")
	bus.refund.emit()  # clear any pending refund state from earlier sections
	var board := _open_board()
	await physics_frame
	spy.seen.clear()
	board._launch(0.0, 20.0)
	await physics_frame
	await physics_frame
	var events := _event_names(spy.seen)
	_check(events.has(&"throw_started"), "a launch should dispatch throw_started, got %s" % str(events))
	_check(events.has(&"marble_spawn"), "a launch should dispatch marble_spawn, got %s" % str(events))
	board._on_wall_hit(&"left", 2.0)
	_check(_event_names(spy.seen).has(&"wall_hit"), "a wall hit should dispatch wall_hit")
	if not board.active_marbles.is_empty():
		var marble: RigidBody3D = board.active_marbles[0]
		var out_z: float = -board.board_def.length / 2.0 - board.rules.edge_margin - 0.5
		marble.global_position = board.board.to_global(Vector3(0.0, 0.09, out_z))
		for i in 8:
			await physics_frame
			if _event_names(spy.seen).has(&"throw_ended"):
				break
		events = _event_names(spy.seen)
		_check(events.has(&"refund"), "the player-edge exit should dispatch refund, got %s" % str(events))
		_check(events.has(&"throw_ended"), "the refund should end the throw, got %s" % str(events))
		var ended: Array = _find_event(spy.seen, &"throw_ended")
		_check(not ended.is_empty() and ended[1].get("outcome", &"") == &"refunded",
				"throw_ended should carry the refunded outcome, got %s" % str(ended))
	board.queue_free()
	await physics_frame
	game.start_run()


## The trompo migrates off the dedicated field into the generic contract:
## effect id + params, and the board asks the prize for its per-wall factor.
func _test_trompo_migration() -> void:
	var trompo: PrizeDef = content.prize_def("trompo")
	_check(trompo != null, "the trompo def should load")
	_check(trompo.get("wall_hit_mult") == null,
			"PrizeDef.wall_hit_mult should be gone (migrated to effect+params)")
	_check(trompo.effect == &"wall_mult", "trompo effect should be wall_mult, got %s" % trompo.effect)
	_check(is_equal_approx(float(trompo.params.get("mult", 0.0)), 1.5),
			"trompo params.mult should be 1.5")
	_check(is_equal_approx(trompo.wall_mult_per_hit(), 1.5),
			"wall_mult_per_hit should read the params")
	_check(trompo.interested_in().has(&"embed"), "the wall prize still scores through embed")


## Globo: one extra throw per board, added to the run ammo budget.
func _test_extra_throw_prize() -> void:
	game.start_run()
	var globo := PrizeDef.new()
	globo.id = "globo"
	globo.display_name = "Globo"
	globo.effect = &"extra_throw"
	globo.params = {"per_board": 1}
	game.prizes.clear()
	game.prizes.append(globo)
	var board := _open_board()
	await physics_frame
	_check(board.shots_total == game.ammo.size() + 1,
			"globo should add one throw to the ammo budget (%d + 1), got %d"
			% [game.ammo.size(), board.shots_total])
	_check(board.shots_left == board.shots_total,
			"the extra throw should be available, shots_left is %d" % board.shots_left)
	board.queue_free()
	await physics_frame
	# Without the prize the budget is exactly the ammo.
	game.start_run()
	var plain := _open_board()
	await physics_frame
	_check(plain.shots_total == game.ammo.size(),
			"without globo the budget is the ammo size")
	plain.queue_free()
	await physics_frame


## Pelota de Goma: spawned marbles bounce x1.3.
func _test_bounce_prize() -> void:
	game.start_run()
	var pelota := PrizeDef.new()
	pelota.id = "pelota"
	pelota.display_name = "Pelota de Goma"
	pelota.effect = &"bounce_scale"
	pelota.params = {"bounce": 1.3}
	game.prizes.clear()
	game.prizes.append(pelota)
	var board := _open_board()
	await physics_frame
	board._launch(0.0, 20.0)
	_check(not board.active_marbles.is_empty(), "the launch should spawn a marble")
	if not board.active_marbles.is_empty():
		var marble: RigidBody3D = board.active_marbles[0]
		var base: float = board.marble_def.bounce
		_check(is_equal_approx(marble.physics_material_override.bounce, base * 1.3),
				"pelota should scale the marble bounce %s x1.3, got %s"
				% [base, marble.physics_material_override.bounce])
	board.queue_free()
	await physics_frame
	game.start_run()


## Rayo: fire marbles fly x1.5. The prize edits the spawn ctx speed_mult;
## the board applies it to the launch impulse.
func _test_fire_speed_prize() -> void:
	game.start_run()
	var rayo := PrizeDef.new()
	rayo.id = "rayo"
	rayo.display_name = "Rayo"
	rayo.effect = &"fire_speed_mult"
	rayo.params = {"mult": 1.5}
	game.prizes.clear()
	game.prizes.append(rayo)
	# Contract level: the ctx edit is conditional on the def id.
	var fire_ctx := {"board": null, "def": content.marble_def("fire"), "speed_mult": 1.0}
	game.dispatch_event(&"marble_spawn", fire_ctx)
	_check(is_equal_approx(fire_ctx["speed_mult"], 1.5),
			"rayo should scale a fire marble x1.5, got %s" % str(fire_ctx["speed_mult"]))
	var common_ctx := {"board": null, "def": content.marble_def("common"), "speed_mult": 1.0}
	game.dispatch_event(&"marble_spawn", common_ctx)
	_check(is_equal_approx(common_ctx["speed_mult"], 1.0),
			"rayo must not touch a common marble, got %s" % str(common_ctx["speed_mult"]))
	# Board level: the launch impulse carries the scale. Fire flies with the
	# rayo; the same def without the prize flies slower.
	game.inventory.clear()
	game.inventory.append(content.marble_def("fire"))
	var board := _open_board()
	await physics_frame
	board.selected_ammo_index = 0
	board._launch(0.0, 20.0)
	_check(not board.active_marbles.is_empty(), "the fire launch should spawn a marble")
	var with_rayo := 0.0
	if not board.active_marbles.is_empty():
		var marble: RigidBody3D = board.active_marbles[0]
		await physics_frame  # the impulse lands in the server state on the step
		if is_instance_valid(marble):
			with_rayo = marble.linear_velocity.length()
	_clear_marbles(board)
	board.queue_free()
	await physics_frame
	game.start_run()
	game.inventory.clear()
	game.inventory.append(content.marble_def("fire"))
	var plain := _open_board()
	await physics_frame
	plain.selected_ammo_index = 0
	plain._launch(0.0, 20.0)
	var without := 0.0
	if not plain.active_marbles.is_empty():
		var plain_marble: RigidBody3D = plain.active_marbles[0]
		await physics_frame
		if is_instance_valid(plain_marble):
			without = plain_marble.linear_velocity.length()
	_clear_marbles(plain)
	plain.queue_free()
	await physics_frame
	_check(with_rayo > 0.0 and without > 0.0 and with_rayo / without > 1.35
				and with_rayo / without < 1.65,
			"rayo should make the same fire throw fly x1.5, ratio %s (with=%s without=%s)"
			% [str(with_rayo / maxf(without, 0.001)), str(with_rayo), str(without)])
	game.start_run()


## Muñeco de Nieve: embeds settle instead of staying fast, i.e. the board's
## capture threshold (skip_speed) is halved while the prize is owned.
func _test_skip_speed_prize() -> void:
	game.start_run()
	var munequito := PrizeDef.new()
	munequito.id = "muneco"
	munequito.display_name = "Muñeco de Nieve"
	munequito.effect = &"skip_speed_scale"
	munequito.params = {"scale": 0.5}
	game.prizes.clear()
	game.prizes.append(munequito)
	var board := _open_board()
	await physics_frame
	_check(is_equal_approx(board.effective_skip_speed(),
			board.board_def.skip_speed * 0.5),
		"munequito should halve the skip speed, got %s"
		% str(board.effective_skip_speed()))
	board.queue_free()
	await physics_frame
	game.start_run()
	var plain := _open_board()
	await physics_frame
	_check(is_equal_approx(plain.effective_skip_speed(), plain.board_def.skip_speed),
			"without the prize the skip speed is the board's own")
	plain.queue_free()
	await physics_frame


## Corona del Circo: x1.1 to everything — every embed mult and the final
## board total.
func _test_global_mult_prize() -> void:
	game.start_run()
	var corona := PrizeDef.new()
	corona.id = "corona"
	corona.display_name = "Corona del Circo"
	corona.effect = &"score_mult_all"
	corona.params = {"mult": 1.1}
	game.prizes.clear()
	game.prizes.append(corona)
	var board := _open_board()
	await physics_frame
	var breakdown: ScoreBreakdown = board.score_engine.evaluate_embed(10, {"board": board})
	_check(breakdown.final() == 11,
			"corona should scale a 10 embed to 11, got %d" % breakdown.final())
	board.score_engine.total = 100
	board._dispatch_board_end()
	_check(board.score_engine.total == 110,
			"corona should scale the board total x1.1, got %d" % board.score_engine.total)
	board.queue_free()
	await physics_frame
	game.start_run()


func _event_names(seen: Array) -> Array:
	var names: Array = []
	for entry in seen:
		names.append(entry[0])
	return names


func _find_event(seen: Array, event: StringName) -> Array:
	for entry in seen:
		if entry[0] == event:
			return entry
	return []


# --- Helpers ---------------------------------------------------------------


func _open_board() -> Node3D:
	var board: Node3D = (load("res://scenes/board/board.tscn") as PackedScene).instantiate()
	root.add_child(board)
	return board


## Board with a fixed list of bonificadores: the test override wins over the
## run's board modifiers.
func _open_board_with(defs: Array) -> Node3D:
	var typed: Array[BoardModifierDef] = []
	for def in defs:
		if def != null:
			typed.append(def)
	var board: Node3D = (load("res://scenes/board/board.tscn") as PackedScene).instantiate()
	board.modifier_override = typed
	root.add_child(board)
	return board


func _hole_scores(board: Node3D) -> Array:
	var scores: Array = []
	for hole in board.holes:
		scores.append(int(hole.score))
	return scores


## First free notch painted with `value`.
func _hole_with_score(board: Node3D, value: int) -> Dictionary:
	for hole in board.holes:
		if not hole.occupied and int(hole.score) == value:
			return hole
	return board.holes[0]


func _same_multiset(a: Array, b: Array) -> bool:
	var left := a.duplicate()
	var right := b.duplicate()
	left.sort()
	right.sort()
	return left == right


## Drop the flying marbles so the next scripted throw starts clean.
func _clear_marbles(board: Node3D) -> void:
	for marble in board.active_marbles.duplicate():
		if is_instance_valid(marble):
			marble.queue_free()
	board.active_marbles.clear()
	board.settle_times.clear()


## A marble at rest on the board surface, away from every notch: drives the
## volley resolution the same way run_loop's win test does.
func _resting_marble(board: Node3D) -> RigidBody3D:
	var marble := RigidBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	marble.add_child(shape)
	marble.freeze = true
	board.board.add_child(marble)
	marble.global_position = board.board.to_global(
			Vector3(0.0, 0.09, board.board_def.launch_z() + 0.4))
	return marble


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
