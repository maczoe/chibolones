# M2 — Hook contract, scoring pipeline and bonificadores

Implements the event-driven rule layer: prizes and board modifiers
(bonificadores) react to gameplay events and edit the score through one
pipeline. Delivers the 10 bonificadores from docs/gdd/content-plan.md §4.3
and the marble durability events (glass break 20%).

## Specs

S1 (architecture §3 hook contract): Defs declare interested_in() events, on_event() triggers and edit_score() contributions; ScoreEngine collects adds/mults, applies flats then multipliers, and publishes the breakdown.
S2 (content-plan §4.3): 10 bonificadores — Cuerda (bouncy walls +mult per hit), Mojado (low friction), Borracho (value shuffle), Espejo (x2 center), Ventoso (cross wind), Mochila (one covered notch per throw), Fantasma (phasing notch), Iman (embedded attraction), Trapecio (swinging grid), Cronometrado (4s decision timer with auto-throw).
S3 (content-plan §4.1, M2 scope): glass break — a glass marble breaks on throw with 20% chance (marble_removed event, bag count updates; the throw still happens).
S4 (GDD §5): scoring stays legible: HUD shows the math when modifiers act (breakdown line), per-board modifiers announce themselves at board start.

## Tasks

T1 [S1] Hook pipeline: DefHooks contract on PrizeDef/BoardModifierDef, ScoreEngine pipeline (events -> adds/mults -> embed value), EventBus additions (marble_removed, modifier events). Commit W1.
T2 [S2] BoardModifierDef + 10 bonificadores as .tres + board runtime for rule edits (friction, wind, shuffle, phases, swings, timers, attraction) + HUD cues. Commit W2.
T3 [S3] Glass break on throw + marble_removed event + bag/HUD update. Commit W2.
T4 [S4] Breakdown HUD line + modifier announcements + tests (hook math per modifier, break probability sanity, objective interplay). Commit W3.
T5 Docs (architecture hook contract delivered, content-plan cross-check, README modifiers). Commit W3.

## Log

L1 (user): "todo funciona correctamente, procede con M2"
