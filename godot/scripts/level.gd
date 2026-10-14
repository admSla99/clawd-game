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
## A shut gate's cells (world 3, scripts/gate.gd): MeshLibrary item 4, solid but drawn by the gate; tile() calls it
## SOLID, so everything treats it as rock.
const GATE := 4
## Plates (a run of one digit is one plate) and gates (every cell of one letter is one gate) in world-3 maps.
const PLATE_CHARS := "123456789"
const GATE_CHARS := "abcdefghiz"
const MESH_LIBRARY := "res://tiles/terrain_meshlib.tres"
## Depth of a block in metres; blocks are centred on the gameplay plane z = 0.
const DEPTH := 3.0
## Distances to open air are stored up to this many cells (terrain_pixels.gdshader decodes R * 12).
const MAX_DIST := 12
## Size of the light arrays in terrain_pixels.gdshader (MAX_LIGHTS).
const LIGHTS_MAX := 32
## Size of the shadow array in terrain_pixels.gdshader (MAX_SHADOWS).
const SHADOWS_MAX := 16
# Loaded in _add_spawn, not preloaded: bug.gd refers back to Level, and a preload cycle fails to load.
const BUG := "res://scenes/bug.tscn"
const TOKEN := "res://scenes/token.tscn"
const CHECKPOINT := "res://scripts/checkpoint.gd"
const GOAL := "res://scripts/goal.gd"
const SIGN := "res://scripts/sign.gd"
const PLATFORM := "res://scripts/moving_platform.gd"
const AGENT := "res://scripts/sub_agent.gd"
const SPARK := "res://scripts/spark.gd"
const SPAMBOT := "res://scripts/spam_bot.gd"
const RATELIMITER := "res://scripts/rate_limiter.gd"
const TURRET := "res://scripts/turret.gd"
const DRONE := "res://scripts/drone.gd"
const SHIELDBOT := "res://scripts/shield_bot.gd"
const INJECTOR := "res://scripts/injector.gd"
const ANCHOR := "res://scripts/anchor.gd"
const PARSER := "res://scripts/parser.gd"
const PLATE := "res://scripts/plate.gd"
const WEBHOOK := "res://scripts/webhook.gd"
const GATE_SCRIPT := "res://scripts/gate.gd"
# '@' becomes a Marker3D named Start; 'E' a bug; 'o' a token; 'C' a checkpoint; 'G' the exit; '?' a sign
# (numbered in map order, like Spawn.index); 'M' / 'V' a moving platform (horizontal / vertical, each one
# 1.3 s further in its swing than the one before, like platPhase in src/scenes/game.ts); 'A' a sub-agent and
# 'S' a spark (each numbered like the signs); 'F' a spam bot and 'R' a rate limiter; world 2's 'T' / 'Y' a
# turret on the floor / ceiling, 'D' a drone, 'H' a shield bot and 'I' an injector; 'B' a Marker3D named Boss
# (Main puts the level's `boss` there). Positions are the tile's
# bottom-centre, like Spawn.x / Spawn.y in src/world/level.ts. Every spawned node keeps its map character in
# the meta "spawn".
const SPAWNS := {"@": "start", "E": "bug", "o": "token", "C": "checkpoint", "G": "goal", "?": "sign", "M": "platform_h", "V": "platform_v", "A": "agent", "S": "spark", "F": "spambot", "R": "ratelimiter", "T": "turret", "Y": "ceilturret", "D": "drone", "H": "shieldbot", "I": "injector", "B": "boss", "+": "anchor", "P": "parser", "W": "webhook"}

## The cell texture (bake_cells()) and its seed, kept for re-baking after blocks break.
var _seed := 0
var _cells_img: Image
var _cells_tex: ImageTexture

@onready var terrain: GridMap = $Terrain
@onready var oneway: GridMap = $OneWay
## Level width in tiles (Level.w in TS) and size in pixels (Level.pixelW / pixelH), fixed when the level
## enters the tree.
var width := 0
var pixel_size := Vector2.ZERO


func _ready() -> void:
	pixel_size = size()
	width = int(pixel_size.x / 16)
	_add_side_walls()


## Like `tile()` in src/world/level.ts, everything left and right of the map is solid: two invisible walls
## on the terrain's physics layer, from far above the level to below where Clawd falls out of it.
func _add_side_walls() -> void:
	var body := StaticBody3D.new()
	body.name = "SideWalls"
	body.collision_layer = 1
	body.collision_mask = 0
	var top := -4096.0
	var bottom := size().y + 256
	for x: float in [-64.0, width * 16.0]:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(64, bottom - top, 64) * Px.M
		shape.shape = box
		shape.position = Px.to3(Vector2(x + 32, (top + bottom) / 2))
		body.add_child(shape)
	add_child(body)


## findFloorBelow() in src/scenes/game.ts: the top (px) of the first solid tile in column `tx` from row `ty`
## down, or the level's bottom.
func floor_below(tx: int, ty: int) -> float:
	for y in range(ty, int(pixel_size.y / 16)):
		if terrain.get_cell_item(Vector3i(tx, -y - 1, 0)) == SOLID:
			return y * 16.0
	return pixel_size.y


