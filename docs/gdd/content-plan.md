# Chibolones — Content Refinement Plan v1

The design wave that turns the validated slice into the full game.
Structure decisions already locked in the GDD v0.3 (D1-D7): 5 blocks of
4 boards (3 normal + 1 boss, random draw), endless after 20, mixed
marble durability, player-picked bag, unlock library, no interest.

## 1. Design waves

| Wave | Content | Lands in |
| --- | --- | --- |
| W1 | Run skeleton, 20 boards (this doc §3), economy v1, shop placeholder | M1 |
| W2 | Hook contract + scoring pipeline; 10 bonificadores (§4.3) | M2 |
| W3 | 10 marbles (§4.1), 10 prizes (§4.2), shop v1, bag/prize pricing | M3 |
| W4 | Library + unlocks (save file), first-run starter pool | M4 |
| W5 | Balance harness over the sim, difficulty curve pass | M5 |
| W6 | Prize 3D models, marble texture patterns/shaders, juice, audio | M6 |

The lists below are design data; each wave implements them as
resources on the systems its milestone builds.

## 2. Economy v1 (tuning numbers live in data/balance/economy.tres)

- Start: 5 marbles + $5.
- Board reward: `base(block) + per_marble(block) * marbles_left + bonus`.
  - `base(block)` = 3 + block * 2 (block = 1..5).
  - `per_marble(block)` = 1 + block (efficiency pays).
  - `bonus` = bonus-objective reward, listed per board (usually $2-4).
- Endless mode: rewards keep the block-5 rate, +1 per board won.
- Prices scale with block: `price(block) = base_price * (1 + 0.35 * (block - 1))`.
- Shop stock after each board: 2 marbles, 2 prizes, 1 extra-marble pack
  (+1 throw, $[4,5,6,7,8] per block), 1 reroll ($2).
- No interest (D4). Losing a board loses the run; run summary shows
  boards cleared, money and collection progress.

## 3. The 20 boards

Values assume the POC feel (notch rows 10/20/30/50). Objective targets
use the difficulty factor `f(block)`: block 1 = x1, 2 = x1.15,
3 = x1.3, 4 = x1.5, 5 = x1.75. Boss targets are for a single board's
score cap (5 throws, max possible 250 before marbles/prizes).

### Block 1 — "La Feria llega al pueblo" (targets x1)
| # | Board | Gimmick (bonificador) | Objective | Bonus |
| --- | --- | --- | --- | --- |
| 1 | Tablero Clasico | none (tutorial board) | score >= 60 | embed 2 marbles |
| 2 | Tablero de Cuerda | back wall is bouncy, wall hits +mult | score >= 70 | 3 wall hits |
| 3 | Tablero Mojado | ice: low friction | score >= 70 | 1 embed in the back row |
| 4 | **JEFE: El Tablero Borracho** | values shuffle every throw | score >= 100 | >= 1 fire marble embed |

### Block 2 — "Luces de neón" (x1.15)
| # | Board | Gimmick | Objective | Bonus |
| --- | --- | --- | --- | --- |
| 5 | Tablero Espejo | center notch is worth x2 but has a glass floor (no embed bounce) | score >= 90 | use the center notch |
| 6 | Tablero Ventoso | gentle cross wind, changes side each throw | score >= 100 | embed against the wind |
| 7 | Tablero Mochila | one random notch is covered each throw | score >= 100 | embed 3 different values |
| 8 | **JEFE: La Barraca Sellada** | walls taller + glass-style marbles only | score >= 130 | no refunds |

### Block 3 — "El circo encantado" (x1.3)
| # | Board | Gimmick | Objective | Bonus |
| --- | --- | --- | --- | --- |
| 9 | Tablero Fantasma | one notch phases in/out every 2 s | score >= 120 | embed a phasing notch |
| 10 | Tablero Iman | embedded marbles attract the rolling one (mild) | score >= 120 | hit 2 embedded marbles |
| 11 | Tablero Trapecio | the notch grid swings sideways slowly | score >= 130 | embed while swinging |
| 12 | **JEFE: El Truco Final** | must call the value: pick a row before throwing, only that row scores | score >= 150 | 2 calls correct |

