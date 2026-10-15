class_name Maps
extends RefCounted

## Maps as items (docs/endgame-plan.md E5): the base "map" (Items.BASES, never rolled as gear) with a tier
## (T1-MAX_TIER for now), a theme, a seed for MapGen and map mods (Items.AFFIXES of kind "map", rolled like
## an item's by rarity). The area level is AREA_BASE + 2 x tier; every mod adds QUANTITY_PER_MOD % item quantity
## and RARITY_PER_MOD % item rarity to what drops in it. Enemies there have more life with the area level
## (life_mult()). Main runs them (start_map(), the Map Device).

const MAX_TIER := 5
const AREA_BASE := 30
const QUANTITY_PER_MOD := 8.0
const RARITY_PER_MOD := 5.0
## Enemies' life in a map: x HP_GROWTH^(area level - 24) (x1.85 at T1, x3.4 at T5) on top of Enemy.HP_FACTOR.
const HP_GROWTH := 1.08
## A defeated enemy drops a map with MAP_DROP chance (raised by quantity); a map is a tier higher UP_CHANCE of
## the time.
const MAP_DROP := 0.03
const UP_CHANCE := 0.25
## What the map boss drops: maps, and items with this much more rarity.
const BOSS_MAPS := 2
const BOSS_RARITY := 300.0
const THEME_NAMES := {"plains": "Latent"}


static func area_level(tier: int) -> int:
	return AREA_BASE + 2 * tier


## A new map of `tier` (rarity "" rolls it like an item's).
static func roll(tier: int, rng: RandomNumberGenerator, rarity := "") -> Dictionary:
	tier = clampi(tier, 1, MAX_TIER)
	var it := Items.roll(area_level(tier), rng, rarity, "map")
	it.tier = tier
	it.theme = "plains"
	it.seed = rng.randi() % 1000000
	return it


## The device gets a normal T1 map when Clawd has none anywhere and none is open, so he is never stuck.
static func ensure_starter() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var main = tree.get_first_node_in_group("main") if tree else null
	if main and not main.map_run.is_empty():
		return
	for it in Progress.inventory + Progress.stash + Progress.device:
		if is_map(it):
			return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var m := roll(1, rng, "normal")
	m.at = [0, 0]
	Progress.device = [m]
	Progress.save_items()


static func is_map(it: Dictionary) -> bool:
	return not it.is_empty() and it.get("base", "") == "map"


static func quantity(it: Dictionary) -> float:
	return QUANTITY_PER_MOD * it.affixes.size()


static func rarity(it: Dictionary) -> float:
	return RARITY_PER_MOD * it.affixes.size()


## A dropped map's tier: the same, or one higher UP_CHANCE of the time (at most MAX_TIER).
static func drop_tier(tier: int, rng: RandomNumberGenerator) -> int:
	return mini(MAX_TIER, tier + (1 if rng.randf() < UP_CHANCE else 0))


static func life_mult(area: int) -> float:
	return pow(HP_GROWTH, maxi(0, area - 24))


## The map's own lines for the tooltip (after its mods): quantity and rarity.
static func extra_lines(it: Dictionary) -> Array:
	return [["+%d%% item quantity" % roundi(quantity(it)), false, true], ["+%d%% item rarity" % roundi(rarity(it)), false, true]]
