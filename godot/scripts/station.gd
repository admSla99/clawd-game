class_name Station
extends Node3D

## A station in the hideout (docs/endgame-plan.md E4): something Clawd uses by standing at it and pressing the
## `pickup` action (E). `kind`: "stash" (a vault crate: the inventory with the stash), "vendor" (a merchant bot:
## buys and sells items, Vendor), "terminal" (the prompt tree), "device" (the Map Device; maps come in E5), "portal"
## (back to the world map). Main finds the one in reach (station_target) and uses it (use_station()); LootView
## draws its prompt. Voxel art at 2 px a cell (CELL), behind the gameplay plane like a checkpoint, with a GlowLight.

## How close Clawd's middle has to be (px), horizontally.
const REACH := 26.0
## Px per art cell.
const CELL := 2
const Z := -0.6
const TITLES := {"stash": "STASH", "vendor": "VENDOR", "terminal": "PROMPT TREE", "device": "MAP DEVICE", "portal": "WORLD MAP"}
const ART := {
	"stash": [
		"..oooooooooooooo..",
		".oLLLLLLLLLLLLLLo.",
		"oLLLLLLLLLLLLLLLLo",
		"ommmmmmmmmmmmmmmmo",
		"oddddddd##dddddddo",
		"oddddddd#Wdddddddo",
		"oddddddd##dddddddo",
		"oddddddddddddddddo",
		"ommmmmmmmmmmmmmmmo",
		"oddddddddddddddddo",
		".oooooooooooooooo.",
	],
	"vendor": [
		"....oooooo....",
		"...oSSSSSSo...",
		"...oSeSSeSo...",
		"...oSSSSSSo...",
		"...oSSmmSSo...",
		"....oooooo....",
		".....oggo.....",
		"..oooooooooo..",
		".oBBBBBBBBBBo.",
		"oBBBBBBBBBBBBo",
		"oBBBYYYYYBBBBo",
		"oBBBYooYYBBBBo",
		"oBBBYYYYYBBBBo",
		".oBBBBBBBBBBo.",
		"..oB......Bo..",
		"..oo......oo..",
	],
	"terminal": [
		"oooooooooooooo",
		"oSSSSSSSSSSSSo",
		"oSTTSSSSSSSSSo",
		"oSSSTTSSSSSSSo",
		"oSSSSSTTTSSSSo",
		"oSSSSSSSSSSSSo",
		"oooooooooooooo",
		"......gg......",
		"....gggggg....",
		"oooooooooooooo",
		"oDDDDDDDDDDDDo",
		".oD........Do.",
		".oD........Do.",
		".oo........oo.",
	],
	"portal": [
		"....oooooooo....",
		"..ooLLLLLLLLoo..",
		".oLLssssssssLLo.",
		".oLssccccccssLo.",
		"oLssc......cssLo",
		"oLsc..cccc..csLo",
		"oLsc.c....c.csLo",
		"oLsc.c.cc.c.csLo",
		"oLsc.c.cc.c.csLo",
		"oLsc.c....c.csLo",
		"oLsc..cccc..csLo",
		"oLssc......cssLo",
		"oLsssccccccsssLo",
		"oLssssssssssssLo",
		"oLssssssssssssLo",
		"oLssssssssssssLo",
		"oLssssssssssssLo",
		"oLLLLLLLLLLLLLLo",
		"oooooooooooooooo",
	],
}
const PALETTE := {
	"o": Color("#2A1E1A"), "L": Color("#D97757"), "m": Color("#8A8A8A"), "d": Color("#5A3A2C"), "#": Color("#CFCFCF"),
	"W": Color("#FFE0A0"), "S": Color("#1E3A3E"), "e": Color("#7FE3EA"), "g": Color("#6A6A70"), "B": Color("#5E5E6E"),
	"Y": Color("#F0A585"), "T": Color("#D97757"), "D": Color("#4A3428"), "s": Color("#1E5A66"), "c": Color("#7FE3EA"),
	"r": Color("#F2D27A"), "k": Color("#3A3A44"),
}
const DEPTH := {"o": 8, "L": 8, "m": 8, "d": 8, "#": 10, "W": 10, "S": 6, "e": 8, "g": 6, "B": 10, "Y": 12, "T": 8,
	"D": 10, "s": 2, "c": 4, "r": 10, "k": 10}

static var _meshes := {}

@export var kind := "stash"
var t := randf() * 10
var _glow: GlowLight


## The Map Device: a stone arch on a plinth, a ring of runes inside (dark until maps power it, E5).
static func device_rows() -> Array:
	var w := 26
	var h := 30
	var rows := []
	for y in h:
		var row := ""
		for x in w:
			var dx := x - (w - 1) / 2.0
			var dy := y - 11.0
			var ch := "."
			var r := sqrt(dx * dx + dy * dy)
			if y >= 26:
				ch = "o" if y == h - 1 or x == 0 or x == w - 1 else "k"
			elif y >= 11 and (x <= 2 or x >= w - 3):
				ch = "o" if x == 0 or x == w - 1 else "k"
			elif y < 11 and r >= 10.0 and r < 13.0:
				ch = "o" if r >= 12.2 else "k"
			elif r >= 7.0 and r < 8.0 and y < 24:
				ch = "r" if (x + y) % 3 == 0 else "c"
			row += ch
		rows.append(row)
	return rows


static func mesh_for(k: String) -> ArrayMesh:
	if not _meshes.has(k):
		var rows: Array = device_rows() if k == "device" else ART[k]
		_meshes[k] = Voxel.mesh(rows, PALETTE, DEPTH, CELL * Px.M)
	return _meshes[k]


func _ready() -> void:
	add_to_group("stations")
	var m := MeshInstance3D.new()
	m.mesh = mesh_for(kind)
	m.position.z = Z
	add_child(m)
	_glow = GlowLight.new()
	_glow.radius = 2.4 if kind == "device" else 1.8
	_glow.energy = 0.8
	_glow.position = Vector3(0, 24 * Px.M, Z + 0.6)
	add_child(_glow)


func _physics_process(dt: float) -> void:
	t += dt
	_glow.energy = 0.7 + 0.15 * sin(t * 2.0)


## Level pixels of the feet.
func feet() -> Vector2:
	return Px.of(position)


func title() -> String:
	return TITLES.get(kind, kind.to_upper())


## The art's height in px (the prompt goes above it).
func height() -> int:
	return (device_rows() if kind == "device" else ART[kind]).size() * CELL


func in_reach(player: Player) -> bool:
	return absf(feet().x - player.pos.x) < REACH + (16.0 if kind == "device" else 0.0) and absf(feet().y - player.pos.y) < 20
