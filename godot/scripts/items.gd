class_name Items
extends RefCounted

## Gear as items (docs/endgame-plan.md E2), Path of Exile's way: a base (what slot it goes in, how big it is in the
## inventory, an implicit stat, the area level it starts dropping at), a rarity (normal, magic: up to one prefix and
## one suffix, rare: up to three of each and a made-up name) and the item level it dropped at, which gates the
## affixes' tiers. An item is a plain Dictionary (saved as JSON by Progress):
##   {"base": id, "rarity": "normal" | "magic" | "rare", "ilvl": int, "affixes": [{"id", "tier", "value"}], "name"}
## Stats are keys added up by Gear.stat() and read through Stats: per cent ones (damage, rate, run, ...) and flat
## ones (life, armour, crit chance in points, ...). Life, armour, evasion, regeneration and resistances only matter
## in the endgame (ENDGAME), where Clawd has hit points; the campaign keeps hearts.

## The equipment slots, in the order the inventory shows them, and the kind of item each takes.
const SLOTS := ["weapon", "helmet", "body", "gloves", "boots", "amulet", "ring1", "ring2"]
const SLOT_KIND := {"weapon": "weapon", "helmet": "helmet", "body": "body", "gloves": "gloves", "boots": "boots",
	"amulet": "amulet", "ring1": "ring", "ring2": "ring"}
## What each kind is called (AI themed).
const KIND_NAME := {"weapon": "WEAPON", "helmet": "CONTEXT WINDOW", "body": "CHASSIS", "gloves": "ACTUATORS",
	"boots": "TREADS", "amulet": "CORE", "ring": "PLUGIN"}
const RARITY_COLOR := {"normal": Color("#E6E6E6"), "magic": Color("#8C9BFF"), "rare": Color("#F2E36B"),
	"unique": Color("#E08A4A")}
## Stats that only count where Clawd has hit points (the hideout and maps).
const ENDGAME := ["life", "armour", "evasion", "regen", "res_fire", "res_cold", "res_lightning"]

