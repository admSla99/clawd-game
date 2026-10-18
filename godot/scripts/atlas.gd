class_name Atlas
extends RefCounted

## The Atlas (docs/endgame-plan.md E8): Clawd's progress through the map tiers and a small passive tree of map
## bonuses, drawn by TreeScreen like the prompt tree (Tab switches; the hideout's Atlas station opens it).
## Progress: the boss of a tier n map completed for the first time unlocks tier n + 1 (unlocked_tier(): maps drop
## no higher, Maps.drop_tier()) and gives an Atlas point; a rare map completed gives one more for its world, once
## (Progress.atlas_bonus). 16 + 3 points, 22 nodes: not everything can be taken. Refunds are free like the prompt
## tree's. Every bonus counts in maps only: Main reads stat() (quantity, rarity, pack size, maps and orbs dropped,
## portals, XP, the resistance penalty) and orb_bonus(). Progress.atlas holds the allocated ids.

const START := "root"
## id -> kind ("start", "small", "notable", "keystone"), name, what it does, where it sits (px from the start, y
## down) and its stats (`mods`, summed by stat()), like Prompts.NODES.
const NODES := {
	"root": {"kind": "start", "name": "THE ATLAS", "at": Vector2(0, 0), "mods": {},
		"desc": "Every new tier completed gives a point, and a rare map completed one for its world."},
	# Loot, east.
	"qty1": {"kind": "small", "name": "Bigger Batches", "at": Vector2(30, 0), "mods": {"quantity": 4}, "desc": "+4% item quantity in maps."},
	"qty2": {"kind": "small", "name": "Bigger Batches", "at": Vector2(58, 0), "mods": {"quantity": 4}, "desc": "+4% item quantity in maps."},
	"scaling": {"kind": "notable", "name": "Scaling Laws.", "at": Vector2(86, -20), "mods": {"quantity": 10, "pack": 10},
		"desc": "+10% item quantity and 10% more enemies in maps."},
	"emergence": {"kind": "keystone", "name": "Emergence.", "at": Vector2(116, -20), "mods": {"mod_loot": 100, "monster_damage": 15},
		"desc": "Every map mod gives twice the item quantity and rarity, but enemies in maps deal 15% more damage."},
	"rar1": {"kind": "small", "name": "Rarer Samples", "at": Vector2(86, 20), "mods": {"rarity": 10}, "desc": "+10% item rarity in maps."},
	"rar2": {"kind": "small", "name": "Rarer Samples", "at": Vector2(114, 20), "mods": {"rarity": 10}, "desc": "+10% item rarity in maps."},
	# Maps, north.
	"drop1": {"kind": "small", "name": "Data Augmentation", "at": Vector2(0, -20), "mods": {"map_drop": 15}, "desc": "Maps drop 15% more often."},
	"drop2": {"kind": "small", "name": "Data Augmentation", "at": Vector2(0, -38), "mods": {"map_drop": 15}, "desc": "Maps drop 15% more often."},
	"curriculum": {"kind": "notable", "name": "Curriculum Learning.", "at": Vector2(-22, -56), "mods": {"map_up": 15},
		"desc": "Dropped maps are a tier higher 15% more often."},
	"up1": {"kind": "small", "name": "Harder Examples", "at": Vector2(-50, -56), "mods": {"map_up": 5}, "desc": "Dropped maps are a tier higher 5% more often."},
	"selfplay": {"kind": "notable", "name": "Self-Play.", "at": Vector2(22, -56), "mods": {"boss_maps": 1}, "desc": "Map bosses drop one more map."},
	"drop3": {"kind": "small", "name": "Data Augmentation", "at": Vector2(50, -56), "mods": {"map_drop": 15}, "desc": "Maps drop 15% more often."},
	# Orbs, west.
	"orb1": {"kind": "small", "name": "Gradient Descent", "at": Vector2(-30, 0), "mods": {"currency": 10}, "desc": "Orbs drop 10% more often in maps."},
	"orb2": {"kind": "small", "name": "Gradient Descent", "at": Vector2(-58, 0), "mods": {"currency": 10}, "desc": "Orbs drop 10% more often in maps."},
	"distill": {"kind": "notable", "name": "Knowledge Distillation.", "at": Vector2(-86, -20), "mods": {"orb_distill": 200},
		"desc": "Distillations drop three times as often in maps."},
	"orb3": {"kind": "small", "name": "Gradient Descent", "at": Vector2(-114, -20), "mods": {"currency": 10}, "desc": "Orbs drop 10% more often in maps."},
	"finetune": {"kind": "keystone", "name": "Fine-tuning Run.", "at": Vector2(-144, -20), "mods": {"orb_finetune": 400, "currency": -20},
		"desc": "Fine-tunes drop five times as often in maps, but orbs drop 20% less often."},
	"temperature": {"kind": "notable", "name": "High Temperature.", "at": Vector2(-86, 20), "mods": {"orb_temperature": 200},
		"desc": "Temperature Spikes drop three times as often in maps."},
	# Sustain, south.
	"xp1": {"kind": "small", "name": "Replay Buffer", "at": Vector2(0, 20), "mods": {"xp": 5}, "desc": "+5% experience in maps."},
	"xp2": {"kind": "small", "name": "Replay Buffer", "at": Vector2(0, 38), "mods": {"xp": 5}, "desc": "+5% experience in maps."},
	"warm": {"kind": "notable", "name": "Warm Start.", "at": Vector2(-22, 56), "mods": {"death_xp": 50}, "desc": "A death in a map costs half the experience."},
	"robust": {"kind": "small", "name": "Robust Training", "at": Vector2(-50, 56), "mods": {"res_penalty": 2},
		"desc": "Resistances drop 2% less a map tier."},
	"redundancy": {"kind": "notable", "name": "Redundancy.", "at": Vector2(22, 56), "mods": {"portals": 2}, "desc": "Maps open two more portals."},
}
const LINKS := [
	["root", "qty1"], ["qty1", "qty2"], ["qty2", "scaling"], ["scaling", "emergence"], ["qty2", "rar1"], ["rar1", "rar2"],
	["root", "drop1"], ["drop1", "drop2"], ["drop2", "curriculum"], ["curriculum", "up1"], ["drop2", "selfplay"], ["selfplay", "drop3"],
	["root", "orb1"], ["orb1", "orb2"], ["orb2", "distill"], ["distill", "orb3"], ["orb3", "finetune"], ["orb2", "temperature"],
	["root", "xp1"], ["xp1", "xp2"], ["xp2", "warm"], ["warm", "robust"], ["xp2", "redundancy"],
]


