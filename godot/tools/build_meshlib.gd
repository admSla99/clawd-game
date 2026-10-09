# Generates tiles/terrain_meshlib.tres, the MeshLibrary of the level GridMaps. Item id = tile id from
# src/world/tiles.ts minus one, in the order of Level.TILE_CHARS ('#' '=' '^' 'X').
# Run from godot/: godot --headless --script tools/build_meshlib.gd
extends SceneTree

const DEPTH := 3.0 # Level.DEPTH
const TILES := [
	{"name": "solid", "color": Color("#8a8a8a")},
	{"name": "oneway", "color": Color("#bdbdbd")},
	{"name": "spike", "color": Color("#e0605a"), "glow": 1.5},
	{"name": "corrupt", "color": Color("#c25bd6"), "glow": 0.6},
]


var GRID := grid_texture()


func _init() -> void:
	var lib := MeshLibrary.new()
	for i in TILES.size():
		var t: Dictionary = TILES[i]
		var mat := StandardMaterial3D.new()
		mat.albedo_color = t.color
		mat.roughness = 0.9
		# A faint grid every metre on the top and front faces, so single blocks read like tiles.
		mat.albedo_texture = GRID
		mat.uv1_triplanar = true
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		if t.has("glow"):
			mat.emission_enabled = true
			mat.emission = t.color
			mat.emission_energy_multiplier = t.glow
		var box := BoxMesh.new()
		box.material = mat
		var at := Transform3D.IDENTITY
		match t.name:
			"oneway":
				box.size = Vector3(1, 0.25, DEPTH)
				at.origin.y = 0.375 # top quarter of the cell
			_:
				box.size = Vector3(1, 1, DEPTH)
		lib.create_item(i)
		lib.set_item_name(i, t.name)
		lib.set_item_mesh_transform(i, at)
		# Spikes are not solid (isSolidTile in src/world/tiles.ts); the player checks them by tile.
		if t.name == "spike":
			lib.set_item_mesh(i, spikes(mat))
			continue
		lib.set_item_mesh(i, box)
		var shape := BoxShape3D.new()
		shape.size = box.size
		lib.set_item_shapes(i, [shape, at])

	var err := ResourceSaver.save(lib, "res://tiles/terrain_meshlib.tres")
	print("terrain_meshlib.tres saved: ", error_string(err))
	quit(err)


## Two rows of four-sided spikes standing on the bottom of the cell, across the block's depth.
func spikes(mat: Material) -> Mesh:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.3
	cone.height = 0.7
	cone.radial_segments = 4
	cone.rings = 1
	var st := SurfaceTool.new()
	for x in [-0.25, 0.25]:
		for z in [-1.0, -0.5, 0.0, 0.5, 1.0]:
			st.append_from(cone, 0, Transform3D(Basis(Vector3.UP, PI / 4), Vector3(x, -0.15, z)))
	st.set_material(mat)
	return st.commit()


## 16x16 white tile with a darker 1 px border, tinted by albedo_color.
func grid_texture() -> ImageTexture:
	var img := Image.create(16, 16, true, Image.FORMAT_RGBA8)
	img.fill(Color(0.72, 0.72, 0.72))
	img.fill_rect(Rect2i(1, 1, 14, 14), Color.WHITE)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
