class_name Injector
extends Enemy

## The prompt injector from `Injector` in src/entities/enemies2.ts (`I` in the map): sits for a moment, then,
## while Clawd is within 260 px, hops at him (330 px/s up, at most 110 px/s across), bouncing off walls. When
## destroyed it splits into two 1-hp bugs that run off left and right at 40 px/s. Drawn at 1 px: a magenta
## blob with a dark rim, a pale top and a ">_" prompt that blinks white and pink. Like the 2D draw it squashes
## wide before a hop and stretches tall in the air, as whole-pixel sizes (mesh() builds each one).

const SIZE := Vector2(16, 14)
const RANGE := 260.0
const GRAVITY := 1300.0
const MAX_FALL := 420.0
const HOP := 330.0
const HOP_X := 110.0
const BUG_SPEED := 40.0
const MAGENTA := Color("#C25BD6")
const PINK := Color("#E3A3EE")
const PALETTE := {
	"m": MAGENTA,
	"p": PINK, # top
	"P": Color("#F6DDFA"), # lit spot
	"d": Color("#7A3487"), # rim
}
const DEPTH := {"m": 12, "p": 12, "P": 12, "d": 10, "T": 14}
const GLYPH := ["#......", ".#.....", "..#....", ".#.....", "#...###"]

static var _meshes := {}

var vel := Vector2.ZERO
var timer := 0.8 + randf() * 0.6
var grounded := false
var t := 0.0
var _body: MeshInstance3D


func _init() -> void:
	size = SIZE
	hp = 5
	tokens = 3 * TOKEN_FACTOR
	collision_layer = 0
	collision_mask = 0


func _ready() -> void:
	super()
	_body = MeshInstance3D.new()
	add_child(_body)
	_update_visual()


## Its own tokens and the two bugs' it leaves behind.
func token_total() -> int:
	return tokens + 2 * 2 * TOKEN_FACTOR


func _physics_process(dt: float) -> void:
	if Game.frozen():
		return
	tick(dt)
	t += dt
	var player: Player = get_tree().get_first_node_in_group("player")
	var dx := player.pos.x - pos.x if player and player.in_play() else INF
	vel.y = minf(vel.y + GRAVITY * dt, MAX_FALL)
	if move_x(vel.x * dt):
		vel.x = -vel.x * 0.5
	grounded = move_y(vel.y * dt) == 1
	if grounded:
		vel = Vector2.ZERO
		timer -= dt
		if timer <= 0 and absf(dx) < RANGE:
			vel = Vector2(signf(dx) * minf(HOP_X, absf(dx) * 1.3), -HOP)
			timer = 1 + randf() * 0.5
	if pos.y > level.pixel_size.y + 50:
		remove()
		return
	_update_visual()


## Splits into two bugs (1 hp even in world 2, times HP_FACTOR like every enemy) that run off to either side.
func _die(_kind: StringName) -> void:
	for s in [-1.0, 1.0]:
		var bug: Bug = load(Level.BUG).instantiate()
		bug.name = "Bug"
		bug.position = Px.to3(pos + Vector2(s * 6, 0))
		bug.dir = s
		bug.speed = BUG_SPEED
		bug.hp = HP_FACTOR
		level.add_child(bug, true)
	queue_free()


## Squashed wide just before a hop, stretched tall in the air (`squash` in the 2D draw()).
func _update_visual() -> void:
	var squash := 1 + maxf(0.0, 0.4 - timer) * 0.6 if grounded else 0.9
	var w := 2 * roundi(SIZE.x / 2 * squash)
	var h := roundi(SIZE.y / squash)
	_body.mesh = mesh(w, h, fmod(Game.time, 1.0) < 0.5)
	set_tint(_body)
	set_rim(_body, 0.4)
	var snap := pos.round() - pos
	_body.position = Vector3(snap.x, -snap.y, 0) * Px.M


## The blob `w` x `h` px with the prompt in white (`bright`) or pink.
static func mesh(w: int, h: int, bright: bool) -> ArrayMesh:
	var key := Vector3i(w, h, int(bright))
	if not _meshes.has(key):
		var palette := PALETTE.duplicate()
		palette["T"] = Color.WHITE if bright else PINK
		_meshes[key] = Voxel.mesh(_rows(w, h), palette, DEPTH, Px.M)
	return _meshes[key]


## A rounded blob: corners cut on the top four and bottom two rows, a dark rim, the top quarter pale with a
## lit spot, and ">_" centred at 45 % of its height like the 2D text.
static func _rows(w: int, h: int) -> Array:
	var cuts := {0: w / 4, 1: w / 8, 2: 1, 3: 1, h - 2: 1, h - 1: w / 8}
	var g := []
	for yy in h:
		var row := []
		row.resize(w)
		row.fill(".")
		var cut: int = cuts.get(yy, 0)
		for xx in range(cut, w - cut):
			row[xx] = "m"
		g.append(row)
	var inside := func(x: int, y: int) -> bool:
		return x >= 0 and y >= 0 and x < w and y < h and g[y][x] != "."
	var rim := []
	for yy in h:
		for xx in w:
			if g[yy][xx] == "." :
				continue
			if not (inside.call(xx + 1, yy) and inside.call(xx - 1, yy) and inside.call(xx, yy + 1) and inside.call(xx, yy - 1)):
				rim.append(Vector2i(xx, yy))
			elif yy <= h / 4:
				g[yy][xx] = "p"
	for r: Vector2i in rim:
		g[r.y][r.x] = "d"
	for yy in [2, 3]:
		var first := (g[yy] as Array).find("p")
		if first >= 0:
			g[yy][first] = "P"
			if yy == 2:
				g[yy][first + 1] = "P"
	var gy := roundi(h * 0.45) - 2
	var gx := w / 2 - 3
	for yy in 5:
		for xx in 7:
			if GLYPH[yy][xx] == "#":
				g[gy + yy][gx + xx] = "T"
	return g.map(func(r: Array) -> String: return "".join(PackedStringArray(r)))
