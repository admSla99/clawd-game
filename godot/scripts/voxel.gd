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

const SHADER := preload("res://shaders/voxel.gdshader")
static var MATERIAL := material()


## `top` optionally gives a character's top-face colour (used as is, without SHADE), e.g. so a light rim
## on the front does not also make a pale band on top.
static func mesh(rows: Array, palette: Dictionary, depth: Dictionary, size := 2 * Px.M, mat: Material = MATERIAL, top := {}) -> ArrayMesh:
	var h := rows.size()
	var w: int = rows[0].length()
	# Each art pixel is one column, `depth` cubes deep around z = 0: front and back quads, and side quads
	# only over the depth a neighbour column does not cover. Same surface as stacking cubes, far fewer
	# triangles.
	var half := {} # Vector2i(c, y) -> half depth in cubes
	for r in h:
		var row: String = rows[r]
		for c in w:
			if palette.has(row[c]):
				half[Vector2i(c, h - 1 - r)] = depth.get(row[c], 2) >> 1
	var origin := Vector3(-w / 2.0, 0, 0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p: Vector2i in half:
		var d: int = half[p]
		var ch: String = rows[h - 1 - p.y][p.x]
		var col: Color = palette[ch]
		_quad(st, origin, p, Vector3i(0, 0, 1), -d, d, col, size)
		_quad(st, origin, p, Vector3i(0, 0, -1), -d, d, col, size)
		for n: Vector3i in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0)]:
			var nd: int = half.get(p + Vector2i(n.x, n.y), 0)
			if nd >= d:
				continue
			if nd == 0 and n.y == 1 and top.has(ch):
				_quad(st, origin, p, n, -d, d, top[ch] / SHADE[n], size)
			elif nd == 0:
				_quad(st, origin, p, n, -d, d, col, size)
			else:
				_quad(st, origin, p, n, nd, d, col, size)
				_quad(st, origin, p, n, -d, -nd, col, size)
	st.set_material(mat)
	return st.commit()


## One face of column `p` with outward normal `n`, its corners from FACES with z mapped to z0..z1 cubes.
static func _quad(st: SurfaceTool, origin: Vector3, p: Vector2i, n: Vector3i, z0: int, z1: int, col: Color, size: float) -> void:
	var c: Color = col * SHADE[n]
	c.a = 1.0
	c = c.srgb_to_linear()
	var q: Array = FACES[n]
	for i in [0, 1, 2, 0, 2, 3]:
		var v: Vector3 = q[i]
		st.set_color(c)
		st.set_normal(Vector3(n))
		st.add_vertex((origin + Vector3(p.x + v.x, p.y + v.y, z0 + v.z * (z1 - z0))) * size)


## Unshaded vertex-colour material (shaders/voxel.gdshader, with the 2.5D oblique projection). `glow` > 1
## scales the colour past 1.0 so the WorldEnvironment glow picks it up, like Fx.glow() did for the 2D
## sprites. mesh() stores linear vertex colours: a StandardMaterial3D with vertex_color_is_srgb showed
## 1 px holes where a shallow part (Clawd's arms, edge column, bottom row) meets the deeper body.
static func material(glow := 1.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("albedo", Vector4(glow, glow, glow, 1))
	return m
