class_name Voxel

## Builds voxel meshes from the text-grid sprites (rows of palette characters, like Player.FRAMES):
## each art pixel becomes a cube `size` wide, extruded `depth[char]` cubes deep around z = 0. Depths
## must be even so every character sits on one grid. Anchored at the bottom-centre like the 2D
## sprites; '.' and characters missing from the palette are empty; faces between two cubes are skipped.

## Corners of each cube face, clockwise seen from outside (Godot's front-face winding).
const FACES := {
	Vector3i(1, 0, 0): [Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(1, 1, 0), Vector3(1, 0, 0)],
	Vector3i(-1, 0, 0): [Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(0, 1, 1), Vector3(0, 0, 1)],
	Vector3i(0, 1, 0): [Vector3(0, 1, 1), Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 1, 1)],
	Vector3i(0, -1, 0): [Vector3(0, 0, 0), Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 0, 0)],
	Vector3i(0, 0, 1): [Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 0, 1)],
	Vector3i(0, 0, -1): [Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(0, 1, 0), Vector3(0, 0, 0)],
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
				st.set_color(cells[v])
				st.set_normal(Vector3(n))
				st.add_vertex((origin + Vector3(v) + q[i]) * size)
	st.set_material(mat)
	return st.commit()


## Vertex-colored material; with `glow` > 0 it also emits `glow_color` for the glow in the
## WorldEnvironment.
static func material(glow := 0.0, glow_color := Color.WHITE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.7
	if glow > 0:
		m.emission_enabled = true
		m.emission = glow_color
		m.emission_energy_multiplier = glow
	return m
