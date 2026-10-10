class_name BugSprite

## The glitch beetle at 1 px resolution, from BUG in src/render/sprites.ts (10 x 6 cells of 2 px): a round
## grey shell with a thinner 1 px rim (so it reads as a dome in depth), a lit spot, the dark spot that
## hops between the two frames, red eyes with a glint and two leg poses. `glitch` shifts one 2 px row
## sideways like the row glitch of drawSprite() in the 2D game. `flat` is the squashed shell left after a
## stomp. mesh() caches every combination.

const W := 20
const PALETTE := {
	"W": Color("#D6D6D6"), # shell
	"L": Color("#F4F4F4"), # lit spot
	"w": Color("#8C8C8C"), # rim, lower shell
	"d": Color("#555555"), # dark spot, closed eyes
	"R": Color("#E0605A"), # eyes
	"P": Color("#FFB0A8"), # eye glint
	"k": Color("#6A6A6A"), # legs
}
## Depth in px (even): a deep shell and eyes, a shallower rim, thin legs.
const DEPTH := {"W": 12, "L": 12, "d": 12, "R": 12, "P": 12, "w": 8, "k": 4}
## Shell span per 1 px row (first and last x), rounder than the 2 px original.
const SHELL := [[7, 12], [5, 14], [4, 15], [3, 16], [2, 17], [1, 18], [0, 19], [0, 19], [0, 19], [0, 19]]
const FLAT := [[4, 17], [2, 19], [1, 20], [0, 21], [0, 21], [0, 21]]
const LEGS := [[2, 6, 12, 16], [4, 8, 10, 14]]

static var _cache := {}
static var _flash := _flash_material()


## `frame` 0 / 1, `glitch` = 2 px row to shift (-1 none), `flat` for the stomped shell, `flash` all white.
static func mesh(frame: int, glitch := -1, flat := false, flash := false) -> ArrayMesh:
	var key := Vector4i(frame, glitch, int(flat), int(flash))
	if not _cache.has(key):
		_cache[key] = Voxel.mesh(rows(frame, glitch, flat), PALETTE, DEPTH, Px.M, _flash if flash else Voxel.MATERIAL)
	return _cache[key]


static func _flash_material() -> ShaderMaterial:
	var m := Voxel.material()
	m.set_shader_parameter("flash", true)
	return m


static func rows(frame: int, glitch := -1, flat := false) -> Array:
	var shell: Array = FLAT if flat else SHELL
	var h := shell.size() + (0 if flat else 2)
	var w := W + 6 # 3 px spare on both sides keeps the shell centred and leaves room for the glitch
	var x0 := 3 - (1 if flat else 0)
	var grid := []
	for y in h:
		var row := []
		row.resize(w)
		row.fill(".")
		grid.append(row)
	var inside := func(x: int, y: int) -> bool:
		return y >= 0 and y < shell.size() and x >= shell[y][0] and x <= shell[y][1]
	for y in shell.size():
		for x in range(shell[y][0], shell[y][1] + 1):
			var ch := "W"
			if not (inside.call(x - 1, y) and inside.call(x + 1, y) and inside.call(x, y - 1)) or y == shell.size() - 1:
				ch = "w"
			elif y >= shell.size() - 3:
				ch = "w" if y == shell.size() - 2 and (x + y) % 2 == 0 else "W"
			grid[y][x0 + x] = ch
	if flat:
		for ex in [5, 15]:
			grid[3][x0 + ex] = "d"
			grid[3][x0 + ex + 1] = "d"
	else:
		# Lit spot, the hopping dark spot, eyes with a glint.
		for p in [Vector2i(6, 2), Vector2i(7, 2), Vector2i(5, 3)]:
			grid[p.y][x0 + p.x] = "L"
		var sx := 8 if frame == 0 else 10
		for y in [4, 5]:
			grid[y][x0 + sx] = "d"
			grid[y][x0 + sx + 1] = "d"
		for ex in [4, 14]:
			for y in [5, 6, 7]:
				grid[y][x0 + ex] = "R"
				grid[y][x0 + ex + 1] = "R"
			grid[5][x0 + ex] = "P"
		for lx: int in LEGS[frame]:
			for y in [h - 2, h - 1]:
				grid[y][x0 + lx] = "k"
				grid[y][x0 + lx + 1] = "k"
	if glitch >= 0:
		for y in [glitch * 2, glitch * 2 + 1]:
			if y < h:
				var row: Array = grid[y]
				grid[y] = row.slice(row.size() - 2) + row.slice(0, row.size() - 2)
	return grid.map(func(row: Array) -> String: return "".join(PackedStringArray(row)))