## Tile item under a point in level pixels, or -1.
## Columns outside the map count as solid, like in TS.
func tile(p: Vector2) -> int:
	if width > 0 and (p.x < 0 or p.x >= width * 16):
		return SOLID
	var c := Px.cell(p)
	var item := oneway.get_cell_item(c)
	if item == GridMap.INVALID_CELL_ITEM:
		item = terrain.get_cell_item(c)
	return SOLID if item == GATE else item


## Fills the blocks' cell texture (shaders/terrain_pixels.gdshader), one texel per 4 px cell:
## R = Chebyshev distance to the nearest open cell / MAX_DIST (bright crust, dark interior), G = random
## from `seed`, B = 1 when the cell above is open, A = 1 for solid or corrupted cells. The MeshLibrary
## materials are shared, so this applies to the level shown last.
func bake_cells(seed: int) -> void:
	_seed = seed
	var s := size()
	_cells_img = Image.create_empty(int(s.x) / 4, int(s.y) / 4, false, Image.FORMAT_RGBA8)
	_bake(Rect2i(Vector2i.ZERO, _cells_img.get_size()))
	_cells_tex = ImageTexture.create_from_image(_cells_img)
	set_param("cells_tex", _cells_tex)
	set_param("cells", Vector2(_cells_img.get_size()))


## Recomputes the texels of the cells in `r`. The distances come from a search over `r` grown by
## MAX_DIST, so cells near its edge still see open air outside it.
func _bake(r: Rect2i) -> void:
	var w := r.grow(MAX_DIST).intersection(Rect2i(Vector2i.ZERO, _cells_img.get_size()))
	var cw := w.size.x
	var ch := w.size.y
	var dist := PackedByteArray()
	dist.resize(cw * ch)
	dist.fill(MAX_DIST)
	var queue := PackedInt32Array()
	for y in ch:
		for x in cw:
			if not _blocky((w.position.x + x) >> 2, (w.position.y + y) >> 2):
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
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			# The level's top row is a ceiling, not a floor: no crust on it.
			var air_above := y > 0 and not _blocky(x >> 2, (y - 1) >> 2)
			_cells_img.set_pixel(x, y, Color(
				float(dist[(y - w.position.y) * cw + x - w.position.x]) / MAX_DIST,
				DotNoise.hash2(x, y, _seed),
				1.0 if air_above else 0.0,
				1.0 if _blocky(x >> 2, y >> 2) else 0.0))


## Removes the corrupted cluster around tile (tx, ty) (4-connected, like breakCluster() in
## src/scenes/game.ts) and re-bakes the cell texture. Returns the broken tiles; empty if (tx, ty) is not
## corrupted.
func break_corrupt(tx: int, ty: int) -> Array[Vector2i]:
	var broken: Array[Vector2i] = []
	var stack: Array[Vector2i] = [Vector2i(tx, ty)]
	while not stack.is_empty():
		var t: Vector2i = stack.pop_back()
		var c := Vector3i(t.x, -t.y - 1, 0)
		if terrain.get_cell_item(c) != CORRUPT:
			continue
		terrain.set_cell_item(c, GridMap.INVALID_CELL_ITEM)
		broken.append(t)
		stack.append_array([t + Vector2i.RIGHT, t + Vector2i.LEFT, t + Vector2i.DOWN, t + Vector2i.UP])
	if not broken.is_empty():
		# Only cells up to MAX_DIST away from the broken tiles change.
		var r := Rect2i(broken[0] * 4, Vector2i(4, 4))
		for t in broken:
			r = r.merge(Rect2i(t * 4, Vector2i(4, 4)))
		_bake(r.grow(MAX_DIST + 1).intersection(Rect2i(Vector2i.ZERO, _cells_img.get_size())))
		_cells_tex.update(_cells_img)
	return broken


## Orange lights for terrain_pixels.gdshader: `lights` = (x, y, z, radius) in metres, `energy` one per light.
func set_lights(lights: PackedVector4Array, energy: PackedFloat32Array) -> void:
	var n := lights.size()
	lights.resize(LIGHTS_MAX)
	energy.resize(LIGHTS_MAX)
	set_param("lights", lights)
	set_param("light_energy", energy)
	set_param("light_count", n)


## Sets a uniform on every block material.
func set_param(param: StringName, value: Variant) -> void:
	for mat in materials():
		mat.set_shader_parameter(param, value)


## A blob shadow for terrain_pixels.gdshader on the floor under `feet` (level pixels), `radius` metres
## wide when the caster stands on it: (x, floor y, height above the floor in tiles, radius).
func shadow_at(feet: Vector2, radius: float) -> Vector4:
	var tx := floori(feet.x / 16)
	for ty in range(floori((feet.y - 1) / 16), int(size().y / 16) + 1):
		if _blocky(tx, ty) or oneway.get_cell_item(Vector3i(tx, -ty - 1, 0)) == ONEWAY:
			return Vector4(feet.x * Px.M, -ty, (ty * 16 - feet.y) / 16.0, radius)
	return Vector4(0, -1e6, 0, 0)


