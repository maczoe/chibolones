extends Node
## Run state machine (autoload "Game"). M1: menu -> 20 boards in 5 blocks of
## 4 (boss every 4th) -> shop placeholder -> run summary -> endless opt-in.
## Money math lives in the Economy autoload; the board scene renders one
## board and reports win/loss here.

enum Phase { MENU, BOARD, SHOP, RESULT, GAME_OVER, WIN }

## The run is five blocks of four boards; bosses land on every 4th board.
const BLOCKS := 5
const BOARDS_PER_BLOCK := 4
const BOARDS_PER_RUN := BLOCKS * BOARDS_PER_BLOCK
## Boss boards aim at their own base target; the block factor still applies.
const BOSS_BASE_OBJECTIVE := 100
## Difficulty factor per block (docs/gdd/content-plan.md §3).
const BLOCK_OBJECTIVE_FACTORS := [1.0, 1.15, 1.3, 1.5, 1.75]
const START_MONEY := 5
## Endless mode pays one extra dollar per board won on top of the block-5
## rate (content-plan §2).
const ENDLESS_BONUS := 1

## Marbles a normal run owns from the start (S10, economy v1 in
## content-plan §2): five commons, no specials. Debug mode will pass its own
## picked loadout (S8).
const STARTING_MARBLES := ["common", "common", "common", "common", "common"]
const SAMPLE_PRIZE := "trompo"

signal phase_changed(phase: Phase)
signal money_changed(money: int)
signal run_started
signal board_won_sig(marbles_left: int, bonus: int)
signal board_lost_sig
signal run_won_sig
signal run_lost_sig

var phase: Phase = Phase.BOARD
## Content board the scene renders when there is no run (headless tests):
## the first BoardDef. Inside a run the board renders its own def, so this
## stays 0.
var board_index := 0
var money := 0
## Marbles the player owns for the whole run (S4/S5): what the shop buys,
## what a board start restores into the ammo, and what only a broken marble
## leaves for good.
var inventory: Array[MarbleDef] = []
## The current board's ammo (S5/S9): one copy of the inventory taken when
## the board starts, and the throws the board has. A thrown marble leaves
## it when the throw resolves (S4); a refunded one stays (S7).
var ammo: Array[MarbleDef] = []
## Prizes owned this run: permanent effects (M2 hook contract).
var prizes: Array[PrizeDef] = []

## True between start_run() and the end of that run (loss or back to menu).
## A board opened without a run (headless tests) keeps its POC behavior.
var run_active := false
## 1..20 in a run, 21+ in endless: the board the run is on.
var current_board_in_run := 0
## 1..BLOCKS, and stays BLOCKS in endless.
var block := 1
var boards_cleared := 0
## Endless opt-in from the run-won screen (GDD D6).
var endless_mode := false
## Result-screen flag: true when the run reached board 20, false when lost.
var run_won := false
## Extra throws bought this run (the M3 shop pack; placeholder in M1).
var extra_throws := 0
## Debug match (S1, S8): one picked board played with a custom loadout, no
## economy, the block factor left at x1. True only between start_debug_run()
## and the end of that board, which returns to the menu.
var debug_mode := false
## BoardDef index the debug match renders (0..ContentDB.board_count() - 1).
var debug_board_index := 0
## Debug setup screen: a finished debug match comes back here (user request,
## 2026-11-08), not to the title.
const DEBUG_SETUP_SCENE := "res://scenes/debug/debug_setup.tscn"


func start_run() -> void:
	debug_mode = false
	board_index = 0
	current_board_in_run = 1
	block = 1
	boards_cleared = 0
	money = START_MONEY
	inventory.clear()
	prizes.clear()
	for marble_id in STARTING_MARBLES:
		var marble: MarbleDef = ContentDB.marble_def(marble_id)
		if marble != null:
			inventory.append(marble)
	var prize: PrizeDef = ContentDB.prize_def(SAMPLE_PRIZE)
	if prize != null:
		prizes.append(prize)
	extra_throws = 0
	endless_mode = false
	run_won = false
	run_active = true
	begin_board()
	_enter(Phase.BOARD)
	run_started.emit()
	money_changed.emit(money)
	change_to_current_scene()


