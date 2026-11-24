class_name UnlockTable
extends Resource
## Starter pool and milestone unlocks (S5, S6): the content a first run may
## draw from, and what clearing a milestone board or winning a run adds to that
## pool forever. Data, not code: the profile reads this table, so tuning the
## progression never touches a script.

## Marbles available before any unlock (six, per S5).
@export var starter_marbles: Array[String] = []
## Prizes available before any unlock (six, per S5).
@export var starter_prizes: Array[String] = []
## One entry per milestone board: {"board": int, "marbles": [ids], "prizes": [ids]}.
@export var milestones: Array[Dictionary] = []
## What winning a run unlocks on top of its board milestones.
@export var run_won_marbles: Array[String] = []
@export var run_won_prizes: Array[String] = []


## The ids a milestone board grants, as one flat list (marbles first).
func unlocked_by_board(board_index: int) -> Dictionary:
	var marbles: Array[String] = []
	var prizes: Array[String] = []
	for entry in milestones:
		if int(entry.get("board", 0)) != board_index:
			continue
		for id in entry.get("marbles", []):
			marbles.append(str(id))
		for id in entry.get("prizes", []):
			prizes.append(str(id))
	return {"marbles": marbles, "prizes": prizes}
