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

## Tasks

| ID | Spec | Route | Commit |
| --- | --- | --- | --- |
| T1 | S1, S4, S9 | `PrizeDef.prize_class` (permanent/consumable/cosmetic) + reclassify the four data files + instant-effect params | pending |
| T2 | S2 | Prize bag slots: permanents enter only into a free slot; buy gate and cap text follow | pending |
| T3 | S10, S7 | Run consumable inventory on Game (cap, add, remove) | pending |
| T4 | S10, S9 | Consumable use: input actions + HUD rail + the four instant effect seams | pending |
| T5 | S8 | Cosmetic class: no gameplay effect, recorded in the run's collection list | pending |
| T6 | S5, S6 | Chest primitive: deck trigger volume, marble passes through and keeps rolling, 2-3 s reveal, drop | pending |
| T7 | S5 | Chest loot: class+rarity draw, one fixed chest plus a hidden roll on every board (BoardDef data) | pending |
| T8 | S11 | Full-bag discard choice: reveal pauses the board and the player picks the prize to drop | pending |
| T9 | S2, S4, S10 | UI: class on shop cards, consumable rail with keys, chest reveal | pending |
| T10 | all | Tests green, board checker still green, docs (GDD + content plan) | pending |
| T11 | all | Delivery PR | pending |

Route: sequential inline slices. The two halves are dependent, not independent —
chest loot cannot draw a class that does not exist yet — so no parallel writers
and no disjoint surfaces: slice A = T1-T5 (classes, bag, consumables), slice B =
T6-T9 (chests, loot, discard, UI).

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
