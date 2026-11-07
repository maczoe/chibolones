# Chibolones — Game Design Document (v0.1 draft)

A roguelike based on the Guatemalan fairground game of chibolones: throw
marbles at a wooden board, embed them in numbered notches, and survive 20
boards in a run while building a collection of marbles and fair prizes.
Design language: the cozy-but-cutthroat atmosphere of a village fair,
where every marble in your bag has a story and every prize on your shelf
changes how the next throw plays out.

Status: **draft for refinement**. Open decisions are numbered `D#` and
listed in §11. Assumptions pending user confirmation are `A#`.

---

## 1. Pillars

1. **Physics you can read** — the marble tells the story: tilt, inertia
   and bounce are honest, and every modifier must stay legible on screen.
2. **Fair-ground shelf** — collection and flavor first: marbles and prizes
   feel like objects you won at a fair, with names, looks and lore.
3. **One more run** — short boards, clear fail state, fast restart; runs
   should feel ~45-90 min like Balatro.
4. **Tunable by hand** — every number a designer would touch lives in one
   obvious place (see architecture doc).

## 2. Loops

| Loop | Length | Content |
| --- | --- | --- |
| Throw loop | 5-20 s | Aim → tilt → power → physics → embed / refund / out |
| Board loop | 2-4 min | 5+ throws, objective check, board reward, bonus objective |
| Run loop | 45-90 min | 20 boards, shop after each, permadeath on board loss |
| Meta loop | across runs | Library/collection, unlocks (open: D3) |

## 3. Run structure (S1)

- Start of run: **5 marbles + $5**.
- Boards are played **1 → 20 in order** (randomized within acts? open:
  D5).
- Win the run by clearing board 20.
- **Lose the run** when a board is lost. A board is lost when the player
  runs out of throws without meeting the objective (assumption A1).
- Marbles **carry over** between boards (assumption A2): winning a board
  with throws to spare is the core efficiency pressure, reinforced by the
  per-marble reward.

## 4. Board structure (S2)

Each board is defined by data (see architecture doc `BoardDef`):

| Field | Meaning |
| --- | --- |
| Theme | Flavor name + visual identity (e.g. "El Tablero Borracho") |
| Layout | Notch grid: rows, columns, spacing, values, special notches |
| Modifiers | 0-2 board modifiers (bonificadores) that change physics/rules |
| Objective | Win condition (score target, embed count, …) |
| Difficulty factor | Scales target numbers with the current level (S2) |
| Bonus objective | Optional challenge → extra $ (e.g. "embed after touching the back wall") |
| Reward | $ fixed by level + $ per marble left unspent on win |

Reference board from S2: **El Tablero Borracho** — notch values shuffle
every throw; win with score ≥ 100 × difficulty factor.

Board loss also covers hard fail states some themes may add (e.g. a board
that demands N embeds and breaks your glass marbles: out of marbles = out
of throws = lost board, A1).

## 5. Scoring model

Balatro-style two-layer math, kept legible:

```
board_score = Σ(embedded notch values this board)
            → +add and ×mult from prizes (permanent, run-scoped)
            → +add and ×mult from board modifiers (board-scoped)
```

The scoring engine is **event-driven**: gameplay physics emits events,
content subscribes. Event vocabulary (first pass):

| Event | Payload |
| --- | --- |
| `throw_started` | marble def |
| `wall_hit` | which wall, impact speed |
| `embedded_marble_hit` | which notch, impact speed |
| `embed` | notch value, marble def |
| `back_wall_hit` | impact speed |
| `refund` (player edge) | — |
| `marble_broke` | marble def |
| `throw_ended` | outcome |

Prizes and modifiers declare which events they react to and how they edit
the score (flat add, multiplier, or reroll effects). This keeps "osito de
peluche: +50" and "cada golpe al borde: ×1.2" as the same mechanism.

## 6. Content taxonomy (S3, S4)

