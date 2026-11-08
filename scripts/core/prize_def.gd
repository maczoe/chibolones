class_name PrizeDef
extends Resource
## Data definition of one feria prize (the Balatro-style permanent modifier).
## Since M2 a prize reacts to gameplay through the hook contract below:
## interested_in() lists the events it cares about and contribute_embed()
## edits the score breakdown of one embed. M3 grows the event surface; the
## contract and the pipeline are already the single seam.

@export var id: String = "prize"
@export var display_name: String = "Premio"
@export var rarity: String = "common"
@export var price: int = 0
@export var flavor: String = ""
## Multiplier applied to the throw's embed score once per wall the marble
## hit during that throw (Trompo = x1.5 per wall).
@export var wall_hit_mult: float = 1.0


## M2 hook contract, part 1: events this prize reacts to. `embed` is the
## scoring moment; more event names land with M3 content.
func interested_in() -> Array[StringName]:
	var events: Array[StringName] = [&"embed"]
	return events


## M2 hook contract, part 2: edit one embed's score. `ctx` carries the
## shared `adds` / `mults` dictionaries (source name -> value), the board
## node and this throw's facts (`ctx.throw`: marble, notch, wall_hits,
## wall_mult, center). Flat adds land after the base value, multipliers
## after the flats; ScoreBreakdown.final() rounds once at the end.
func contribute_embed(_base: int, ctx: Dictionary) -> void:
	var mults: Dictionary = ctx.get("mults", {})
	var throw_ctx: Dictionary = ctx.get("throw", {})
	# Wall-hit multiplier: once per wall this throw (Trompo x1.5 x walls).
	if is_equal_approx(wall_hit_mult, 1.0):
		return
	var hits: int = int(throw_ctx.get("wall_hits", 0))
	if hits <= 0:
		return
	mults[StringName(display_name)] = pow(wall_hit_mult, hits)


## HUD text for a multiplier: "x" plus the value without trailing zeros
## (1.5 -> "x1.5", 2.25 -> "x2.25", 2.0 -> "x2").
static func format_mult(value: float) -> String:
	var text := String.num(value, 2)
	while text.ends_with("0"):
		text = text.substr(0, text.length() - 1)
	if text.ends_with("."):
		text = text.substr(0, text.length() - 1)
	return "x" + text
