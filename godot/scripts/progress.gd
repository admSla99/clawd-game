extends Node

## Autoload "Progress": the player's progress, like the level part of SaveData in src/save.ts. Per level id:
## completed, which sub-agents were rescued and the best time; plus the wallet of tokens banked from finished
## levels. Saved as JSON in user://progress.json. A level is unlocked when it is the first one or the one before
## it was completed (App.isUnlocked() in src/app.ts).

## Where it is saved (tools/check.gd points this elsewhere so it never touches the player's file).
var path := "user://progress.json"
## id -> {completed: bool, agents: Array[bool], best_time: float or null}
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
	return levels.get(id, {"completed": false, "agents": [], "best_time": null})


## recordRun(): merges a finished run (rescued sub-agents are never lost, the best time is kept) and banks its
## tokens.
func record_run(id: String, agents: Array, time: float, tokens: int) -> void:
	var prev := progress_for(id)
	var old: Array = prev.agents
	var merged := []
	for i in maxi(old.size(), agents.size()):
		merged.append((i < old.size() and old[i]) or (i < agents.size() and agents[i]))
	levels[id] = {
		"completed": true,
		"agents": merged,
		"best_time": time if prev.best_time == null else minf(prev.best_time, time),
	}
	wallet += tokens
	save()


func is_unlocked(ids: Array, index: int) -> bool:
	return index == 0 or progress_for(ids[index - 1]).completed


static func count(arr: Array) -> int:
	return arr.filter(func(b): return b).size()


## formatTime() in src/scenes/levelSelect.ts: m:ss.cc
static func format_time(t: float) -> String:
	return "%d:%02d.%02d" % [floori(t / 60), floori(fmod(t, 60)), floori(fmod(t * 100, 100))]
