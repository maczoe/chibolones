extends Node
## Economy v1 (autoload "Economy"): every money number of a run lives here
## as a pure function, so the balance and the shop can be tested without a
## scene. Numbers come from docs/gdd/content-plan.md §2 (M1 wave); M5 moves
## them into data/balance/economy.tres.

## Extra-throw pack: base 3 + block, i.e. $4..$8 over the five blocks.
const EXTRA_PACK_BASE := 3
## Shop reroll (one fresh stock), flat.
const REROLL_PRICE := 2
## Stock sizes the shop offers after each board.
const STOCK_MARBLES := 2
const STOCK_PRIZES := 2
## Draw weights per rarity (S5): commons dominate, rares are a treat.
const RARITY_WEIGHTS := {"common": 60, "uncommon": 30, "rare": 10}
## S6 discovery: a chest may reveal a prize the profile has not unlocked yet,
## which is the second unlock source beside the milestone boards. One chest per
## run gets the chance.
const CHEST_DISCOVERY_CHANCE := 0.10


## Reward for clearing a board: base(block) + per_marble(block) * marbles_left
## + bonus. Efficiency pays: every marble still available is worth more in
## later blocks.
func reward_for_block_win(block: int, marbles_left: int, bonus: int) -> int:
	var base := 3 + block * 2
	var per_marble := 1 + block
	return base + per_marble * marbles_left + bonus


## Price multiplier per block: 1.0 in block 1, +0.35 per block after.
func price_scale(block: int) -> float:
	return 1.0 + 0.35 * float(block - 1)


## Scaled price of a content def. Defs own their base price (W3): Economy
## only applies the block scale and rounds to nearest. A def without a
## price (0) stays 0 — missing data is a bug to surface, not a $1 tag.
func marble_price(def_base_price: int, block: int) -> int:
	return roundi(float(def_base_price) * price_scale(block))


## One extra throw for the current board.
func extra_marble_pack_price(block: int) -> int:
	return EXTRA_PACK_BASE + block


func reroll_price() -> int:
	return REROLL_PRICE


## Price of a def id before the block scale (0 for unknown ids). Since W3
## the price lives in the def itself; this looks it up in the content DB.
func base_price_for(def_id: String) -> int:
	var marble := ContentDB.find_marble_def(def_id)
	if marble != null:
		return marble.price
	var prize := ContentDB.find_prize_def(def_id)
	if prize != null:
		return prize.price
	return 0


## W3b rescue value when selling an item back: half the CURRENT list price
## (block-scaled), rounded up. Selling is a stopgap, not an economy.
func rescue_price(def_base_price: int, block: int) -> int:
	return ceili(marble_price(def_base_price, block) / 2.0)


## Placeholder shop stock for a block: the two marbles, two prizes, the
## extra-throw pack and the reroll the real shop will sell in M3. Prizes
## wrap around when the content pool is smaller than the stock, so the
## placeholder still fills its cards.
## The W3 shop stock: a weighted rarity draw over the content pool (S5),
## 2 marbles + 2 prizes, no repeats, plus the pack and the reroll. A seed
## >= 0 makes the draw deterministic (tests); -1 randomizes.
func shop_stock(block: int, seed: int = -1) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	if seed >= 0:
		rng.seed = seed
	else:
		rng.randomize()
	return {
		"marbles":
		_draw_stock(_unlocked_only(ContentDB.marbles(), "marbles"), STOCK_MARBLES, block, rng),
		"prizes":
		_draw_stock(_unlocked_only(_sellable_prizes(), "prizes"), STOCK_PRIZES, block, rng),
		"extra_pack_price": extra_marble_pack_price(block),
		"reroll_price": reroll_price(),
	}


## S5/D3: the shop sells the profile's unlocked pool, never the whole catalog.
## Without a profile (headless suites that do not install SaveGame) the catalog
## is the pool, which is the pre-M4 behavior.
func _unlocked_only(defs: Array, kind: String) -> Array:
	if SaveGame == null:
		return defs
	var ids: Array = SaveGame.unlocked_ids(kind)
	if ids.is_empty():
		return defs
	var out: Array = []
	for def in defs:
		if ids.has(def.id):
			out.append(def)
	return out


## D8: cosmetics never reach the shop — their source is chests and the
## gachapon — and a class the shop does not sell would otherwise list at $0.
func _sellable_prizes() -> Array:
	var out: Array = []
	for def in ContentDB.prizes():
		if def.prize_class != PrizeDef.PrizeClass.COSMETIC:
			out.append(def)
	return out


## Count-many picks without replacement, weighted by rarity.
func _draw_stock(
	pool: Array, count: int, block: int, rng: RandomNumberGenerator
) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var remaining := pool.duplicate()
	for i in count:
		if remaining.is_empty():
			break
		var def: Resource = _weighted_pick(remaining, rng)
		remaining.erase(def)
		(
			out
			. append(
				{
					"def_id": def.id,
					"price": marble_price(def.price, block),
				}
			)
		)
	return out


