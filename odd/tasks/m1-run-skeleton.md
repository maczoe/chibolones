# M1 — Run skeleton

Menu → board → win/lose → shop placeholder → game over, with economy v1
and the 5-block progression from docs/gdd/content-plan.md. Boards 1-4
(block 1) play the real loop; boards beyond the current data set are
procedural variants of the classic BoardDef until content waves land.

## Specs

S1 (content-plan §2): start of run 5 marbles + $5; board reward = base(block) + per_marble(block) x marbles_left + bonus; endless keeps block-5 rate +1 per board.
S2 (content-plan §3): 5 blocks of 4 boards (3 normal random draw + 1 boss); boss targets x1/x1.15/x1.3/x1.5/x1.75 factor.
S3 (content-plan §2): shop after each board: 2 marbles, 2 prizes, 1 extra-marble pack, 1 reroll; prices scale per block; no interest.
S4 (GDD D2): player picks the marble from the bag before each throw (already in the board scene).
S5 (GDD S1): losing a board (out of throws without meeting the objective) loses the run; winning board 20 wins the run; endless opt-in.
S6 (user): decisions via questionnaire before implementation.

## Tasks

T1 [S6] DONE. Decisions: menu minimal (Jugar + Biblioteca disabled), defeat screen = summary + Reintentar/Menú, shop = placeholder visual (purchases land M3), loss = standard shots-exhausted; endless opt-in from run-won screen (GDD D6).
T2 [S1,S2] DONE. `autoload/economy.gd` (autoload Economy: reward, price scale, marble/pack/reroll prices, placeholder stock) + `autoload/game.gd` (BLOCKS=5, BOARDS_PER_BLOCK=4, block_of/is_boss/objective_for_board, RESULT phase, run/board signals, money) + board run objective and win/loss reporting.
T3 [S5,S3] DONE. `scenes/menu`, `scenes/shop`, `scenes/run/result` with `scripts/ui/*` screens + `scripts/run/run_flow.gd` phase→scene routing and `Game.change_to_current_scene()`; main scene is the menu.
T4 [S1-S5] DONE. `tests/run_loop.gd` (RUN LOOP OK): economy math, progression helpers, phase machine, board win/loss and HUD wiring; `tests/smoke.gd` stays green (score=10, no run transitions).
T5 [S1-S5] DONE. README "The run" section + layout/tests, architecture M1 marked delivered, content-plan §2/§3 numbers cross-checked against Economy/Game constants.

## Log

L1 (user): "arranca con M1 prepara preguntas para que yo tome las decisiones"
L2 (user decisions): menu minimal; derrota resumen+reintentar; tienda placeholder visual; perdida estandar tiros agotados.
L3 (impl): board no longer auto-starts a run (the "temporary bootstrapping until M1 adds the menu" comment); the menu owns start_run(), and a board opened without a run keeps the plain POC round over — that is the smoke/probe path.
L4 (impl): Game state methods stay scene-free (they call change_to_current_scene(), which is a no-op when the tree has no current scene), so tests assert phases without the engine swapping scenes under them.
