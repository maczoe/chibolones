# D8 + D10: prize classes and board chests

The economy wave: split the prize system into three classes (permanent usable,
consumable usable, cosmetic) so loot has somewhere to go, and add chests on the
board as the pickup source. Source: docs/gdd/design-decisions-v2.md D8/D10,
ordered first in that document's dependency list ("D8 + D10 — biggest
game-loop mover").

## Specs

- S1: "Economía: clases de premio + cofres (D8 + D10)" (user, 2026-11-21) —
  scope of this unit; no other wave is in scope.
- S2: "Activo solo si entra en los slots del bolso" (user, 2026-11-21) — a
  permanent usable prize unlocked in the library becomes available, but it only
  takes effect in a run when it occupies a bag slot. Bag capacity is the
  limiter, not ownership.
- S3: "Activo ya esta run + desbloqueado para siempre" (user, 2026-11-21) — a
  chest that draws a permanent usable prize grants it immediately in the
  current run AND records the unlock permanently.
- S4: "Reclasificar 3-4 situacionales como consumibles" (user, 2026-11-21) —
  Globo, Boleto Retro, Billete de la Suerte and Muñeco de Nieve become
  consumables; the other six current prizes stay permanent usable.
- S9: "Redefinir los 4 como efectos instantáneos" (user, 2026-11-21) — the four
  consumed prizes keep their names and get instantaneous effects instead of
  their old continuous passives: Globo = +1 throw now; Boleto = repeat the last
  throw; Billete = +$2 now; Muñeco = the current board runs without skip speed.
  Rationale recorded in L4: their original effects were continuous reads with
  no meaning as a single use.
- S10: "Guardados y se usan con una tecla en el tablero" (user, 2026-11-21) —
  consumables are held in a run inventory and activated by the player during a
  board with a key, not on acquisition and not shop-only.
- S11: "El jugador elige a quién descarta" (user, 2026-11-21) — when a chest
  drops a permanent usable prize and the prize bag is already full, the reveal
  offers the player the choice of which owned prize to discard.
- S5: "Todos los tableros: 1 fijo + roll oculto por rareza" (user, 2026-11-21) —
  every board carries one fixed chest plus a hidden chest rolled by chance and
  rarity, not only the new boards.
- S6: D10 constraints from the design doc: the marble is NOT consumed by a
  chest (it keeps rolling after the reveal) and the reveal must stay short
  (2-3 s target) to protect the 5-20 s throw loop.
- S7: Consumable usable prizes are single use within a run, sourced from the
  shop or from chests (D8) — not from the starting pool.
- S8: Cosmetic prizes have no gameplay effect; they are recorded as collected
  only. Persistence and the library UI belong to D11/W4 and are OUT of scope
  here; this unit must not invent a save file.
- S12: Chest = trigger volume resting on the deck, not a wall: the marble rolls
  through it, the chest opens, and the marble keeps rolling with its score
  untouched. No physics deflection, no consumed marble (S6).
- S13: Every board carries one fixed chest plus one hidden chest rolled by
  chance; both are BoardDef data with defaults, so the 25 existing boards need
  no per-board edit and a board can still opt out.
- S14: A chest draws loot in two steps: rarity by weight, then a class inside
  that rarity (permanent / consumable / cosmetic). A def the run already owns
  or collected is skipped, so every chest is a new toy; an empty pool pays cash
  instead of granting nothing.
- S15: A chest grants through `Game.add_prize()`, the same routing seam the shop
  uses, so the class decides the shelf (S2, S10).
- S16: The reveal never pauses the flight: a short chest animation plus one HUD
  cue naming the prize and its class, inside the 2-3 s budget. Only the discard
  choice of S11 pauses the board.

## Tasks

