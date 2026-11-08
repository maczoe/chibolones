class_name MarbleDef
extends Resource
## Data definition of one marble type. One 3D model, identity via material:
## palette colors now (M0), texture patterns and shaders from M6.

enum Category { COMMON, MAGIC }

@export var id: String = "common"
@export var display_name: String = "Canica Comun"
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
