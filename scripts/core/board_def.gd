class_name BoardDef
extends Resource
## Data definition of one board (level): geometry, notch layout, capture
## rules and objective. Boards are content: a new level is a new .tres in
## data/boards/, no code changes.

@export var theme_name: String = "Tablero Clasico"

@export_group("Notch grid")
@export var cols: int = 5
@export var rows: int = 4
@export var spacing_x: float = 0.72
@export var first_row_z: float = -0.5
@export var spacing_z: float = 1.0
## Painted score per row, nearest player row first.
@export var row_scores: Array[int] = [10, 20, 30, 50]

@export_group("Notch matrix (D12)")
## Per-hole values, row-major (rows*cols entries). 0 or a missing entry
## falls back to row_scores[row]. The classic 10/20/30/50 board leaves
## this empty; a themed matrix paints e.g. a single 30 trap-column.
@export var hole_values: Array[int] = []
## Trap holes, row-major, same indexing as hole_values. A marble landing
## in a trap sinks with no score and the throw is voided (tiro anulado);
## the shot budget is untouched.
@export var trap_holes: Array[bool] = []

@export_group("Board geometry")
@export var width: float = 3.9
@export var length: float = 6.4
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
## Tuning 2026-11-08: 0.08 -> 0.10 so bouncing drops land more often.
@export var capture_radius: float = 0.1
## Gentle attraction toward the nearest open notch while the marble rolls
## below skip speed (tuning 2026-11-08): nudges the drop-in without
## steering the throw. 0 disables it; Iman stacks its stronger magnet on
## top of this.
@export var capture_pull: float = 0.4
## Faster than this, the marble skips over notches.
@export var skip_speed: float = 4.5

@export_group("Objective")
## How this board is won (design-decisions-v2.md D9). THRESHOLD is the
## classic `score >= objective_target` (current behavior, scaled by the
## run's block factor); the other kinds read their own fields below and
## are absolute — scaling an exact target would break the designed matrix.
enum ObjectiveKind { THRESHOLD, EXACT, RANGE, LIST, MATH, ANY }

@export var objective_kind: ObjectiveKind = ObjectiveKind.THRESHOLD
## THRESHOLD: score to reach. EXACT: the exact final score. RANGE: ignored
## (see objective_range_min/max). LIST/ANY: ignored (see objective_goals).
## MATH: minimum score before the rule can win.
## 0 = no numeric objective (POC behavior). The run scales this base by the
## block difficulty factor (Game.objective_for_board) on THRESHOLD only.
@export var objective_target: int = 0
## RANGE: inclusive bounds; invalid bounds fall back to exact of the target.
@export var objective_range_min: int = 0
@export var objective_range_max: int = 0
## LIST: cumulative totals to hit exactly, in order. ANY: one of
## these totals wins on its own (alternatives, La Escalera).
@export var objective_goals: Array[int] = []
## MATH: rule the final score must satisfy once the minimum is reached.
@export var objective_rule: StringName = &"even"

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
## Painted score number on each notch. Must contrast with board_color
## (themes.gd checks the luminance difference).
@export var notch_label_color: Color = Color(0.95, 0.9, 0.75)
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


## Value painted on one hole, by grid position: the per-hole matrix when
## it defines one, the row default otherwise.
func hole_value(row: int, col: int) -> int:
	var idx := row * cols + col
	if idx >= 0 and idx < hole_values.size() and hole_values[idx] != 0:
		return hole_values[idx]
	return row_scores[row] if row >= 0 and row < row_scores.size() else 0


## True when the hole at this grid position is a trap (D12 loss hole).
func is_trap_hole(row: int, col: int) -> bool:
	var idx := row * cols + col
	return idx >= 0 and idx < trap_holes.size() and trap_holes[idx]


func launch_z() -> float:
	return -length / 2.0 + launch_depth
