# Chibolones POC

Proof of concept for a 3D game based on *chibolones*, the Guatemalan fair
tradition: a wooden board with numbered holes where players throw large
marbles ("cincos"), and the holes' numbers add up to earn a prize.

Built with **Godot 4.7**. Content (boards, marbles, tuning) lives in
`data/` as Def resources; gameplay systems live under `scripts/` and the
project layout is documented in `docs/architecture.md`.

## Running

Open the project folder in Godot 4.7 and press Play, or:

```
godot --path . 
```

## Gameplay

1. **Aim** — Left/Right arrows (or A/D) pick the horizontal launch position;
   both move the marker in screen directions.
2. **Tilt** — Space starts the shot tilt guide: a line pivoting at the launch
   point leans left/right with the same Left/Right arrows. The guide is
   clamped so it can never point past the side walls from the current launch
   spot; Space locks the angle and adds the sideways component to the throw.
3. **Power** — Space then starts the power bar. It fills automatically,
   reverses when full, and keeps oscillating; pressing Space again locks it
   and throws. The captured percentage maps linearly to the launch speed.
4. **Throw** — 5 shots per round. The board tilts toward the player, so a
   marble either embeds itself in a notch (when it rolls over it slowly
   enough; a fast one skips over it) or rolls back off the player's edge,
   which **returns the throw without consuming it**. The board has low
   walls on the sides and the back: a bouncy marble with enough inertia can
   still hop over them, and any marble that leaves the board loses the shot
   (0 points).
5. **Score** — Notches score 10 / 20 / 30 / 50 from the near row to the
   back row, with the numbers painted readable from the player's camera.
   Like the real fairground board, the notches are carved at marble size:
   an embedded marble stays stuck with half its circumference exposed and
   becomes a fixed obstacle later shots bounce off, so the same notch can
   never take a second marble. The score is added the moment the marble
   embeds. After the 5th throw the round total is shown; R restarts.

### Sample content (M0.5)

While aiming, **Up/Down** swap the marble in the bag; the HUD shows the
selected marble under the score, and a flash line describes its effect.

| Marble | Look | Effect now |
| --- | --- | --- |
| Canica Comun | solid palette color | none (the POC marble) |
| Canica de Fuego | dark core, glowing ember | launch speed x1.25 |
| Canica de Vidrio | translucent, glossy | Puntos x2; the break roll is live (M2) but the 20% lands with the data in M3 |

Prizes are permanent run modifiers. **Trompo de Madera** multiplies the
throw's embed value by x1.5 for every wall the marble hits during that
throw (two walls = x2.25), and is shown as a badge in the top-right corner.
Content lives in `data/marbles/*.tres` and `data/prizes/*.tres`, so a new
marble or prize is a resource file, not a code change.

### Bonificadores (M2)

A bonificador is the board's own rule, the fairness twist of the round. The
10 of the content plan are data (`data/modifiers/*.tres`) and one runtime
(`scripts/board/board_theme.gd`), so a board is a theme plus its rules:

| Bonificador | Effect in play |
| --- | --- |
| Cuerda | walls bounce more and every wall you hit adds x1.2 to the embed |
| Mojado | wet floor: the marble barely slows down (friction x0.45) |
| Borracho | the notch values are reshuffled at every throw |
| Espejo | the center column pays x2 |
| Ventoso | a cross wind pushes the marble, changing side every throw |
| Mochila | one random notch is covered and cannot take a marble |
| Fantasma | one notch phases in and out every 2 seconds |
| Iman | an embedded marble pulls the rolling one when it comes within 1 unit |
| Trapecio | the whole notch grid sways sideways while you aim |
| Cronometrado | 4 seconds per step: if you don't choose, the board throws for you |

Normal boards carry none or one bonificador; boss boards (4, 8, 12, 16, 20)
run the themed pair of their block — block 1 opens with **Borracho**, then
Ventoso + Espejo, Fantasma + Iman, Mojado + Cuerda and Trapecio +
Cronometrado. The board announces them at start, one flash every 1.2 seconds,
and `Game.board_modifiers(n)` decides the list from the board number (so a run
is replayable). A board played outside a run has none, which keeps the plain
round untouched.

### Score math on screen

Every embed value comes out of one pipeline
(`ScoreEngine.evaluate_embed`): the painted notch value, then flat adds, then
multipliers, rounded once. When a prize, marble or bonificador changed the
value, the HUD prints the math under the messages — `20 +5 (Osito) x1.5
(Trompo de Madera)` — so a big number always explains itself. A clean throw
shows no line at all.

## The run

**JUGAR** in the title screen starts a run; the library button stays
disabled until M4. A run is **20 boards in 5 blocks of 4**, a boss board on
every 4th (4, 8, 12, 16, 20). Until the content waves land, the classic
board backs all of them and what escalates is the objective: the board
target scaled by the block factor (x1, x1.15, x1.3, x1.5, x1.75), with boss
boards aiming at 100 before that factor. The HUD shows the objective under
the score and the money in the run.

