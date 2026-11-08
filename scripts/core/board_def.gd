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
## Cabinet drop below the play surface: how tall the box stands (a small
## person's height at marble scale).
@export var skirt_height: float = 1.2

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

@export_group("Theme style")
## Play surface color (the pinball-cabinet interior).
@export var board_color: Color = Color("5b34a6")
## Cabinet frame and walls.
@export var frame_color: Color = Color("2e1b58")
## Emissive rim glow around notches.
@export var notch_glow_color: Color = Color("4deeea")
## Fair bulbs along the cabinet edges.
@export var bulb_color: Color = Color("ffe066")
## Tint of the spotlight over the board.
@export var light_color: Color = Color("ff9fd6")
## Ambient brightness of the scene (dark = dramatic).
@export var ambient_energy: float = 0.55

@export_group("Backdrop")
## Psychedelic moving backdrop: three cycling colors, speed and scale.
@export var backdrop_color_a: Color = Color("3a1f6e")
@export var backdrop_color_b: Color = Color("ff6fb5")
@export var backdrop_color_c: Color = Color("4deeea")
@export var backdrop_speed: float = 0.6
@export var backdrop_scale: float = 3.0

@export_group("Floor")
## Circus checker floor, tinted per theme.
@export var floor_checker_a: Color = Color("f2f2f7")
@export var floor_checker_b: Color = Color("14102a")
@export var floor_checker_size: float = 8.0

@export_group("Deck art")
## Decorative art printed on the play surface between the launch zone and
## the notch rows, centered on X and on that band (null = none).
@export var deck_art: Texture2D
@export var deck_art_width: float = 1.6
## Same art on both cabinet side faces, centered; 0 disables side art.
@export var deck_art_side_width: float = 0.5


func launch_z() -> float:
	return -length / 2.0 + launch_depth
