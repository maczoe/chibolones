class_name ScoreBreakdown
extends RefCounted
## One embed's score math, collected by ScoreEngine.evaluate_embed: the
## painted value, the flat adds and the multipliers every interested party
## contributed. Legibility is the point (GDD §5): the same object renders
## the HUD line and, via final(), the number that is actually scored.
##
## Math order is fixed: flats are added to the base, then the multipliers
## multiply the sum, and only then the value is rounded.

## Painted value of the notch before any rule acts.
var base_value := 0
## Flat additions, keyed by source name (StringName -> int).
var adds: Dictionary = {}
## Multipliers, keyed by source name (StringName -> float).
var mults: Dictionary = {}


## The value the board actually scores.
func final() -> int:
	var flat := float(base_value)
	for value in adds.values():
		flat += float(value)
	var product := 1.0
	for value in mults.values():
		product *= float(value)
	return roundi(flat * product)


## True when a prize, marble or bonificador changed the value.
func acted() -> bool:
	return not adds.is_empty() or not mults.is_empty()


## Compact single line for the HUD ("20 +5 (Osito) x1.5 (Trompo)"), or ""
## when nothing acted, so a clean throw shows no score-math noise.
func describe() -> String:
	if not acted():
		return ""
	var parts: Array[String] = [str(base_value)]
	for source in adds:
		parts.append("+%d (%s)" % [int(adds[source]), source])
	for source in mults:
		parts.append("%s (%s)" % [PrizeDef.format_mult(float(mults[source])), source])
	var line := ""
	for part in parts:
		line += (" " if line != "" else "") + part
	return line
