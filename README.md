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
| Shoot / lock steps (1st-3rd) | Space or Enter | A / Cross |
| Camera mode (free view) | Z | LB |
| Cancel / step back | X | B |
| Move camera (in camera mode) | Arrows, WASD | Stick, D-pad |
| Restart round | R | Start |

## Project layout

```
autoload/    EventBus (gameplay events), ContentDB (Def registry), Game (run flow)
scripts/     core/ Def resources - board/ board scene, HUD, marble factory - scoring/
scenes/      board/board.tscn (main scene)
data/        balance/ shooting rules - boards/ level defs - marbles/ marble defs
tests/       headless SceneTree tests (smoke round, physics probe)
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
  state machine inside the board scene; the run loop (shop, escalation) is the
  `Game` autoload phase machine, ready to wrap it.
- Physics is honest: real rigidbody marbles on a tilted board, so future
  modifiers can act on marble material, board tilt, or hole geometry.

## Tests

Headless smoke test drives the real scene through a full 5-shot round with
synthetic input (retries until all 5 shots are spent, since the player-edge
refund returns throws without consuming them):

```
godot --headless --path . --script res://tests/smoke.gd
godot --headless --path . --script res://tests/physics_probe.gd
```

`tests/physics_probe.gd` guards a physics gotcha found during development:
a rigidbody that spawns intersecting the board collider can escape through
it, so colliders are aligned with the visible surface and marbles spawn
clear of it.
