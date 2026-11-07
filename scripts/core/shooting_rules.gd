class_name ShootingRules
extends Resource
## Tunable numbers of the throw flow (aim, tilt, power, settling). Lives in
## data/balance/ so a designer can tweak the feel without touching logic.

@export_group("Aim")
@export var aim_speed: float = 1.2

@export_group("Tilt guide")
@export var tilt_speed: float = 70.0

@export_group("Power & launch")
@export var min_speed: float = 2.2
@export var max_speed: float = 9.0
@export var power_speed: float = 110.0

@export_group("Off board")
## Past an edge plus this margin = off board.
@export var edge_margin: float = 0.25

@export_group("Settling")
@export var settle_speed: float = 0.15
@export var settle_time: float = 1.2
@export var flight_timeout: float = 7.0

@export_group("Board round")
@export var shots_per_board: int = 5
