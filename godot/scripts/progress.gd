extends Node

## Autoload "Progress": the player's progress, like the level part of SaveData in src/save.ts. Per level id:
## completed, which sparks were found and which sub-agents rescued, and the best time; plus the wallet of tokens
## banked from finished levels. Saved as JSON in user://progress.json. A level is unlocked when it is the first
## one or the one before it was completed (App.isUnlocked() in src/app.ts).
## The shop's state lives here too (the rest of SaveData): upgrade levels, sparks spent, the stock of
## consumables, which hidden things HAIKU has already told about, and the last fortune; and the prompt tree's,
## and Clawd's character level (scripts/experience.gd). Items (the equipped gear and the inventory) are saved to a
## file of their own next to it (items_path(), save_items()).

## Where it is saved (tools/check.gd points this elsewhere so it never touches the player's file).
var path := "user://progress.json"
## id -> {completed: bool, sparks: Array[bool], agents: Array[bool], best_time: float or null}
var levels := {}
var wallet := 0
## Upgrade id -> level bought (save.upgrades).
var upgrades := {}
## Sparks spent in the shop (save.sparksSpent).
var sparks_spent := 0
## Consumable id -> how many are in stock.
var stock := {}
## Hidden things HAIKU has already hinted at ("<level id>:<S or A>:<index>").
var hinted: Array = []
## The last fortune's three lines.
var fortune: Array = []
## Weapon ids owned, in the order found (save.weapons), and the one in Clawd's hands (save.equipped).
var weapons: Array = []
var equipped := ""
## World 3's tools owned: "hook" (the Tool Call, dropped by Codex), "agents" (sending sub-agents, from clearing 3-1).
var tools: Array = []
## The prompt tree (scripts/prompts.gd): the allocated nodes and the points bought with tokens.
var tree: Array = []
var points_bought := 0
## Clawd's character level and the XP gathered toward the next one (scripts/experience.gd).
var char_level := 1
var xp := 0
## Items (scripts/items.gd): slot -> the item equipped there (Gear), the items carried and the stash's (grids).
var gear := {}
var inventory: Array = []
var stash: Array = []
## The hideout vendor's stock (Vendor) and the number of runs it was stocked at.
var vendor: Array = []
var vendor_at := -1
## Levels cleared, all runs counted (the vendor restocks after each).
var runs := 0
## Maps completed per tier ("1" -> count), the Atlas's nodes allocated (scripts/atlas.gd) and the worlds whose
## rare map was completed (an Atlas point each).
var maps_done := {}
var atlas: Array = []
var atlas_bonus: Array = []
## The map lying in the Map Device (0 or 1 items, a 1 x 1 grid).
var device: Array = []
## Currency orbs (scripts/currency.gd): id -> count.
var currency := {}
## The weapons found before items existed were given as normal items into the stash (once).
var weapon_items := false
## What world 3's first System Prompts cost (bought once each, for tokens and sparks), and Longer System Prompt's
## levels: refunded when an old save is loaded (they became the prompt tree).
const OLD_PROMPTS := {"concise": [120, 1], "cite": [150, 1], "temperature": [120, 1], "steps": [160, 1],
	"ontask": [200, 2], "delegate": [220, 2], "expert": [260, 2], "reflect": [240, 1]}
const OLD_SYSPROMPT := [[150, 3], [350, 6]]


func _ready() -> void:
	load_file()


