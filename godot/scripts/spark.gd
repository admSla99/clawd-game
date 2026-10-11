class_name Spark
extends Node3D

## A spark from src/entities/collectibles.ts (`S` in the map), the level's rare collectible. drawSpark() in
## src/render/shapes.ts is a dot in the middle with dotted arms out in the four directions (3 dots, flickering
## to 4), four diagonal dots and, while the arms are long, four fainter ones further out. Here those dots are
## glowing 1 px voxels around a white-hot core, bobbing 2 px, in front of a dithered orange halo
## (shaders/halo.gdshader, the 2D game's soft glow circle) that breathes, with a GlowLight that warms the ground.
## Touching it (14 x 14 px box) calls Main.collect_spark(). One collected on an earlier run (Progress) is a
## ghost: every other dot, dim and not glowing, still collectible.

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

static var MATERIAL := Voxel.material(1.7)
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
	quad.size = Vector2(24, 24) * Px.M
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/halo.gdshader")
	quad.material = mat
	_halo = MeshInstance3D.new()
	_halo.mesh = quad
	# Just behind the spark.
	_halo.position.z = -0.1
	add_child(_halo)
	_body = MeshInstance3D.new()
	add_child(_body)
	_glow = GlowLight.new()
	_glow.radius = 1.4
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
	if player and player.visible and Rect2(feet() + RECT.position, RECT.size).intersects(player.hitbox()):
		var main := get_tree().get_first_node_in_group("main")
		if main:
			main.collect_spark(self)
		queue_free()
		return
	_update_visual()


func _update_visual() -> void:
	var long := sin(t * 6) > 0.3
	_body.mesh = mesh(4 if long else 3, ghost)
	# The 19 px grid's centre sits CENTRE_Y above the feet, bobbing 2 px in whole pixels.
	var bob := roundf(sin(t * 2.5) * 2)
	_body.position.y = (CENTRE_Y - 9 + bob) * Px.M
	_halo.visible = not ghost
	# The quad's centre on the spark's centre pixel (24 px quad: its centre is a pixel corner).
	_halo.position.y = (CENTRE_Y + bob - 0.5) * Px.M
	(_halo.mesh.material as ShaderMaterial).set_shader_parameter("pulse", 0.5 + sin(Game.time * 3) * 0.5)
	_glow.energy = 0.0 if ghost else 0.5 + sin(Game.time * 3) * 0.15


## The dots of drawSpark() as text rows, 19 x 19 px: dot index i lies 2|i| + 1 px out, so the arms are dotted;
## `arm` 3 or 4. "W" core, "L" light orange, "O" orange, "h" the fainter outer diagonals; a ghost keeps only
## the dots whose index sum is even, like `ghost` in drawSpark().
static func rows(arm: int, ghost := false) -> Array:
	var grid := []
	for y in 19:
		var row := []
		row.resize(19)
		row.fill(".")
		grid.append(row)
	var put := func(ix: int, iy: int, ch: String) -> void:
		if ghost and (ix + iy) % 2 != 0:
			return
		var x := 9 + (signi(ix) * (2 * absi(ix) + 1) if ix != 0 else 0)
		var y := 9 + (signi(iy) * (2 * absi(iy) + 1) if iy != 0 else 0)
		grid[y][x] = ch
	# Core: a plus of light orange around a white middle.
	for d in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]:
		grid[9 + d.y][9 + d.x] = "L"
	grid[9][9] = "W"
	for i in range(1, arm + 1):
		var ch := "L" if i == 1 else "O"
		put.call(i, 0, ch)
		put.call(-i, 0, ch)
		put.call(0, i, ch)
		put.call(0, -i, ch)
	for d in [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		put.call(d.x, d.y, "O")
		if arm > 3:
			put.call(d.x * 2, d.y * 2, "h")
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
