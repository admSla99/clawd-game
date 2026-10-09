# Generates tiles/terrain.png and tiles/terrain.tres from the tile ids in src/world/tiles.ts.
# Run from godot/: godot --headless --script tools/build_tileset.gd
extends SceneTree

const TILE := 16
# Atlas column = TS tile id - 1, so a converter can map '#','=','^','X' straight to coords.
const TILES := [
	{"name": "solid", "char": "#", "color": Color("#8a8a8a"), "shape": "full"},
	{"name": "oneway", "char": "=", "color": Color("#bdbdbd"), "shape": "top"},
	{"name": "spike", "char": "^", "color": Color("#e0605a"), "shape": "spike"},
	{"name": "corrupt", "char": "X", "color": Color("#c25bd6"), "shape": "full"},
]

func _init() -> void:
	var img := Image.create(TILE * TILES.size(), TILE, false, Image.FORMAT_RGBA8)
	for i in TILES.size():
		var c: Color = TILES[i].color
		match TILES[i].shape:
			"top":
				img.fill_rect(Rect2i(i * TILE, 0, TILE, 4), c)
			"spike":
				for y in TILE:
					var half := y / 2
					img.fill_rect(Rect2i(i * TILE + 8 - half, y, half * 2, 1), c)
			_:
				img.fill_rect(Rect2i(i * TILE, 0, TILE, TILE), c)
	img.save_png("res://tiles/terrain.png")

	var tex := ImageTexture.create_from_image(img)
	tex.resource_path = "res://tiles/terrain.png"

	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1) # "world"
	ts.add_custom_data_layer()
	ts.set_custom_data_layer_name(0, "kind")
	ts.set_custom_data_layer_type(0, TYPE_STRING)

	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(TILE, TILE)
	ts.add_source(src, 0)

	var h := TILE / 2.0
	for i in TILES.size():
		var coords := Vector2i(i, 0)
		src.create_tile(coords)
		var data := src.get_tile_data(coords, 0)
		data.set_custom_data("kind", TILES[i].name)
		# Spikes are not solid (isSolidTile in src/world/tiles.ts); the player checks them by tile kind.
		if TILES[i].shape == "spike":
			continue
		var poly: PackedVector2Array
		match TILES[i].shape:
			"top":
				poly = PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, -h + 4), Vector2(-h, -h + 4)])
			_:
				poly = PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
		data.add_collision_polygon(0)
		data.set_collision_polygon_points(0, 0, poly)
		data.set_collision_polygon_one_way(0, 0, TILES[i].shape == "top")

	var err := ResourceSaver.save(ts, "res://tiles/terrain.tres")
	print("terrain.tres saved: ", error_string(err))
	quit(err)
