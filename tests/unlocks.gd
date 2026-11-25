extends SceneTree
## Unlock pool test (S5, S6): the starter pool a first run draws from, the
## milestone unlocks by board cleared and run won, and the availability queries
## the shop and the library read. A locked id must never reach a shop stock, and
## unlocking twice must unlock once.
## Run: godot --headless --path . --script res://tests/unlocks.gd

const SAVE_SCRIPT := "res://autoload/save_game.gd"
const TEST_PATH := "user://test_unlocks.json"

var save
var content
var failed := false


func _initialize() -> void:
	_ensure_autoloads()
	_run()


## ContentDB fills its catalogs in _ready(), so the first checks wait one frame
## (same pattern as tests/inventory.gd).
func _run() -> void:
	await physics_frame
	_clean()
	if not _api_present():
		quit(1)
		return
	_test_starter_pool()
	_test_locked_ids_stay_out()
	_test_board_milestones()
	_test_run_won_milestones()
	_test_unknown_ids_are_ignored()
	_test_pool_survives_a_reload()
	_clean()
	if failed:
		quit(1)
		return
	print("UNLOCKS OK")
	quit(0)


func _ensure_autoloads() -> void:
	var autoloads := [
		["EventBus", "res://autoload/event_bus.gd"],
		["ContentDB", "res://autoload/content_db.gd"],
		["SaveGame", SAVE_SCRIPT],
	]
	for entry in autoloads:
		if not root.has_node(entry[0]):
			var node: Node = (load(entry[1]) as GDScript).new()
			node.name = entry[0]
			root.add_child(node)
	content = root.get_node("ContentDB")
	save = root.get_node("SaveGame")
	save.path = TEST_PATH


func _api_present() -> bool:
	var missing: Array[String] = []
	for method in [
		"available_marbles",
		"available_prizes",
		"unlock_for_board",
		"unlock_for_run_won",
	]:
		if not save.has_method(method):
			missing.append("SaveGame." + method)
	if not content.has_method("unlock_table"):
		missing.append("ContentDB.unlock_table")
	if not missing.is_empty():
		print("UNLOCKS FAIL: missing %s" % ", ".join(missing))
		return false
	return true


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	print("UNLOCKS FAIL: " + label)


func _reload() -> void:
	save.load_profile()


# --- (a) A fresh profile draws from the starter pool (S5) -----------------


func _test_starter_pool() -> void:
	save.reset_profile()
	_reload()
	var table = content.unlock_table()
	_check(table != null, "ContentDB should expose an unlock table")
	if table == null:
		return
	_check(
		table.starter_marbles.size() == 6,
		"the starter pool should hold 6 marbles, holds %d" % table.starter_marbles.size()
	)
	_check(
		table.starter_prizes.size() == 6,
		"the starter prize pool should hold 6 prizes, holds %d" % table.starter_prizes.size()
	)
	_check(
		save.available_marbles().size() == 6,
		"a fresh profile should offer 6 marbles, offers %d" % save.available_marbles().size()
	)
	_check(
		save.available_prizes().size() == 6,
		"a fresh profile should offer 6 prizes, offers %d" % save.available_prizes().size()
	)
	for def in save.available_marbles():
		_check(def != null, "every available marble should resolve to a def")


# --- (b) A locked id never reaches the pool (S5) --------------------------


func _test_locked_ids_stay_out() -> void:
	_check(
		not save.is_unlocked("marbles", "espejo"),
		"the rare marble should start locked, unlocked ids are %s"
		% str(save.unlocked_ids("marbles"))
	)
	for def in save.available_marbles():
		_check(def.id != "espejo", "a locked marble should not be available, got '%s'" % def.id)
	for def in save.available_prizes():
		_check(
			def.id != "corona", "a locked prize should not be available, got '%s'" % def.id
		)


# --- (c) Clearing a milestone board unlocks its content (S6) --------------


func _test_board_milestones() -> void:
	save.reset_profile()
	var first: Array = save.unlock_for_board(4)
	_check(
		first == ["teledirigida"],
		"board 4 should unlock teledirigida, unlocked %s" % str(first)
	)
	_check(save.is_unlocked("marbles", "teledirigida"), "teledirigida should be unlocked")
	_check(
		save.unlock_for_board(4).is_empty(),
		"clearing board 4 twice should unlock nothing new, got %s"
		% str(save.unlock_for_board(4))
	)
	_check(
		save.unlock_for_board(3).is_empty(),
		"board 3 has no milestone, unlocked %s" % str(save.unlock_for_board(3))
	)
	_check(
		save.unlock_for_board(8) == ["rayo"],
		"board 8 should unlock the rayo prize, unlocked %s" % str(save.unlock_for_board(8))
	)
	_check(
		save.available_prizes().size() == 7,
		"one prize unlock should grow the pool to 7, pool is %d"
		% save.available_prizes().size()
	)


# --- (d) Winning the run unlocks the last tier (S6) -----------------------


func _test_run_won_milestones() -> void:
	save.reset_profile()
	var won: Array = save.unlock_for_run_won()
	_check(won.has("boleto"), "winning a run should unlock boleto, unlocked %s" % str(won))
	_check(won.has("nitro"), "winning a run should unlock nitro, unlocked %s" % str(won))
	_check(
		save.unlock_for_run_won().is_empty(),
		"winning twice should unlock nothing new, got %s" % str(save.unlock_for_run_won())
	)


# --- (e) An id that is not content never joins the pool (S5) --------------


func _test_unknown_ids_are_ignored() -> void:
	save.reset_profile()
	_reload()
	save.unlock("marbles", "no_such_marble")
	save.unlock("prizes", "no_such_prize")
	var marble_ids: Array[String] = []
	for def in save.available_marbles():
		marble_ids.append(def.id)
	var prize_ids: Array[String] = []
	for def in save.available_prizes():
		prize_ids.append(def.id)
	_check(
		not marble_ids.has("no_such_marble"),
		"an unknown marble id should not reach the pool, got %s" % str(marble_ids)
	)
	_check(
		not prize_ids.has("no_such_prize"),
		"an unknown prize id should not reach the pool, got %s" % str(prize_ids)
	)


# --- (f) The pool is the same after a save and reload (S6) ---------------


func _test_pool_survives_a_reload() -> void:
	save.reset_profile()
	save.unlock_for_board(4)
	save.unlock_for_board(8)
	_check(save.save_profile(), "saving the unlocked pool should succeed")
	var reloaded: Node = (load(SAVE_SCRIPT) as GDScript).new()
	reloaded.path = TEST_PATH
	reloaded.load_profile()
	_check(
		reloaded.is_unlocked("marbles", "teledirigida"),
		"the unlocked marble should survive the reload, got %s"
		% str(reloaded.unlocked_ids("marbles"))
	)
	_check(
		reloaded.available_prizes().size() == 7,
		"the reloaded pool should keep 7 prizes, pool is %d"
		% reloaded.available_prizes().size()
	)
	reloaded.free()


func _clean() -> void:
	for path in [TEST_PATH, TEST_PATH + ".tmp", TEST_PATH + ".corrupt"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
