extends Node

## Autoload "Progress": the player's progress, like the level part of SaveData in src/save.ts. Per level id:
## completed, which sparks were found and which sub-agents rescued, and the best time; plus the wallet of tokens
## banked from finished levels. Saved as JSON in user://progress.json. A level is unlocked when it is the first
## one or the one before it was completed (App.isUnlocked() in src/app.ts).
## The shop's state lives here too (the rest of SaveData): upgrade levels, sparks spent, the stock of
## consumables, which hidden things HAIKU has already told about, and the last fortune.

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
## World 3's tools owned: "hook" (the Tool Call, dropped by Codex).
var tools: Array = []


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
		# Codex beaten before it dropped the Tool Call (saves from before world 3): the hook is Clawd's.
		if progress_for("2-B").completed and not tools.has("hook"):
			tools.append("hook")


func save() -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"levels": levels, "wallet": wallet, "upgrades": upgrades, "sparks_spent": sparks_spent,
			"stock": stock, "hinted": hinted, "fortune": fortune, "weapons": weapons, "equipped": equipped, "tools": tools}))


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


## sparksAvailable(): found sparks not spent yet.
func sparks_available() -> int:
	return total_sparks() - sparks_spent


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
