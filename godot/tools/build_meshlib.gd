# Generates tiles/terrain_meshlib.tres, the MeshLibrary of the level GridMaps. Item id = tile id from
# src/world/tiles.ts minus one, in the order of Level.TILE_CHARS ('#' '=' '^' 'X'), then item 4: a closed gate
# (world 3, scripts/gate.gd puts it where its cells are while it is shut): a solid box with no mesh, as the gate
# draws its own bars.
# Every block is a box with shaders/terrain_pixels.gdshader (one material each, `mode` 0..3);
# Level.bake_cells() fills their cell texture.
# Run from godot/: godot --headless --script tools/build_meshlib.gd
extends SceneTree

const DEPTH := 3.0 # Level.DEPTH
## One-way platforms are a thin strip: 4 px tall at the top of the cell and this deep (4 view rows of top
## band at GameCamera.ROW_Z), so they read as light ledges, not as blocks.
const ONEWAY_DEPTH := 0.75
## Spikes are a bed of SPIKE_ROWS rows of flat spike quads across the whole block depth, SPIKE_STEP apart (4 view
## rows of oblique shift each), facing the camera; the shader cuts the triangles out of them.
const SPIKE_ROWS := 5
const SPIKE_STEP := 0.75


func _init() -> void:
	var lib := MeshLibrary.new()
	var shader: Shader = load("res://shaders/terrain_pixels.gdshader")
	for i in 4:
		var name: String = ["solid", "oneway", "spike", "corrupt"][i]
		lib.create_item(i)
		lib.set_item_name(i, name)
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("mode", {"solid": 0, "oneway": 1, "corrupt": 2, "spike": 3}[name])
		var box := BoxMesh.new()
		box.size = Vector3(1, 1, DEPTH)
		# A vertex row at z = 0, where the perspective in shaders/oblique.gdshaderinc bends.
		box.subdivide_depth = 1
		if name == "oneway":
			box.size = Vector3(1, 0.25, ONEWAY_DEPTH)
			lib.set_item_mesh_transform(i, Transform3D(Basis.IDENTITY, Vector3(0, 0.375, 0)))
		mat.set_shader_parameter("half_depth", box.size.z / 2)
		box.material = mat
		lib.set_item_mesh(i, _spike_bed(mat) if name == "spike" else box)
		# Spikes are not solid (isSolidTile in src/world/tiles.ts); the player checks them by tile.
		if name == "spike":
			continue
		var shape := BoxShape3D.new()
		var at := Transform3D.IDENTITY
		shape.size = Vector3(1, 1, DEPTH)
		if name == "oneway":
			# Collides on the top quarter of the cell, like the 4 px one-way polygon in 2D.
			shape.size.y = 0.25
			at.origin.y = 0.375
		lib.set_item_shapes(i, [shape, at])

	lib.create_item(4)
	lib.set_item_name(4, "gate")
	var gate := BoxShape3D.new()
	gate.size = Vector3(1, 1, DEPTH)
	lib.set_item_shapes(4, [gate, Transform3D.IDENTITY])

	var err := ResourceSaver.save(lib, "res://tiles/terrain_meshlib.tres")
	print("terrain_meshlib.tres saved: ", error_string(err))
	quit(err)


## The spike tile: SPIKE_ROWS quads over the bottom half of the cell (the 8 px spikes), the first on the block's
## front face (z = DEPTH / 2), each next one SPIKE_STEP further back, all facing +z.
func _spike_bed(mat: Material) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3(0, 0, 1))
	for r in SPIKE_ROWS:
		var z := DEPTH / 2 - r * SPIKE_STEP
		var a := Vector3(-0.5, -0.5, z)
		var b := Vector3(0.5, -0.5, z)
		var c := Vector3(0.5, 0.0, z)
		var d := Vector3(-0.5, 0.0, z)
		# Clockwise seen from the front, which is the front face in Godot.
		for v in [a, c, b, a, d, c]:
			st.add_vertex(v)
	st.set_material(mat)
	return st.commit()
