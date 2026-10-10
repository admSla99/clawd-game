extends CharacterBody3D

## The patrolling bug from src/entities/enemies.ts: walks, turns at walls and ledges, dies when stomped.
## Lives inside a Level; the origin is at the feet, horizontally centred. Like the player it moves in
## level pixels (`pos`, `vel`, see Px).

const SPEED := 30.0
const GRAVITY := 1400.0
const MAX_FALL := 400.0
const SIZE := Vector2(16, 11)
## The sprite sits 1 px below the feet, like drawSprite(..., bottom + 1) in the 2D game.
const SPRITE_Y := -1.0

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
	_update_visual()


## BugSprite frame (walk cycle at 6 fps, the row glitch re-rolled 10 times a second like the 2D draw()),
## snapped to whole pixels like Clawd.
func _update_visual() -> void:
	var seed := floori(Game.time * 10)
	var glitch := -1
	for r in 6:
		if DotNoise.hash2(r, seed, int(pos.x - SIZE.x / 2)) > 0.93:
			glitch = r
			break
	body.mesh = BugSprite.mesh(int(t * 6) % 2, glitch)
	var rim := GlowLight.rim_for(self, global_position + Vector3(0, 0.35, 0))
	body.set_instance_shader_parameter("rim_light", rim.light)
	body.set_instance_shader_parameter("rim_energy", rim.energy)
	var snap := pos.round() - pos
	body.position = Vector3(snap.x, -snap.y + SPRITE_Y, 0) * Px.M
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


## Leaves the flattened shell behind (a white flash, then grey; hitstop holds it) and frees the bug.
func stomped() -> void:
	remove_from_group("enemies")
	var at := Px.to3(pos.round()) + Vector3(0, SPRITE_Y * Px.M, 0)
	SpriteFx.spawn(level, at, [BugSprite.mesh(0, -1, true, true), BugSprite.mesh(0, -1, true)], [0.06, 0.22], dir > 0)
	queue_free()
