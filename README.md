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
4. **Throw** — in a run the throws are the marbles you carry: the board ammo
   is the run inventory, restored to full at every board start (5 common
   marbles to begin with). The POC board played outside a run keeps 5
   shots. The board tilts toward the player, so a marble either embeds
   itself in a notch (when it rolls over it slowly enough; a fast one
   skips over it) or rolls back off the player's edge, which **returns the
   throw and the marble without consuming either**. The board has low
   walls on the sides and the back: a bouncy marble with enough inertia can
   still hop over them, and any marble that leaves the board loses the
   shot and the marble (0 points; both come back next board). A marble
   broken on the glass durability roll is gone for the rest of the run.
5. **Score** — Notches score 10 / 20 / 30 / 50 from the near row to the
   back row, with the numbers painted readable from the player's camera.
   Like the real fairground board, the notches are carved at marble size:
   an embedded marble stays stuck with half its circumference exposed and
   becomes a fixed obstacle later shots bounce off, so the same notch can
   never take a second marble. The score is added the moment the marble
   embeds. After the last marble the round total is shown; R restarts.

   Controls guides stay out of normal play: the per-step hints and the
   opening controls line only appear for the tutorial (when it exists) or
   after 20 idle seconds in the aim step.

### Sample content (M0.5)

While aiming, **Up/Down** swap the marble in the ammo; the HUD shows the
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

Normal boards carry none or one bonificador: their list lives in the board's
own `BoardDef` (`modifiers`), so the assignment is content instead of code.
The bosses (4, 8, 12, 16, 20) carry two — **Borracho** on board 4, then
Ventoso + Espejo, Fantasma + Iman, Mojado + Cuerda and Trapecio +
Cronometrado. `Game.modifier_ids(n)` resolves the board's def (board N ->
def N-1) and `Game.board_modifiers(n)` loads the defs, so a run is
replayable. The board announces them at start, one flash every 1.2 seconds,
after the `Tablero N: <nombre>` cue. A board played outside a run has none,
which keeps the plain round untouched.

### Tableros (M2.5)

The 20 boards of a run are data: `data/boards/board_01..board_20.tres`, one
`BoardDef` each, and board N renders def N-1 (filename order). Every board
paints its own theme — surface, frame, notch glow, bulbs, spotlight, ambient,
checker floor and the three backdrop colors — following its block:

| Block | Boards | Look |
| --- | --- | --- |
| 1 La feria llega al pueblo | 1-4 | warm daylight feria: light violet board on a wood frame |
| 2 Luces de neon | 5-8 | neon city: pinks and cyans over a deep night board |
| 3 El circo encantado | 9-12 | enchanted: deep purples with a teal glow |
| 4 La noche de los cincos | 13-16 | dark night: near-black board, white and steel accents |
| 5 La carpa infinita | 17-20 | surreal inverse: dark teal board with a hot pink frame |

| # | Board | Rules |
| --- | --- | --- |
| 1 | Tablero Clasico | none (tutorial) |
| 2 | Tablero de Cuerda | Cuerda |
| 3 | Tablero Mojado | Mojado |
| 4 | El Tablero Borracho (jefe) | Borracho |
| 5 | Tablero Espejo | Espejo |
| 6 | Tablero Ventoso | Ventoso |
| 7 | Tablero Mochila | Mochila |
| 8 | La Barraca Sellada (jefe) | Ventoso + Espejo |
| 9 | Tablero Fantasma | Fantasma |
| 10 | Tablero Iman | Iman |
| 11 | Tablero Trapecio | Trapecio |
| 12 | El Truco Final (jefe) | Fantasma + Iman |
| 13 | Tablero de Vidrio | Mojado |
| 14 | Tablero Culebra | Cuerda |
| 15 | Tablero Mil Voces | Mojado + Cuerda |
| 16 | El Show de Medianoche (jefe) | Mojado + Cuerda |
| 17 | Tablero de Cuerdas Tricioneras | Ventoso + Cuerda |
| 18 | Tablero Cronometrado | Cronometrado |
| 19 | Tablero Espejismo | Fantasma |
| 20 | El Quinto Cinco (jefe) | Trapecio + Cronometrado |

The moving backdrop comes in three shader variants —
`backdrop.gdshader` (waves), `backdrop_spiral.gdshader` (slow hypnotic rings)
and `backdrop_rays.gdshader` (rotating rays). `BoardDef.backdrop_style` picks
one per board (unknown falls back to waves) and all three take the same three
colors, speed and scale, so a new look is a `.tres` edit, not a new shader.

Each board also carries an emblem (`data/art/emblem_*.svg`, 512x512,
transparent background, style-guide palette and outline): the art printed on
the play surface and on both cabinet sides. On screen the HUD keeps the
board's identity top-center for the whole board — its name in candy yellow
and, under it, the active bonificadores (`Sin modificadores` when the board
has none).

