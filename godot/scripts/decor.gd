class_name Decor
extends Node3D

## Props on the level, placed from the level's terrainSeed when it loads, as 1 px voxels (Voxel.mesh)
## without collision:
## - on exposed tops: lanterns that light the terrain (a GlowLight each), tufts in the theme's light colour
##   that sway and bend away from Clawd as he walks through (interact()), and neuron flowers, a stalk with
##   a glowing bulb and its own small GlowLight (more in dark levels);
## - under ceilings and one-way platforms: data vines that hang and sway, ending in a glowing node now and
##   then, and short dark drips.
## Lanterns and most flowers stand at the back of the top band, behind Clawd; some tufts, vines and
## flowers are in front of the gameplay plane for depth. Sway runs in shaders/voxel.gdshader.

const LANTERN := [
	"...fff...",
	"..fffff..",
	".f.....f.",
	".f.....f.",
	".f.....f.",
	".f.....f.",
	".f.....f.",
	"..fffff..",
	"...fpf...",
	"....p....",
	"....p....",
	"....p....",
	"....p....",
	"....p....",
	"....p....",
	"....p....",
	"....p....",
	"....p....",
	"....p....",
	"....p....",
	"....p....",
	"....p....",
	"....p....",
	"...ppp...",
	"..ppppp..",
]
## The lamp inside LANTERN's frame, on the same grid; a separate mesh so only it glows.
const LAMP := [
	".........",
	".........",
	"..LLLLL..",
	"..LWWWL..",
	"..LWWWL..",
	"..LWWWL..",
	"..LLLLL..",
]
const TUFTS := [
	["G..G", ".gg.", "gggg"],
	[".G..", "gG.G", "gggg"],
	["..G.", "G.g.", "gggg"],
	["G...", "g.G.", "ggg."],
]
## Lamp centre above the lantern's feet, in pixels.
const LAMP_Y := 20.5
## Fewest tiles between two lanterns.
const LANTERN_GAP := 7
## How far (px) Clawd pushes tufts aside, and by how many px at most.
const BEND_REACH := 12.0
const BEND_PX := 3.0

## Tufts for interact(): {mesh: MeshInstance3D, x: px, y: ground px, bend: current px}, sorted by x.
var _tufts: Array[Dictionary] = []

static var LANTERN_MESH := Voxel.mesh(LANTERN, {"f": Color8(66, 62, 70), "p": Color8(42, 40, 46)}, {"f": 6, "p": 2}, Px.M)
static var LAMP_MESH := Voxel.mesh(LAMP + _empty_rows(LANTERN.size() - LAMP.size(), 9), {"L": Color8(232, 120, 72), "W": Color8(255, 200, 140)}, {"L": 4, "W": 4}, Px.M, Voxel.material(1.6))


static func _empty_rows(n: int, w: int) -> Array:
	var rows := []
	for i in n:
		rows.append(".".repeat(w))
	return rows


