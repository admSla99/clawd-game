class_name Spark
extends Node3D

## A spark from src/entities/collectibles.ts (`S` in the map), the level's rare collectible. drawSpark() in
## src/render/shapes.ts is a dot in the middle with dotted arms out in the four directions (3 dots, flickering
## to 4), four diagonal dots and, while the arms are long, four fainter ones further out. At the port's 1 px
## those dots were too faint to spot in the dark levels, so here the star is solid: a white-hot core, four rays
## that taper from light orange to a faint tip and flicker between 7 and 9 px long, and short diagonal rays,
## all glowing strongly (bloom), bobbing 2 px, in front of a dithered orange halo (shaders/halo.gdshader, the 2D
## game's glow circle, made larger and brighter) that breathes, with a GlowLight that warms the ground and small
## embers drifting up from it. Touching it (14 x 14 px box) calls Main.collect_spark(). One collected on an
## earlier run (Progress) is a ghost: drawSpark()'s dotted star with every other dot, muted, no glow or halo.

## Pickup box relative to the feet (x - 7, bottom - 15 in TS).
const RECT := Rect2(-7, -15, 14, 14)
## Height of the spark's centre above the feet.
const CENTRE_Y := 8
const ORANGE := Color("#D97757")
const ORANGE_LIGHT := Color("#F0A585")
## A ghost is the orange at about 55 % over the night (the 2D globalAlpha 0.55), not glowing.
const GHOST := Color("#A35E48")
## A small spark for the HUD, the map and the results (drawSpark at half size), 9 x 9 px.
const ICON := [
	"....o....",
	"....o....",
	"..o.L.o..",
	"....L....",
	"ooLLWLLoo",
	"....L....",
	"..o.L.o..",
	"....o....",
	"....o....",
]

static var MATERIAL := Voxel.material(2.4)
## Size of the star's grid and its centre pixel.
const GRID := 21
const C := 10
static var _meshes := {}

## Order among the level's sparks (Spawn.index), set by the level converter.
@export var index := 0
var ghost := false
var t := randf() * 10
var _body: MeshInstance3D
var _glow: GlowLight
var _halo: MeshInstance3D


func _ready() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(32, 32) * Px.M
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/halo.gdshader")
	mat.set_shader_parameter("size", Vector2(32, 32))
	mat.set_shader_parameter("radius", 15.0)
	quad.material = mat
	_halo = MeshInstance3D.new()
	_halo.mesh = quad
	# Just behind the spark.
	_halo.position.z = -0.1
	add_child(_halo)
	_body = MeshInstance3D.new()
	add_child(_body)
	_glow = GlowLight.new()
	_glow.radius = 2.0
	_glow.position = Vector3(0, CENTRE_Y * Px.M, 0.5)
	add_child(_glow)
	_update_visual()


## Level pixels of the feet.
func feet() -> Vector2:
	return Px.of(position)


func _physics_process(dt: float) -> void:
	if Game.frozen():
		return
	t += dt
	var player: Player = get_tree().get_first_node_in_group("player")
	if player and player.in_play() and Rect2(feet() + RECT.position, RECT.size).intersects(player.hitbox()):
		var main := get_tree().get_first_node_in_group("main")
		if main:
			main.collect_spark(self)
		queue_free()
		return
	# Embers drifting up from it, a few a second.
	if not ghost and randf() < dt * 5:
		var a := randf() * TAU
		Fx.burst(self, feet() + Vector2(cos(a) * 6, -CENTRE_Y + sin(a) * 6), {count = 1, speed = 8, life = 0.7, color = [ORANGE_LIGHT, ORANGE], vy = -18})
	_update_visual()


func _update_visual() -> void:
	var long := sin(t * 6) > 0.3
	_body.mesh = mesh(4 if long else 3, ghost)
	# The grid's centre pixel sits CENTRE_Y above the feet, bobbing 2 px in whole pixels.
	var bob := roundf(sin(t * 2.5) * 2)
	_body.position.y = (CENTRE_Y - C + bob) * Px.M
	_halo.visible = not ghost
	# The quad's centre on the spark's centre pixel (32 px quad: its centre is a pixel corner).
	_halo.position.y = (CENTRE_Y + bob - 0.5) * Px.M
	(_halo.mesh.material as ShaderMaterial).set_shader_parameter("pulse", 0.5 + sin(Game.time * 3) * 0.5)
	_glow.energy = 0.0 if ghost else 0.9 + sin(Game.time * 3) * 0.25