## Start a single-board debug match (S1, S3, S8): `config` carries the
## picked BoardDef index, the active prizes and the starting marbles, i.e.
## what the debug setup screen builds. The board renders its own def with the
## block factor at x1, the match has no money, and its end returns to the
## menu. Returns false when the loadout has no marble: a match needs at least
## one throw, and a rejected launch never touches the run state.
func start_debug_run(config: Dictionary) -> bool:
	var marbles: Array[MarbleDef] = []
	for def in config.get("marbles", []):
		if def is MarbleDef:
			marbles.append(def)
	if marbles.is_empty() or ContentDB.board_count() <= 0:
		return false
	debug_mode = true
	debug_board_index = clampi(int(config.get("board_index", 0)), 0,
			ContentDB.board_count() - 1)
	current_board_in_run = 1
	block = 1
	boards_cleared = 0
	# No money economy in a debug match (S8): the board HUD reads $0 and the
	# shop never opens.
	money = 0
	inventory.clear()
	inventory.assign(marbles)
	prizes.clear()
	for def in config.get("prizes", []):
		if def is PrizeDef and not prizes.has(def):
			prizes.append(def)
	extra_throws = 0
	endless_mode = false
	run_won = false
	run_active = true
	begin_board()
	_enter(Phase.BOARD)
	run_started.emit()
	money_changed.emit(money)
	change_to_current_scene()
	return true


func restart_board() -> void:
	get_tree().reload_current_scene()


## A board is starting: its ammo is the whole run inventory again (S5). The
## board calls this when it renders, so both the next board and a restart
## get the full loadout back, while a broken marble stays lost because it
## already left the inventory.
func begin_board() -> void:
	ammo.assign(inventory)


## A thrown marble resolved without a refund (S4): it leaves the board ammo
## only, so the next board restores it from the inventory. Returns the spent
## def, or null when the ammo had no such marble.
func spend_ammo(def: MarbleDef) -> MarbleDef:
	var spent := _take_marble(ammo, def)
	if spent == null:
		return null
	EventBus.marble_removed.emit(spent.id, &"thrown")
	return spent


## A marble broke on the durability roll (S5): it leaves the board ammo and
## the run inventory for good, so the next board does not restore it.
## Returns the lost def, or null when the ammo had no such marble.
func break_ammo(def: MarbleDef) -> MarbleDef:
	var lost := _take_marble(ammo, def)
	if lost == null:
		return null
	_take_marble(inventory, def)
	EventBus.marble_removed.emit(lost.id, &"broke")
	return lost


## Remove the first entry with this def id from a marble list (ammo or
## inventory hold defs, never instances of the marble in flight).
func _take_marble(list: Array[MarbleDef], def: MarbleDef) -> MarbleDef:
	if def == null:
		return null
	for i in list.size():
		if list[i].id == def.id:
			var taken: MarbleDef = list[i]
			list.remove_at(i)
			return taken
	return null


## The board scene is on screen; the run plays board by board.
func in_run() -> bool:
	return run_active


## Block a board belongs to: ceil(n / 4), clamped to the run's blocks so
## endless boards keep the block-5 economy.
func block_of(n: int) -> int:
	return clampi(ceili(n / float(BOARDS_PER_BLOCK)), 1, BLOCKS)


## Boss boards are the last board of every block: 4, 8, 12, 16, 20 (24...).
func is_boss(n: int) -> bool:
	return n % BOARDS_PER_BLOCK == 0


## BoardDef index of run board `n`: boards and defs map one to one in
## filename order (board_01 -> def 0). ContentDB clamps, so endless boards
## (21+) keep rendering the last def and their last identity.
func board_def_index(n: int) -> int:
	if debug_mode:
		# A debug match renders the picked board (S2), whatever run board the
		# single-board match is on.
		return clampi(debug_board_index, 0, maxi(ContentDB.board_count() - 1, 0))
	return n - 1


## Bonificadores of board `n`. Since M2.5 the list comes from the board's
## own BoardDef (`modifiers`), i.e. the assignment is content: a board with
## no modifiers simply has none.
func board_modifiers(n: int) -> Array[BoardModifierDef]:
	var result: Array[BoardModifierDef] = []
	for id in modifier_ids(n):
		var def: BoardModifierDef = ContentDB.modifier_def(id)
		if def != null:
			result.append(def)
	return result


## Ids behind board_modifiers(), without loading the defs: the run board
## asks here and the tests check the assignment cheaply.
func modifier_ids(n: int) -> Array[StringName]:
	var board: BoardDef = ContentDB.board_def(board_def_index(n))
	if board == null:
		return []
	return board.modifiers.duplicate()


## Score a board must reach: bosses use their own base target, then the
## block difficulty factor scales it for every board.
func objective_for_board(n: int, target_base: int) -> int:
	if debug_mode:
		# Debug matches keep the block factor at x1 (S8): the board asks
		# exactly its own BoardDef base target, with no boss override.
		return maxi(target_base, 0)
	var base := BOSS_BASE_OBJECTIVE if is_boss(n) else target_base
	var factor: float = BLOCK_OBJECTIVE_FACTORS[block_of(n) - 1]
	return roundi(float(base) * factor)


## Stats of the last won board, for the win interstitial: puntuación,
## canicas restantes and the reward paid (placeholder until the juice
## pass). Empty until the first board_won.
var last_win_stats := {}


