# Chibolones — Architecture & Implementation Plan

Companion to `docs/gdd/gdd.md`. Goal: a codebase where content (marbles,
prizes, boards, modifiers) is **data**, gameplay rules react through an
**event bus**, and every tuning number has one obvious home — so the
designer can enter the project and tweak variables without touching logic.

## 1. Principles

1. **Data-driven content**: a new marble/prize/board/modifier is a
   resource file, not a code change.
2. **Event-driven rules**: physics emits domain events; scoring and
   modifiers subscribe. No gameplay system reaches into another's state.
3. **One balance surface**: `data/balance/` holds every tunable number.
4. **Headless-testable core**: run loop, economy, scoring and objectives
   are plain GDScript, testable without rendering (existing smoke-test
   pattern scales to all systems).
5. **Scene = view, Game = state**: 3D scenes render; the run state
   (money, marbles, prizes, board index) lives in autoload state objects.

## 2. Project layout (target)

```
autoload/
  game.gd             # run state machine: MENU/RUN/BOARD/SHOP/GAME_OVER
  run_state.gd        # money, marbles owned, prizes owned, board index
  event_bus.gd        # gameplay events (SignalBus)
  content_db.gd       # loads and indexes all Def resources
scripts/
  board/              # board builder from BoardDef, notch logic
  marble/             # marble spawning from MarbleDef, effects
  scoring/            # score engine: events -> add/mult pipeline
  objectives/         # objective + bonus-objective checks
  economy/            # rewards, shop stock generation, pricing
  ui/                 # HUD, shop, library, menus
scenes/
  menu/ board/ shop/ library/
data/
  balance/            # ALL tunable numbers (balance.tres or per-system)
  marbles/*.tres      # MarbleDef resources
  prizes/*.tres       # PrizeDef
  boards/*.tres       # BoardDef
  modifiers/*.tres    # BoardModifierDef
tests/                # headless SceneTree tests (smoke.gd pattern)
```

## 3. Core types

- `MarbleDef` (Resource): id, name, rarity, material id, physics overrides
  (speed mult, mass, bounce), effect hooks (rethrow, homing, glass…),
  break_chance, price, flavor.
- `PrizeDef` (Resource): id, name, rarity, model id, event hooks, score
  edits (add/mult), price, flavor.
- `BoardDef` (Resource): theme id, layout (rows, cols, spacing, values,
  special notches), modifier ids, objective, difficulty factor, bonus
  objective, reward base.
- `BoardModifierDef` (Resource): rule edits (wall bounce, friction, moving
  notches, value shuffle…) + event hooks + HUD cue.

**Modifier hook contract** (shared by prizes and modifiers):

```gdscript
class_name DefHooks
func interested_in() -> Array[StringName]   # events this def reacts to
func on_event(event: StringName, ctx: Dictionary) -> void  # trigger effects
func edit_score(current: float, ctx: Dictionary) -> float  # scoring pass
```

`ScoreEngine` pipeline per scoring moment: collect add/mult from all
interested defs → apply flat adds → apply multipliers → publish breakdown
(for HUD "score math" display and debug overlay).

## 4. Migration from the POC (M0)

`scripts/main.gd` (single file, ~600 lines) splits into:

1. `autoload/game.gd` + `run_state.gd` — state machine + run state.
2. `scripts/board/board_builder.gd` — `_build_board`, `_add_hole`,
   `_add_wall`, layout from `BoardDef`.
3. `scripts/marble/marble_factory.gd` — `_make_marble` from `MarbleDef`
   (material system arrives later; physics params first).
4. `scripts/scoring/score_engine.gd` — capture/embed logic stops mutating
   `total_score` directly and emits `embed` on the bus.
5. Board input/controls stay in the board scene; HUD out of board scene.
6. Constants in `main.gd` move to `data/balance/` (physics, economy,
   timings). The POC's semantic (notch embedding, walls, refund edge)
   must not change during M0 — existing smoke + probe tests stay green.

## 5. Milestones

| M | Deliverable | Tests |
| --- | --- | --- |
| **M0** | DELIVERED (commits 5446263, eab1943): POC split into autoloads + board scene + ScoreEngine + HUD; Defs and balance data extracted; cross-device InputMap and scaling set up | smoke + probe green; smoke asserts event/score consistency |
| **M1** | Run skeleton: menu → board → win/lose → shop placeholder → game over; 3 handcrafted boards; economy v1 (rewards formula) | run-loop headless test: scripted throws, board win/loss, money math |
| **M2** | Scoring engine + event bus + hook contract; 5 bonificadores and 5 premios working | scoring pipeline unit tests with fake defs |
| **M3** | Content wave 1: 10 canicas, 10 premios, 10 board defs; shop v1 with stock/reroll | shop stock + pricing tests, content lint (all defs valid, prices in curve) |
| **M4** | Library + persistence (per D3), unlock pool if chosen | save/load round-trip test |
| **M5** | Full 20-board run + difficulty curve + board variety pass; balance harness (scripted-throw sim per board) | balance sim asserts win-rate bands per board |
| **M6** | Juice: marble shaders/materials, prize 3D models, audio, particles, score-math HUD; release prep | visual QA checklist, full-run smoke |

Order is deliberate: architecture before content, content before balance,
balance before juice. Each milestone ends with the GDD updated (content
lists live in the GDD or a content appendix).

## 6. Testing strategy

- Keep the existing headless SceneTree pattern (`tests/smoke.gd`).
- Per system: economy math, scoring pipeline, objective checks, shop
  stock, save/load — all pure-logic tests.
- Physics stays covered by `physics_probe.gd` + scripted-throw sim.
- Balance harness: deterministic seeded sim (fixed aim/tilt/power
  scripts) per board, asserting score bands, run as a test.

## 7. Tuning workflow (S6)

- All numbers in `data/balance/` as `.tres` resources grouped by domain
  (`physics.tres`, `economy.tres`, `difficulty.tres`…), edited in the
  Godot inspector or as text.
- Debug overlay (toggle key): current board def, score breakdown per
  throw, money deltas, active hooks firing — so tuning sessions show
  cause and effect live.
- Content lint test: every Def references valid materials/models, prices
  within curve, objective reachable by the sim.