## id -> kind, name, size [w, h] in inventory cells, level (the lowest area level it drops in), implicit stats;
## weapons name the weapon they fire (Weapons.WEAPONS) and have a base critical strike chance.
const BASES := {
	# Weapons: the five guns, from the area levels of the worlds where the shop sells them.
	"blaster": {"kind": "weapon", "name": "Token Blaster", "size": [1, 3], "level": 1, "weapon": "blaster", "implicit": {"crit": 5}},
	"spreader": {"kind": "weapon", "name": "Context Spreader", "size": [2, 3], "level": 9, "weapon": "spreader", "implicit": {"crit": 5}},
	"stream": {"kind": "weapon", "name": "Stream Output", "size": [1, 3], "level": 13, "weapon": "stream", "implicit": {"crit": 4}},
	"beam": {"kind": "weapon", "name": "Attention Beam", "size": [2, 3], "level": 19, "weapon": "beam", "implicit": {"crit": 3}},
	"cannon": {"kind": "weapon", "name": "Opus Cannon", "size": [2, 3], "level": 25, "weapon": "cannon", "implicit": {"crit": 7}},
	# Context windows (helmets): armour or evasion, three tiers of base.
	"tin_visor": {"kind": "helmet", "name": "Tin Visor", "size": [2, 2], "level": 1, "implicit": {"armour": 6}},
	"mesh_hood": {"kind": "helmet", "name": "Mesh Hood", "size": [2, 2], "level": 1, "implicit": {"evasion": 8}},
	"iron_context": {"kind": "helmet", "name": "Iron Context", "size": [2, 2], "level": 15, "implicit": {"armour": 18}},
	"phantom_cowl": {"kind": "helmet", "name": "Phantom Cowl", "size": [2, 2], "level": 15, "implicit": {"evasion": 22}},
	"titan_crown": {"kind": "helmet", "name": "Titan Crown", "size": [2, 2], "level": 30, "implicit": {"armour": 34}},
	"ghost_veil": {"kind": "helmet", "name": "Ghost Veil", "size": [2, 2], "level": 30, "implicit": {"evasion": 40}},
	# Chassis (body).
	"scrap_plating": {"kind": "body", "name": "Scrap Plating", "size": [2, 3], "level": 1, "implicit": {"armour": 12}},
	"fibre_weave": {"kind": "body", "name": "Fibre Weave", "size": [2, 3], "level": 1, "implicit": {"evasion": 15}},
	"riveted_chassis": {"kind": "body", "name": "Riveted Chassis", "size": [2, 3], "level": 15, "implicit": {"armour": 35}},
	"carbon_weave": {"kind": "body", "name": "Carbon Weave", "size": [2, 3], "level": 15, "implicit": {"evasion": 42}},
	"titan_chassis": {"kind": "body", "name": "Titan Chassis", "size": [2, 3], "level": 30, "implicit": {"armour": 70}},
	"ghost_weave": {"kind": "body", "name": "Ghost Weave", "size": [2, 3], "level": 30, "implicit": {"evasion": 85}},
	# Actuators (gloves).
	"grip_pads": {"kind": "gloves", "name": "Grip Pads", "size": [2, 2], "level": 1, "implicit": {"armour": 4}},
	"silk_actuators": {"kind": "gloves", "name": "Silk Actuators", "size": [2, 2], "level": 1, "implicit": {"evasion": 5}},
	"servo_gauntlets": {"kind": "gloves", "name": "Servo Gauntlets", "size": [2, 2], "level": 15, "implicit": {"armour": 12}},
	"nimble_actuators": {"kind": "gloves", "name": "Nimble Actuators", "size": [2, 2], "level": 15, "implicit": {"evasion": 14}},
	"titan_fists": {"kind": "gloves", "name": "Titan Fists", "size": [2, 2], "level": 30, "implicit": {"armour": 24}},
	"phase_grips": {"kind": "gloves", "name": "Phase Grips", "size": [2, 2], "level": 30, "implicit": {"evasion": 28}},
	# Treads (boots).
	"rubber_treads": {"kind": "boots", "name": "Rubber Treads", "size": [2, 2], "level": 1, "implicit": {"armour": 4}},
	"felt_treads": {"kind": "boots", "name": "Felt Treads", "size": [2, 2], "level": 1, "implicit": {"evasion": 5}},
	"steel_treads": {"kind": "boots", "name": "Steel Treads", "size": [2, 2], "level": 15, "implicit": {"armour": 12}},
	"glide_treads": {"kind": "boots", "name": "Glide Treads", "size": [2, 2], "level": 15, "implicit": {"evasion": 14}},
	"titan_treads": {"kind": "boots", "name": "Titan Treads", "size": [2, 2], "level": 30, "implicit": {"armour": 24}},
	"phase_treads": {"kind": "boots", "name": "Phase Treads", "size": [2, 2], "level": 30, "implicit": {"evasion": 28}},
	# Cores (amulets).
	"amber_core": {"kind": "amulet", "name": "Amber Core", "size": [1, 1], "level": 1, "implicit": {"damage": 8}},
	"coral_core": {"kind": "amulet", "name": "Coral Core", "size": [1, 1], "level": 1, "implicit": {"life": 15}},
	"jade_core": {"kind": "amulet", "name": "Jade Core", "size": [1, 1], "level": 5, "implicit": {"rate": 6}},
	"onyx_core": {"kind": "amulet", "name": "Onyx Core", "size": [1, 1], "level": 20, "implicit": {"crit_multi": 15}},
	# Plugins (rings).
	"iron_plugin": {"kind": "ring", "name": "Iron Plugin", "size": [1, 1], "level": 1, "implicit": {"damage": 5}},
	"copper_plugin": {"kind": "ring", "name": "Copper Plugin", "size": [1, 1], "level": 1, "implicit": {"tokens": 5}},
	"silver_plugin": {"kind": "ring", "name": "Silver Plugin", "size": [1, 1], "level": 5, "implicit": {"run": 3}},
	"gold_plugin": {"kind": "ring", "name": "Gold Plugin", "size": [1, 1], "level": 10, "implicit": {"rarity": 12}},
}

