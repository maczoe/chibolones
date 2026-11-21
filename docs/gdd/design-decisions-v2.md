# Chibolones — Design Decision Log v2: Economy & Board Variety Pivot

Records the design pivot decided after playtesting felt the game loop
lacked variety. These decisions amend and extend `content-plan.md`
(v1, D1-D7) and `gdd.md`; where they conflict, this document wins.
Status: **decided (D8-D15)**, not yet implemented. Each decision keeps
its open sub-questions in its section; they are resolved during the
implementing wave's design, not blockers for recording.

## D8 — Prize classes (consumables and cosmetics join the economy)

The prize system splits into three classes, to reward the run economy
and permanent unlock progress:

1. **Permanent usable prizes** ( comodines, Balatro's Jokers ): unlocked
   for the run's starting pool; persist across runs once unlocked.
2. **Consumable usable prizes** (like Balatro's Tarot/Planet cards):
   single use within the run, bought in shop or found in chests.
3. **Cosmetic prizes**: no gameplay effect; shown in the fair shelf /
   library; sourced from chests, gachapon and minigames.

Run economy rebalanced: board objectives no longer always demand "score
high" (see D9), so purchases become strategic adaptations to the run
rather than pure power scaling. Buy what this run's boards need.

Impact analysis:

- Content surface is 3 classes x rarities x 3 sources (shop, chests,
  gachapon). Cap the first wave per cell (e.g. shop-first for usable,
  chest/gachapon-first for cosmetic) instead of filling the matrix.
- D1-D3 economy numbers in `content-plan.md` §2 need a rebalance pass
  once objectives stop paying flat score bonuses.

Open: what a chest drawn permanent usable prize does mid-run (active
this run vs. unlock-only for future runs).

## D9 — Objective types beyond the score threshold

Boards are won by one of four objective kinds:

| Kind | Example |
| --- | --- |
| Threshold | score >= 100 (current behavior) |
| Exact | final score = 100 |
| Goal list | hit all of =50, then =80, then =120 |
| Math rule | final score is prime / even / odd |

Threshold boards keep the arcade feel; exact/list/rule boards add the
planning layer. Shuffle-value boards (Borracho, Mil Voces) must use
threshold or range objectives — an exact target over shifting values
is contradictory (open: whether "range" e.g. 90-110 is a fifth kind or
an exact variant).

Open: overshoot rule for exact objectives (single forgiveness, surplus
converts to money, etc.) and live HUD feedback for math rules (the
player must be able to judge "need 73, is it prime?" mid-throw).

## D10 — Chests on boards

Some boards carry fixed, predefined chests; every board can also roll
hidden chests inside a defined spawn area (usually near or behind the
notch rows) with a hidden spawn percentage and random chest rarity.

- A chest hit opens it: a wheel-of-fortune animation reveals a prize
  drawn by chest rarity (permanent usable / consumable / cosmetic).
- The marble is NOT consumed by the chest; it keeps rolling after the
  reveal.
- Open: chest neutrality toward score on exact/list boards; the reveal
  must stay short (2-3 s target) to protect the 5-20 s throw loop.

## D11 — Library / collection section in the main menu

The library gains an index of: cosmetic prizes, usable prizes,
consumable prizes, game songs, game sound effects and marbles. Every
entry shows: rarity (common / rare / legendary), name, lore text,
effect description, and a 3D model + sprite. First wave may use tinted
placeholder models; lore + effect text define identity before art.

## D12 — Configurable notch matrices and loss holes

Every board's hole matrix (values and arrangement) is per-board data
instead of the fixed 10/20/30/50 everywhere:

- Strategically themed boards pair a specific matrix with specific
  goals (e.g. all-odd matrix with "final score is even"; "hit a 5, 10
  or 20" while one hole's 30 loses the run).
- Shuffle/random boards (Borracho) define range/threshold objectives.
- **Rule: every board must be winnable with a baseline inventory.**
  Winnability is enforced by a checker tool (analyze/simulate matrix x
  objectives vs. a reference marble set), not by hand runs. Facilitating
  prizes (consumables that bend score or movement) make the shop a
  planning layer, per D8.

## D13 — Alternative hole layouts

Some boards use non-grid notch distributions: inverted triangle, a
single central hole, and similar; moving groups (Trapecio) already
exist. Layouts are data-driven generators selectable per board, so new
layouts cost a generator, not a board rewrite. Spacing must preserve
marble physics and readability.

## D14 — Ramps and upper platforms (mini-golf boards)

Thematic boards only (a minority, not all) add ramps to raised
platforms holding holes or treasure chests, leveraging the marble
physics for variety. Expect the highest per-item tuning cost; dose as
2-4 themed boards across the run, validated for the existing marble set
(nitro/glass speed extremes must not trivially skip over structures).

## D15 — Fair tickets, gachapon and the minigame hub

At run end the accumulated money converts to fair tickets. Tickets feed
a gachapon machine in the main menu containing cosmetic prizes, songs
and sound effects. A minigame hub will later add income sources for
cosmetics only (the post-boss shooting gallery (previously analyzed as
pivot idea 3) lands here); gameplay items stay run-only, so the meta
economy never dilutes the run economy.

## ## D16 — Configurable floor texture per board

The floor (the fairground ground under the cabinet) is configurable per
board as data, like the backdrop shader already is (D-list in gdd.md
"Theme style"): today every board shares the `checker` floor shader
(`floor_checker_a/b`, `floor_checker_size`). Add a `floor_style`
selector plus per-style parameters so themed boards can feel like a
different place: `checker` (current), plus variants planned with the
content (e.g. wet puddle reflections for Mojado, sand/dust for a
desert-themed board, glow grid for neon blocks, cobblestone/starfield).
Same rule as the backdrop: one shader with parameters, variant chosen
by data in the BoardDef; a new look costs a shader fragment + a
StringName, not board code. Goal of the decision: every board's
environment (backdrop + floor + palette) reads as its own scene, not
color swaps of one room.

Board building workflow (decided approach)

Boards are composed from a small catalog of reusable, data-configured
primitives instead of per-board code or a custom editor:

- **Primitives** (each a BoardDef field or modifier family): layout
  generators (D13), goal types (D9), chest zones fixed/probabilistic
  (D10), ramps/platforms (D14), trap holes (D12), matrix value sets
  (D12), floor/backdrop styles (D16), existing BoardModifiers.
- **Winnability checker** (script): validates every board against its
  own matrix + objectives (D12's rule) before content lands.
- **Workflow**: the designer proposes a board in one sentence; the
  implementer composes it from existing primitives and only builds a
  new primitive when the idea cannot be expressed otherwise; every new
  primitive joins the catalog for later boards. Marginal cost per new
  board decreases with the catalog.

## Dependency order for implementation (analysis result)

1. D12 + D9 (matrix + objective kinds) — cheap, changes the player's
   head first, blocker for the checker tool.
2. D8 + D10 (prize classes + chests) — biggest game-loop mover; the
   library section (D11) must exist or land with it so loot has a home.
3. D13 + D14 (layouts + ramps) — dosed, highest tuning cost.
4. D15 (tickets + gachapon + hub) — meta layer, lands last.