### Score math on screen

Every embed value comes out of one pipeline
(`ScoreEngine.evaluate_embed`): the painted notch value, then flat adds, then
multipliers, rounded once. When a prize, marble or bonificador changed the
value, the HUD prints the math under the messages — `20 +5 (Osito) x1.5
(Trompo de Madera)` — so a big number always explains itself. A clean throw
shows no line at all.

## The run

**JUGAR** in the title screen starts a run; **MODO DEBUG** opens the
single-board setup (below); the library button stays disabled until M4. A run is **20 boards in 5 blocks of 4**, a boss board on
every 4th (4, 8, 12, 16, 20), and each board renders its own def: its name,
palette, backdrop variant, emblem and rules (`data/boards/`). What escalates
is the objective: the board target (60 normal, 100 boss) scaled by the block
factor (x1, x1.15, x1.3, x1.5, x1.75). The HUD shows the board name and its
rules on top, the objective under the score and the money in the run.

- **Board won** — reaching the objective wins the board on the spot and the
  run pays `base(block) + per_marble(block) * canicas restantes + bonus`,
  i.e. `3 + block*2` plus `1 + block` per marble left. The win plays a
  placeholder fanfare and a **GANADOR** interstitial with the board stats
  (puntuación, canicas restantes, dinero); **CONTINUAR** goes to the shop,
  or to the run summary after board 20.
- **Board lost** — running out of marbles under the objective ends the run:
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

The run state (money, inventory, ammo, prizes, board, phase) lives in the
`Game` autoload and the money numbers in the `Economy` autoload; the screens
are `Game` phases routed through `scripts/run/run_flow.gd`.

### Debug mode

**MODO DEBUG** in the title screen opens the single-board setup: cycle all
20 boards (the screen always shows the board name and the rules text the
board announces at start), toggle
the active prizes, and pick the 5 starting marbles (at least 1; short picks
are topped up with commons). The match renders the picked board at its own
base objective — block factor x1, no money — through the normal inventory
rules, and win or lose it returns straight to the debug setup with the last
picks kept (tweak one thing and replay). Built for reproducing board bugs
with an exact loadout.

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
| Swap marble in the ammo (while aiming) | Up-Down arrows, W/S | D-pad up/down |
| Shoot / lock steps (1st-3rd) | Space or Enter | A / Cross |
| Camera mode (free view) | Z | LB |
| Pause menu | ESC | Start |
| Restart board | R | Back/Select |
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
godot --headless --path . --script res://tests/marbles_w3.gd
godot --headless --path . --script res://tests/themes.gd
godot --headless --path . --script res://tests/inventory.gd
godot --headless --path . --script res://tests/debug_mode.gd
godot --headless --path . --script res://tests/guide.gd
godot --headless --path . --script res://tests/physics_probe.gd
godot --headless --path . --script res://tests/pause.gd
godot --headless --path . --script res://tests/shop_focus.gd
godot --headless --path . --script res://tests/shooting_tilt.gd
godot --headless --path . --script res://tests/win_flow.gd
godot --headless --path . --script res://tests/lost_marble.gd
godot --headless --path . --script res://tests/wind_indicator.gd
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

`tests/inventory.gd` covers the marble inventory: consumption on embed and
on settled throws, refunds keeping the marble, the ammo restoring at every
board start, a glass break leaving the run for good, an empty ammo short of
the objective being a defeat, and the throw budget equaling the ammo size.

`tests/debug_mode.gd` covers the debug match: menu entry, the setup screen
defaults and all-20-board picker labels (name + gimmick), the empty-loadout
guard at screen and Game level, the launch wiring (ammo, prizes, base
objective, picked BoardDef), won and lost boards returning to the menu, and
the normal JUGAR flow unchanged.

`tests/guide.gd` covers the controls-guide gating: no controls in the
opening announcements, step hints silent during normal play, the idle
clock bringing the guide back after 20 s (once per episode, reset by any
action) and the tutorial flag turning the hints on.

`tests/themes.gd` covers the M2.5 board identity: the 20 boards load from
`data/boards/` in filename order with unique names, a loadable emblem and a
valid backdrop style (waves, spiral and rays all in use), the modifier
mapping of every board matches the content plan and resolves through
`ContentDB`, the board scene renders the run board's own def with its name
and rules in the HUD, and the objective semantics stay the M1 ones (boss base
100, normal base 60, block factor applied).

`tests/physics_probe.gd` guards a physics gotcha found during development:
a rigidbody that spawns intersecting the board collider can escape through
it, so colliders are aligned with the visible surface and marbles spawn
clear of it.