## Adds a Decor child with the props for `level`.
static func populate(level: Level, seed: int, palette: Dictionary, dark := false) -> void:
	var decor := Decor.new()
	decor.name = "Decor"
	level.add_child(decor)
	var light: Color = palette.light
	var tuft_meshes := TUFTS.map(func(rows: Array) -> ArrayMesh:
		return Voxel.mesh(rows, {"g": light * 0.45, "G": light * 0.8}, {}, Px.M))
	var tops := []
	var bottoms := []
	for map: GridMap in [level.terrain, level.oneway]:
		for c: Vector3i in map.get_used_cells():
			var tx := c.x
			var ty := -c.y - 1
			var item := map.get_cell_item(c)
			if item == Level.SOLID and level.tile(Vector2(tx * 16 + 8, ty * 16 - 8)) < 0:
				tops.append(Vector2i(tx, ty))
			if item in [Level.SOLID, Level.ONEWAY] and level.tile(Vector2(tx * 16 + 8, ty * 16 + 24)) < 0:
				bottoms.append(Vector3i(tx, ty, item))
	tops.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	var last_lantern := -LANTERN_GAP
	for t: Vector2i in tops:
		var top := Vector3(t.x + 0.5, -t.y, 0)
		if t.x - last_lantern >= LANTERN_GAP and DotNoise.hash2(t.x, t.y, seed + 41) > 0.82 \
				and level.tile(Vector2(t.x * 16 + 8, t.y * 16 - 24)) < 0:
			last_lantern = t.x
			decor._lantern(top + Vector3(0, 0, -1.0))
		for k in 3:
			if DotNoise.hash2(t.x, t.y * 3 + k, seed + 42) < 0.7:
				continue
			var x := t.x + (1 + floorf(DotNoise.hash2(t.x, t.y * 3 + k, seed + 43) * 13)) / 16.0
			# Front lip or the back of the band.
			var z := 1.3 if k == 0 else -0.4 - DotNoise.hash2(t.x, k, seed + 44) * 0.9
			var mi := MeshInstance3D.new()
			mi.mesh = tuft_meshes[floori(DotNoise.hash2(t.x, t.y + k, seed + 45) * tuft_meshes.size())]
			mi.position = Vector3(x, top.y, z)
			mi.set_instance_shader_parameter("sway", Vector4(0.6, DotNoise.hash2(t.x, k, seed + 47), 3 * Px.M, 0))
			decor.add_child(mi)
			decor._tufts.append({"mesh": mi, "x": x * 16, "y": t.y * 16, "bend": 0.0})
		# Neuron flowers, more of them in dark levels.
		if DotNoise.hash2(t.x, t.y, seed + 48) > (0.84 if dark else 0.91):
			var x := t.x + (3 + floorf(DotNoise.hash2(t.x, t.y, seed + 49) * 10)) / 16.0
			var front := DotNoise.hash2(t.x, t.y, seed + 50) > 0.75
			decor._flower(Vector3(x, top.y, 1.25 if front else -0.5 - DotNoise.hash2(t.x, t.y, seed + 51) * 0.8), light, seed + t.x * 31 + t.y)
	decor._tufts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.x < b.x)
	# Under ceilings and one-way platforms: vines and drips.
	for b: Vector3i in bottoms:
		var r := DotNoise.hash2(b.x, b.y, seed + 60)
		var x := b.x + (2 + floorf(DotNoise.hash2(b.x, b.y, seed + 61) * 12)) / 16.0
		var ceiling := -(b.y + 1) + (0.75 if b.z == Level.ONEWAY else 0.0)
		var front := DotNoise.hash2(b.x, b.y, seed + 62) > 0.6
		var z := (0.3 if b.z == Level.ONEWAY else 1.25) if front else -0.4 - DotNoise.hash2(b.x, b.y, seed + 63) * 0.9
		if r > 0.62:
			decor._vine(Vector3(x, ceiling, z), light, seed + b.x * 17 + b.y)
		elif r > 0.45 and b.z == Level.SOLID:
			decor._drip(Vector3(x, ceiling, z), light, seed + b.x * 13 + b.y)


## Bends the tufts near Clawd's feet (`feet`, level pixels) away from him, and lets the rest spring back.
func interact(feet: Vector2, dt: float) -> void:
	var lo := _tufts.bsearch_custom({"x": feet.x - BEND_REACH * 3}, func(a: Dictionary, b: Dictionary) -> bool: return a.x < b.x)
	for i in range(lo, _tufts.size()):
		var t: Dictionary = _tufts[i]
		if t.x > feet.x + BEND_REACH * 3:
			break
		var dx: float = t.x - feet.x
		var near: bool = absf(dx) < BEND_REACH and absf(t.y - feet.y) < 6
		var target := signf(dx) * BEND_PX * (1.0 - absf(dx) / BEND_REACH) if near else 0.0
		t.bend = move_toward(t.bend, target, dt * (40.0 if near else 14.0))
		t.mesh.set_instance_shader_parameter("bend", t.bend)