### Block 4 — "La noche de los cincos" (x1.5)
| # | Board | Gimmick | Objective | Bonus |
| --- | --- | --- | --- | --- |
| 13 | Tablero de Vidrio | the board is glass: marbles that settle slide off (0 pts) | score >= 140 | 2 embeds |
| 14 | Tablero Culebra | notches connected by rails: embed rolls to the next notch | score >= 150 | chain 2 rails |
| 15 | Tablero Mil Voces | each embed plays a random rule from blocks 1-3 | score >= 150 | 3 embeds |
| 16 | **JEFE: El Show de Medianoche** | only the back row exists (all 50s), marbles break on 2nd wall hit (glass rule) | score >= 200 | 3 embeds |

### Block 5 — "La carpa infinita" (x1.75)
| # | Board | Gimmick | Objective | Bonus |
| --- | --- | --- | --- | --- |
| 17 | Tablero de Cuerdas Tricioneras | wind + bouncy walls together | score >= 170 | 5 wall hits |
| 18 | Tablero Cronometrado | 4 s per throw decision or it auto-throws | score >= 180 | never auto-throw |
| 19 | Tablero Espejismo | notch values hide until the marble is mid-flight | score >= 180 | embed 2 unseen values |
| 20 | **JEFE: El Quinto Cinco** | all gimmicks rotate every throw; win the run | score >= 250 | score >= 300 |

Endless mode: random boss-tier gimmick stack per board, factor +0.25
per board won. Implementation notes: gimmicks map to BoardModifierDef
(event hooks + rule edits, M2); no new engine per board.

## 4. Content lists (wave targets)

### 4.1 Marbles (M3) — 10
Common set (permanent): Común, Fuego (speed x1.25), Vidrio (score x2,
break 20% when M2 lands), Agata (heavy: mass 1.5, steady in wind),
Remolino (curves slightly toward board center).
Magic set (single-use): Teledirigida (choose the notch, gentle homing),
Rebote (refund even off the sides), Nitro (speed x1.6, one-shot), Trampa
(embeds anywhere it touches, even fast), Espejo (copies the previous
throw's score). Rarities: 5 common, 3 uncommon, 2 rare — pricing in
economy.tres per §2.

### 4.2 Prizes (M3) — 10
Osito de Peluche (+50 flat on board end), Trompo de Madera (x1.5 per
wall hit, shipped), Muñeco de Nieve (embeds settle instead of staying
fast: skip_speed halved), Pelota de Goma (marbles bounce x1.3),
Billete de la Suerte (+$2 per refund), Globo (one extra throw per
board), Boleto Retro (first throw each board replays if it scored 0),
Carpa en Miniatura (+1 marble slot in the bag), Rayo (fire marbles
speed x1.5), Corona del Circo (x1.1 to everything, rare). Rarities:
6 common, 3 uncommon, 1 rare.

### 4.3 Bonificadores (M2) — 10 — implemented (W2)
Cuerda (bouncy walls +mult), Mojado (low friction), Borracho (value
shuffle), Espejo (x2 center), Ventoso (cross wind), Mochila (covered
notch), Fantasma (phasing notch), Iman (embedded attraction), Trapecio
(swinging grid), Cronometrado (decision timer). Each = rule edit +
event hooks + HUD cue, per the M2 hook contract.

All ten ship as data (`data/modifiers/*.tres` -> `BoardModifierDef`) with
`scripts/board/board_theme.gd` as their runtime and
`ScoreEngine.evaluate_embed()` as the scoring seam; the board announces
them at board start and shows the score math when a rule changed the
value. Boss boards run their block's pair (block 1 opens with Borracho)
and normal boards carry none or one. Numbers live in the .tres files; the
assignment lives in `Game.board_modifiers(n)`.

## 5. Open for the next refinement round

- Exact objective numbers after the M5 balance sim (targets above are
  design estimates from the POC feel).
- Marble break rules once M2 adds durability events (glass 20%): the roll
  and the bag event are live since M2, the 20% value lands with the M3
  marble data.
- Unlock pool split for first runs (M4): which 6 marbles / 6 prizes
  are available before any unlock.