const WEAPON := ["weapon"]
const ARMOUR := ["helmet", "body", "gloves", "boots"]
const JEWEL := ["amulet", "ring"]
const NOT_WEAPON := ["helmet", "body", "gloves", "boots", "amulet", "ring"]
## id -> prefix or suffix, the stat it adds, the kinds it rolls on, its tiers [item level, min, max] from the
## lowest, the magic item's name part per tier, and its line ("%d" is the value).
const AFFIXES := {
	# Prefixes.
	"local_damage": {"type": "prefix", "stat": "local_damage", "kinds": WEAPON, "text": "+%d%% weapon damage",
		"tiers": [[1, 15, 24], [10, 25, 39], [20, 40, 59], [35, 60, 84], [55, 85, 119], [75, 120, 150]],
		"names": ["Sharpened", "Honed", "Tuned", "Overfit", "Superhuman", "Singular"]},
	"damage": {"type": "prefix", "stat": "damage", "kinds": ["gloves", "amulet", "ring"], "text": "+%d%% damage",
		"tiers": [[1, 4, 7], [12, 8, 12], [26, 13, 18], [45, 19, 25], [70, 26, 32]],
		"names": ["Keen", "Biting", "Vicious", "Brutal", "Merciless"]},
	"life": {"type": "prefix", "stat": "life", "kinds": NOT_WEAPON, "text": "+%d maximum life",
		"tiers": [[1, 5, 10], [8, 11, 20], [18, 21, 35], [30, 36, 55], [50, 56, 80], [75, 81, 110]],
		"names": ["Healthy", "Sturdy", "Robust", "Stout", "Vigorous", "Immortal"]},
	"armour": {"type": "prefix", "stat": "armour", "kinds": ARMOUR, "text": "+%d armour",
		"tiers": [[1, 5, 12], [12, 13, 30], [25, 31, 60], [45, 61, 100], [70, 101, 150]],
		"names": ["Lacquered", "Plated", "Riveted", "Fortified", "Adamant"]},
	"evasion": {"type": "prefix", "stat": "evasion", "kinds": ARMOUR, "text": "+%d evasion",
		"tiers": [[1, 5, 12], [12, 13, 30], [25, 31, 60], [45, 61, 100], [70, 101, 150]],
		"names": ["Agile", "Dancer's", "Elusive", "Phantasm's", "Ghostly"]},
	"heat": {"type": "prefix", "stat": "heat", "kinds": ["weapon", "helmet"], "text": "+%d%% context window",
		"tiers": [[1, 10, 15], [15, 16, 25], [35, 26, 40]], "names": ["Roomy", "Spacious", "Unbounded"]},
	# Suffixes.
	"local_rate": {"type": "suffix", "stat": "local_rate", "kinds": WEAPON, "text": "+%d%% weapon fire rate",
		"tiers": [[1, 5, 8], [12, 9, 12], [25, 13, 16], [45, 17, 21], [70, 22, 27]],
		"names": ["of Skill", "of Ease", "of Mastery", "of Grandmastery", "of Celebration"]},
	"rate": {"type": "suffix", "stat": "rate", "kinds": ["gloves", "amulet", "ring"], "text": "+%d%% fire rate",
		"tiers": [[1, 3, 5], [15, 6, 8], [30, 9, 12], [55, 13, 16]], "names": ["of Haste", "of Speed", "of Alacrity", "of Inference"]},
	"crit": {"type": "suffix", "stat": "crit", "kinds": ["weapon", "amulet", "helmet"], "text": "+%d%% critical strike chance",
		"tiers": [[1, 1, 2], [15, 3, 4], [35, 5, 6], [60, 7, 8]], "names": ["of Needling", "of Stinging", "of Piercing", "of Incision"]},
	"crit_multi": {"type": "suffix", "stat": "crit_multi", "kinds": ["weapon", "amulet", "ring"], "text": "+%d%% critical strike damage",
		"tiers": [[5, 10, 15], [20, 16, 25], [45, 26, 35], [70, 36, 45]], "names": ["of Ire", "of Anger", "of Rage", "of Fury"]},
	"run": {"type": "suffix", "stat": "run", "kinds": ["boots"], "text": "+%d%% run speed",
		"tiers": [[1, 3, 5], [15, 6, 9], [35, 10, 14], [60, 15, 20]], "names": ["of the Runner", "of the Sprinter", "of the Gazelle", "of the Cheetah"]},
	"hover": {"type": "suffix", "stat": "hover", "kinds": ["boots", "body"], "text": "+%d%% hover time",
		"tiers": [[1, 5, 10], [20, 11, 18], [45, 19, 28]], "names": ["of Lift", "of the Glider", "of the Jet"]},
	"rarity": {"type": "suffix", "stat": "rarity", "kinds": ["helmet", "boots", "amulet", "ring"], "text": "+%d%% item rarity",
		"tiers": [[1, 6, 10], [20, 11, 18], [40, 19, 26], [65, 27, 35]], "names": ["of Plunder", "of Raiding", "of Archaeology", "of Excavation"]},
	"tokens": {"type": "suffix", "stat": "tokens", "kinds": ["gloves", "amulet", "ring"], "text": "+%d%% tokens from enemies",
		"tiers": [[1, 4, 7], [20, 8, 12], [45, 13, 18]], "names": ["of Billing", "of Revenue", "of Profit"]},
	"reach": {"type": "suffix", "stat": "reach", "kinds": ["gloves"], "text": "+%d%% hook reach",
		"tiers": [[1, 4, 7], [25, 8, 12], [50, 13, 18]], "names": ["of Grasping", "of Reaching", "of the Long Arm"]},
	"regen": {"type": "suffix", "stat": "regen", "kinds": ["helmet", "body", "amulet"], "text": "+%d life per second",
		"tiers": [[5, 1, 2], [25, 3, 5], [50, 6, 9]], "names": ["of Mending", "of Recovery", "of Renewal"]},
	"res_fire": {"type": "suffix", "stat": "res_fire", "kinds": NOT_WEAPON, "text": "+%d%% overheat resistance",
		"tiers": [[1, 6, 11], [12, 12, 17], [24, 18, 23], [36, 24, 29], [50, 30, 35], [70, 36, 41]],
		"names": ["of the Fan", "of Cooling", "of the Heatsink", "of Coolant", "of Liquid Nitrogen", "of Absolute Zero"]},
	"res_cold": {"type": "suffix", "stat": "res_cold", "kinds": NOT_WEAPON, "text": "+%d%% latency resistance",
		"tiers": [[1, 6, 11], [12, 12, 17], [24, 18, 23], [36, 24, 29], [50, 30, 35], [70, 36, 41]],
		"names": ["of Caching", "of Prefetch", "of Low Ping", "of the Edge", "of Fibre", "of Light Speed"]},
	"res_lightning": {"type": "suffix", "stat": "res_lightning", "kinds": NOT_WEAPON, "text": "+%d%% voltage resistance",
		"tiers": [[1, 6, 11], [12, 12, 17], [24, 18, 23], [36, 24, 29], [50, 30, 35], [70, 36, 41]],
		"names": ["of Grounding", "of the Fuse", "of Insulation", "of the Breaker", "of Faraday", "of the Void"]},
}
## How each implicit stat reads (the same words as the affixes).
const STAT_TEXT := {"crit": "+%d%% critical strike chance", "armour": "+%d armour", "evasion": "+%d evasion",
	"damage": "+%d%% damage", "life": "+%d maximum life", "rate": "+%d%% fire rate", "crit_multi": "+%d%% critical strike damage",
	"tokens": "+%d%% tokens from enemies", "run": "+%d%% run speed", "rarity": "+%d%% item rarity"}