## A vine hanging from `at` (its top): a 1 px data cable that wanders by a pixel now and then, with
## leaves and, on some, a glowing node at the end. Sways from the top.
func _vine(at: Vector3, light: Color, seed: int) -> void:
	var length := 6 + floori(DotNoise.hash2(seed, 1, 5) * 22)
	var rows := []
	var x := 2
	for y in length:
		if y > 0 and DotNoise.hash2(seed, y, 6) > 0.8:
			x = clampi(x + (1 if DotNoise.hash2(seed, y, 7) > 0.5 else -1), 1, 3)
		var row := [".", ".", ".", ".", "."]
		row[x] = "c"
		if y > 2 and DotNoise.hash2(seed, y, 8) > 0.78:
			row[x + (1 if DotNoise.hash2(seed, y, 9) > 0.5 else -1)] = "l"
		rows.append("".join(PackedStringArray(row)))
	var glow := DotNoise.hash2(seed, 2, 5) > 0.55
	if glow:
		rows.append(".".repeat(x) + "n" + ".".repeat(4 - x))
	var mi := MeshInstance3D.new()
	mi.mesh = Voxel.mesh(rows, {"c": light * 0.5, "l": light * 0.8, "n": light.lerp(Color.WHITE, 0.4) * 1.8}, {}, Px.M)
	var h := rows.size() * Px.M
	mi.position = at - Vector3(0, h, 0)
	mi.set_instance_shader_parameter("sway", Vector4(1.2, DotNoise.hash2(seed, 3, 5), h, 1))
	add_child(mi)


## A short dark drip under a ceiling, sometimes with a glowing drop at its tip.
func _drip(at: Vector3, light: Color, seed: int) -> void:
	var rows := ["rrrr", "rrr.", ".rr.", ".r.."]
	if DotNoise.hash2(seed, 1, 5) > 0.5:
		rows = ["rrr", "rr.", ".r.", ".r.", ".d."]
	var mi := MeshInstance3D.new()
	mi.mesh = Voxel.mesh(rows, {"r": Color8(34, 33, 40), "d": light.lerp(Color.WHITE, 0.3) * 1.6}, {"r": 4}, Px.M)
	mi.position = at - Vector3(0, rows.size() * Px.M, 0)
	add_child(mi)


## A neuron flower standing at `at`: a stalk with a leaf and a glowing bulb that lights the terrain.
func _flower(at: Vector3, light: Color, seed: int) -> void:
	var stalk := 5 + floori(DotNoise.hash2(seed, 1, 4) * 8)
	var rows := [".BBB.", "BBWBB", ".BBB."]
	for y in stalk:
		var leaf := y == stalk / 2
		rows.append(".lk.." if leaf and DotNoise.hash2(seed, 2, 4) > 0.5 else "..kl." if leaf else "..k..")
	var mi := MeshInstance3D.new()
	mi.mesh = Voxel.mesh(rows, {"k": light * 0.3, "l": light * 0.5, "B": light * 1.7, "W": Color.WHITE * 1.9}, {"B": 4, "W": 4}, Px.M)
	mi.position = at
	var h := rows.size() * Px.M
	mi.set_instance_shader_parameter("sway", Vector4(0.8, DotNoise.hash2(seed, 3, 4), h, 0))
	add_child(mi)
	var glow := GlowLight.new()
	glow.radius = 1.6
	glow.energy = 0.6
	glow.position = at + Vector3(0, h - 1.5 * Px.M, 0.3)
	add_child(glow)


func _lantern(at: Vector3) -> void:
	for m in [LANTERN_MESH, LAMP_MESH]:
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.position = at
		add_child(mi)
	var glow := GlowLight.new()
	glow.radius = 3.5
	glow.position = at + Vector3(0, LAMP_Y * Px.M, 0)
	add_child(glow)
