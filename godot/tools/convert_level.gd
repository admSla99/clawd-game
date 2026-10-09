# Converts levels/<id>.txt (written by export_levels.mjs) into levels/<id>.tscn: a TileMapLayer
# painted with tiles/terrain.tres, plus child nodes for the spawns in SPAWNS. Other spawn
# characters are skipped for now.
# Run from godot/: godot --headless --script tools/convert_level.gd [-- <id>...]   (no ids = all)
extends SceneTree

# Same char -> atlas column table the TileSet is built from.
const TILES = preload("res://tools/build_tileset.gd").TILES
const TILE := 16
const BUG := preload("res://scenes/bug.tscn")
const TOKEN := preload("res://scenes/token.tscn")
# '@' becomes a Marker2D named Start; 'E' a bug; 'o' a token. Positions are the tile's
# bottom-centre, like Spawn.x / Spawn.y in src/world/level.ts.
const SPAWNS := {"@": "start", "E": "bug", "o": "token"}


func _init() -> void:
	var tileset: TileSet = load("res://tiles/terrain.tres")
	var coords := {}
	for i in TILES.size():
		coords[TILES[i].char] = Vector2i(i, 0)

	var ids := Array(OS.get_cmdline_user_args())
	if ids.is_empty():
		ids = Array(DirAccess.get_files_at("res://levels")).filter(func(f): return f.ends_with(".txt")).map(func(f): return f.get_basename())

	var failed := false
	for id in ids:
		var txt := "res://levels/%s.txt" % id
		if not FileAccess.file_exists(txt):
			push_error("%s not found; run tools/export_levels.mjs first" % txt)
			failed = true
			continue
		var rows := FileAccess.get_file_as_string(txt).trim_suffix("\n").split("\n")
		var layer := TileMapLayer.new()
		layer.name = "Terrain"
		layer.tile_set = tileset
		for y in rows.size():
			for x in rows[y].length():
				var ch := rows[y][x]
				if coords.has(ch):
					layer.set_cell(Vector2i(x, y), 0, coords[ch])
				elif SPAWNS.has(ch):
					_add_spawn(layer, SPAWNS[ch], Vector2(x * TILE + TILE / 2.0, (y + 1) * TILE))
		if not layer.has_node("Start"):
			push_error("%s has no start '@'" % txt)
			failed = true
		var scene := PackedScene.new()
		scene.pack(layer)
		var path := "res://levels/%s.tscn" % id
		var err := ResourceSaver.save(scene, path)
		print("%s: %d cells, %d spawns, %s" % [path, layer.get_used_cells().size(), layer.get_child_count(), error_string(err)])
		failed = failed or err != OK
		layer.free()
	quit(1 if failed else 0)


func _add_spawn(layer: TileMapLayer, kind: String, pos: Vector2) -> void:
	var node: Node2D
	match kind:
		"start":
			node = Marker2D.new()
			node.name = "Start"
		"bug":
			node = BUG.instantiate()
		"token":
			node = TOKEN.instantiate()
			pos.y -= 8 # floats half a tile up, like `new Token(s.x, s.y - 8)` in src/scenes/game.ts
	node.position = pos
	layer.add_child(node, true)
	node.owner = layer