## Rare names: one word of each.
const RARE_FIRST := ["Hollow", "Latent", "Sparse", "Dense", "Frozen", "Quantized", "Stochastic", "Recursive", "Feral",
	"Silent", "Broken", "Gilded", "Vanishing", "Exploding", "Greedy", "Attentive", "Residual", "Masked"]
const RARE_SECOND := {"weapon": ["Gradient", "Sampler", "Decoder", "Kernel", "Argmax"], "helmet": ["Visor", "Crown", "Mask", "Halo"],
	"body": ["Shell", "Carapace", "Frame", "Hull"], "gloves": ["Grasp", "Touch", "Hands", "Claws"],
	"boots": ["Stride", "Tread", "Path", "Steps"], "amulet": ["Heart", "Core", "Engine", "Seed"],
	"ring": ["Loop", "Hook", "Token", "Circuit"]}
## Chances of a dropped item being magic or rare (normal otherwise), raised by item rarity.
const MAGIC_CHANCE := 0.3
const RARE_CHANCE := 0.06
## Affixes on a rare item: 3 to 6, these weights.
const RARE_COUNT := {3: 35, 4: 35, 5: 20, 6: 10}


## A new random item of item level `ilvl`. `rarity` "" rolls it (more magic and rare with `rarity_bonus` %);
## `base` "" picks a base that drops at that level (every kind as likely, then a base of it).
static func roll(ilvl: int, rng: RandomNumberGenerator, rarity := "", base := "", rarity_bonus := 0.0) -> Dictionary:
	if base == "":
		var kinds := {}
		for id in BASES:
			if BASES[id].level <= ilvl:
				kinds[BASES[id].kind] = kinds.get(BASES[id].kind, []) + [id]
		var kind: String = kinds.keys()[rng.randi() % kinds.size()]
		base = kinds[kind][rng.randi() % kinds[kind].size()]
	if rarity == "":
		var r := rng.randf()
		var k := 1.0 + rarity_bonus / 100.0
		rarity = "rare" if r < RARE_CHANCE * k else "magic" if r < (RARE_CHANCE + MAGIC_CHANCE) * k else "normal"
	var item := {"base": base, "rarity": rarity, "ilvl": ilvl, "affixes": []}
	var count := 0
	if rarity == "magic":
		count = 1 + rng.randi() % 2
	elif rarity == "rare":
		count = _weighted(RARE_COUNT, rng)
	for i in count:
		add_affix(item, rng)
	if rarity == "rare":
		var kind: String = BASES[base].kind
		item.name = RARE_FIRST[rng.randi() % RARE_FIRST.size()] + " " + RARE_SECOND[kind][rng.randi() % RARE_SECOND[kind].size()]
	return item