func load_file() -> void:
	levels = {}
	wallet = 0
	upgrades = {}
	sparks_spent = 0
	stock = {}
	hinted = []
	fortune = []
	weapons = []
	equipped = ""
	tools = []
	tree = []
	points_bought = 0
	char_level = 1
	xp = 0
	runs = 0
	maps_done = {}
	atlas = []
	atlas_bonus = []
	_load_items()
	if not FileAccess.file_exists(path):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is Dictionary:
		levels = data.get("levels", {})
		wallet = int(data.get("wallet", 0))
		upgrades = data.get("upgrades", {})
		sparks_spent = int(data.get("sparks_spent", 0))
		stock = data.get("stock", {})
		hinted = data.get("hinted", [])
		fortune = data.get("fortune", [])
		weapons = data.get("weapons", [])
		equipped = data.get("equipped", "")
		tools = data.get("tools", [])
		tree = data.get("tree", [])
		points_bought = int(data.get("points_bought", 0))
		char_level = clampi(int(data.get("char_level", 1)), 1, Experience.MAX_LEVEL)
		xp = maxi(0, int(data.get("xp", 0)))
		runs = int(data.get("runs", 0))
		maps_done = data.get("maps_done", {})
		atlas = data.get("atlas", [])
		atlas_bonus = data.get("atlas_bonus", []).map(func(w): return int(w))
		# World 3's first System Prompts (bought, then switched on within a budget) are refunded.
		for id in data.get("prompts", []):
			if OLD_PROMPTS.has(id):
				wallet += OLD_PROMPTS[id][0]
				sparks_spent -= OLD_PROMPTS[id][1]
		for lv in mini(upgrade("sysprompt"), OLD_SYSPROMPT.size()):
			wallet += OLD_SYSPROMPT[lv][0]
			sparks_spent -= OLD_SYSPROMPT[lv][1]
		var migrated: bool = data.has("prompts") or upgrades.has("sysprompt")
		upgrades.erase("sysprompt")
		sparks_spent = maxi(0, sparks_spent)
		# Saved at once, so the refund is not paid again on the next start.
		if migrated:
			save()
		# Codex beaten before it dropped the Tool Call (saves from before world 3): the hook is Clawd's.
		if progress_for("2-B").completed and not tools.has("hook"):
			tools.append("hook")
		if progress_for("3-1").completed and not tools.has("agents"):
			tools.append("agents")
	# The weapons found before items: a normal item of each into the stash, once.
	if not weapon_items:
		weapon_items = true
		for id in weapons:
			Gear.place(stash, Gear.STASH_SIZE, weapon_item(id))
		save_items()


func save() -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"levels": levels, "wallet": wallet, "upgrades": upgrades, "sparks_spent": sparks_spent,
			"stock": stock, "hinted": hinted, "fortune": fortune, "weapons": weapons, "equipped": equipped, "tools": tools,
			"tree": tree, "points_bought": points_bought, "char_level": char_level, "xp": xp, "runs": runs, "maps_done": maps_done,
			"atlas": atlas, "atlas_bonus": atlas_bonus}))


## Where the items are saved: next to the progress, "<name>_items.json".
func items_path() -> String:
	return path.get_basename() + "_items.json"


func save_items() -> void:
	var f := FileAccess.open(items_path(), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"gear": gear, "inventory": inventory, "stash": stash, "weapon_items": weapon_items,
			"vendor": vendor, "vendor_at": vendor_at, "device": device, "currency": currency}))


func _load_items() -> void:
	gear = {}
	inventory = []
	stash = []
	vendor = []
	vendor_at = -1
	device = []
	currency = {}
	weapon_items = false
	if FileAccess.file_exists(items_path()):
		var data = JSON.parse_string(FileAccess.get_file_as_string(items_path()))
		if data is Dictionary:
			for slot in data.get("gear", {}):
				var it = data.gear[slot]
				if slot in Items.SLOTS and _valid_item(it):
					gear[slot] = it
			inventory = data.get("inventory", []).filter(_valid_item)
			stash = data.get("stash", []).filter(_valid_item)
			weapon_items = data.get("weapon_items", false) == true
			vendor = data.get("vendor", []).filter(_valid_item)
			vendor_at = int(data.get("vendor_at", -1))
			device = data.get("device", []).filter(_valid_item).slice(0, 1)
			for id in data.get("currency", {}):
				if Currency.ORBS.has(id):
					currency[id] = int(data.currency[id])
	# Every item on a spot of its own; what the inventory cannot hold goes to the stash.
	for it in Gear.normalize(inventory, Gear.INV_SIZE):
		Gear.place(stash, Gear.STASH_SIZE, it)
	Gear.normalize(stash, Gear.STASH_SIZE)
	Gear.invalidate()


## JSON reads numbers back as floats: whole numbers again, and items whose base or affixes no longer exist go.
static func _valid_item(it) -> bool:
	if not (it is Dictionary and Items.BASES.has(it.get("base", ""))):
		return false
	it.ilvl = int(it.get("ilvl", 1))
	if it.has("tier"):
		it.tier = int(it.tier)
		it.seed = int(it.get("seed", 0))
	for a in it.get("affixes", []):
		if not (a is Dictionary and Items.AFFIXES.has(a.get("id", ""))):
			return false
		a.tier = int(a.tier)
		a.value = int(a.value)
	return true


