# M2 — Hook contract, scoring pipeline and bonificadores

Implements the event-driven rule layer: prizes and board modifiers
(bonificadores) react to gameplay events and edit the score through one
pipeline. Delivers the 10 bonificadores from docs/gdd/content-plan.md §4.3
and the marble durability events (glass break 20%).

## Specs

S1 (architecture §3 hook contract, M2 scope): Defs declare interested_in() and contribute_embed() (the embedding scoring slice of on_event/edit_score; full per-event triggers land with M3+ content); ScoreEngine collects adds/mults, applies flats then multipliers, and publishes the breakdown.
S2 (content-plan §4.3): 10 bonificadores — Cuerda (bouncy walls +mult per hit), Mojado (low friction), Borracho (value shuffle), Espejo (x2 center), Ventoso (cross wind), Mochila (one covered notch per throw), Fantasma (phasing notch), Iman (embedded attraction), Trapecio (swinging grid), Cronometrado (4s decision timer with auto-throw).
S3 (content-plan §4.1, M2 scope): glass break — a glass marble breaks on throw with 20% chance (marble_removed event, bag count updates; the throw still happens).
S4 (GDD §5): scoring stays legible: HUD shows the math when modifiers act (breakdown line), per-board modifiers announce themselves at board start.

## Tasks

T1 [S1] DONE. Pipeline: ScoreBreakdown (final/describe) + ScoreEngine.evaluate_embed; PrizeDef.interested_in/contribute_embed; MarbleDef.score_mult; EventBus +5 signals (marble_removed, modifier_active, throw_timer_tick, value_shuffled, wind_changed).
- DONE (W1): `ScoreBreakdown` (base -> adds -> mults -> one roundi) and `ScoreEngine.evaluate_embed(base, ctx)`; `PrizeDef.interested_in()` / `contribute_embed()` (trompo = x1.5 per wall, read from `ctx.throw.wall_hits`), `BoardModifierDef.contribute_embed()` (Espejo), `MarbleDef.score_mult` and the board's wall accumulation as extra mult sources. EventBus gained `marble_removed`, `modifier_active`, `throw_timer_tick`, `value_shuffled`, `wind_changed`. Evidence: hooks (a)(b)(i) green; smoke + run_loop identical and green.
T2 [S2] BoardModifierDef + 10 bonificadores as .tres + board runtime for rule edits (friction, wind, shuffle, phases, swings, timers, attraction) + HUD cues. Commit W2.
- DONE (W2): 10 .tres under `data/modifiers/` loaded by `ContentDB.modifier_def()`; `scripts/board/board_theme.gd` applies every rule (wall bounce + wall mult, friction, wind, value shuffle, covered notch, phasing notch, magnet, grid sway, decision timer); `Game.board_modifiers(n)` gives none/one per normal board and the block pair per boss board. HUD: `set_breakdown()`, `set_timer()` and the queued board-start banners (1.2 s apart). Evidence: hooks (c)(d)(e)(g)(h) green.
T3 [S3] Glass break on throw + marble_removed event + bag/HUD update. Commit W2.
- DONE (W2): `_launch` rolls `break_chance` once before spawning, emits `marble_removed(id, &"broke")`, drops the first matching bag entry (never the last one: guard documented in `_try_break`), flashes "Tu canica de vidrio se rompio!" and throws the next bag marble. The .tres keeps `break_chance = 0.0` until the M3 data wave. Evidence: hooks (f) green.
T4 [S4] Breakdown HUD line + modifier announcements + tests (hook math per modifier, break probability sanity, objective interplay). Commit W3.
- DONE (W3): breakdown line under the flash messages (hidden when nothing acted) and the modifier banner chain; `tests/hooks.gd` covers the pipeline, the 10 defs, shuffle, timer, break, center mult, wind/sway wiring and the M1 wall math. No objective math changed (bonus objectives still future work).
T5 Docs (architecture hook contract delivered, content-plan cross-check, README modifiers). Commit W3.
- DONE (W3): `docs/architecture.md` §3 hook contract + M2 row delivered, `docs/gdd/content-plan.md` §4.3 marked implemented (W2), README gained the bonificadores table, the boss-pair rule and the score-math line.

## Log

L1 (user): "todo funciona correctamente, procede con M2"