## The star as text rows, GRID x GRID px around pixel (C, C); `arm` 3 or 4 (drawSpark()'s flicker). "W" white
## core, "L" light orange, "O" orange, "h" faint tips. A ghost is drawSpark()'s dotted star instead (dot index i
## lies 2|i| + 1 px out) with only the dots whose index sum is even.
static func rows(arm: int, ghost := false) -> Array:
	var grid := []
	for y in GRID:
		var row := []
		row.resize(GRID)
		row.fill(".")
		grid.append(row)
	var at := func(x: int, y: int, ch: String) -> void:
		grid[C + y][C + x] = ch
	if ghost:
		var put := func(ix: int, iy: int, ch: String) -> void:
			if (ix + iy) % 2 == 0:
				at.call(signi(ix) * (2 * absi(ix) + 1) if ix != 0 else 0, signi(iy) * (2 * absi(iy) + 1) if iy != 0 else 0, ch)
		for d in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]:
			at.call(d.x, d.y, "L")
		at.call(0, 0, "W")
		for i in range(1, arm + 1):
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				put.call(d.x * i, d.y * i, "L" if i == 1 else "O")
		for d in [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
			put.call(d.x, d.y, "O")
		return grid.map(func(r: Array) -> String: return "".join(PackedStringArray(r)))
	# Rays: 9 px long while the arms are long, 7 while short; 3 px wide next to the core.
	var length := 9 if arm > 3 else 7
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var side := Vector2i(d.y, d.x)
		for i in range(2, length + 1):
			at.call(d.x * i, d.y * i, "L" if i <= 3 else "O" if i <= length - 2 else "h")
			if i <= 3:
				at.call(d.x * i + side.x, d.y * i + side.y, "O")
				at.call(d.x * i - side.x, d.y * i - side.y, "O")
	# Diagonal rays.
	for d in [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		at.call(d.x * 2, d.y * 2, "L")
		at.call(d.x * 3, d.y * 3, "O")
		if arm > 3:
			at.call(d.x * 4, d.y * 4, "h")
	# Core: white plus with light orange corners.
	for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		at.call(d.x, d.y, "W")
	for d in [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		at.call(d.x, d.y, "L")
	return grid.map(func(r: Array) -> String: return "".join(PackedStringArray(r)))


static func mesh(arm: int, ghost := false) -> ArrayMesh:
	var key := "%d %s" % [arm, ghost]
	if not _meshes.has(key):
		var pal := {"W": Color("#FFF1E6"), "L": ORANGE_LIGHT, "O": ORANGE, "h": ORANGE.darkened(0.45)}
		if ghost:
			pal = {"W": GHOST.lightened(0.3), "L": GHOST, "O": GHOST, "h": GHOST.darkened(0.3)}
		_meshes[key] = Voxel.mesh(rows(arm, ghost), pal, {"W": 2, "L": 2, "O": 2, "h": 2}, Px.M, Voxel.MATERIAL if ghost else MATERIAL)
	return _meshes[key]


## The small spark as a texture; `dim` greys it out (not found yet).
static func icon(dim := false) -> ImageTexture:
	var key := "icon %s" % dim
	if not _meshes.has(key):
		var pal := {"W": Color("#FFF1E6"), "L": ORANGE_LIGHT, "o": ORANGE}
		if dim:
			pal = {"W": Color("#5A5A5A"), "L": Color("#4A4A4A"), "o": Color("#3A3A3A")}
		_meshes[key] = _texture(ICON, pal)
	return _meshes[key]


static func _texture(grid: Array, pal: Dictionary) -> ImageTexture:
	var img := Image.create_empty(grid[0].length(), grid.size(), false, Image.FORMAT_RGBA8)
	for y in grid.size():
		for x in grid[y].length():
			if pal.has(grid[y][x]):
				img.set_pixel(x, y, pal[grid[y][x]])
	return ImageTexture.create_from_image(img)
