# Generates tiles/terrain_meshlib.tres, the MeshLibrary of the level GridMaps. Item id = tile id from
# src/world/tiles.ts minus one, in the order of Level.TILE_CHARS ('#' '=' '^' 'X').
# Every block is a box with shaders/terrain_dots.gdshader (one material each, `mode` 0..3); Level.bake_dots()
# fills their dot texture.
# Run from godot/: godot --headless --script tools/build_meshlib.gd
extends SceneTree

const DEPTH := 3.0 # Level.DEPTH


func _init() -> void:
	var lib := MeshLibrary.new()
	var shader: Shader = load("res://shaders/terrain_dots.gdshader")
	for i in 4:
		var name: String = ["solid", "oneway", "spike", "corrupt"][i]
		lib.create_item(i)
		lib.set_item_name(i, name)
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("mode", {"solid": 0, "oneway": 1, "corrupt": 2, "spike": 3}[name])
		mat.set_shader_parameter("half_depth", DEPTH / 2)
		var box := BoxMesh.new()
		box.size = Vector3(1, 1, DEPTH)
		box.material = mat
		lib.set_item_mesh(i, box)
		# Spikes are not solid (isSolidTile in src/world/tiles.ts); the player checks them by tile.
		if name == "spike":
			continue
		var shape := BoxShape3D.new()
		var at := Transform3D.IDENTITY
		shape.size = box.size
		if name == "oneway":
			# Collides on the top quarter of the cell, like the 4 px one-way polygon in 2D.
			shape.size.y = 0.25
			at.origin.y = 0.375
		lib.set_item_shapes(i, [shape, at])

	var err := ResourceSaver.save(lib, "res://tiles/terrain_meshlib.tres")
	print("terrain_meshlib.tres saved: ", error_string(err))
	quit(err)
