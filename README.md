# Chibolones POC

Proof of concept for a 3D game based on *chibolones*, the Guatemalan fair
tradition: a wooden board with numbered holes where players throw large
marbles ("cincos"), and the holes' numbers add up to earn a prize.

Built with **Godot 4.7**. Scenes and nodes are built from code in
`scripts/main.gd`, so the whole vertical slice lives in one readable file.

## Running

Open the project folder in Godot 4.7 and press Play, or:

```
godot --path . 
```

## Gameplay

1. **Aim** — Left/Right arrows (or A/D) pick the horizontal launch position;
   both move the marker in screen directions.
2. **Tilt** — Space starts the shot tilt guide: a line pivoting at the launch
   point leans left/right automatically; Space locks the angle and adds the
   sideways component to the throw.
3. **Power** — Space then starts the power bar. It fills automatically,
   reverses when full, and keeps oscillating; pressing Space again locks it
   and throws. The captured percentage maps linearly to the launch speed.
4. **Throw** — 5 shots per round. The board tilts toward the player, so a
   marble either sinks into a hole (when it rolls over it slowly enough; a
   fast one skips over it) or rolls back off the player's edge, which
   **returns the throw without consuming it**. Marbles that exit through the
   back or the sides lose the shot (0 points).
5. **Score** — Holes score 10 / 20 / 30 / 50 from the near row to the back
   row, with the numbers painted readable from the player's camera. After
   the 5th throw the round total is shown; R restarts.

## Controls

| Input | Action |
| --- | --- |
| Left/Right, A/D | Move the launch position |
| Space (1st) | Start the tilt guide oscillation |
| Space (2nd) | Lock tilt, start the power bar |
| Space (3rd) | Lock power and throw |
| R | Restart the round |

## Architecture notes (for the roguelike idea)

The plan is a roguelike on top of this base mechanic in the spirit of
Balatro: rounds that escalate, and card-like modifiers that rewrite how a
throw is scored (multipliers, hole rerolls, marble properties). For that:

- The score table is the `ROW_SCORES` constant; per-hole values already flow
  through one capture path (`_sink`), the natural seam for scoring modifiers.
- The round loop (`Aim -> Power -> Flight -> x5 -> total`) is a plain state
  machine, easy to wrap with round modifiers, shop and escalation logic.
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
