extends Node
## Content registry (autoload "ContentDB"): loads every Def resource under
## data/ and indexes it. Content is data: adding a marble, board, prize or
## modifier means adding a .tres file under data/, no code changes.

const BALANCE_RULES := "res://data/balance/shooting_rules.tres"
const DEFAULT_MARBLE := "common"

var _marbles: Array[MarbleDef] = []
var _prizes: Array[PrizeDef] = []
var _boards: Array[BoardDef] = []
var _modifiers: Array[BoardModifierDef] = []
var _rules: ShootingRules


func _ready() -> void:
	_rules = _load_rules()
	for def in _load_defs("res://data/marbles"):
		if def is MarbleDef:
			_marbles.append(def)
	for def in _load_defs("res://data/prizes"):
		if def is PrizeDef:
			_prizes.append(def)
	for def in _load_defs("res://data/boards"):
		if def is BoardDef:
			_boards.append(def)
	for def in _load_defs("res://data/modifiers"):
		if def is BoardModifierDef:
			_modifiers.append(def)
	_marbles.sort_custom(func(a, b): return a.id < b.id)
	_prizes.sort_custom(func(a, b): return a.id < b.id)
	_boards.sort_custom(func(a, b): return a.theme_name < b.theme_name)
	_modifiers.sort_custom(func(a, b): return a.id < b.id)


func rules() -> ShootingRules:
	return _rules


func marbles() -> Array[MarbleDef]:
	return _marbles.duplicate()


func marble_def(id: String) -> MarbleDef:
	for def in _marbles:
		if def.id == id:
			return def
	push_warning("MarbleDef not found: %s, falling back to first" % id)
	return _marbles[0] if not _marbles.is_empty() else null


func prizes() -> Array[PrizeDef]:
	return _prizes.duplicate()


func prize_def(id: String) -> PrizeDef:
	for def in _prizes:
		if def.id == id:
			return def
	push_warning("PrizeDef not found: %s, falling back to first" % id)
	return _prizes[0] if not _prizes.is_empty() else null


## The 10 bonificadores, indexed by id (content-plan §4.3).
func modifiers() -> Array[BoardModifierDef]:
	return _modifiers.duplicate()


## A bonificador by id; null when the id is unknown (a board asking for a
## modifier that does not exist simply has no rule, never a broken board).
func modifier_def(id: StringName) -> BoardModifierDef:
	for def in _modifiers:
		if def.id == id:
			return def
	push_warning("BoardModifierDef not found: %s" % id)
	return null


func board_count() -> int:
	return _boards.size()


## Boards are indexed by data file order (alphabetical). M1 runs every board
## of the run on the single classic BoardDef (Game.board_index stays 0); the
## content wave replaces this with per-board defs.
func board_def(index: int) -> BoardDef:
	if _boards.is_empty():
		push_error("No BoardDef resources under data/boards")
		return null
	return _boards[clampi(index, 0, _boards.size() - 1)]


func _load_rules() -> ShootingRules:
	if ResourceLoader.exists(BALANCE_RULES):
		return load(BALANCE_RULES)
	push_warning("Missing %s, using defaults" % BALANCE_RULES)
	return ShootingRules.new()


func _load_defs(dir_path: String) -> Array[Resource]:
	var defs: Array[Resource] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("Content dir missing: %s" % dir_path)
		return defs
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if not dir.current_is_dir() and file.ends_with(".tres"):
			var def: Resource = load(dir_path + "/" + file)
			if def != null:
				defs.append(def)
		file = dir.get_next()
	dir.list_dir_end()
	return defs
