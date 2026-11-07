extends Node
## Run flow state machine (autoload "Game"). M0: board-only shell; the run
## loop (economy, shop, 20 boards, permadeath) lands in M1 on top of this.

enum Phase { MENU, BOARD, SHOP, GAME_OVER }

signal phase_changed(phase: Phase)

var phase: Phase = Phase.BOARD
var board_index := 0
var money := 0
## The marble bag (M1 fills it; the board scene still uses the common def).
var bag: Array[MarbleDef] = []
var prizes: Array[Resource] = []


func start_run() -> void:
	board_index = 0
	money = 5
	bag.clear()
	prizes.clear()
	_enter(Phase.BOARD)


func restart_board() -> void:
	get_tree().reload_current_scene()


func _enter(next_phase: Phase) -> void:
	phase = next_phase
	phase_changed.emit(phase)