## Passes the blob shadows (shadow_at()) to the blocks, at most SHADOWS_MAX.
func set_shadows(shadows: PackedVector4Array) -> void:
	var n := mini(shadows.size(), SHADOWS_MAX)
	shadows.resize(SHADOWS_MAX)
	set_param("shadows", shadows)
	set_param("shadow_count", n)


## The block ShaderMaterials of the MeshLibrary, one per item.
func materials() -> Array[ShaderMaterial]:
	var lib := terrain.mesh_library
	var out: Array[ShaderMaterial] = []
	for item in [SOLID, ONEWAY, SPIKE, CORRUPT]:
		out.append(lib.get_item_mesh(item).surface_get_material(0))
	return out


func _blocky(tx: int, ty: int) -> bool:
	return terrain.get_cell_item(Vector3i(tx, -ty - 1, 0)) in [SOLID, CORRUPT]


func _process(_dt: float) -> void:
	set_param("game_time", Game.time)


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
	var signs := 0
	var agents := 0
	var sparks := 0
	var platform_phase := 0.0
	var gate_cells := {}
	for y in rows.size():
		for x in rows[y].length():
			var ch := rows[y][x]
			var item := TILE_CHARS.find(ch)
			if item >= 0:
				maps[int(item == ONEWAY)].set_cell_item(Vector3i(x, -y - 1, 0), item)
			elif PLATE_CHARS.contains(ch):
				# A plate per run of the same digit, at the run's bottom middle.
				if x > 0 and rows[y][x - 1] == ch:
					continue
				var w := 1
				while x + w < rows[y].length() and rows[y][x + w] == ch:
					w += 1
				var plate := _add_spawn(level, "plate", Vector2(x * 16 + w * 8, (y + 1) * 16))
				plate.set("digit", int(ch))
				plate.set("cells", w)
				plate.set_meta("spawn", ch)
			elif GATE_CHARS.contains(ch):
				if not gate_cells.has(ch):
					gate_cells[ch] = []
				gate_cells[ch].append(Vector2i(x, y))
			elif SPAWNS.has(ch):
				var node := _add_spawn(level, SPAWNS[ch], Vector2(x * 16 + 8, (y + 1) * 16))
				node.set_meta("spawn", ch)
				if SPAWNS[ch] == "sign":
					node.set("index", signs)
					signs += 1
				elif SPAWNS[ch] == "agent":
					node.set("index", agents)
					agents += 1
				elif SPAWNS[ch] == "spark":
					node.set("index", sparks)
					sparks += 1
				elif SPAWNS[ch].begins_with("platform"):
					node.set("phase", platform_phase)
					platform_phase += 1.3
	for ch in gate_cells:
		var gate := _add_spawn(level, "gate", Vector2.ZERO)
		gate.set("letter", ch)
		gate.set("cells", Array(gate_cells[ch], TYPE_VECTOR2I, "", null))
		gate.set_meta("spawn", ch)
	return level


static func _add_spawn(level: Level, kind: String, pos: Vector2) -> Node3D:
	var node: Node3D
	match kind:
		"start":
			node = Marker3D.new()
			node.name = "Start"
		"boss":
			node = Marker3D.new()
			node.name = "Boss"
		"bug":
			node = load(BUG).instantiate()
		"token":
			node = load(TOKEN).instantiate()
			pos.y -= 8 # floats half a tile up, like `new Token(s.x, s.y - 8)` in src/scenes/game.ts
		"checkpoint":
			node = load(CHECKPOINT).new()
			node.name = "Checkpoint"
		"goal":
			node = load(GOAL).new()
			node.name = "Goal"
		"sign":
			node = load(SIGN).new()
			node.name = "Sign"
		"agent":
			node = load(AGENT).new()
			node.name = "SubAgent"
		"spark":
			node = load(SPARK).new()
			node.name = "Spark"
		"spambot":
			node = load(SPAMBOT).new()
			node.name = "SpamBot"
		"ratelimiter":
			node = load(RATELIMITER).new()
			node.name = "RateLimiter"
		"turret", "ceilturret":
			node = load(TURRET).new()
			node.name = "Turret"
			node.ceiling = kind == "ceilturret"
		"drone":
			node = load(DRONE).new()
			node.name = "Drone"
		"shieldbot":
			node = load(SHIELDBOT).new()
			node.name = "ShieldBot"
		"injector":
			node = load(INJECTOR).new()
			node.name = "Injector"
		"anchor":
			node = load(ANCHOR).new()
			node.name = "Anchor"
		"parser":
			node = load(PARSER).new()
			node.name = "Parser"
		"plate":
			node = load(PLATE).new()
			node.name = "Plate"
		"webhook":
			node = load(WEBHOOK).new()
			node.name = "Webhook"
		"gate":
			node = load(GATE_SCRIPT).new()
			node.name = "Gate"
		"platform_h", "platform_v":
			node = load(PLATFORM).new()
			node.name = "Platform"
			node.axis = "h" if kind == "platform_h" else "v"
	node.position = Px.to3(pos)
	level.add_child(node, true)
	node.owner = level
	return node
