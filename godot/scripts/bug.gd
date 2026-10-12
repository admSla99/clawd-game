class_name Bug
extends Enemy

## The patrolling bug from src/entities/enemies.ts: walks, turns at walls and ledges. A stomp or a pound
## flattens it, anything else just destroys it (Enemy.die() pops the tokens and the burst).

const SPEED := 30.0
const GRAVITY := 1400.0
const MAX_FALL := 400.0
const SIZE := Vector2(16, 11)
## The sprite sits 1 px below the feet, like drawSprite(..., bottom + 1) in the 2D game.
const SPRITE_Y := -1.0

var dir := -1.0
## Walking speed: SPEED, or 40 px/s for the bugs an Injector splits into.
var speed := SPEED
var vel := Vector2.ZERO
var t := randf() * 3

@onready var body: MeshInstance3D = $Body


func _init() -> void:
	size = SIZE


func _physics_process(dt: float) -> void:
	if Game.frozen():
		return
	tick(dt)
	t += dt
	vel.x = dir * speed
	vel.y = minf(vel.y + GRAVITY * dt, MAX_FALL)
	velocity = Vector3(vel.x, -vel.y, 0) * Px.M
	move_and_slide()
	vel = Vector2(velocity.x, -velocity.y) / Px.M
	if is_on_wall():
		dir = -dir
	elif is_on_floor() and not _floor_at(Vector2(pos.x + dir * (SIZE.x / 2 + 1), pos.y + 2)):
		dir = -dir
	if pos.y > level.pixel_size.y + 50:
		remove()
		return
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
	set_rim(body)
	set_tint(body)
	var snap := pos.round() - pos
	body.position = Vector3(snap.x, -snap.y + SPRITE_Y, 0) * Px.M
	body.rotation.y = PI if dir > 0 else 0.0


func _floor_at(p: Vector2) -> bool:
	var item := level.tile(p)
	return item >= 0 and item != Level.SPIKE


func hurtbox() -> Rect2:
	return Rect2(pos + Vector2(-SIZE.x / 2 + 2, -SIZE.y + 3), SIZE - Vector2(4, 3))


## A stomp or a pound leaves the flattened shell behind (a white flash, then grey; hitstop holds it).
func _die(kind: StringName) -> void:
	if kind == &"stomp" or kind == &"pound":
		var at := Px.to3(pos.round()) + Vector3(0, SPRITE_Y * Px.M, 0)
		SpriteFx.spawn(level, at, [BugSprite.mesh(0, -1, true, true), BugSprite.mesh(0, -1, true)], [0.06, 0.22], dir > 0)
	queue_free()
