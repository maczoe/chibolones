# D9 board content wave 1: boards composed from the new primitives

First content wave after the D9+D12 engine (odd/tasks/d9-d12-objectives-matrices.md,
PR #1): four boards composed from the new primitives, one objective kind at a
time, each co-designed with the user and validated by playtest. Run rotation
untouched by decision; boards live in ContentDB and the debug picker only.

Delivery shape: Calcetas + Tijeras + accessibility + endless fix shipped as
PR #2 (merged, merge commit 253bae0). Guac-a-mole + Blackjack ride the same
branch as a follow-up PR (PR #2 was a merge commit, so the new PR diffs only
the new boards).

## Specs

- S1: "vamos a iniciar con un tablero sencillo de dificultad baja, 'Par de
  calcetas' es un tablero clásico con la matriz filas de arriba a abajo (7, 5,
  3, 1)" (user, 2026-11-21) — math objective, even total; minimum raised to 8
  after playtest (user: "listo quedó mejor así"). All-odd matrix 1/3/5/7:
  pairs of odds always make an even; small pairs stay short, so the board asks
  for a quality pair.
- S2: "el tablero inverso a este 'Las tijeras' la matriz es [2, 4, 6, 8]
  objetivo impar >= 9 el sabor un par de tijeras pueden cortar y dividir
  dejando un res..." (user, 2026-11-21) — all-even matrix with one odd notch
  (the blade, the 1 deep at the back row); every odd total must pass through
  the blade (1+8 or 1+4+4), even sums never win.
- S3: "El siguiente tablero será el Guac-a-mole (juego de palabras entre el
  juego y la fruta) consiste en agujeros trampa que cambian constantemente con
  los números tradicionales, este será un tablero de ran..." (user,
  2026-11-21) — RANGE objective 150-200 over the classic 10/20/30/50 matrix,
  moving mole traps (guacamole modifier) that relocate on an interval.
- S4: "podrías agregar un topo más dejar 5, todavía se siente facil" (user,
  2026-11-21) — Guac-a-mole tuned to 5 mole traps.
- S5: Blackjack (user picked the EXACT concept and named it with matrix
  1,3,5,7): EXACT objective =21 over the all-odd matrix, no modifiers. 21 odd
  requires an odd number of embeds: [7,7,7] in 3 perfect deep shots or
  5-marble lines. Overshoot busts the hand (objective lost; board fails only
  at shot exhaustion per the D9 overshoot rule).
- S6: "no vamos a tocar la run por ahora, vamos a crear mecánicas y tableros
  primero" (user, 2026-11-21) — the 20-board run rotation is untouched this
  wave.

## Tasks

| ID | Spec | Route | Commit |
| --- | --- | --- | --- |
| T1 | S1 | Par de Calcetas board def + emblem + tests (parent inline) | c488bd9, 9435f12 (PR #2 merged) |
| T2 | S2 | Las Tijeras board def + odd blade + emblem + tests (parent inline) | cad7205 (PR #2 merged) |
| T3 | S2 | notch_label_color accessibility + endless boss-def fix (parent inline) | d8e10af, d42938d (PR #2 merged) |
| T4 | S3, S4 | Guac-a-mole board + guacamole modifier + mole tuning (parent inline) | 7039968, a231248 |
| T5 | S5 | Blackjack board + emblem + tests (parent inline) | ebf67fc |
| T6 | S6 | Ledger + delivery PR for Guac-a-mole + Blackjack (parent inline) | d170f5f (PR #3) |

Route rationale: each board is one small unit of data + tests on a shared,
already-merged engine seam; no Writer trigger fires for data composition.
Winnability enforced by the existing checker (tools/check_boards.gd), feel
validated by user playtest via the debug picker.

## Log

- L1 (2026-11-21): "listo puedes lanzar pr y después de que yo apruebe el pr
  trabajamos en el primer tablero con nuevas normas, lo diseñamos juntos y yo
  lo pruebo" — co-design loop established: user proposes in one sentence,
  parent composes from primitives, checker proves winnability, user playtests.
- L2 (2026-11-21): Par de Calcetas born (S1); objective minimum raised to 8
  after the user's first playtest.
- L3 (2026-11-21): Las Tijeras born (S2) with the parity-closure discovery:
  an all-even matrix can never total odd, so the board needs one odd "blade"
  notch.
- L4 (2026-11-21): "listo lanza pr, luego seguimos con otro tablero con nuevas
  mecánicas" — PR #2 opened (Calcetas + Tijeras + label contrast + endless
  fix) and merged as 253bae0.
- L5 (2026-11-21): Guac-a-mole born (S3); theme runtime aggregation vars with
  nonzero defaults beat smaller def values under maxf (mole_trap_interval),
  and paint_hole hardcoded cream labels defeated notch_label_color on
  repaints — both fixed in-wave.
- L6 (2026-11-21): "podrías agregar un topo más dejar 5, todavía se siente
  facil" — moles raised to 5 (S4); user approved the feel ("ya esta aprobado
  el gameplay, terminamos el tablero y seguimos con el siguiente").
- L7 (2026-11-21): Blackjack born (S5) — first EXACT board; "puedes cerrar acá,
  el tablero quedó correcto" (user-approved).
- L8 (2026-11-21): "podrías ayudarme a continuar con la prueba de las nuevas
  mecánicas y con el ledger pendiente" — user chose "solo ledger + PR hoy":
  this document records the wave retroactively and Guac-a-mole + Blackjack
  ship as the follow-up PR (PR #3). 4 of 5 objective kinds premiered
  (THRESHOLD, MATH, RANGE, EXACT); LIST (La Escalera =30 -> =60 -> =90) is
  next. Verified at delivery: full 17-script suite GREEN, checker BOARDS OK
  (24/24 winnable; Guac-a-mole [50,50,50] in 3, Blackjack [7,7,7] in 3),
  gdcheck OK on board_theme.gd/board.gd/board_modifier_def.gd.
