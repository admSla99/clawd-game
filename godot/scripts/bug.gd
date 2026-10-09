extends CharacterBody3D

## The patrolling bug from src/entities/enemies.ts: walks, turns at walls and ledges, dies when stomped.
## Lives inside a Level; the origin is at the feet, horizontally centred. Like the player it moves in
## level pixels (`pos`, `vel`, see Px).

const SPEED := 30.0
const GRAVITY := 1400.0
const MAX_FALL := 400.0
const SIZE := Vector2(16, 11)
const PALETTE := {"W": Color("#D6D6D6"), "w": Color("#8C8C8C"), "d": Color("#555555"), "R": Color("#E0605A"), "r": Color("#8F3A37")}
const DEPTH := {"W": 6, "w": 4, "d": 6, "R": 6, "r": 6}
const FRAMES := [
	["...wwww...", "..wWWWWw..", ".wWWdWWWw.", "wWRWWWWRWw", "wWWWWWWWWw", ".w.w..w.w."],
	["...wwww...", "..wWWWWw..", ".wWWWdWWw.", "wWRWWWWRWw", "wWWWWWWWWw", "..w.ww.w.."],
]
static var MESHES := FRAMES.map(func(f): return Voxel.mesh(f, PALETTE, DEPTH))

var dir := -1.0
var vel := Vector2.ZERO
var prev_pos: Vector2
var t := randf() * 3
var pos: Vector2:
	get: return Px.of(position)
	set(v): position = Px.to3(v)

@onready var level: Level = get_parent()
@onready var body: MeshInstance3D = $Body


func _ready() -> void:
	prev_pos = pos


func _physics_process(dt: float) -> void:
	if Game.frozen():
		return
	prev_pos = pos
	t += dt
	vel.x = dir * SPEED
	vel.y = minf(vel.y + GRAVITY * dt, MAX_FALL)
	velocity = Vector3(vel.x, -vel.y, 0) * Px.M
	move_and_slide()
	vel = Vector2(velocity.x, -velocity.y) / Px.M
	if is_on_wall():
		dir = -dir
	elif is_on_floor() and not _floor_at(Vector2(pos.x + dir * (SIZE.x / 2 + 1), pos.y + 2)):
		dir = -dir
	body.mesh = MESHES[int(t * 6) % 2]
	body.rotation.y = PI if dir > 0 else 0.0


func _floor_at(p: Vector2) -> bool:
	var item := level.tile(p)
	return item >= 0 and item != Level.SPIKE


func rect() -> Rect2:
	return Rect2(pos + Vector2(-SIZE.x / 2, -SIZE.y), SIZE)


func hurtbox() -> Rect2:
	return Rect2(pos + Vector2(-SIZE.x / 2 + 2, -SIZE.y + 3), SIZE - Vector2(4, 3))


## A falling player whose feet were above this line last frame stomps the bug.
func stomp_line() -> float:
	return prev_pos.y - SIZE.y + maxf(8.0, SIZE.y / 2)


func stomped() -> void:
	remove_from_group("enemies")
	queue_free()
