extends CharacterBody2D

## The patrolling bug from src/entities/enemies.ts: walks, turns at walls and ledges, dies when stomped.
## Lives inside a level's TileMapLayer; the origin is at the feet, horizontally centred.

const SPEED := 30.0
const GRAVITY := 1400.0
const MAX_FALL := 400.0
const SIZE := Vector2(16, 11)
const PALETTE := {"W": Color("#D6D6D6"), "w": Color("#8C8C8C"), "d": Color("#555555"), "R": Color("#E0605A"), "r": Color("#8F3A37")}
const FRAMES := [
	["...wwww...", "..wWWWWw..", ".wWWdWWWw.", "wWRWWWWRWw", "wWWWWWWWWw", ".w.w..w.w."],
	["...wwww...", "..wWWWWw..", ".wWWWdWWw.", "wWRWWWWRWw", "wWWWWWWWWw", "..w.ww.w.."],
]

var dir := -1.0
var prev_position: Vector2
var t := randf() * 3

@onready var terrain: TileMapLayer = get_parent()


func _ready() -> void:
	prev_position = position


func _physics_process(dt: float) -> void:
	if Game.frozen():
		return
	prev_position = position
	t += dt
	velocity.x = dir * SPEED
	velocity.y = minf(velocity.y + GRAVITY * dt, MAX_FALL)
	move_and_slide()
	if is_on_wall():
		dir = -dir
	elif is_on_floor() and not _floor_at(Vector2(position.x + dir * (SIZE.x / 2 + 1), position.y + 2)):
		dir = -dir
	queue_redraw()


func _floor_at(p: Vector2) -> bool:
	var data := terrain.get_cell_tile_data(terrain.local_to_map(p))
	return data != null and data.get_custom_data("kind") != "spike"


func rect() -> Rect2:
	return Rect2(position + Vector2(-SIZE.x / 2, -SIZE.y), SIZE)


func hurtbox() -> Rect2:
	return Rect2(position + Vector2(-SIZE.x / 2 + 2, -SIZE.y + 3), SIZE - Vector2(4, 3))


## A falling player whose feet were above this line last frame stomps the bug.
func stomp_line() -> float:
	return prev_position.y - SIZE.y + maxf(8.0, SIZE.y / 2)


func stomped() -> void:
	remove_from_group("enemies")
	queue_free()


func _draw() -> void:
	# Rows glitch sideways now and then, like Bug.draw() in src/entities/enemies.ts.
	var seed := floori(Game.time * 10)
	var x := int(position.x - SIZE.x / 2)
	PixelArt.draw(self, FRAMES[int(t * 6) % 2], PALETTE, Vector2(0, 1), {
		px = 2, fill = 0.8, flip = dir > 0,
		glitch = func(row: int) -> float: return 1.0 if DotNoise.hash2(row, seed, x) > 0.93 else 0.0,
	})
