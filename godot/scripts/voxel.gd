class_name Voxel

## Builds voxel meshes from the text-grid sprites (rows of palette characters, like Player.FRAMES):
## each art pixel becomes a cube `size` wide, extruded `depth[char]` cubes deep around z = 0. Depths
## must be even so every character sits on one grid. Anchored at the bottom-centre like the 2D
## sprites; '.' and characters missing from the palette are empty; faces between two cubes are skipped.
## Flat retro shading: the front face keeps the palette colour exactly, the other faces are scaled by
## SHADE, and the material is unshaded, so no scene light changes the sprite colours.

## Corners of each cube face, clockwise seen from outside (Godot's front-face winding).
const FACES := {
	Vector3i(1, 0, 0): [Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(1, 1, 0), Vector3(1, 0, 0)],
	Vector3i(-1, 0, 0): [Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(0, 1, 1), Vector3(0, 0, 1)],
	Vector3i(0, 1, 0): [Vector3(0, 1, 1), Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 1, 1)],
	Vector3i(0, -1, 0): [Vector3(0, 0, 0), Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 0, 0)],
	Vector3i(0, 0, 1): [Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 0, 1)],
	Vector3i(0, 0, -1): [Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(0, 1, 0), Vector3(0, 0, 0)],
}

const SHADE := {
	Vector3i(0, 0, 1): 1.0, Vector3i(0, 1, 0): 1.25, Vector3i(1, 0, 0): 0.72,
	Vector3i(-1, 0, 0): 0.72, Vector3i(0, -1, 0): 0.5, Vector3i(0, 0, -1): 0.85,
}

static var MATERIAL := material()


static func mesh(rows: Array, palette: Dictionary, depth: Dictionary, size := 2 * Px.M, mat: Material = MATERIAL) -> ArrayMesh:
	var h := rows.size()
	var w: int = rows[0].length()
	var cells := {}
	for r in h:
		var row: String = rows[r]
		for c in w:
			if not palette.has(row[c]):
				continue
			var half: int = depth.get(row[c], 2) >> 1
			for k in range(-half, half):
				cells[Vector3i(c, h - 1 - r, k)] = palette[row[c]]
	var origin := Vector3(-w / 2.0, 0, 0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v: Vector3i in cells:
		for n: Vector3i in FACES:
			if cells.has(v + n):
				continue
			var q: Array = FACES[n]
			for i in [0, 1, 2, 0, 2, 3]:
				var col: Color = cells[v] * SHADE[n]
				col.a = 1.0
				st.set_color(col)
				st.set_normal(Vector3(n))
				st.add_vertex((origin + Vector3(v) + q[i]) * size)
	st.set_material(mat)
	return st.commit()


## Unshaded vertex-colour material. `glow` > 1 scales the colour past 1.0 so the WorldEnvironment glow
## picks it up, like Fx.glow() did for the 2D sprites.
static func material(glow := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.albedo_color = Color(glow, glow, glow)
	return m