func _weighted_pick(pool: Array, rng: RandomNumberGenerator) -> Resource:
	var total := 0
	for def in pool:
		total += int(RARITY_WEIGHTS.get(def.rarity, 10))
	var roll := rng.randi_range(1, total)
	for def in pool:
		roll -= int(RARITY_WEIGHTS.get(def.rarity, 10))
		if roll <= 0:
			return def
	return pool.back()


## D10/S14: what one chest holds. Rarity first, by the same weights the shop
## rolls, then a class inside that rarity, then one def of the class; defs
## the run already owns or collected never come back, so every chest is a
## new toy. A seed >= 0 makes the draw deterministic (tests); -1 randomizes.
## Returns {"def_id": String, "cash": int}: an empty pool hands nothing
## over, and the board pays its own `chest_cash_fallback` for both that case
## and a refused grant — the cash number is board data, not an economy
## constant, so tuning it never has to happen twice.
func chest_draw(
	owned_ids: Array[String],
	collected_ids: Array[String],
	seed: int,
	unlocked_ids: Array[String] = []
) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	if seed >= 0:
		rng.seed = seed
	else:
		rng.randomize()
	var pool := chest_pool(owned_ids, collected_ids, unlocked_ids)
	if pool.is_empty():
		return {"def_id": "", "cash": 0}
	# Step 1: the rarity, weighted so a rare stays a treat.
	var groups := _chest_groups(pool)
	var rarity := _weighted_rarity(groups.keys(), rng)
	# Step 2: a class inside that rarity, uniform, then one of its defs.
	var by_class: Dictionary = groups[rarity]
	var classes := by_class.keys()
	var candidates: Array = by_class[classes[rng.randi_range(0, classes.size() - 1)]]
	var def: Resource = candidates[rng.randi_range(0, candidates.size() - 1)]
	return {"def_id": def.id, "cash": 0}


## Prizes a chest may still give: everything the run does not own and has
## not collected yet (S14). Public because the board's wheel cycles the same
## pool it draws from: two filters that could disagree would show loot that
## can never drop.
func chest_pool(
	owned_ids: Array[String], collected_ids: Array[String], unlocked_ids: Array[String] = []
) -> Array:
	var pool: Array = []
	for def in ContentDB.prizes():
		if owned_ids.has(def.id) or collected_ids.has(def.id):
			continue
		# An empty list means "do not filter" (headless tests and the pre-M4
		# callers); the board always passes the profile's unlocked ids.
		if not unlocked_ids.is_empty() and not unlocked_ids.has(def.id):
			continue
		pool.append(def)
	return pool


## S6 discovery: the chest draw with the unlocked filter and the once-per-run
## reveal. Returns {"def_id": String, "cash": int, "discovered": bool}.
## `reveal_used` is the run's single discovery already spent; a discovered def
## is always one the profile has not unlocked, so the caller unlocks it.
func chest_draw_discovery(
	owned_ids: Array[String],
	collected_ids: Array[String],
	unlocked_ids: Array[String],
	reveal_used: bool,
	seed: int
) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	if seed >= 0:
		rng.seed = seed
	else:
		rng.randomize()
	if not reveal_used and rng.randf() < CHEST_DISCOVERY_CHANCE:
		var locked := chest_discovery_pool(owned_ids, collected_ids, unlocked_ids)
		if not locked.is_empty():
			var picked: Resource = locked[rng.randi_range(0, locked.size() - 1)]
			return {"def_id": picked.id, "cash": 0, "discovered": true}
	var draw := chest_draw(owned_ids, collected_ids, seed, unlocked_ids)
	draw["discovered"] = false
	return draw


## Prizes a chest may discover (S6): locked in the profile, still unowned and
## uncollected in this run.
func chest_discovery_pool(
	owned_ids: Array[String], collected_ids: Array[String], unlocked_ids: Array[String]
) -> Array:
	var pool: Array = []
	for def in ContentDB.prizes():
		if unlocked_ids.has(def.id) or owned_ids.has(def.id) or collected_ids.has(def.id):
			continue
		pool.append(def)
	return pool


## The pool split by rarity and then by class, so the second step can pick
## a class uniformly instead of re-reading every def.
func _chest_groups(pool: Array) -> Dictionary:
	var groups := {}
	for def in pool:
		var by_class: Dictionary = groups.get(def.rarity, {})
		var slot: Array = by_class.get(def.prize_class, [])
		slot.append(def)
		by_class[def.prize_class] = slot
		groups[def.rarity] = by_class
	return groups


func _weighted_rarity(rarities: Array, rng: RandomNumberGenerator) -> String:
	var total := 0
	for rarity in rarities:
		total += int(RARITY_WEIGHTS.get(rarity, 10))
	var roll := rng.randi_range(1, total)
	for rarity in rarities:
		roll -= int(RARITY_WEIGHTS.get(rarity, 10))
		if roll <= 0:
			return String(rarity)
	return String(rarities.back())