## progressFor(): a level's progress, or an empty one.
func progress_for(id: String) -> Dictionary:
	var p: Dictionary = levels.get(id, {}).duplicate()
	p.merge({"completed": false, "sparks": [], "agents": [], "best_time": null})
	return p


## recordRun(): merges a finished run (found sparks and rescued sub-agents are never lost, the best time is
## kept) and banks its tokens.
func record_run(id: String, sparks: Array, agents: Array, time: float, tokens: int) -> void:
	var prev := progress_for(id)
	levels[id] = {
		"completed": true,
		"sparks": _merge(prev.sparks, sparks),
		"agents": _merge(prev.agents, agents),
		"best_time": time if prev.best_time == null else minf(prev.best_time, time),
	}
	wallet += tokens
	runs += 1
	save()


## Adds `n` XP (saved at once); returns how many levels it gained. At the cap XP stays 0.
func add_xp(n: int) -> int:
	if char_level >= Experience.MAX_LEVEL:
		return 0
	var gained := 0
	xp += maxi(n, 0)
	while char_level < Experience.MAX_LEVEL and xp >= Experience.need(char_level):
		xp -= Experience.need(char_level)
		char_level += 1
		gained += 1
	if char_level >= Experience.MAX_LEVEL:
		xp = 0
	save()
	return gained


## Loses `frac` of the current level's XP (a death in a map, later), never below the level's start; returns how
## much was lost.
func lose_xp(frac: float) -> int:
	var lost := mini(xp, roundi(Experience.need(char_level) * frac))
	xp -= lost
	save()
	return lost


static func _merge(a: Array, b: Array) -> Array:
	var out := []
	for i in maxi(a.size(), b.size()):
		out.append((i < a.size() and a[i]) or (i < b.size() and b[i]))
	return out


## totalSparks(): sparks found over all levels.
func total_sparks() -> int:
	var n := 0
	for id in levels:
		n += count(progress_for(id).sparks)
	return n


## Sparks found in world 3 and later: points in the prompt tree, not spent in the shop.
func tree_sparks() -> int:
	var n := 0
	for id in levels:
		if world_of(id) >= 3:
			n += count(progress_for(id).sparks)
	return n


static func world_of(id: String) -> int:
	return int(id.get_slice("-", 0))


## Sub-agents rescued in every level.
func total_agents() -> int:
	var n := 0
	for id in levels:
		n += count(progress_for(id).agents)
	return n


## sparksAvailable(): sparks found in worlds 1 and 2 not spent in the shop yet (world 3's are tree points).
func sparks_available() -> int:
	return total_sparks() - tree_sparks() - sparks_spent


## upgradeLevel()
func upgrade(id: String) -> int:
	return int(upgrades.get(id, 0))


func in_stock(id: String) -> int:
	return int(stock.get(id, 0))


## Takes one of a consumable out of stock (it was used).
func use_stock(id: String) -> void:
	stock[id] = maxi(0, in_stock(id) - 1)
	save()


## grantWeapon() in src/weapons.ts: owns `id` from now on and holds it (saved).
func grant_weapon(id: String) -> void:
	if not weapons.has(id):
		weapons.append(id)
		# And a normal item of it into the stash (docs/endgame-plan.md: the weapons are item bases).
		Gear.place(stash, Gear.STASH_SIZE, weapon_item(id))
		save_items()
	equipped = id
	save()


## A normal item of weapon `id`.
static func weapon_item(id: String) -> Dictionary:
	return {"base": id, "rarity": "normal", "ilvl": 1, "affixes": []}


## Owns world 3's tool `id` from now on (saved).
func grant_tool(id: String) -> void:
	if not tools.has(id):
		tools.append(id)
	save()


func has_tool(id: String) -> bool:
	return tools.has(id)


func is_unlocked(ids: Array, index: int) -> bool:
	return index == 0 or progress_for(ids[index - 1]).completed


static func count(arr: Array) -> int:
	return arr.filter(func(b): return b).size()


## formatTime() in src/scenes/levelSelect.ts: m:ss.cc
static func format_time(t: float) -> String:
	return "%d:%02d.%02d" % [floori(t / 60), floori(fmod(t, 60)), floori(fmod(t * 100, 100))]
