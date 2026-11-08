class_name BoardModifierDef
extends Resource
## Data definition of one bonificador: the board-scoped rule of a board
## (content-plan §4.3). Every field is a rule edit, never code: the board
## runtime (scripts/board/board_theme.gd) reads the fields of the active
## modifiers and applies them, and ScoreEngine asks the same defs for their
## contributions through the M2 hook contract.
##
## A field left at its neutral value means "this rule is off", so one def
## can combine several rules and a future board can stack two of them.

@export var id: StringName = &"modifier"
@export var display_name: String = "Bonificador"
@export var description: String = ""

@export_group("Wall rules")
## Restitution the side and back walls gain in this board (0 = off).
@export var wall_bounciness: float = 0.0
## Embed multiplier per wall the marble hits this throw (1 = off).
@export var wall_hit_mult: float = 1.0

@export_group("Marble rules")
## Scales the spawned marble's physics friction (1 = off, below 1 = ice).
@export var friction_scale: float = 1.0
## Sideways force in flight (Newtons at mass 1); the side flips per throw.
@export var wind_strength: float = 0.0
## Attraction from an embedded marble to a rolling one within 1 unit.
@export var magnet_strength: float = 0.0

@export_group("Notch rules")
## Reshuffle the painted notch values at every throw start.
@export var value_shuffle: bool = false
## One random notch is covered (unembeddable) for the whole throw.
@export var cover_notch: bool = false
## One random notch phases in and out every 2 seconds.
@export var phase_notch: bool = false
## Sideways sway of the whole notch grid, in radians per second (0 = off).
@export var grid_swing_speed: float = 0.0
## Embed multiplier for the center column (1 = off).
@export var center_mult: float = 1.0


## M3 hook contract: the trigger half of the shared contract, symmetric
## with PrizeDef.on_event. Modifiers react through the same dispatcher;
## data rules only (edit ctx, never touch autoloads directly).
func on_event(_event: StringName, _ctx: Dictionary) -> void:
	pass

@export_group("Decision rules")
## Seconds the player has per throw step before the board decides for them
## (0 = off).
@export var decision_timer_sec: float = 0.0

@export_group("Event hooks")
## Events this modifier reacts to beyond the scoring moment (M3 grows the
## trigger surface; M2 only scores embeds).
@export var embed_events: Array[StringName] = []


## M2 hook contract, part 1: events this bonificador reacts to.
func interested_in() -> Array[StringName]:
	var events: Array[StringName] = [&"embed"]
	for event in embed_events:
		if not events.has(event):
			events.append(event)
	return events


## M2 hook contract, part 2 (scoring pass). Rules that only change physics
## or the notch layout do not score by themselves; the center column pays
## its own multiplier here.
func contribute_embed(_base: int, ctx: Dictionary) -> void:
	if is_equal_approx(center_mult, 1.0):
		return
	var throw_ctx: Dictionary = ctx.get("throw", {})
	if not bool(throw_ctx.get("center", false)):
		return
	var mults: Dictionary = ctx.get("mults", {})
	mults[StringName(display_name)] = center_mult
