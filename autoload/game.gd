extends Node
## Run flow state machine (autoload "Game"). M0: board-only shell; the run
## loop (economy, shop, 20 boards, permadeath) lands in M1 on top of this.

enum Phase { MENU, BOARD, SHOP, GAME_OVER }

## Sample marbles the run starts with, in bag order (M1 hands this to the
## shop; M0.5 seeds the three sample defs so the slice can be played).
const SAMPLE_MARBLES := ["common", "fire", "glass"]
const SAMPLE_PRIZE := "trompo"

signal phase_changed(phase: Phase)

var phase: Phase = Phase.BOARD
var board_index := 0
var money := 0
## The marble bag: what the player can pick per throw (index = bag slot).
var bag: Array[MarbleDef] = []
## Prizes owned this run: permanent effects (M2 hook contract).
var prizes: Array[PrizeDef] = []


func start_run() -> void:
	board_index = 0
	money = 5
	bag.clear()
	prizes.clear()
	for marble_id in SAMPLE_MARBLES:
		var marble: MarbleDef = ContentDB.marble_def(marble_id)
		if marble != null:
			bag.append(marble)
	var prize: PrizeDef = ContentDB.prize_def(SAMPLE_PRIZE)
	if prize != null:
		prizes.append(prize)
	_enter(Phase.BOARD)


func restart_board() -> void:
	get_tree().reload_current_scene()


func _enter(next_phase: Phase) -> void:
	phase = next_phase
	phase_changed.emit(phase)