| ID | Spec | Route | Commit |
| --- | --- | --- | --- |
| T1 | S1, S4, S9 | `PrizeDef.prize_class` (permanent/consumable/cosmetic) + reclassify the four data files + instant-effect params | 2895873 |
| T2 | S2 | Prize bag slots: permanents enter only into a free slot; buy gate and cap text follow | 2895873 |
| T3 | S10, S7 | Run consumable inventory on Game (cap, add, remove) | 2895873 |
| T4 | S10, S9 | Consumable use: input actions + HUD rail + the four instant effect seams | 2895873 |
| T5 | S8 | Cosmetic class: no gameplay effect, recorded in the run's collection list | 2895873 |
| T6 | S5, S6, S12, S13, S16 | Chest primitive: deck trigger volume, marble passes through and keeps rolling, 2-3 s reveal, drop | 3cf3458 |
| T7 | S5, S14, S15 | Chest loot: class+rarity draw, one fixed chest plus a hidden roll on every board (BoardDef data) | 3cf3458 |
| T8 | S11 | Full-bag discard choice: reveal pauses the board and the player picks the prize to drop | 4636c69 |
| T9 | S2, S4, S10 | UI: class on shop cards, consumable rail with keys (chest reveal belongs to T6) | 2895873 |
| T10 | all | Tests green, board checker still green, docs (GDD + content plan) | 4636c69 |
| T11 | all | Delivery PR | PRs #7-#9 opened (chain, by area) |
| T12 | S17 | Chest reveal becomes a paused wheel with icons that spin and stop | pending |
| T13 | S18 | Full shelf: drop one owned prize of that class OR decline for cash | pending |
| T14 | S19 | Run starts with an empty prize shelf (no sample trompo) | pending |
| T15 | S20 | An opened chest disappears from the deck | pending |
| T16 | S21 | Run-ending diagnostics (no behavior change until evidence) | pending |

Route: sequential inline slices. The two halves are dependent, not independent —
chest loot cannot draw a class that does not exist yet — so no parallel writers
and no disjoint surfaces: slice A = T1-T5 + T9 (commit 2895873, 721 lines, one
behavior area; recorded here because it passed the ~400-line slice guidance and
the delivery shape is chosen at publishing), slice B = T6-T7 (chests), slice C =
T8 (discard) plus the verification follow-up 7437793, then T11 (delivery PR).
The branch carries four commits and ~2.4k authored lines: publishing as one PR
breaks the 400-line review guidance, so the delivery shape is a chained split by
area (classes/consumables, chests, discard) unless the user asks otherwise.

## Implementation notes for T6-T7 (parent design decisions, not new specs)

- `BoardDef` gains defaults only, so the 25 boards need no edit: `chest_fixed:
  bool = true`, `chest_hidden_chance: float = 0.25`, `chest_cash_fallback: int
  = 3` (paid when the shelf has no room; T8 replaces it with the discard
  choice).
- Placement: a chest sits on the deck behind the notch rows, at
  `z = first_row_z + (rows - 1) * spacing_z + spacing_z * 0.9`. The fixed one is
  centered on `x = 0`; the hidden one rolls `x` in `±width * 0.35` and is
  skipped when it would land within 0.6 of the fixed chest.
- Visual: a `Node3D` chest root holding one gold `BoxMesh` (~0.34 x 0.22 x
  0.34), no collision body — it is a trigger, never an obstacle (S12). Keep the
  node in an array of chest dicts (`pos`, `opened`, `node`) like the existing
  `holes` array.
- Detection: a `_check_chests(local)` call from `_update_flight` after the notch
  proximity loop, horizontal distance <= 0.28 and `local.y` <= 0.4. One-shot:
  `opened` guards it. Never consume the marble, never touch the score.
- Loot: `Economy.chest_draw(owned_ids, collected_ids, seed)` returning
  `{"def_id": String, "cash": int}` — rarity by `RARITY_WEIGHTS`, then a uniform
  class inside that rarity, skipping defs the run already owns or collected;
  empty pool returns `cash`. Deterministic for a seed so tests never flake.
- Grant: `Game.add_prize(def)`; on a refused grant pay `chest_cash_fallback`.
- Reveal: chest tween (scale + spin) and one `hud.flash` naming prize and class,
  inside the 2-3 s budget. No modal, no pause (S16).

## Implementation notes for T8 (parent design decisions)

- The draw already refuses a class with no room; T8 replaces the cash answer for
  that case (the empty-pool answer keeps paying `chest_cash_fallback`).
