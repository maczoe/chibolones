extends Node
## Save profile (S7, S10): the data that outlives one run.
##
## The profile is a plain dictionary so it can be tested without a scene and
## migrated field by field: what the player collected, what is unlocked, the
## run stats and the settings. The file is versioned, written through a temp
## file so a crash cannot leave a half-written profile behind, and an
## unreadable profile is moved to `<path>.corrupt` instead of being
## overwritten: losing a whole collection to one bad write is the one failure
## this layer must not have.
##
## Call sites change the data and then call `save_profile()`: the game saves on
## the events it cares about (run end, unlock, collection), not on every write.

const PROFILE_VERSION := 1
const DEFAULT_PATH := "user://profile.json"
## Kinds the profile tracks, one key each inside `collection` and `unlocks`.
const KINDS := ["marbles", "prizes"]

## Where this profile lives. Tests point it at a scratch file.
var path: String = DEFAULT_PATH

var _data: Dictionary = {}
var _loaded := false


func load_profile() -> Dictionary:
	_data = defaults()
	_loaded = true
	if not FileAccess.file_exists(path):
		ensure_starter_pool()
		return _data
	var json := JSON.new()
	var parsed: Variant = null
	if json.parse(_read_text(path)) == OK:
		parsed = json.data
	if typeof(parsed) != TYPE_DICTIONARY:
		_quarantine()
		ensure_starter_pool()
		return _data
	_absorb(parsed)
	ensure_starter_pool()
	return _data


func has_profile() -> bool:
	return FileAccess.file_exists(path)


func reset_profile() -> void:
	_data = defaults()
	_loaded = true
	ensure_starter_pool()