Three layers, mirroring Balatro's separation:

| Layer | Scope | Balatro analogue |
| --- | --- | --- |
| **Bonificadores** | board modifiers, defined per board | Blinds / boss effects |
| **Premios** | permanent during run, bought in shop | Jokers |
| **Canicas** | consumable-ish ammo with effects | Playing cards + consumables |

### 6.1 Canicas

- **One 3D model**, identity via material: colors, texture patterns,
  shaders (classic swirl, agate, fire, glass, …). Surreal designs allowed
  (fire marble = extra speed).
- Data (`MarbleDef`): display name, rarity, material (shader/texture),
  physics tweaks (speed, mass, bounciness), effect hooks, durability /
  break chance, price.
- Known effects from S4: rethrow (reset the marble once), glass (break
  chance, bigger bonus), homing (aim assist to chosen notch).
- Model question — open: **D1** (single-use vs reusable vs mixed).
- Selection per throw — open: **D2**.

### 6.2 Premios

- 3D shelf objects with fair-prize flavor (teddy bear, plastic robot,
  goldfish in a bag…), each with a short lore line tied to its effect.
- Permanent run effects that edit the score math or trigger on events
  (e.g. teddy bear: +50 flat; "trompo": each wall hit adds ×0.2 mult…).
- Data (`PrizeDef`): name, rarity, 3D model, hooks, price, flavor text.

### 6.3 Bonificadores (board modifiers)

- Attached to boards, they bend rules or physics: "walls are bouncy and
  each hit adds mult", "marble must touch the back wall before embedding
  or it doesn't count", "notches move", "numbers shuffle" (the S2
  example), "wind", "ice (less friction)".
- Data (`BoardModifierDef`): rules edits + event hooks + visual cues.

## 7. Economy (S2, S4)

- Currency: **$**, earned only during the run.
- Income per board won: `base(level) + per_marble(level) × marbles_left +
  bonus_objective_reward`. Exact numbers live in balance data.
- Shop appears **after each board** (boards 1-19; maybe also after 20 for
  endless mode — open: D6).
- Shop stock: 2-3 marbles, 2-3 prizes, 1 extra-marble pack, optional
  reroll. Prices scale with level.
- Interest on unspent money: open **D4**.
- Extra marbles bought in shop increase throw count for the rest of the
  run (S4). Do extra marbles persist if lost? They can't be "lost" except
  by being thrown (glass breaks) — durability model (D1) decides.

## 8. Library / collection (S4)

- In-game reference of every marble and prize ever seen: 3D viewer +
  effect text + flavor.
- Persistence and gameplay impact: open **D3**.

## 9. UX flow

Menu → Run (board) → [Board won] → Shop → next board … → Run won/lost →
summary → Library (from menu or pause). In-board HUD: throws left, money,
score vs target, active prizes row, bonus objective status.

## 10. Difficulty & balance strategy

- One difficulty **factor per level** (S2) scaling numeric targets.
- Physics difficulty stays hand-tuned per board theme (spacing, tilt,
  special notches) rather than scaled automatically.
- All balance numbers live in data files; a debug overlay (level, money,
  score math breakdown) supports tuning sessions.
- Balance test harness: headless sim of scripted throws per board to
  catch gross imbalance (see architecture doc).

## 11. Open decisions

| # | Decision | Options |
| --- | --- | --- |
| D1 | Marble durability model | reusable all run / single-use / mixed categories |
| D2 | Marble selection per throw | player picks / fixed queue / random hand of 2-3 |
| D3 | Library persistence & impact | cosmetic only / unlocks content pool / no persistence |
| D4 | Interest on unspent $ | yes (Balatro-style) / no |
| D5 | Board order | fixed 1-20 / randomized within acts |
| D6 | Shop after board 20 (endless) | yes / no |
| D7 | Run length feel | 20 boards as-is vs acts of 5 with a boss board each |
