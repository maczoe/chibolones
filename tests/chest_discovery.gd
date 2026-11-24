extends SceneTree
## Chest discovery test (S6): the second unlock source — a chest may reveal a
## prize the profile has not unlocked yet, at the decided 10% rate, at most once
## per run, and a discovered prize joins the collection and the pool.
## Run: godot --headless --path . --script res://tests/chest_discovery.gd

const SAVE_SCRIPT := "res://autoload/save_game.gd"
const TEST_PATH := "user://test_chest_discovery.json"
const SAMPLES := 400

var save
var economy
var content
var game
var failed := false
var checks := 0


func _initialize() -> void:
	_ensure_autoloads()
	_run()


func _run() -> void:
	await physics_frame
	_clean()
	if not _api_present():
		quit(1)
		return
	_test_discovery_pool_is_locked_only()
	_test_rate_is_ten_percent()
	_test_one_discovery_per_run()
	_test_discovered_prize_joins_the_profile()
	_test_run_resets_the_discovery()
	_clean()
	if failed:
		quit(1)
		return
	# A dead suite (an early script error that skipped every check) must not
	# report success: the same guard tests/chests.gd carries.
	if checks < 12:
		print("CHEST DISCOVERY FAIL: only %d checks ran" % checks)
		quit(1)
		return
	print("CHEST DISCOVERY OK (%d checks)" % checks)
	quit(0)


func _ensure_autoloads() -> void:
	var autoloads := [
		["EventBus", "res://autoload/event_bus.gd"],
		["ContentDB", "res://autoload/content_db.gd"],
		["Economy", "res://autoload/economy.gd"],
		["Game", "res://autoload/game.gd"],
		["SaveGame", SAVE_SCRIPT],
	]
	for entry in autoloads:
		if not root.has_node(entry[0]):
			var node: Node = (load(entry[1]) as GDScript).new()
			node.name = entry[0]
			root.add_child(node)
	content = root.get_node("ContentDB")
	economy = root.get_node("Economy")
	game = root.get_node("Game")
	save = root.get_node("SaveGame")
	save.path = TEST_PATH


func _api_present() -> bool:
	var missing: Array[String] = []
	for method in ["chest_discovery_pool", "chest_draw_discovery"]:
		if not economy.has_method(method):
			missing.append("Economy." + method)
	if not save.has_method("discover"):
		missing.append("SaveGame.discover")
	if not ("discovery_used" in game):
		missing.append("Game.discovery_used")
	if not missing.is_empty():
		print("CHEST DISCOVERY FAIL: missing %s" % ", ".join(missing))
		return false
	return true


func _check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		return
	failed = true
	print("CHEST DISCOVERY FAIL: " + label)


# --- (a) Only locked, unowned and uncollected prizes can be discovered (S6) --


func _test_discovery_pool_is_locked_only() -> void:
	save.reset_profile()
	var empty: Array[String] = []
	var unlocked: Array[String] = []
	unlocked.assign(save.unlocked_ids("prizes"))
	var pool: Array = economy.chest_discovery_pool(empty, empty, unlocked)
	_check(not pool.is_empty(), "a fresh profile should have discoverable prizes, pool is empty")
	for def in pool:
		_check(
			not save.is_unlocked("prizes", def.id),
			"a discoverable prize should be locked, '%s' is unlocked" % def.id
		)
	var locked_ids: Array[String] = []
	for def in pool:
		locked_ids.append(def.id)
	for id in save.unlocked_ids("prizes"):
		_check(
			not locked_ids.has(id),
			"an unlocked prize should not be discoverable, '%s' is in the pool" % id
		)
	var owned: Array[String] = []
	var collected: Array[String] = []
	for def in pool:
		owned.append(def.id)
	var rerun: Array = economy.chest_discovery_pool(owned, collected, unlocked)
	for def in rerun:
		_check(
			not owned.has(def.id),
			"a prize the run already owns should not be discoverable, got '%s'" % def.id
		)


# --- (b) The roll reveals at the decided 10% rate (S6) ----------------------


func _test_rate_is_ten_percent() -> void:
	save.reset_profile()
	var empty: Array[String] = []
	var unlocked: Array[String] = []
	unlocked.assign(save.unlocked_ids("prizes"))
	var found := 0
	for sample in SAMPLES:
		var draw: Dictionary = economy.chest_draw_discovery(empty, empty, unlocked, false, sample)
		if bool(draw.get("discovered", false)):
			found += 1
			_check(
				not save.is_unlocked("prizes", String(draw["def_id"])),
				"a discovered draw should be a locked prize, got '%s'" % String(draw["def_id"])
			)
	var rate := float(found) / float(SAMPLES)
	_check(
		rate >= 0.05 and rate <= 0.16,
		"discovery should land near 10%% of the draws, landed %.1f%%" % (rate * 100.0)
	)


# --- (c) One discovery per run (S6) ---------------------------------------


func _test_one_discovery_per_run() -> void:
	save.reset_profile()
	var empty: Array[String] = []
	var unlocked: Array[String] = []
	unlocked.assign(save.unlocked_ids("prizes"))
	for sample in 200:
		var draw: Dictionary = economy.chest_draw_discovery(empty, empty, unlocked, true, sample)
		_check(
			not bool(draw.get("discovered", false)),
			"a run that already discovered should never discover again (seed %d)" % sample
		)


# --- (d) A discovered prize joins the collection and the pool (S6) --------


func _test_discovered_prize_joins_the_profile() -> void:
	save.reset_profile()
	var before: int = save.available_prizes().size()
	save.discover("prizes", "foto")
	_check(save.is_unlocked("prizes", "foto"), "a discovered prize should be unlocked")
	_check(save.is_collected("prizes", "foto"), "a discovered prize should be collected")
	_check(
		save.available_prizes().size() == before + 1,
		(
			"a discovered prize should widen the pool from %d, pool is %d"
			% [before, save.available_prizes().size()]
		)
	)


# --- (e) A new run may discover again (S6) --------------------------------


func _test_run_resets_the_discovery() -> void:
	game.start_run()
	_check(not game.discovery_used, "a new run should start with its discovery available")
	game.discovery_used = true
	game.start_run()
	_check(not game.discovery_used, "starting a run again should refill the discovery")


func _clean() -> void:
	for path in [TEST_PATH, TEST_PATH + ".tmp", TEST_PATH + ".corrupt"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
