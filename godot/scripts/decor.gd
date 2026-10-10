class_name Decor
extends Node3D

## Props on the level's exposed tops, placed from the level's terrainSeed when it loads: lanterns that
## light the terrain (a GlowLight each) and small tufts in the theme's light colour. Lanterns stand at
## the back of the top band, behind Clawd; tufts sit at the front lip and at the back. Props are 1 px
## voxels (Voxel.mesh) and have no collision.

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

static var LANTERN_MESH := Voxel.mesh(LANTERN, {"f": Color8(66, 62, 70), "p": Color8(42, 40, 46)}, {"f": 6, "p": 2}, Px.M)
static var LAMP_MESH := Voxel.mesh(LAMP + _empty_rows(LANTERN.size() - LAMP.size(), 9), {"L": Color8(232, 120, 72), "W": Color8(255, 200, 140)}, {"L": 4, "W": 4}, Px.M, Voxel.material(1.6))


static func _empty_rows(n: int, w: int) -> Array:
	var rows := []
	for i in n:
		rows.append(".".repeat(w))
	return rows


## Adds a Decor child with the props for `level`.
static func populate(level: Level, seed: int, palette: Dictionary) -> void:
	var decor := Decor.new()
	decor.name = "Decor"
	level.add_child(decor)
	var light: Color = palette.light
	var tuft_meshes := TUFTS.map(func(rows: Array) -> ArrayMesh:
		return Voxel.mesh(rows, {"g": light * 0.45, "G": light * 0.8}, {}, Px.M))
	var tops := []
	for c: Vector3i in level.terrain.get_used_cells():
		var tx := c.x
		var ty := -c.y - 1
		if level.terrain.get_cell_item(c) == Level.SOLID and level.tile(Vector2(tx * 16 + 8, ty * 16 - 8)) < 0:
			tops.append(Vector2i(tx, ty))
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
			decor.add_child(mi)


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