func save_profile() -> bool:
	_ensure_loaded()
	var tmp := path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		push_error("SaveGame: cannot write %s (error %d)" % [tmp, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(_data, "\t"))
	file.close()
	var tmp_abs := ProjectSettings.globalize_path(tmp)
	var path_abs := ProjectSettings.globalize_path(path)
	if DirAccess.rename_absolute(tmp_abs, path_abs) == OK:
		return true
	# Some platforms refuse to rename over an existing file: copy truncating
	# it instead, which keeps the temp file as the only partial write.
	if DirAccess.copy_absolute(tmp_abs, path_abs) != OK:
		push_error("SaveGame: cannot replace %s with %s" % [path_abs, tmp_abs])
		return false
	DirAccess.remove_absolute(tmp_abs)
	return true


# --- Collection and unlocks ------------------------------------------------


func collected_ids(kind: String) -> Array:
	_ensure_loaded()
	return (_data["collection"] as Dictionary).get(kind, [])


func is_collected(kind: String, id: String) -> bool:
	return collected_ids(kind).has(id)


## S6: a discovered prize joins the collection and the pool at once, so the
## library shows it and the next run's shops may sell it.
func discover(kind: String, id: String) -> void:
	unlock(kind, id)
	collect(kind, id)


func collect(kind: String, id: String) -> void:
	_ensure_loaded()
	var list: Array = (_data["collection"] as Dictionary).get(kind, [])
	if not list.has(id):
		list.append(id)
		(_data["collection"] as Dictionary)[kind] = list


func unlocked_ids(kind: String) -> Array:
	_ensure_loaded()
	return (_data["unlocks"] as Dictionary).get(kind, [])


func is_unlocked(kind: String, id: String) -> bool:
	return unlocked_ids(kind).has(id)


func unlock(kind: String, id: String) -> void:
	_ensure_loaded()
	var list: Array = (_data["unlocks"] as Dictionary).get(kind, [])
	if not list.has(id):
		list.append(id)
		(_data["unlocks"] as Dictionary)[kind] = list


# --- Unlock pool (S5, S6) -------------------------------------------------


## The starter pool is unlocked on every load, so a profile written before the
## table existed (or a table that grew) is never missing its starters.
func ensure_starter_pool() -> void:
	var table := unlock_table()
	if table == null:
		return
	for id in table.starter_marbles:
		unlock("marbles", id)
	for id in table.starter_prizes:
		unlock("prizes", id)


func available_marbles() -> Array[MarbleDef]:
	_ensure_loaded()
	var out: Array[MarbleDef] = []
	for def in ContentDB.marbles():
		if is_unlocked("marbles", def.id):
			out.append(def)
	return out


func available_prizes() -> Array[PrizeDef]:
	_ensure_loaded()
	var out: Array[PrizeDef] = []
	for def in ContentDB.prizes():
		if is_unlocked("prizes", def.id):
			out.append(def)
	return out


## Unlock what clearing `board_index` (0-based, as the run counts boards)
## grants. Returns the ids that were new, so the caller can announce them.
func unlock_for_board(board_index: int) -> Array:
	var table := unlock_table()
	if table == null:
		return []
	var granted := table.unlocked_by_board(board_index)
	var newly := _grant("marbles", granted["marbles"])
	newly.append_array(_grant("prizes", granted["prizes"]))
	return newly


func unlock_for_run_won() -> Array:
	var table := unlock_table()
	if table == null:
		return []
	var newly := _grant("marbles", table.run_won_marbles)
	newly.append_array(_grant("prizes", table.run_won_prizes))
	return newly


func unlock_table() -> UnlockTable:
	if ContentDB.has_method("unlock_table"):
		return ContentDB.unlock_table()
	return null


## Unlock the ids of one kind that are not unlocked yet, in table order.
func _grant(kind: String, ids: Array) -> Array:
	var newly: Array = []
	for id in ids:
		var text := str(id)
		if text == "" or is_unlocked(kind, text):
			continue
		unlock(kind, text)
		newly.append(text)
	return newly


# --- Stats and settings ---------------------------------------------------


func stats() -> Dictionary:
	_ensure_loaded()
	return _data["stats"]


## One finished run: `board` is how deep it got, `won` whether it cleared board
## 20 and `score` its best board score.
func record_run(result: Dictionary) -> void:
	_ensure_loaded()
	var state: Dictionary = _data["stats"]
	state["runs_played"] = int(state.get("runs_played", 0)) + 1
	if bool(result.get("won", false)):
		state["runs_won"] = int(state.get("runs_won", 0)) + 1
	state["best_board"] = maxi(int(state.get("best_board", 0)), int(result.get("board", 0)))
	state["best_score"] = maxi(int(state.get("best_score", 0)), int(result.get("score", 0)))


func setting(key: String, fallback: Variant = null) -> Variant:
	_ensure_loaded()
	return (_data["settings"] as Dictionary).get(key, fallback)


func set_setting(key: String, value: Variant) -> void:
	_ensure_loaded()
	(_data["settings"] as Dictionary)[key] = value


# --- Defaults and validation ----------------------------------------------


func defaults() -> Dictionary:
	var collection: Dictionary = {}
	var unlocks: Dictionary = {}
	for kind in KINDS:
		collection[kind] = []
		unlocks[kind] = []
	return {
		"version": PROFILE_VERSION,
		"collection": collection,
		"unlocks": unlocks,
		"stats": {"runs_played": 0, "runs_won": 0, "best_board": 0, "best_score": 0},
		"settings": {"master_volume": 1.0, "sfx_volume": 1.0, "text_speed": 1.0},
	}


## Take what the file says, keep what we do not know, repair what we do: an
## unknown key survives the round trip (a newer profile must not be destroyed
## on our write) while every section we read is validated.
func _absorb(parsed: Dictionary) -> void:
	for key in parsed:
		_data[key] = parsed[key]
	_data["collection"] = _string_lists(parsed.get("collection", {}))
	_data["unlocks"] = _string_lists(parsed.get("unlocks", {}))
	_data["stats"] = _stats_from(parsed.get("stats", {}))
	_data["settings"] = _settings_from(parsed.get("settings", {}))
	# JSON reads every number back as a float, so the version marker needs the
	# same check as the stats: a valid one stays, a missing or odd one resets.
	var version: Variant = _data.get("version")
	if typeof(version) != TYPE_INT and typeof(version) != TYPE_FLOAT:
		_data["version"] = PROFILE_VERSION


func _string_lists(source: Variant) -> Dictionary:
	var out: Dictionary = {}
	for kind in KINDS:
		var list: Array = []
		if typeof(source) == TYPE_DICTIONARY:
			var raw: Variant = (source as Dictionary).get(kind, [])
			if typeof(raw) == TYPE_ARRAY:
				for id in raw:
					if typeof(id) == TYPE_STRING and not list.has(id):
						list.append(id)
		out[kind] = list
	return out


func _stats_from(source: Variant) -> Dictionary:
	var out: Dictionary = {}
	for key in ["runs_played", "runs_won", "best_board", "best_score"]:
		var value: Variant = 0
		if typeof(source) == TYPE_DICTIONARY:
			value = (source as Dictionary).get(key, 0)
		if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
			out[key] = int(value)
		else:
			out[key] = 0
	return out


func _settings_from(source: Variant) -> Dictionary:
	var out: Dictionary = (defaults()["settings"] as Dictionary).duplicate()
	if typeof(source) != TYPE_DICTIONARY:
		return out
	for key in source as Dictionary:
		if typeof(key) != TYPE_STRING:
			continue
		var value: Variant = (source as Dictionary)[key]
		if (
			typeof(value) == TYPE_FLOAT
			or typeof(value) == TYPE_INT
			or typeof(value) == TYPE_BOOL
			or typeof(value) == TYPE_STRING
		):
			out[key] = value
	return out


func _read_text(file_path: String) -> String:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


## Keep the unreadable profile instead of overwriting it (S10).
func _quarantine() -> void:
	var broken := path + ".corrupt"
	var broken_abs := ProjectSettings.globalize_path(broken)
	if FileAccess.file_exists(broken):
		DirAccess.remove_absolute(broken_abs)
	DirAccess.rename_absolute(ProjectSettings.globalize_path(path), broken_abs)


func _ensure_loaded() -> void:
	if not _loaded:
		load_profile()