- One new `Game.discard_prize(def) -> bool` seam: remove an owned prize from its
  shelf with NO money move (selling pays rescue value and is the shop's rule,
  not the chest's).
- UI: a small `scripts/board/chest_choice.gd` CanvasLayer built in code — title
  naming the chest prize, one button per owned prize of that class with its
  effect line, and a `picked(prize)` signal. Public `pick(index)` so a headless
  test can decide without simulating clicks. `process_mode = PROCESS_MODE_ALWAYS`
  and `get_tree().paused = true` while it is up, exactly like pause_menu.gd; it
  resumes the tree on every close path, including `_exit_tree`, so a torn-down
  panel can never strand the board paused. A rejected `pick` stays inert (panel
  open, tree paused): unpausing under a live modal would run the board behind it.
- On `picked`: `Game.discard_prize(old)`, `Game.add_prize(drawn)`, refresh both
  HUD rails, one `hud.flash`, close and unpause. No cash is paid on this path.
- Tests: shelf full + a chest that draws a permanent → panel appears, board is
  paused, `pick(0)` drops the chosen prize and grants the chest one (shelf size
  unchanged, money unchanged), panel closes and the tree resumes; picking
  outside the list is rejected and changes nothing.

## Wave 2 (post-playtest 2026-11-21): wheel, empty shelf, chest fix

- S17: "Ruleta con casillas e íconos" (user, 2026-11-21) — the chest reveal is a
  paused wheel whose slots/icons spin and stop on the winner. This supersedes
  S16 for the chest: the pause is now intended, because the tension is the point.
- S18: "Opcional: podés dejarlo y cobrar" (user, 2026-11-21) — when the drawn
  prize's class has no room, the wheel offers dropping one owned prize of that
  class OR declining and taking the cash fallback. No mandatory trade.
- S19: "Dos slots vacíos, sin trompo" (user, 2026-11-21) — a run starts with an
  empty prize shelf (2 slots, both empty). The free sample trompo at run start
  is gone.
- S20: chests must disappear from the deck once opened (user bug report, "los
  cofres no desaparecen luego de haber sido tocados"). The reveal ends and the
  node leaves the board.
- S21: run boards stop routing their ending (user bug report: "en la run ahora
  no se puede ganar ni perder, softlock al terminar las canicas"; happens "siempre,
  sin tocar cofres"). Every simulated run ending passes in tests, so the defect
  lives in state no test reproduces: a run board whose `_inventory_mode()` is
  false never consumes ammo, never evaluates the objective and never reports.
  Fix the cause once evidence names it; until then the board prints one
  diagnostic line at start and one at round end in debug builds so the next
  playtest names the wrong condition.

## Implementation notes for wave 2 (T12-T16)

- T12 (S17): `scripts/board/chest_choice.gd` becomes the wheel: a paused panel
  with N slots (icons/orbs) that cycle the loot pool fast, decelerate and stop on
  the winner, then resolve. Keep the testable API (`present`, `pick`, `is_open`,
  `picked`) and add the spin as an internal step with a deterministic `settle()`
  the tests call instead of waiting real time. The tree stays paused for the
  whole reveal (S17), so the throw resumes only after the resolve.
- T13 (S18): the resolve step offers `drop(owned)` for each owned prize of the
  drawn class plus `decline` (cash fallback via `board_def.chest_cash_fallback`)
  when the shelf is full. Every path unpauses; a rejected pick stays inert (panel
  open), and the panel still unpauses in `_exit_tree`.
- T14 (S19): drop `Game.SAMPLE_PRIZE` and its use in `start_run`; the shelf
  starts empty. Update every test that assumed the trompo (badge, size
  assertions) to the empty shelf, keeping the rule each test verifies intact.
- T15 (S20): after the reveal completes, the chest node leaves the board
  (`queue_free`) and its dict stops being checked; opening twice stays
  impossible.
- T16 (S21): diagnostic only — `print` one line at board start and one at round
  end, guarded by `OS.is_debug_build()`, with phase, run_active,
  `_inventory_mode()`, objective_state, shots_total/left and ammo. No behavior
  change until evidence names the wrong condition.

## Log

- L1 (2026-11-21): "vamos a continuar trabajando en los pendientes, podrías
  hacer un inventario de que falta y yo decido como continuar" — user asked for
  a pending-work inventory and reserved the decision.
- L2 (2026-11-21): user chose "Economía: clases de premio + cofres (D8 + D10)"
  from the inventory.
- L3 (2026-11-21): four design decisions closed by structured choice: S2 bag
  slots gate permanents, S3 chest permanents are active now and unlocked
  forever, S4 four situational prizes become consumables, S5 chests on every
  board (1 fixed + hidden rarity roll).
- L4 (2026-11-21): contradicción detectada antes de escribir código: los cuatro
  premios elegidos para consumibles (Globo, Boleto, Billete, Muñeco) son
  lecturas pasivas continuas en `PrizeDef.on_event`/`contribute_embed`, no
  efectos instantáneos; clasificarlos como one-shot los vaciaba de contenido.
  El usuario eligió "Redefinir los 4 como efectos instantáneos" (S9).
- L5 (2026-11-21): seam map (explorador) confirmó: `PRIZE_CAP := 2` constante en
  autoload/game.gd:20 y `prize_cap()` sin variable de capacidad; `marble_cap()`
  es dinámico (base + carpa). Los premios nunca se consumen al usarse. No existe
  ningún objeto interactivo de tablero que copiar para el cofre: los topos son
  flags `trap` repintados en board_theme.gd. El cofre se diseña como volumen
  trigger en la cubierta, sin deflexión física (S6: la canica sigue rodando).
- L6 (2026-11-21): decisiones de activación y bolso cerradas: consumibles
  guardados y usados con una tecla durante el tablero (S10); cofre con
  permanente y bolso lleno = el jugador elige el descarte (S11).
- L7 (2026-11-21): slice A entregado en 2895873 (clases, estantes, consumibles
  instantáneos, cosméticos, etiqueta de clase en la tienda, rail del HUD).
  Precio de los 4 consumibles bajado a $2-$4 para que un uso único no cueste lo
  mismo que un permanente; queda para el playtest del usuario. Dos invariantes
  existentes obligaron ajustes: bandas de rareza ($2-3 común, $4-5 poco común,
  $7 raro) y "todo premio tiene precio positivo" — los cosméticos quedan
  exentos por clase (precio 0) con una regla explícita en su lugar. La suite
  pasó de 18 a 19 scripts y quedó verde; boards checker 25/25.
- L8 (2026-11-21): slice B entregado en 3cf3458: cofres de cubierta con draw
  rareza→clase. Correcciones del padre sobre el trabajo delegado: un solo origen
  para el fallback en efectivo (era una constante duplicada en Economy y en
  BoardDef), el invariante "el cofre cae sobre la cubierta en los 25 tableros"
  (el `length` por defecto de BoardDef es 6.4 y todo el contenido usa 8.0), y un
  piso de checks en tests/chests.gd porque un error de GDScript aborta una
  función de test sin tocar `failed` — la suite podía imprimir OK con tests que
  nunca corrieron (deuda del patrón viejo, anotada para el resto de las suites).
  Suite completa de 20 scripts verde, boards checker 25/25.
- L9 (2026-11-21): verificador independiente sobre A+B: PASS con notas. Tres
  notas eran defectos y se arreglaron en 7437793: el cofre no abría con canica
  rápida (la comprobación estaba debajo del gate de skip-speed, un umbral
  invisible para el jugador) y ahora abre en cualquier pasada con un piso de
  trigger para que una canica caída no abra desde abajo; el loadout de debug
  salteaba el ruteo por clase; y w3_flow había quedado flojo con un total de dos
  estantes, más el piso de checks que pasó de 170 a ojo al total exacto (190).
- L10 (2026-11-21): T8 entregado en 4636c69: panel de descarte que pausa el
  tablero y es dueño del unpause (incluido _exit_tree), Game.discard_prize sin
  pago, y el fallback en efectivo reducido a pool vacío o def irresoluble. El
  test del estante lleno se reescribió a la regla nueva (no se borró cobertura)
  y el piso exacto pasó a 194. Suite de 21 scripts verde, checker 25/25.
  Dos cosas quedan para el playtest del usuario: el descarte es obligatorio (no
  hay opción de rechazar y quedarse con el efectivo) y los precios de los
  consumibles son una decisión de tuning mía ($2-$4).
