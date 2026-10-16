class_name TdRoom
extends Node3D

## The top-down prototype's arena (branch topdown-prototype): a W x H grid of 1 m cells, walls round the edge and
## seeded blocks inside (pillars, short walls, crates), everything cut off from the middle filled in so every free
## cell can be reached. Built as one mesh of unshaded vertex colours: a checkered floor and walls WALL_H high with a
## lit top and darker sides (the voxel sprites' SHADE). Positions are Vector2 (x, z) in metres; the ground is y = 0.

const W := 34
const H := 26
const WALL_H := 0.9

var solid := PackedByteArray()
var rng := RandomNumberGenerator.new()


func generate(seed: int) -> void:
	rng.seed = seed
	solid.resize(W * H)
	solid.fill(0)
	for x in W:
		for y in H:
			if x == 0 or y == 0 or x == W - 1 or y == H - 1:
				solid[y * W + x] = 1
	var centre := Vector2i(W / 2, H / 2)
	for i in 22:
		var size: Vector2i = [Vector2i(1, 1), Vector2i(2, 2), Vector2i(3, 1), Vector2i(1, 3), Vector2i(2, 1)][rng.randi() % 5]
		var at := Vector2i(rng.randi_range(2, W - 3 - size.x), rng.randi_range(2, H - 3 - size.y))
		if Rect2i(at, size).grow(2).has_point(centre):
			continue
		for x in size.x:
			for y in size.y:
				solid[(at.y + y) * W + at.x + x] = 1
	# Fill what the middle cannot reach.
	var seen := {centre: true}
	var queue := [centre]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = c + d
			if not is_solid(n) and not seen.has(n):
				seen[n] = true
				queue.append(n)
	for x in W:
		for y in H:
			if not seen.has(Vector2i(x, y)):
				solid[y * W + x] = 1


func is_solid(c: Vector2i) -> bool:
	if c.x < 0 or c.y < 0 or c.x >= W or c.y >= H:
		return true
	return solid[c.y * W + c.x] == 1


func solid_at(p: Vector2) -> bool:
	return is_solid(Vector2i(floori(p.x), floori(p.y)))


## A circle of radius `r` at `p` clear of walls.
func free_circle(p: Vector2, r: float) -> bool:
	for o in [Vector2(-r, -r), Vector2(r, -r), Vector2(-r, r), Vector2(r, r)]:
		if solid_at(p + o):
			return false
	return true


## Moves a circle by `d`, one axis at a time, sliding along walls; returns the new position.
func slide(p: Vector2, d: Vector2, r: float) -> Vector2:
	var q := p
	if free_circle(Vector2(q.x + d.x, q.y), r):
		q.x += d.x
	if free_circle(Vector2(q.x, q.y + d.y), r):
		q.y += d.y
	return q


## Nothing solid between `a` and `b`.
func line_clear(a: Vector2, b: Vector2) -> bool:
	var n := ceili(a.distance_to(b) / 0.25)
	for i in n:
		if solid_at(a.lerp(b, float(i) / maxi(n, 1))):
			return false
	return true


## A free cell's middle at least `min_dist` from `away`.
func random_floor(away: Vector2, min_dist: float) -> Vector2:
	for i in 200:
		var p := Vector2(rng.randi_range(1, W - 2) + 0.5, rng.randi_range(1, H - 2) + 0.5)
		if not solid_at(p) and p.distance_to(away) >= min_dist:
			return p
	return Vector2(W / 2.0, H / 2.0)


func build(palette: Dictionary, mat: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var floor_a: Color = palette.mid.lerp(palette.light, 0.22)
	var floor_b: Color = floor_a.darkened(0.12)
	var wall_top: Color = palette.light.lerp(Color("#D97757"), 0.25)
	for x in W:
		for y in H:
			if is_solid(Vector2i(x, y)):
				_box(st, x, y, wall_top)
			else:
				var c: Color = floor_a if (x + y) % 2 == 0 else floor_b
				c = c.darkened(rng.randf() * 0.06)
				_quad(st, [Vector3(x, 0, y), Vector3(x + 1, 0, y), Vector3(x + 1, 0, y + 1), Vector3(x, 0, y + 1)], c)
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	m.material_override = mat
	add_child(m)


func _box(st: SurfaceTool, x: int, y: int, top: Color) -> void:
	var h := WALL_H
	_quad(st, [Vector3(x, h, y), Vector3(x + 1, h, y), Vector3(x + 1, h, y + 1), Vector3(x, h, y + 1)], top)
	# Sides only where they face a free cell (the camera sees +x and +z).
	if not is_solid(Vector2i(x, y + 1)):
		_quad(st, [Vector3(x, h, y + 1), Vector3(x + 1, h, y + 1), Vector3(x + 1, 0, y + 1), Vector3(x, 0, y + 1)], top * 0.62)
	if not is_solid(Vector2i(x + 1, y)):
		_quad(st, [Vector3(x + 1, h, y + 1), Vector3(x + 1, h, y), Vector3(x + 1, 0, y), Vector3(x + 1, 0, y + 1)], top * 0.48)
	if not is_solid(Vector2i(x, y - 1)):
		_quad(st, [Vector3(x + 1, h, y), Vector3(x, h, y), Vector3(x, 0, y), Vector3(x + 1, 0, y)], top * 0.4)
	if not is_solid(Vector2i(x - 1, y)):
		_quad(st, [Vector3(x, h, y), Vector3(x, h, y + 1), Vector3(x, 0, y + 1), Vector3(x, 0, y)], top * 0.4)


## A quad from four corners (any winding: drawn both ways).
func _quad(st: SurfaceTool, v: Array, c: Color) -> void:
	c.a = 1.0
	for tri in [[0, 1, 2], [0, 2, 3], [2, 1, 0], [3, 2, 0]]:
		for i in tri:
			st.set_color(c)
			st.add_vertex(v[i])
