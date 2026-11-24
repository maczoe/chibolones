extends SceneTree
## Save profile test (S7, S10): the data that outlives one run — a first boot
## with defaults, a session round trip, idempotent collection and unlocks, run
## stats, settings, and the corrupt-file rule that keeps an unreadable profile
## aside instead of destroying it.
## Run: godot --headless --path . --script res://tests/save_load.gd

const SAVE_SCRIPT := "res://autoload/save_game.gd"
const TEST_PATH := "user://test_profile.json"
const TEST_TMP := "user://test_profile.json.tmp"
const BROKEN_PATH := "user://test_profile.json.corrupt"

var failed := false


func _initialize() -> void:
	if not _api_present():
		quit(1)
		return
	_clean()
	_test_defaults_on_first_boot()
	_test_round_trip()
	_test_idempotent_writes()
	_test_stats_accumulate()
	_test_corrupt_file_is_quarantined()
	_test_unknown_fields_survive()
	_clean()
	if failed:
		quit(1)
		return
	print("SAVE OK")
	quit(0)


## Red without the script instead of a wall of errors: the suite must fail
## loudly when the autoload is missing, not crash.
func _api_present() -> bool:
	if ResourceLoader.exists(SAVE_SCRIPT):
		return true
	print("SAVE FAIL: %s does not exist" % SAVE_SCRIPT)
	return false


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	print("SAVE FAIL: " + label)


func _new_save() -> Node:
	var save: Node = (load(SAVE_SCRIPT) as GDScript).new()
	save.path = TEST_PATH
	return save


# --- (a) A first boot has defaults and writes nothing (S7) -----------------


func _test_defaults_on_first_boot() -> void:
	var save := _new_save()
	save.load_profile()
	_check(
		save.collected_ids("marbles").is_empty(),
		"a first boot should collect no marbles, got %s" % str(save.collected_ids("marbles"))
	)
	_check(
		save.collected_ids("prizes").is_empty(),
		"a first boot should collect no prizes, got %s" % str(save.collected_ids("prizes"))
	)
	_check(
		int(save.stats().get("runs_played", -1)) == 0,
		"a first boot should have no runs played, got %s" % str(save.stats())
	)
	_check(
		save.setting("master_volume", 1.0) == 1.0,
		(
			"the master volume should default to full, got %s"
			% str(save.setting("master_volume", null))
		)
	)
	_check(
		not FileAccess.file_exists(TEST_PATH), "loading a missing profile should not write a file"
	)
	save.free()


# --- (b) A session round trip keeps everything (S7) -----------------------


func _test_round_trip() -> void:
	_clean()
	var save := _new_save()
	save.load_profile()
	save.unlock("marbles", "espejo")
	save.collect("marbles", "fire")
	save.collect("prizes", "osito")
	save.record_run({"board": 7, "won": false, "score": 210})
	save.set_setting("master_volume", 0.4)
	_check(save.save_profile(), "saving a profile should report success")
	_check(
		not FileAccess.file_exists(TEST_TMP),
		"a save should leave no temp file behind, found %s" % TEST_TMP
	)
	save.free()

	var reloaded := _new_save()
	reloaded.load_profile()
	_check(
		reloaded.unlocked_ids("marbles").has("espejo"),
		(
			"the unlocked marble should survive a reload, got %s"
			% str(reloaded.unlocked_ids("marbles"))
		)
	)
	_check(
		reloaded.collected_ids("marbles").has("fire"),
		(
			"the collected marble should survive a reload, got %s"
			% str(reloaded.collected_ids("marbles"))
		)
	)
	_check(
		reloaded.collected_ids("prizes").has("osito"),
		(
			"the collected prize should survive a reload, got %s"
			% str(reloaded.collected_ids("prizes"))
		)
	)
	_check(
		int(reloaded.stats().get("best_board", -1)) == 7,
		"the best board should survive a reload, got %s" % str(reloaded.stats())
	)
	_check(
		is_equal_approx(float(reloaded.setting("master_volume", 1.0)), 0.4),
		(
			"the saved setting should survive a reload, got %s"
			% str(reloaded.setting("master_volume", null))
		)
	)

	# A second save replaces the profile in place instead of appending to it.
	var again := _new_save()
	again.load_profile()
	again.set_setting("master_volume", 0.25)
	_check(again.save_profile(), "a second save over an existing profile should succeed")
	again.free()
	var third := _new_save()
	third.load_profile()
	_check(
		is_equal_approx(float(third.setting("master_volume", 1.0)), 0.25),
		(
			"a replaced profile should keep the last write, got %s"
			% str(third.setting("master_volume", null))
		)
	)
	third.free()
	reloaded.free()