## Adds one more affix that fits (a free prefix or suffix slot, one the item does not have, a tier its level
## allows). Returns false when none fits.
static func add_affix(item: Dictionary, rng: RandomNumberGenerator) -> bool:
	var kind: String = BASES[item.base].kind
	var room := {"prefix": max_affixes(item) - count_type(item, "prefix"), "suffix": max_affixes(item) - count_type(item, "suffix")}
	var have: Array = item.affixes.map(func(a): return a.id)
	var pool := []
	for id in AFFIXES:
		var a: Dictionary = AFFIXES[id]
		if kind in a.kinds and room[a.type] > 0 and not have.has(id) and a.tiers[0][0] <= item.ilvl:
			pool.append(id)
	if pool.is_empty():
		return false
	var id: String = pool[rng.randi() % pool.size()]
	var tiers: Array = AFFIXES[id].tiers.filter(func(t): return t[0] <= item.ilvl)
	# Higher tiers are rarer: weights n, n - 1, ..., 1 from the lowest.
	var weights := {}
	for i in tiers.size():
		weights[i] = tiers.size() - i
	var tier := _weighted(weights, rng)
	item.affixes.append({"id": id, "tier": tier, "value": rng.randi_range(tiers[tier][1], tiers[tier][2])})
	return true


static func max_affixes(item: Dictionary) -> int:
	return 1 if item.rarity == "magic" else 3 if item.rarity == "rare" else 0


static func count_type(item: Dictionary, type: String) -> int:
	return item.affixes.filter(func(a): return AFFIXES[a.id].type == type).size()


## What `item` adds to `stat`: its base's implicit and its affixes.
static func stat(item: Dictionary, key: String) -> float:
	var n := float(BASES[item.base].get("implicit", {}).get(key, 0))
	for a in item.affixes:
		if AFFIXES[a.id].stat == key:
			n += a.value
	return n


static func kind(item: Dictionary) -> String:
	return BASES[item.base].kind


static func size(item: Dictionary) -> Vector2i:
	var s: Array = BASES[item.base].size
	return Vector2i(s[0], s[1])


## The item's name: a rare's own, a magic one's prefix and suffix around the base, else the base's.
static func name_of(item: Dictionary) -> String:
	var base: String = BASES[item.base].name
	if item.rarity == "rare" and item.has("name"):
		return item.name
	if item.rarity == "magic":
		var out := base
		for a in item.affixes:
			var def: Dictionary = AFFIXES[a.id]
			var part: String = def.names[mini(int(a.tier), def.names.size() - 1)]
			out = part + " " + out if def.type == "prefix" else out + " " + part
		return out
	return base


## Its lines for a tooltip: [text, endgame-only] for the implicit stats, then the affixes, prefixes first.
static func lines(item: Dictionary) -> Array:
	var out := []
	var imp: Dictionary = BASES[item.base].get("implicit", {})
	for k in imp:
		out.append([STAT_TEXT.get(k, "+%d " + k) % imp[k], k in ENDGAME, true])
	var sorted: Array = item.affixes.duplicate()
	sorted.sort_custom(func(a, b): return AFFIXES[a.id].type == "prefix" and AFFIXES[b.id].type == "suffix")
	for a in sorted:
		var def: Dictionary = AFFIXES[a.id]
		out.append([def.text % a.value, def.stat in ENDGAME, false])
	return out


static func color(item: Dictionary) -> Color:
	return RARITY_COLOR.get(item.rarity, Color.WHITE)


static func _weighted(weights: Dictionary, rng: RandomNumberGenerator) -> int:
	var total := 0
	for k in weights:
		total += weights[k]
	var r := rng.randi() % total
	for k in weights:
		r -= weights[k]
		if r < 0:
			return k
	return weights.keys()[0]
