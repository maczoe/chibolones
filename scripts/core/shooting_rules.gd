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
## Safety net only: real outcomes (embed, settle, off-board exit) resolve
## throws on their own. Generous, because a slow roll back down the tilted
## board can legitimately take a while and ends as a refund.
@export var flight_timeout: float = 15.0

@export_group("Board round")
@export var shots_per_board: int = 5

@export_group("Camera")
## Default (cenital) camera: height above the surface, distance behind the
## player edge, and the board-center Z the camera always aims at. The orbit
## radius and default elevation derive from these.
@export var cam_height: float = 7.2
@export var cam_back: float = 1.6
@export var cam_look_z: float = 0.4
## Camera mode (Z / LB) orbits the board center: angular speed, elevation
## limits (never below the surface plane, so the view can't flip past 90
## degrees) and how far sideways the camera may travel.
@export var cam_orbit_speed: float = 70.0
@export var cam_min_elev_deg: float = 10.0
@export var cam_max_elev_deg: float = 86.0
@export var cam_azimuth_limit_deg: float = 100.0