## An allocated node (the start always is).
static func on(id: String) -> bool:
	return id == START or Progress.atlas.has(id)


## A stat summed over the allocated nodes.
static func stat(key: String) -> float:
	var n := 0.0
	for id in Progress.atlas:
		n += float(NODES.get(id, {}).get("mods", {}).get(key, 0))
	return n


## The orbs' drop weights in a map, more by the allocated nodes: orb id -> % more.
static func orb_bonus() -> Dictionary:
	var out := {}
	for id in Currency.ORDER:
		if stat("orb_" + id) != 0:
			out[id] = stat("orb_" + id)
	return out


static func allocated() -> Array:
	return Progress.atlas


# --- Progress ------------------------------------------------------------------

static func done(tier: int) -> bool:
	return int(Progress.maps_done.get(str(tier), 0)) > 0


static func tiers_done() -> int:
	var n := 0
	for t in range(1, Maps.MAX_TIER + 1):
		if done(t):
			n += 1
	return n


## The highest tier open to Clawd: one above the highest completed.
static func unlocked_tier() -> int:
	for t in range(Maps.MAX_TIER, 0, -1):
		if done(t):
			return mini(Maps.MAX_TIER, t + 1)
	return 1


## A map of `tier` (rare or not) was completed: counts it. Returns what it gave: "tier" (a new tier: a point and
## the next one open), "bonus" (the world's rare map: a point), both, or none.
static func complete(tier: int, rare: bool) -> Array:
	var out := []
	if not done(tier):
		out.append("tier")
	Progress.maps_done[str(tier)] = int(Progress.maps_done.get(str(tier), 0)) + 1
	var world := Maps.world_of(tier)
	if rare and not Progress.atlas_bonus.has(world):
		Progress.atlas_bonus.append(world)
		out.append("bonus")
	Progress.save()
	return out


# --- Points (the same rules as Prompts') --------------------------------------

static func points_total() -> int:
	return tiers_done() + Progress.atlas_bonus.size()


static func points_free() -> int:
	return points_total() - Progress.atlas.size()


## Atlas points are never sold.
static func point_price() -> int:
	return -1


static func buy_point() -> String:
	return "max"


static func reachable(id: String) -> bool:
	return Prompts.neighbours(id, LINKS).any(func(n: String) -> bool: return on(n))


static func can_refund(id: String) -> bool:
	if id == START or not Progress.atlas.has(id):
		return false
	var rest: Array = Progress.atlas.filter(func(n: String) -> bool: return n != id)
	return Prompts.joined(rest, LINKS, START).size() == rest.size()


## Allocates or refunds `id`, like Prompts.toggle().
static func toggle(id: String) -> String:
	if not NODES.has(id) or id == START:
		return "none"
	if Progress.atlas.has(id):
		if not can_refund(id):
			return "holds"
		Progress.atlas.erase(id)
		Progress.save()
		return "refunded"
	if not reachable(id):
		return "far"
	if points_free() <= 0:
		return "no points"
	Progress.atlas.append(id)
	Progress.save()
	return "allocated"


static func reset() -> void:
	Progress.atlas = []
	Progress.save()
