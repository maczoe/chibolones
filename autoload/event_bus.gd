extends Node
## Global gameplay event bus (autoload "EventBus").
## Physics-adjacent systems emit domain events; scoring, modifiers and UI
## subscribe. Payloads stay simple so future content (M2 modifier hooks)
## can react without touching the emitters.

## A marble was launched (marble def id).
signal throw_started(marble_id: String)
## The active marble touched a wall ("left", "right", "back").
signal wall_hit(side: StringName, impact_speed: float)
## The active marble hit a marble already embedded in a notch.
signal embedded_marble_hit(notch_index: int, impact_speed: float)
## A marble embedded in a notch (value = painted score of the notch).
signal embed(notch_index: int, value: int)
## The throw was returned by the forgiving player edge (shot not consumed).
signal refund()
## The active marble finished its throw: "embedded", "settled",
## "off_board", "refunded" or "timed_out".
signal throw_ended(outcome: StringName)
## The board round finished (after every throw resolved).
signal board_ended(score: int)
