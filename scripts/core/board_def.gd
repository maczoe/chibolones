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
## reaching this score. Used from M1 on. The run scales this base by the
## block difficulty factor (Game.objective_for_board).
@export var objective_target: int = 0

@export_group("Board rules")
## Bonificadores of this board, by id (content-plan §4.3): each id is
## resolved through ContentDB into a BoardModifierDef. Empty = no rule.
@export var modifiers: Array[StringName] = []

@export_group("Theme style")
## Play surface color (the pinball-cabinet interior).
@export var board_color: Color = Color("5b34a6")
## Cabinet frame and walls.
@export var frame_color: Color = Color("2e1b58")
## Emissive rim glow around notches.
@export var notch_glow_color: Color = Color("4deeea")
## Fair bulbs along the cabinet edges.
@export var bulb_color: Color = Color("ffe066")
## Chase speed of the pinball bulb pattern while preparing a throw.
@export var bulb_pattern_speed: float = 8.0
## Tint of the spotlight over the board.
@export var light_color: Color = Color("ff9fd6")
## Ambient brightness of the scene (dark = dramatic).
@export var ambient_energy: float = 0.55

@export_group("Backdrop")
## Moving backdrop: three cycling colors, speed and scale, plus the shader
## variant that paints them (waves, spiral or rays; unknown = waves).
@export var backdrop_color_a: Color = Color("3a1f6e")
@export var backdrop_color_b: Color = Color("ff6fb5")
@export var backdrop_color_c: Color = Color("4deeea")
@export var backdrop_speed: float = 0.6
@export var backdrop_scale: float = 3.0
@export var backdrop_style: StringName = &"waves"

@export_group("Floor")
## Circus checker floor, tinted per theme.
@export var floor_checker_a: Color = Color("f2f2f7")
@export var floor_checker_b: Color = Color("14102a")
@export var floor_checker_size: float = 8.0

@export_group("Deck art")
## Emblem of the board: the decorative art printed on the play surface
## between the launch zone and the notch rows, and on both cabinet sides.
## It is the board's identity card, so every board def carries one.
@export var emblem: Texture2D
## Deprecated alias of `emblem`, kept so older defs still show their art;
## read it through deck_art_texture(), never directly.
@export var deck_art: Texture2D
@export var deck_art_width: float = 1.6
## Same art on both cabinet side faces, centered; 0 disables side art.
@export var deck_art_side_width: float = 0.5

## Shader variants of the moving backdrop, by style id.
const BACKDROP_SHADERS := {
	&"waves": "res://scripts/board/shaders/backdrop.gdshader",
	&"spiral": "res://scripts/board/shaders/backdrop_spiral.gdshader",
	&"rays": "res://scripts/board/shaders/backdrop_rays.gdshader",
}


## Art the board prints on its deck and sides: the emblem, falling back to
## the deprecated deck_art field. Null when the def has neither.
func deck_art_texture() -> Texture2D:
	return emblem if emblem != null else deck_art


## Shader that paints this board's backdrop; an unknown style falls back to
## waves so a typo in a .tres never leaves the board without a void.
func backdrop_shader_path() -> String:
	return BACKDROP_SHADERS.get(backdrop_style, BACKDROP_SHADERS[&"waves"])


func launch_z() -> float:
	return -length / 2.0 + launch_depth
