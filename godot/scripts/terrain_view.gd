class_name TerrainView
extends Node2D

## Draws a level's terrain like TerrainRenderer in src/render/dotRenderer.ts: a matrix of dots whose
## size and brightness depend on how close each 4 px cell is to open air (bright crusty edges, dim
## dense interior). Solid, one-way and spike tiles are baked once per level into 256 px chunk
## textures; corrupted blocks and the surface shimmer are drawn live each frame, so breaking a
## corrupted block needs no re-bake (TS never re-bakes either). Reads tiles from the level's
## TileMapLayer (atlas column = tile id - 1, see tools/build_tileset.gd).

const TILE := 16
const DOT := 4
const CELLS := TILE / DOT
const CHUNK := 16
const MAX_DIST := 12
enum { EMPTY, SOLID, ONEWAY, SPIKE, CORRUPT }

var terrain: TileMapLayer
var seed := 7
var w := 0
var h := 0
var tiles := PackedByteArray()
var dist := PackedByteArray()
var cw := 0
var ch := 0


func build(level: TileMapLayer, terrain_seed: int) -> void:
	terrain = level
	seed = terrain_seed
	for c in get_children():
		c.free()
	var used := level.get_used_rect()
	w = used.end.x
	h = used.end.y
	tiles.resize(w * h)
	tiles.fill(EMPTY)
	for cell in level.get_used_cells():
		tiles[cell.y * w + cell.x] = level.get_cell_atlas_coords(cell).x + 1
	cw = w * CELLS
	ch = h * CELLS
	_compute_distance()
	var size := CHUNK * TILE
	for cy in ceili(float(h) / CHUNK):
		for cx in ceili(float(w) / CHUNK):
			var img := _bake(cx, cy)
			if img == null:
				continue
			var s := Sprite2D.new()
			s.texture = ImageTexture.create_from_image(img)
			s.centered = false
			s.position = Vector2(cx * size, cy * size)
			s.show_behind_parent = true
			add_child(s)


func tile_at(tx: int, ty: int) -> int:
	if tx < 0 or tx >= w:
		return SOLID
	if ty < 0 or ty >= h:
		return EMPTY
	return tiles[ty * w + tx]


func _solid_cell(cx: int, cy: int) -> bool:
	return tile_at(cx / CELLS, cy / CELLS) == SOLID


## Chebyshev distance (in cells) from every solid cell to the nearest open cell.
func _compute_distance() -> void:
	dist.resize(cw * ch)
	dist.fill(MAX_DIST)
	var queue := PackedInt32Array()
	for y in ch:
		for x in cw:
			if not _solid_cell(x, y):
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
				if nx < 0 or ny < 0 or nx >= cw or ny >= ch:
					continue
				var n := ny * cw + nx
				if dist[n] > nd:
					dist[n] = nd
					queue.append(n)


func _bake(chx: int, chy: int) -> Image:
	var size := CHUNK * TILE
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var any := false
	var n := CHUNK * CELLS
	for y in n:
		for x in n:
			var cx := chx * n + x
			var cy := chy * n + y
			if cx >= cw or cy >= ch:
				continue
			var t := tile_at(cx / CELLS, cy / CELLS)
			match t:
				SOLID: _solid_dot(img, cx, cy, x * DOT, y * DOT)
				ONEWAY: _oneway_dot(img, cx, y * DOT, x * DOT)
				SPIKE: _spike_dot(img, cx, cy, x * DOT, y * DOT)
				_: continue
			any = true
	return img if any else null


static func _gray(v: float) -> Color:
	var c := clampi(roundi(v), 0, 255)
	return Color8(c, c, c)


func _solid_dot(img: Image, cx: int, cy: int, px: int, py: int) -> void:
	var d := dist[cy * cw + cx]
	var r := DotNoise.hash2(cx, cy, seed)
	var strata := DotNoise.value_noise2(cx * 0.18, cy * 0.5, seed + 3)
	var air_above := cy > 0 and not _solid_cell(cx, cy - 1)
	var b: float
	if d <= 1: b = 0.92
	elif d == 2: b = 0.68
	elif d == 3: b = 0.52
	else: b = maxf(0.12, 0.5 - (d - 3) * 0.05)
	b += (strata - 0.5) * 0.28 + (r - 0.5) * 0.18

	if b < 0.1 and r < 0.4:
		return
	if air_above and r < 0.22:
		# Bright plus-shaped sparkles along the surface.
		img.fill_rect(Rect2i(px + 1, py, 1, 3), _gray(225))
		img.fill_rect(Rect2i(px, py + 1, 3, 1), _gray(225))
		return
	if b > 0.85:
		img.fill_rect(Rect2i(px + 1, py + 1, 2, 2), _gray(200 + r * 40))
	elif b > 0.66:
		img.fill_rect(Rect2i(px + 1, py + 1, 2, 2 if r > 0.6 else 1), _gray(165 + r * 30))
	elif b > 0.45:
		img.set_pixel(px + 1, py + 1, _gray(120 + r * 30))
	elif b > 0.28:
		img.set_pixel(px + 1, py + 1, _gray(80 + r * 20))
	else:
		img.set_pixel(px + 1, py + 1, _gray(52 + r * 14))


