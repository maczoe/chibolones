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
## W3: which effect this prize carries. Empty string = no active effect
## (a shelf trophy). The effect decides the events the prize reacts to and
## what its on_event/contribute_embed do; params carries the numbers.
@export var effect: StringName = &""
## Effect parameters (flat amount, refund money, per-wall mult...), read
## by the effect implementation. One def, one effect, its own params.
@export var params: Dictionary = {}


## Events each effect reacts to, beyond the shared `embed` scoring pass
## (architecture.md hook contract: interested_in / on_event /
## contribute_embed). New effects register here in T3.
const EFFECT_EVENTS := {
	&"wall_mult": [&"embed"],
	&"board_end_flat": [&"board_ended"],
	&"refund_money": [&"refund"],
	&"score_mult_all": [&"embed", &"board_ended"],
	&"bounce_scale": [&"marble_spawn"],
	&"fire_speed_mult": [&"marble_spawn"],
	# Queried by the board, no trigger events.
	&"extra_throw": [],
	&"skip_speed_scale": [],
}


## M2 hook contract, part 1: events this prize reacts to. `embed` is the
## scoring moment; the effect adds its trigger events on top.
func interested_in() -> Array[StringName]:
	var events: Array[StringName] = [&"embed"]
	for event in EFFECT_EVENTS.get(effect, []):
		if not events.has(event):
			events.append(event)
	return events


## M3 hook contract: react to one gameplay event the prize declared
## interest in. Data effects only: prizes edit the ctx the dispatcher
## carries (score_bonus, money_delta...); the owner applies it.
func on_event(event: StringName, ctx: Dictionary) -> void:
	match event:
		&"board_ended":
			if effect == &"board_end_flat":
				var bonus: Dictionary = ctx.get("score_bonus", {})
				bonus[StringName(display_name)] = int(params.get("flat", 0))
			elif effect == &"score_mult_all":
				ctx["score_mult_all"] = float(ctx.get("score_mult_all", 1.0)) \
						* float(params.get("mult", 1.0))
		&"refund":
			if effect == &"refund_money":
				ctx["money_delta"] = int(ctx.get("money_delta", 0)) \
						+ int(params.get("amount", 0))
		&"marble_spawn":
			if effect == &"bounce_scale":
				ctx["bounce_scale"] = float(ctx.get("bounce_scale", 1.0)) \
						* float(params.get("bounce", 1.0))
			elif effect == &"fire_speed_mult":
				var def = ctx.get("def")
				if def != null and def.id == "fire":
					ctx["speed_mult"] = float(ctx.get("speed_mult", 1.0)) \
							* float(params.get("mult", 1.0))


## M2 hook contract, part 2: edit one embed's score. `ctx` carries the
## shared `adds` / `mults` dictionaries (source name -> value), the board
## node and this throw's facts (`ctx.throw`: marble, notch, wall_hits,
## wall_mult, center). Flat adds land after the base value, multipliers
## after the flats; ScoreBreakdown.final() rounds once at the end.
func contribute_embed(_base: int, ctx: Dictionary) -> void:
	var mults: Dictionary = ctx.get("mults", {})
	# Corona del Circo: x1.1 to everything, on every embed.
	if effect == &"score_mult_all":
		mults[StringName(display_name)] = float(params.get("mult", 1.0))
		return
	var throw_ctx: Dictionary = ctx.get("throw", {})
	# Wall-hit multiplier: once per wall this throw (Trompo x1.5 x walls).
	if is_equal_approx(wall_mult_per_hit(), 1.0):
		return
	var hits: int = int(throw_ctx.get("wall_hits", 0))
	if hits <= 0:
		return
	mults[StringName(display_name)] = pow(wall_mult_per_hit(), hits)


## Per-wall factor of this prize for the board's wall accumulation
## (migrated from the retired wall_hit_mult field into effect+params).
func wall_mult_per_hit() -> float:
	if effect == &"wall_mult":
		return float(params.get("mult", 1.0))
	return 1.0


## HUD text for a multiplier: "x" plus the value without trailing zeros
## (1.5 -> "x1.5", 2.25 -> "x2.25", 2.0 -> "x2").
static func format_mult(value: float) -> String:
	var text := String.num(value, 2)
	while text.ends_with("0"):
		text = text.substr(0, text.length() - 1)
	if text.ends_with("."):
		text = text.substr(0, text.length() - 1)
	return "x" + text