# --- (c) Unlocking and collecting twice is one entry (S7) -----------------


func _test_idempotent_writes() -> void:
	_clean()
	var save := _new_save()
	save.load_profile()
	save.unlock("marbles", "nitro")
	save.unlock("marbles", "nitro")
	save.collect("prizes", "corona")
	save.collect("prizes", "corona")
	_check(
		save.unlocked_ids("marbles").count("nitro") == 1,
		"unlocking twice should keep one entry, got %s" % str(save.unlocked_ids("marbles"))
	)
	_check(
		save.collected_ids("prizes").count("corona") == 1,
		"collecting twice should keep one entry, got %s" % str(save.collected_ids("prizes"))
	)
	_check(
		save.is_unlocked("marbles", "nitro"),
		"an unlocked id should report unlocked, ids are %s" % str(save.unlocked_ids("marbles"))
	)
	_check(
		save.is_collected("prizes", "corona"),
		"a collected id should report collected, ids are %s" % str(save.collected_ids("prizes"))
	)
	save.free()


# --- (d) Run stats accumulate (S7) ----------------------------------------


func _test_stats_accumulate() -> void:
	_clean()
	var save := _new_save()
	save.load_profile()
	save.record_run({"board": 3, "won": false, "score": 90})
	save.record_run({"board": 9, "won": true, "score": 320})
	save.record_run({"board": 5, "won": false, "score": 140})
	var stats: Dictionary = save.stats()
	_check(
		int(stats.get("runs_played", -1)) == 3, "three runs should count three, got %s" % str(stats)
	)
	_check(int(stats.get("runs_won", -1)) == 1, "one won run should count one, got %s" % str(stats))
	_check(
		int(stats.get("best_board", -1)) == 9,
		"the best board should be the deepest one, got %s" % str(stats)
	)
	_check(
		int(stats.get("best_score", -1)) == 320,
		"the best score should be the highest one, got %s" % str(stats)
	)
	save.free()


# --- (e) A corrupt profile is quarantined, never destroyed (S10) ----------


func _test_corrupt_file_is_quarantined() -> void:
	_clean()
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string("{ this is not a profile")
	file.close()
	var save := _new_save()
	save.load_profile()
	_check(
		save.collected_ids("marbles").is_empty(),
		(
			"a corrupt profile should fall back to empty defaults, got %s"
			% str(save.collected_ids("marbles"))
		)
	)
	_check(
		FileAccess.file_exists(BROKEN_PATH),
		"the unreadable profile should be kept at %s" % BROKEN_PATH
	)
	if FileAccess.file_exists(BROKEN_PATH):
		var kept := FileAccess.open(BROKEN_PATH, FileAccess.READ)
		if kept != null:
			_check(
				kept.get_as_text().contains("not a profile"),
				"the quarantined file should keep its original bytes"
			)
			kept.close()
	save.collect("marbles", "rebote")
	_check(save.save_profile(), "saving over a quarantined profile should succeed")
	var reloaded := _new_save()
	reloaded.load_profile()
	_check(
		reloaded.collected_ids("marbles").has("rebote"),
		(
			"the profile after a quarantine should save and reload, got %s"
			% str(reloaded.collected_ids("marbles"))
		)
	)
	reloaded.free()
	save.free()


# --- (f) Unknown fields from a newer profile survive (S10) ----------------


func _test_unknown_fields_survive() -> void:
	var profile := {
		"version": 99,
		"collection": {"marbles": ["agata"], "prizes": ["foto"]},
		"unlocks": {"marbles": [], "prizes": []},
		"stats": {"runs_played": 4, "runs_won": 2, "best_board": 12, "best_score": 500},
		"settings": {},
		"future_key": "keep me",
	}
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(profile))
	file.close()
	var save := _new_save()
	save.load_profile()
	_check(
		save.collected_ids("marbles").has("agata"),
		"a newer profile should keep its collection, got %s" % str(save.collected_ids("marbles"))
	)
	_check(
		int(save.stats().get("runs_played", -1)) == 4,
		"a newer profile should keep its stats, got %s" % str(save.stats())
	)
	save.save_profile()
	save.free()
	var reopened := FileAccess.open(TEST_PATH, FileAccess.READ)
	_check(reopened != null, "the rewritten profile should be readable")
	if reopened != null:
		var text := reopened.get_as_text()
		reopened.close()
		_check(
			text.contains("future_key"),
			"an unknown field of a newer profile should survive the rewrite, got %s" % text
		)


func _clean() -> void:
	for path in [TEST_PATH, TEST_TMP, BROKEN_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
