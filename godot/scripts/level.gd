class_name Level
extends Node3D

## A converted level (levels/<id>.tscn, built by build() from levels/<id>.txt): Terrain and OneWay
## GridMaps, a Start marker and the spawned bugs and tokens. MeshLibrary item = index in TILE_CHARS
## = tile id from src/world/tiles.ts minus one. One-way platforms get their own GridMap on the
## physics layer "oneway", which the player only collides with from above.

const TILE_CHARS := "#=^X"
const SOLID := 0
const ONEWAY := 1
const SPIKE := 2
const CORRUPT := 3
const MESH_LIBRARY := "res://tiles/terrain_meshlib.tres"
## Depth of a block in metres; blocks are centred on the gameplay plane z = 0.
const DEPTH := 3.0
# Loaded in _add_spawn, not preloaded: bug.gd refers back to Level, and a preload cycle fails to load.
const BUG := "res://scenes/bug.tscn"
const TOKEN := "res://scenes/token.tscn"
# '@' becomes a Marker3D named Start; 'E' a bug; 'o' a token. Positions are the tile's
# bottom-centre, like Spawn.x / Spawn.y in src/world/level.ts.
const SPAWNS := {"@": "start", "E": "bug", "o": "token"}

@onready var terrain: GridMap = $Terrain
@onready var oneway: GridMap = $OneWay


## Tile item under a point in level pixels, or -1.
func tile(p: Vector2) -> int:
	var c := Px.cell(p)
	var item := oneway.get_cell_item(c)
	return item if item != GridMap.INVALID_CELL_ITEM else terrain.get_cell_item(c)


## Level size in pixels: right edge of the widest row by the bottom of the lowest, like
## Level.pixelW / pixelH in TS.
func size() -> Vector2:
	var s := Vector2.ZERO
	for map: GridMap in [terrain, oneway]:
		for c in map.get_used_cells():
			s = s.max(Vector2((c.x + 1) * 16, -c.y * 16))
	return s


static func build(rows: PackedStringArray) -> Level:
	var level := Level.new()
	level.name = "Level"
	var maps: Array[GridMap] = []
	for map_name in ["Terrain", "OneWay"]:
		var map := GridMap.new()
		map.name = map_name
		map.mesh_library = load(MESH_LIBRARY)
		map.cell_size = Vector3(1, 1, DEPTH)
		map.position.z = -DEPTH / 2
		map.collision_layer = 1 if map_name == "Terrain" else 8
		map.collision_mask = 0
		level.add_child(map)
		map.owner = level
		maps.append(map)
	for y in rows.size():
		for x in rows[y].length():
			var ch := rows[y][x]
			var item := TILE_CHARS.find(ch)
			if item >= 0:
				maps[int(item == ONEWAY)].set_cell_item(Vector3i(x, -y - 1, 0), item)
			elif SPAWNS.has(ch):
				_add_spawn(level, SPAWNS[ch], Vector2(x * 16 + 8, (y + 1) * 16))
	return level


static func _add_spawn(level: Level, kind: String, pos: Vector2) -> void:
	var node: Node3D
	match kind:
		"start":
			node = Marker3D.new()
			node.name = "Start"
		"bug":
			node = load(BUG).instantiate()
		"token":
			node = load(TOKEN).instantiate()
			pos.y -= 8 # floats half a tile up, like `new Token(s.x, s.y - 8)` in src/scenes/game.ts
	node.position = Px.to3(pos)
	level.add_child(node, true)
	node.owner = level