- **Board won** — reaching the objective wins the board on the spot and the
  run pays `base(block) + per_marble(block) * canicas restantes + bonus`,
  i.e. `3 + block*2` plus `1 + block` per marble left.
- **Board lost** — running out of shots under the objective ends the run:
  the summary shows the boards cleared, the money and which board beat you,
  with **REINTENTAR** and **MENU**.
- **Shop (placeholder)** — after every won board the shop lists the stock a
  real shop sells from M3: 2 marbles, 2 prizes, an extra-marble pack (+1
  throw, $4..$8 by block) and a reroll ($2), every price scaled by the block
  (`1 + 0.35 * (block - 1)`). Everything is disabled and marked
  "(en camino, M3)"; in M1 the screen only shows the run's prices.
  **CONTINUAR** moves to the next board.
- **Run won** — clearing board 20 shows the summary and offers
  **CONTINUAR** into endless mode (GDD D6): boards 21+ keep the block-5
  prices and pay $1 extra per board won, and the summary counts the run
  boards plus the endless ones.
- **No interest** (D4): income comes only from boards won, so unspent money
  never grows on its own.

The run state (money, bag, prizes, board, phase) lives in the `Game`
autoload and the money numbers in the `Economy` autoload; the screens are
`Game` phases routed through `scripts/run/run_flow.gd`.

## Platforms

- **Scaling**: 1920x1080 base viewport with `canvas_items` stretch and
  `expand` aspect, so the UI holds on most screens and handhelds; the 3D
  board adapts to any window shape.
- **Renderers**: Forward+ on desktop, automatic Mobile fallback for
  Android.
- **Input**: gameplay is bound to device-agnostic InputMap actions
  (`move_left`, `move_right`, `shoot`, `restart`), currently mapped to
  keyboard and gamepad. Touch controls will reuse the same actions.

## Controls

| Input | Keyboard | Gamepad |
| --- | --- | --- |
| Move aim / lean tilt guide | Left-Right arrows, A/D | Left stick, D-pad |
| Swap marble in the bag (while aiming) | Up-Down arrows, W/S | D-pad up/down |
| Shoot / lock steps (1st-3rd) | Space or Enter | A / Cross |
| Camera mode (free view) | Z | LB |
| Cancel / step back | X | B |
| Move camera (in camera mode) | Arrows, WASD | Stick, D-pad |
| Restart round | R | Start |

## Project layout

```
autoload/    EventBus (gameplay events), ContentDB (Def registry), Game (run flow), Economy (money math)
scripts/     core/ Def resources - board/ board scene, HUD, marble factory - scoring/ - run/ phase routing - ui/ menu, shop, summary
scenes/      menu/ (main scene), board/, shop/, run/ (run summary)
data/        balance/ shooting rules - boards/ level defs - marbles/ marble defs - prizes/ prize defs - modifiers/ bonificadores
tests/       headless SceneTree tests (smoke round, physics probe, run loop, M2 hooks)
docs/        GDD (docs/gdd) and architecture plan
```

## Architecture notes (for the roguelike idea)

The plan is a roguelike on top of this base mechanic in the spirit of
Balatro: rounds that escalate, and card-like modifiers that rewrite how a
throw is scored (multipliers, notch rerolls, marble properties). For that:

- Notch values are board data (`BoardDef.row_scores`); captures flow through
  the EventBus `embed` event into `ScoreEngine`, the natural seam for scoring
  modifiers (M2 hook contract in `docs/architecture.md`).
- The round loop (`Aim -> Tilt -> Power -> Flight -> x5 -> total`) is a plain
  state machine inside the board scene; the run loop (menu, shop,
  escalation) is the `Game` autoload phase machine, which wraps it since M1.
- Physics is honest: real rigidbody marbles on a tilted board, so future
  modifiers can act on marble material, board tilt, or hole geometry.

## Tests

Headless smoke test drives the real scene through a full 5-shot round with
synthetic input (retries until all 5 shots are spent, since the player-edge
refund returns throws without consuming them):

```
godot --headless --path . --script res://tests/smoke.gd
godot --headless --path . --script res://tests/run_loop.gd
godot --headless --path . --script res://tests/hooks.gd
godot --headless --path . --script res://tests/physics_probe.gd
```

`tests/run_loop.gd` covers M1 without rendering: economy math, the 20-board
progression helpers, the `Game` phase machine (win, loss, shop, endless) and
the board's run wiring (objective/money in the HUD, board win and loss
reaching `Game`, no double reward).

`tests/hooks.gd` covers the M2 hook contract: the breakdown math (flats then
multipliers, one round at the end), the trompo contributing through the
pipeline, the 10 bonificadores loading with their designed values, Borracho
shuffling without losing a value, Cronometrado auto-advancing a step, the
glass break roll taking a marble out of the bag, Espejo doubling the center
column, and the M1 wall math still holding.

`tests/physics_probe.gd` guards a physics gotcha found during development:
a rigidbody that spawns intersecting the board collider can escape through
it, so colliders are aligned with the visible surface and marbles spawn
clear of it.