func _oneway_dot(img: Image, cx: int, py: int, px: int) -> void:
	var local := (py / DOT) % CELLS
	if local == 0:
		img.fill_rect(Rect2i(px, py, 3, 1), _gray(215))
		img.set_pixel(px + 1, py + 2, _gray(120))
	elif local == 1 and cx % 2 == 0:
		img.set_pixel(px + 1, py + 1, _gray(70))


func _spike_dot(img: Image, cx: int, cy: int, px: int, py: int) -> void:
	# Two dotted triangles per tile.
	var lx := cx % CELLS
	var ly := cy % CELLS
	var in_tri := ly == 3 or (ly == 2 and lx <= 2) or (ly == 1 and lx % 2 == 0)
	if not in_tri:
		return
	var c := Color("#F07A72") if ly <= 1 else Color("#C9524B") if ly == 2 else Color("#7E3431")
	if ly <= 1:
		img.fill_rect(Rect2i(px + 2, py + 1, 1, 2), c)
	else:
		img.fill_rect(Rect2i(px + 1, py + 1, 2, 2), c)


func _physics_process(_dt: float) -> void:
	if not Game.frozen():
		queue_redraw()


## Live layer: corrupted blocks and shimmer over the visible tiles (drawCorrupted / drawShimmer).
func _draw() -> void:
	if terrain == null:
		return
	var view := get_viewport().get_canvas_transform().affine_inverse() * get_viewport_rect()
	var tx0 := maxi(0, floori(view.position.x / TILE))
	var ty0 := maxi(0, floori(view.position.y / TILE))
	var tx1 := mini(w - 1, floori(view.end.x / TILE))
	var ty1 := mini(h - 1, floori(view.end.y / TILE))
	var frame := floori(Game.time * 12)
	var live := func(tx: int, ty: int) -> int:
		var a := terrain.get_cell_atlas_coords(Vector2i(tx, ty))
		return a.x + 1 if a.x >= 0 else EMPTY
	for ty in range(ty0, ty1 + 1):
		for tx in range(tx0, tx1 + 1):
			if live.call(tx, ty) != CORRUPT:
				continue
			var x := tx * TILE
			var y := ty * TILE
			for j in CELLS:
				for i in CELLS:
					var r := DotNoise.hash2(tx * 4 + i, ty * 4 + j, frame)
					var edge := i == 0 or j == 0 or i == CELLS - 1 or j == CELLS - 1
					if (i + j) % 2 == 0:
						draw_rect(Rect2(x + i * DOT + 1, y + j * DOT + 1, 2, 2), Color("#D58BE3") if edge else Color("#8E4A9C"))
					elif r > 0.8:
						draw_rect(Rect2(x + i * DOT, y + j * DOT + 1, 4, 1), Color("#D97757") if r > 0.94 else Color.WHITE)
			# Glitch scanline.
			if DotNoise.hash2(tx, ty, frame) > 0.8:
				draw_rect(Rect2(x - 2, y + floorf(DotNoise.hash2(ty, tx, frame) * 16), TILE + 4, 1), Color(217 / 255.0, 119 / 255.0, 87 / 255.0, 0.6))

	# Sparse twinkling dots on exposed edges.
	frame = floori(Game.time * 6)
	for ty in range(ty0, ty1 + 1):
		for tx in range(tx0, tx1 + 1):
			var t: int = live.call(tx, ty)
			var above: int = live.call(tx, ty - 1) if ty > 0 else EMPTY
			if not (t == SOLID or t == CORRUPT) or above == SOLID or above == CORRUPT:
				continue
			var r := DotNoise.hash2(tx, ty, frame)
			if r > 0.88:
				var i := floori(DotNoise.hash2(ty, tx, frame) * CELLS)
				draw_rect(Rect2(tx * TILE + i * DOT + 1, ty * TILE + 1, 2, 2),
					Color(240 / 255.0, 165 / 255.0, 133 / 255.0, 0.9) if r > 0.97 else Color(1, 1, 1, 0.85))
