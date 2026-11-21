# D9+D12: Objective kinds + notch matrices + winnability checker

Wave 1 of the design pivot (docs/gdd/design-decisions-v2.md): boards gain
objective kinds beyond the score threshold (D9) and per-board notch value
matrices with trap holes (D12), plus the winnability checker that enforces
"every board must be winnable with a baseline inventory".

Scope decision (user, 2026-11-21): engine + checker only; reworking board
content with the new primitives lands in the next wave.

## Specs

- S1: "Boards are won by one of four objective kinds: Threshold (score >=
  100, current behavior), Exact (final score = 100), Goal list (hit all of
  =50, then =80, then =120), Math rule (final score is prime / even / odd)"
  (design-decisions-v2.md D9). Range stays an exact variant (`exact` with
  `objective_min`/`objective_max`) per D9's open question.
- S2: "Shuffle-value boards (Borracho, Mil Voces) must use threshold or
  range objectives" (D9).
- S3: Overshoot rule (user decision, 2026-11-21): "La run se pierde cuando
  no quedan canicas y no se cumple el objetivo" — an overshoot never ends
  the run instantly; the board is lost only when shots run out without the
  objective satisfied. Future score-lowering prizes stay viable mid-board.
- S4: "Every board's hole matrix (values and arrangement) is per-board data
  instead of the fixed 10/20/30/50 everywhere" (D12). A per-hole value
  matrix (`hole_values`) coexists with `row_scores`; trap holes are holes
  marked in the matrix.
- S5: Trap holes (user decision, 2026-11-21): "Tiro anulado" — a marble
  landing in a trap hole sinks without scoring (the throw counts as 0), the
  player keeps the remaining shots.
- S6: "Rule: every board must be winnable with a baseline inventory.
  Winnability is enforced by a checker tool (analyze/simulate matrix x
  objectives vs. a reference marble set), not by hand runs." (D12).
- S7: "Open: ... live HUD feedback for math rules (the player must be able
  to judge 'need 73, is it prime?' mid-throw)" (D9) — the HUD objective line
  must express the active kind (exact "100 / =100", range "100 / 90-110",
  list next goal, math rule description).
- S8: Threshold keeps current scaling (Game.objective_for_board block
  factors); non-threshold kinds are NOT scaled (S1 examples are absolute;
  scaling an exact target breaks the designed matrix).

## Tasks

| ID | Spec | Route | Commit |
| --- | --- | --- | --- |
| T1 | S1, S2, S8 | BoardDef objective-kind data + validation (parent inline, test-first) | 5bbf4b5 |
| T2 | S1, S3, S7 | board.gd/_run_win_reached/_round_over/game.gd/hud.gd wiring (parent inline, test-first) | 5bbf4b5 |
| T3 | S4, S5 | hole_values matrix + trap holes in board.gd (parent inline, test-first) | 5bbf4b5 |
| T4 | S6 | winnability checker core + headless CLI (parent inline, test-first) | 2f011cb |
| T5 | S1-S8 | full suite + gdcheck + docs + close (parent inline) | docs close |

Route rationale: single tightly-coupled seam (one scoring/objective code
path in board.gd); Writer rule does not fire for one unit of behavior.

## Log

- L1 (2026-11-21): "Continuá Chibolones: implementá D12+D9 según
  design-decisions-v2.md"
- L2 (2026-11-21, user decisions): overshoot = lose only when marbles run
  out unmet (S3); scope = engine + checker only this wave; trap holes =
  "tiro anulado" (S5).
- L3 (2026-11-21): branch `feat/d9-d12-objectives-matrices` created from
  main. Integration map from explore: objective seam = game.gd:422
  objective_for_board, board.gd:162/1014/1030 (_round_over,
  _run_win_reached), hud.gd:102 set_target/_update_objective; hole seam =
  board.gd:1529-1536 build loop + _add_hole:1602 (already takes per-hole
  value), possible-score formula board.gd:1012 breaks with matrices;
  shuffle rewrites hole.score from row pools (board_theme.gd:265-292).
- L4 (2026-11-21): T1-T3 delivered in commit 5bbf4b5 (737 lines: engine
  slice, past the ~400-line guidance — single coupled seam, kept as one
  reviewable unit; D9 and D12 share the same test file and board.gd
  paths, splitting would churn the same lines twice). Win check moved
  from flight frames to score_changed (list goals count once per score
  change). tests/win_flow.gd updated to the new immediate-win seam.
  Smoke grep artifact resolved: SMOKE OK. gdcheck OK on all changed
  files; gdscript-formatter not on PATH (skipped, reported at close).
- L5 (2026-11-21): T4 delivered in commit 2f011cb (BoardChecker BFS over
  (total, goal-progress) states + tools/check_boards.gd CLI; all 20
  current boards winnable in 2 shots). Slice boundary: 1037 lines over 2
  commits — D9 engine and checker are separable seams, split at the
  natural boundary (engine wiring vs analysis tool); delivery shape
  (single PR vs chained) decided at publish time with the user.
- L6 (2026-11-21): T5 close. Full 17-script suite GREEN + checker CLI
  exit 0. tools/check_boards.gd first draft printed no rows (autoload
  _ready defers to first frame in --script mode); fixed by awaiting
  physics_frame like every tests/ script. First checker draft also had a
  typed-array runtime error that the OK-print masked (abort before
  _finish leaves the process hanging with no FAIL line) — the suite
  runner now treats NO-OUTPUT as failure. Unit closed: engine + checker
  only; board content redesign with the new primitives is the next wave
  (per L2 scope decision).
