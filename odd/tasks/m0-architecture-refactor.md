# M0 — Architecture refactor

Refactor the POC into the target architecture from docs/architecture.md
with zero gameplay change. Also establishes cross-platform foundations:
InputMap actions decoupled from devices (keyboard + gamepad now, touch
later), resolution scaling for most devices, renderer fallbacks.

## Specs

S1 (from architecture plan): data-driven content — marbles, boards,
modifiers, prizes are .tres Def resources; adding content means adding
data, not code.
S2 (from architecture plan): event-driven rules — physics emits domain
events on an EventBus; scoring subscribes; no cross-system reach-ins.
S3 (from architecture plan): one balance surface — all tunable numbers in
data/balance/ and Def resources.
S4 (user): "toma en consideracion el mapeo de controles para publicar en
pc, android, consolas etc" — InputMap actions with keyboard + gamepad
bindings, device-agnostic action names, touch to come later.
S5 (user): "toma en cuenta la resolucion y que funcione en la mayoria de
dispositivos" — 1080p base viewport, canvas_items stretch + expand aspect,
landscape handheld, renderer with mobile fallback.
S6 (architecture plan M0): POC behavior must not change; existing smoke +
probe tests stay green (smoke updated to the new seams).

## Tasks

T1 [S4,S5] project.godot: display scaling (1920x1080 canvas_items/expand,
landscape), mobile renderer fallback, InputMap with gamepad bindings
(stick + dpad, face button, start). Commit W1.
T2 [S2] autoload/event_bus.gd gameplay signals. Commit W1.
T3 [S1] Def scripts (BoardDef, MarbleDef, ShootingRules) + balance/boards/
marbles .tres data + autoload content_db.gd. Commit W1.
T4 [S2,S3] Board refactor: scripts/board/board.gd (throw flow from defs,
event emission), marble_factory.gd, scoring/score_engine.gd,
board/hud.gd, game.gd autoload shell, scenes/board/board.tscn; POC
main.gd/main.tscn retired. Commit W2.
T5 [S6] Tests: smoke.gd updated to new seams (board scene + event
assertions), physics_probe.gd untouched; all headless green. Commit W3.
T6 [S6] Docs: README (controls table + gamepad + scaling), architecture.md
(M0 delivered), feature doc status. Commit W3.

## Log

L1 (user, verbatim): "arranca con M0, toma en consideracion el mapeo de controles para publicar en pc, android, consolas etc, toma en cuenta la resolucion y que funcione en la mayoria de dispositivos, lo demas te dejo a ti que lo estructures con una buena arquitectura y luego pasamos a realizar la planificacion del refinado del diseno"