## The board was cleared. Guarded by phase so the board's deferred call and
## any duplicate never pay the reward twice.
func board_won(marbles_left: int, bonus: int, score: int = 0) -> void:
	if not run_active or phase != Phase.BOARD:
		return
	boards_cleared += 1
	if debug_mode:
		# S8: the debug board is the whole match. No reward, no shop, no result
		# screen: back to the debug setup so the loadout can be tweaked and
		# replayed (user request, 2026-11-08).
		board_won_sig.emit(marbles_left, bonus)
		_return_to_debug_setup()
		return
	var reward: int = Economy.reward_for_block_win(block, marbles_left, bonus)
	if endless_mode:
		reward += ENDLESS_BONUS
	money += reward
	money_changed.emit(money)
	board_won_sig.emit(marbles_left, bonus)
	# Win interstitial (user request, 2026-11-08): every won board first
	# plays the GANADOR sequence, then CONTINUAR routes on: the shop in the
	# normal flow, the run summary after board 20 (run_won set below).
	last_win_stats = {
		"score": maxi(score, 0),
		"marbles_left": maxi(marbles_left, 0),
		"reward": reward,
	}
	if current_board_in_run >= BOARDS_PER_RUN and not endless_mode:
		run_won = true
		run_won_sig.emit()
	_enter(Phase.WIN)
	# Win over the live board (user request, 2026-11-08): the board hosts the
	# win screen as a translucent overlay so the game stays visible and alive
	# behind GANADOR and the resumen. A scene that cannot host (or a headless
	# test with no current scene) falls back to the plain scene switch.
	if not _host_overlay(&"host_win_overlay"):
		change_to_current_scene()


## Offer the current scene the chance to host a screen overlay in place
## (win sequence, run summary). Returns false when there is no host, so the
## caller keeps the old scene switch. Never touches run state: the phase and
## routing stay the same.
func _host_overlay(host_method: StringName) -> bool:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return false
	var scene := tree.current_scene
	if not scene.has_method(host_method):
		return false
	scene.call(host_method)
	return true


## CONTINUAR on the win interstitial: back to the run flow — the shop after
## every normal board, the run summary once the run itself is won. Guarded
## by phase like every other screen transition.
func win_screen_continue() -> void:
	if phase != Phase.WIN:
		return
	if run_won:
		# The run summary also plays over the live board (user request,
		# 2026-11-08): the board hosts it in place of the win overlay.
		_enter(Phase.RESULT)
		if not _host_overlay(&"host_result_overlay"):
			change_to_current_scene()
	else:
		_enter(Phase.SHOP)
		change_to_current_scene()


## The shots ran out without reaching the objective: the run is over.
## Guarded by run_active only, so a repeated report never ends a finished
## run twice.
func board_lost() -> void:
	if not run_active:
		return
	run_won = false
	if debug_mode:
		# S8: the lost debug board ends the match back at the debug setup,
		# never at the run summary (user request, 2026-11-08).
		board_lost_sig.emit()
		_return_to_debug_setup()
		return
	run_active = false
	board_lost_sig.emit()
	_enter(Phase.RESULT)
	run_lost_sig.emit()
	# The defeat screen plays over the live board too, like the win sequence
	# (user request, 2026-11-08).
	if not _host_overlay(&"host_result_overlay"):
		change_to_current_scene()


## Leave the shop for the next board; endless boards keep block 5.
func shop_continue() -> void:
	if phase != Phase.SHOP or not run_active:
		return
	current_board_in_run += 1
	block = block_of(current_board_in_run)
	_enter(Phase.BOARD)
	change_to_current_scene()


## Endless opt-in from the run-won screen (GDD D6): back to the shop, then
## every further board is board 21+ at the block-5 rate.
func start_endless() -> void:
	if not run_active:
		return
	endless_mode = true
	_enter(Phase.SHOP)
	change_to_current_scene()


## Back to the title screen; the current run is abandoned.
func enter_menu() -> void:
	run_active = false
	run_won = false
	debug_mode = false
	_enter(Phase.MENU)
	change_to_current_scene()


## A debug match ended: clean the run state like the menu would, but load
## the debug setup screen again (S8, user request) instead of the title.
func _return_to_debug_setup() -> void:
	run_active = false
	run_won = false
	debug_mode = false
	_enter(Phase.MENU)
	_open_debug_setup()


## Load the debug setup screen. Headless runs have no current scene; the
## same guard as change_to_current_scene keeps tests quiet.
func _open_debug_setup() -> void:
	if get_tree().current_scene == null:
		return
	get_tree().change_scene_to_file(DEBUG_SETUP_SCENE)


## Show the scene that renders the current phase. Headless tests run with no
## current scene, so the switch is skipped there and state stays inspectable.
func change_to_current_scene() -> void:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return
	tree.change_scene_to_file(RunFlow.scene_path_for(phase))


func _enter(next_phase: Phase) -> void:
	phase = next_phase
	phase_changed.emit(phase)
