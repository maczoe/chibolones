class_name BoardDef
extends Resource
## Data definition of one board (level): geometry, notch layout, capture
## rules and objective. Boards are content: a new level is a new .tres in
## data/boards/, no code changes.

@export var theme_name: String = "Tablero Clasico"

@export_group("Notch grid")
@export var cols: int = 5
@export var rows: int = 4
@export var spacing_x: float = 0.8
@export var first_row_z: float = -0.5
@export var spacing_z: float = 1.1
## Painted score per row, nearest player row first.
@export var row_scores: Array[int] = [10, 20, 30, 50]

@export_group("Board geometry")
@export var width: float = 4.2
@export var length: float = 7.0
@export var thickness: float = 0.12
@export var tilt_deg: float = 6.0
@export var wall_height: float = 0.22
@export var wall_thickness: float = 0.1

@export_group("Aim & capture")
## How far inside the walls the aim marker and tilt guide stay.
@export var aim_limit_margin: float = 0.2
## Launch distance from the forgiving player edge.
@export var launch_depth: float = 0.5
## Max distance between marble center and notch center to embed.
@export var capture_radius: float = 0.08
## Faster than this, the marble skips over notches.
@export var skip_speed: float = 4.5

@export_group("Objective")
## 0 = no numeric objective (POC behavior); otherwise the board is won by
## reaching this score. Used from M1 on.
@export var objective_target: int = 0


func launch_z() -> float:
	return -length / 2.0 + launch_depth
