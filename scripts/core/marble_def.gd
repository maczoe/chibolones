class_name MarbleDef
extends Resource
## Data definition of one marble type. One 3D model, identity via material:
## palette colors now (M0), texture patterns and shaders from M6.

enum Category { COMMON, MAGIC }

@export var id: String = "common"
@export var display_name: String = "Canica Comun"
@export var rarity: String = "common"
@export var category: Category = Category.COMMON
## Magic marbles are single-use: consumed when thrown.
@export var single_use: bool = false
@export var flavor: String = ""

@export_group("Physics")
@export var radius: float = 0.09
@export var mass: float = 1.0
@export var bounce: float = 0.2
@export var friction: float = 0.6
## Multiplier applied to the launch speed.
@export var speed_mult: float = 1.0
## Scoring multiplier applied to notch values embedded by this marble.
@export var score_mult: float = 1.0

@export_group("Identity & economy")
## Material style MarbleFactory builds for the shared 3D model: "swirl"
## (solid palette color, the POC look), "fire" (glowing core) or "glass"
## (translucent). A new look is a def, not a code change.
@export var style: StringName = &"swirl"
## Shot colors for the common set (index = shot number in M0).
@export var palette: Array[Color] = [Color.WHITE]
@export var price: int = 0
## Effect ids the marble carries (rethrow, glass, homing...). Active from
## M2 on; decorative until then.
@export var effects: Array[StringName] = []
## Chance [0..1] of the marble breaking when thrown (glass).
@export var break_chance: float = 0.0


## W3b: what this marble does, one readable line for the shop. Driven by
## the effects ids plus the physics fields the marble itself owns.
func effect_description() -> String:
	var parts: Array[String] = []
	for effect in effects:
		match effect:
			&"wind_steady":
				parts.append("No la mueve el viento")
			&"center_pull":
				parts.append("Curva hacia el centro del tablero")
			&"homing":
				parts.append("Elige tu muesca con la mira: va sola hacia ella")
			&"side_refund":
				parts.append("Si sale por un costado, vuelve y no se gasta")
			&"embed_anywhere":
				parts.append("Se clava en cualquier muesca, aunque pase rapido")
			&"copy_prev":
				parts.append("Vale lo mismo que tu tiro anterior (si hizo mas de 0)")
			_:
				parts.append(str(effect))
	if not is_equal_approx(speed_mult, 1.0):
		parts.append("Sale x%s de velocidad" % PrizeDef.format_mult(speed_mult))
	if not is_equal_approx(score_mult, 1.0):
		parts.append("Puntua x%s" % PrizeDef.format_mult(score_mult))
	if break_chance > 0.0:
		parts.append("Puede romperse al tirar (%d%%)" % roundi(break_chance * 100))
	if single_use:
		parts.append("De un solo uso")
	if parts.is_empty():
		parts.append("Sin efectos: la canica clasica")
	return " ".join(parts)
