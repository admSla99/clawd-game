extends Node

## Autoload "Progress": the player's progress, like the level part of SaveData in src/save.ts. Per level id:
## completed, which sparks were found and which sub-agents rescued, and the best time; plus the wallet of tokens
## banked from finished levels. Saved as JSON in user://progress.json. A level is unlocked when it is the first
## one or the one before it was completed (App.isUnlocked() in src/app.ts).

## Where it is saved (tools/check.gd points this elsewhere so it never touches the player's file).
var path := "user://progress.json"
## id -> {completed: bool, sparks: Array[bool], agents: Array[bool], best_time: float or null}
var levels := {}
var wallet := 0


func _ready() -> void:
	load_file()


func load_file() -> void:
	levels = {}
	wallet = 0
	if not FileAccess.file_exists(path):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is Dictionary:
		levels = data.get("levels", {})
		wallet = int(data.get("wallet", 0))


func save() -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"levels": levels, "wallet": wallet}))


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


func is_unlocked(ids: Array, index: int) -> bool:
	return index == 0 or progress_for(ids[index - 1]).completed


static func count(arr: Array) -> int:
	return arr.filter(func(b): return b).size()


## formatTime() in src/scenes/levelSelect.ts: m:ss.cc
static func format_time(t: float) -> String:
	return "%d:%02d.%02d" % [floori(t / 60), floori(fmod(t, 60)), floori(fmod(t * 100, 100))]
