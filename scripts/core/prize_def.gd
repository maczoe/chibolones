class_name PrizeDef
extends Resource
## Data definition of one feria prize (the Balatro-style permanent modifier).
## M0.5 carries the wall-hit multiplier only; the M2 hook contract
## (interested_in / on_event / edit_score) plugs into this same resource.

@export var id: String = "prize"
@export var display_name: String = "Premio"
@export var rarity: String = "common"
@export var price: int = 0
@export var flavor: String = ""
## Multiplier applied to the throw's embed score once per wall the marble
## hit during that throw (Trompo = x1.5 per wall).
@export var wall_hit_mult: float = 1.0


## HUD text for a multiplier: "x" plus the value without trailing zeros
## (1.5 -> "x1.5", 2.25 -> "x2.25", 2.0 -> "x2").
static func format_mult(value: float) -> String:
	var text := String.num(value, 2)
	while text.ends_with("0"):
		text = text.substr(0, text.length() - 1)
	if text.ends_with("."):
		text = text.substr(0, text.length() - 1)
	return "x" + text
