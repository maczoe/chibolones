class_name RunFlow
## Screen routing for the run skeleton: which scene renders each Game phase.
## The phase constants mirror the Game.Phase enum order; this file stays free
## of any dependency on the Game autoload because game.gd depends on it.

const PHASE_MENU := 0
const PHASE_BOARD := 1
const PHASE_SHOP := 2
const PHASE_RESULT := 3
const PHASE_GAME_OVER := 4
const PHASE_WIN := 5

const MENU_SCENE := "res://scenes/menu/menu.tscn"
const BOARD_SCENE := "res://scenes/board/board.tscn"
const SHOP_SCENE := "res://scenes/shop/shop.tscn"
const RESULT_SCENE := "res://scenes/run/result.tscn"
const WIN_SCENE := "res://scenes/run/win.tscn"


## Scene path for a Game.Phase value; unknown phases fall back to the menu
## so the player is never left on a dead screen.
static func scene_path_for(phase: int) -> String:
	match phase:
		PHASE_BOARD:
			return BOARD_SCENE
		PHASE_SHOP:
			return SHOP_SCENE
		PHASE_RESULT, PHASE_GAME_OVER:
			return RESULT_SCENE
		PHASE_WIN:
			return WIN_SCENE
		_:
			return MENU_SCENE
