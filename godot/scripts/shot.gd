class_name Shot
extends Enemy

## The projectile spam bots (and later the bosses) fire, from `Shot` in src/entities/enemies.ts: flies
## straight for `life` seconds and dies on a solid tile; a spin destroys it, it vanishes when it hits Clawd
## and does not bounce him. Drawn as the 2D shot's 5 x 5 plus at 1 px, a glowing voxel cross with a white
## core, leaving a trail of sparks.

const RED := Color("#E0605A")
const SHOT_SIZE := 5.0
const CROSS := [".ccc.", "ccccc", "ccWcc", "ccccc", ".ccc."]

static var _meshes := {}

var vel := Vector2.ZERO
var life := 4.0
var color := RED
var _mesh: MeshInstance3D


## A shot from `at` (its centre, level pixels) flying at `velocity` px/s, added to `level`.
static func fire(parent: Level, at: Vector2, velocity: Vector2, shot_color := RED, cancel := true, seconds := 4.0) -> Shot:
	var s := Shot.new()
	s.name = "Shot"
	s.vel = velocity
	s.color = shot_color
	s.cancellable = cancel
	s.life = seconds
	s.position = Px.to3(at + Vector2(0, SHOT_SIZE / 2))
	parent.add_child(s, true)
	return s


func _init() -> void:
	size = Vector2(SHOT_SIZE, SHOT_SIZE)
	projectile = true
	stompable = false
	tokens = 0
	collision_layer = 0
	collision_mask = 0


func _ready() -> void:
	super()
	_mesh = MeshInstance3D.new()
	_mesh.mesh = _cross(color)
	add_child(_mesh)
	_snap()


func _physics_process(dt: float) -> void:
	if Game.frozen():
		return
	tick(dt)
	life -= dt
	pos += vel * dt
	var c := rect().get_center()
	if randf() < 0.5:
		Fx.burst(self, c, {count = 1, speed = 5, life = 0.25, color = [color]})
	if life <= 0 or _hits_solid(Rect2(c - Vector2(1.5, 1.5), Vector2(3, 3))):
		remove()
		return
	_snap()


## The cross is 5 px wide around `pos`: snap its top-left corner to whole pixels.
func _snap() -> void:
	var tl := rect().position
	var snap := tl.round() - tl
	_mesh.position = Vector3(snap.x, -snap.y, 0) * Px.M


func _hits_solid(r: Rect2) -> bool:
	for p in [r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end]:
		if level.tile(p) in [Level.SOLID, Level.CORRUPT]:
			return true
	return false


## Shot down or spun: a small burst in its colour and white.
func _die(_kind: StringName) -> void:
	Fx.burst(self, rect().get_center(), {count = 8, speed = 60, life = 0.3, color = [color, Color.WHITE]})
	queue_free()


static func _cross(c: Color) -> ArrayMesh:
	if not _meshes.has(c):
		_meshes[c] = Voxel.mesh(CROSS, {"c": c, "W": Color.WHITE}, {"c": 4, "W": 6}, Px.M, Voxel.material(1.8))
	return _meshes[c]
