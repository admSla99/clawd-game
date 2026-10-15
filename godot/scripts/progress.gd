extends Node

## Autoload "Progress": the player's progress, like the level part of SaveData in src/save.ts. Per level id:
## completed, which sparks were found and which sub-agents rescued, and the best time; plus the wallet of tokens
## banked from finished levels. Saved as JSON in user://progress.json. A level is unlocked when it is the first
## one or the one before it was completed (App.isUnlocked() in src/app.ts).
## The shop's state lives here too (the rest of SaveData): upgrade levels, sparks spent, the stock of
## consumables, which hidden things HAIKU has already told about, and the last fortune; and the prompt tree's.

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


func save() -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"levels": levels, "wallet": wallet, "upgrades": upgrades, "sparks_spent": sparks_spent,
			"stock": stock, "hinted": hinted, "fortune": fortune, "weapons": weapons, "equipped": equipped, "tools": tools,
			"tree": tree, "points_bought": points_bought}))


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
	save()


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
	equipped = id
	save()


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
