class_name Vendor
extends RefCounted

## The hideout's vendor (docs/endgame-plan.md E4): it buys any item for tokens and sells a stock of COUNT items
## of Clawd's level (half normal, most of the rest magic, a few rare) for four times that. The stock is in
## Progress.vendor (a grid like the stash) and comes anew after every level cleared (Progress.runs).
## An item's worth: VALUE x (1 + item level / 10) x its rarity's factor.

const COUNT := 10
const SIZE := Vector2i(12, 12)
const VALUE := 3.0
const RARITY := {"normal": 1.0, "magic": 3.0, "rare": 8.0, "unique": 20.0}
const MARKUP := 4.0
## The stock's rarities: normal, magic and rare weights.
const STOCK_RARITY := {"normal": 50, "magic": 40, "rare": 10}


static func value(it: Dictionary) -> float:
	return VALUE * (1.0 + it.ilvl / 10.0) * RARITY.get(it.rarity, 1.0)


static func sell_price(it: Dictionary) -> int:
	return maxi(1, roundi(value(it)))


static func buy_price(it: Dictionary) -> int:
	return roundi(value(it) * MARKUP)


## A new stock when a level was cleared since the last one (or there is none yet).
static func ensure_stock() -> void:
	if Progress.vendor_at != Progress.runs or Progress.vendor.is_empty():
		restock()


static func restock(seed := -1) -> void:
	var rng := RandomNumberGenerator.new()
	if seed >= 0:
		rng.seed = seed
	else:
		rng.randomize()
	Progress.vendor = []
	for i in COUNT:
		var r := rng.randi() % 100
		var rarity := "normal" if r < STOCK_RARITY.normal else "magic" if r < STOCK_RARITY.normal + STOCK_RARITY.magic else "rare"
		Gear.place(Progress.vendor, SIZE, Items.roll(maxi(1, Progress.char_level), rng, rarity))
	Progress.vendor_at = Progress.runs
	Progress.save_items()


## Sells `it` (out of the inventory) to the vendor: its tokens into the wallet.
static func sell(it: Dictionary) -> int:
	var price := sell_price(it)
	Progress.inventory.erase(it)
	Progress.wallet += price
	Progress.save()
	Progress.save_items()
	return price


## Buys `it` from the stock into the inventory: "bought", "poor" or "full".
static func buy(it: Dictionary) -> String:
	var price := buy_price(it)
	if Progress.wallet < price:
		return "poor"
	if not Gear.fits(it):
		return "full"
	Progress.vendor.erase(it)
	Gear.take(it)
	Progress.wallet -= price
	Progress.save()
	Progress.save_items()
	return "bought"
