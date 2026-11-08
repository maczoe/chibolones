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


## Placeholder shop stock for a block: the two marbles, two prizes, the
## extra-throw pack and the reroll the real shop will sell in M3. Prizes
## wrap around when the content pool is smaller than the stock, so the
## placeholder still fills its cards.
func shop_stock(block: int) -> Dictionary:
	var marbles: Array[Dictionary] = []
	var marbles_pool := ContentDB.marbles()
	for i in STOCK_MARBLES:
		if marbles_pool.is_empty():
			break
		var marble: MarbleDef = marbles_pool[i % marbles_pool.size()]
		marbles.append({
			"def_id": marble.id,
			"price": marble_price(base_price_for(marble.id), block),
		})
	var prizes: Array[Dictionary] = []
	var prizes_pool := ContentDB.prizes()
	for i in STOCK_PRIZES:
		if prizes_pool.is_empty():
			break
		var prize: PrizeDef = prizes_pool[i % prizes_pool.size()]
		prizes.append({
			"def_id": prize.id,
			"price": marble_price(base_price_for(prize.id), block),
		})
	return {
		"marbles": marbles,
		"prizes": prizes,
		"extra_pack_price": extra_marble_pack_price(block),
		"reroll_price": reroll_price(),
	}
