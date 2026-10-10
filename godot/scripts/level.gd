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
const MAX_DIST := 12
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


## Fills the blocks' dot texture (shaders/terrain_dots.gdshader) like TerrainRenderer.bake() in
## src/render/dotRenderer.ts: per 4 px cell, R = brightness from the distance to the nearest open cell
## (bright crust, dim interior) plus strata and noise from `seed`, G = random, B = 1 when the cell above
## is open. The MeshLibrary materials are shared, so this applies to the level shown last.
func bake_dots(seed: int) -> void:
	var s := size()
	var cw := int(s.x) / 4
	var ch := int(s.y) / 4
	var solid := func(cx: int, cy: int) -> bool:
		if cx < 0 or cx >= cw:
			return true
		if cy < 0 or cy >= ch:
			return false
		return terrain.get_cell_item(Vector3i(cx >> 2, -(cy >> 2) - 1, 0)) == SOLID
	# Chebyshev distance (in cells) from every solid cell to the nearest open cell.
	var dist := PackedByteArray()
	dist.resize(cw * ch)
	dist.fill(MAX_DIST)
	var queue := PackedInt32Array()
	for y in ch:
		for x in cw:
			if not solid.call(x, y):
				dist[y * cw + x] = 0
				queue.append(y * cw + x)
	var i := 0
	while i < queue.size():
		var idx := queue[i]
		i += 1
		var nd := dist[idx] + 1
		if nd >= MAX_DIST:
			continue
		var x := idx % cw
		var y := idx / cw
		for oy in range(-1, 2):
			for ox in range(-1, 2):
				var nx := x + ox
				var ny := y + oy
				if nx >= 0 and ny >= 0 and nx < cw and ny < ch and dist[ny * cw + nx] > nd:
					dist[ny * cw + nx] = nd
					queue.append(ny * cw + nx)
	var img := Image.create_empty(cw, ch, false, Image.FORMAT_RGB8)
	for y in ch:
		for x in cw:
			var d := dist[y * cw + x]
			var r := DotNoise.hash2(x, y, seed)
			var strata := DotNoise.value_noise2(x * 0.18, y * 0.5, seed + 3)
			var b: float
			if d <= 1: b = 0.92
			elif d == 2: b = 0.68
			elif d == 3: b = 0.52
			else: b = maxf(0.12, 0.5 - (d - 3) * 0.05)
			b += (strata - 0.5) * 0.28 + (r - 0.5) * 0.18
			var air_above := y > 0 and not _blocky(x >> 2, (y - 1) >> 2)
			img.set_pixel(x, y, Color(clampf(b, 0, 1), r, 1.0 if air_above else 0.0))
	var tex := ImageTexture.create_from_image(img)
	for mat in materials():
		mat.set_shader_parameter("dots", tex)
		mat.set_shader_parameter("cells", Vector2(cw, ch))


## Puts Clawd's blob shadow (terrain_dots.gdshader) on the floor under `feet` (level pixels).
func set_shadow(feet: Vector2) -> void:
	var tx := floori(feet.x / 16)
	var floor_y := INF
	for ty in range(floori((feet.y - 1) / 16), int(size().y / 16) + 1):
		if _blocky(tx, ty) or oneway.get_cell_item(Vector3i(tx, -ty - 1, 0)) == ONEWAY:
			floor_y = ty * 16
			break
	var v := Vector3(feet.x * Px.M, -floor_y * Px.M, (floor_y - feet.y) / 16.0) if floor_y < INF else Vector3(0, -1e6, 0)
	for mat in materials():
		mat.set_shader_parameter("shadow", v)


## The dot ShaderMaterials of the MeshLibrary, one per item.
func materials() -> Array[ShaderMaterial]:
	var lib := terrain.mesh_library
	var out: Array[ShaderMaterial] = []
	for item in [SOLID, ONEWAY, SPIKE, CORRUPT]:
		out.append((lib.get_item_mesh(item) as BoxMesh).material)
	return out


func _blocky(tx: int, ty: int) -> bool:
	return terrain.get_cell_item(Vector3i(tx, -ty - 1, 0)) in [SOLID, CORRUPT]


func _process(_dt: float) -> void:
	for mat in materials():
		mat.set_shader_parameter("game_time", Game.time)


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
