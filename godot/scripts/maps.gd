class_name Maps
extends RefCounted

## Maps as items (docs/endgame-plan.md E5, E8): the base "map" (Items.BASES, never rolled as gear) with a tier
## (T1-MAX_TIER), a theme, a seed for MapGen and map mods (Items.AFFIXES of kind "map", rolled like an item's by
## rarity). A tier belongs to a world (MapGen.world_of(): T1-5 world 1, T6-10 world 2, T11-16 world 3), whose
## chunks MapGen joins and whose map boss waits at the end; the theme (palette, scenery, motif, music) is one of that
## world's levels'. The area level grows by 2 a tier in world 1, 3 in world 2 and 4 in world 3 (T1 32, T5 40, T10
## 55, T16 79); every mod adds QUANTITY_PER_MOD % item quantity and RARITY_PER_MOD % item rarity to what drops in it,
## and the Atlas (scripts/atlas.gd) adds more (run_quantity(), run_rarity()). Enemies there have more life with the
## area level (life_mult()). Main runs them (start_map(), the Map Device).

const MAX_TIER := 16
const AREA_BASE := 30
const QUANTITY_PER_MOD := 8.0
const RARITY_PER_MOD := 5.0
## Enemies' life in a map: x HP_GROWTH^(area level - 24) up to area level HP_KNEE (x1.85 at T1, x3.4 at T5), then
## x HP_GROWTH_HIGH a level (x7.6 at T10, x19 at T16), on top of Enemy.HP_FACTOR.
const HP_GROWTH := 1.08
const HP_KNEE := 40
const HP_GROWTH_HIGH := 1.045
## A defeated enemy drops a map with MAP_DROP chance (raised by quantity); a map is a tier higher UP_CHANCE of
## the time, but never above the Atlas's unlocked tier.
const MAP_DROP := 0.03
const UP_CHANCE := 0.25
## What the map boss drops: maps, and items with this much more rarity.
const BOSS_MAPS := 2
const BOSS_RARITY := 300.0
## The themes a world's maps take (its levels', bosses' left out) and the word a map of each is named by.
const THEMES := {1: ["plains", "caves", "window"], 2: ["mesa", "forge", "swamp", "towers"], 3: ["canopy", "cliffs", "sandbox", "ravine"]}
const THEME_NAMES := {"plains": "Latent", "caves": "Gradient", "window": "Context", "mesa": "Merge", "forge": "Forge",
	"swamp": "Injection", "towers": "Diff", "canopy": "Endpoint", "cliffs": "Callback", "sandbox": "Sandbox", "ravine": "Timeout"}
## The map boss of each world's maps.
const BOSSES := {1: "res://scripts/map_boss.gd", 2: "res://scripts/jailbreak.gd", 3: "res://scripts/infinite_loop.gd"}


static func world_of(tier: int) -> int:
	return MapGen.world_of(tier)


static func area_level(tier: int) -> int:
	var a := AREA_BASE
	for t in range(1, clampi(tier, 1, MAX_TIER) + 1):
		a += 1 + world_of(t)
	return a


## A new map of `tier` (rarity "" rolls it like an item's).
static func roll(tier: int, rng: RandomNumberGenerator, rarity := "") -> Dictionary:
	tier = clampi(tier, 1, MAX_TIER)
	var it := Items.roll(area_level(tier), rng, rarity, "map")
	it.tier = tier
	var themes: Array = THEMES[world_of(tier)]
	it.theme = themes[rng.randi() % themes.size()]
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


## The map's own item quantity and rarity (its mods), as its tooltip says.
static func quantity(it: Dictionary) -> float:
	return QUANTITY_PER_MOD * it.affixes.size()


static func rarity(it: Dictionary) -> float:
	return RARITY_PER_MOD * it.affixes.size()


## What a run of it gets: its mods' (more with the Atlas's Emergence) plus the Atlas's.
static func run_quantity(it: Dictionary) -> float:
	return quantity(it) * (1.0 + Atlas.stat("mod_loot") / 100.0) + Atlas.stat("quantity")


static func run_rarity(it: Dictionary) -> float:
	return rarity(it) * (1.0 + Atlas.stat("mod_loot") / 100.0) + Atlas.stat("rarity")


## A dropped map's tier: the same, or one higher UP_CHANCE (+ `up_bonus` %) of the time, but no higher than the
## Atlas has unlocked (a map above it, from an old save, drops its own tier).
static func drop_tier(tier: int, rng: RandomNumberGenerator, up_bonus := 0.0) -> int:
	var up := 1 if rng.randf() < UP_CHANCE + up_bonus / 100.0 else 0
	return mini(tier + up, maxi(tier, Atlas.unlocked_tier()))


static func life_mult(area: int) -> float:
	return pow(HP_GROWTH, clampi(area, 24, HP_KNEE) - 24) * pow(HP_GROWTH_HIGH, maxi(0, area - HP_KNEE))


## The map's own lines for the tooltip (after its mods): quantity and rarity.
static func extra_lines(it: Dictionary) -> Array:
	return [["+%d%% item quantity" % roundi(quantity(it)), false, true], ["+%d%% item rarity" % roundi(rarity(it)), false, true]]
