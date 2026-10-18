class_name RetryLoop
extends Enemy

## World 3's Retry Loop (`L` in the map; not in TS): a `while (true)` hanging in place, a spinning ring that keeps
## retrying: while Clawd is within RANGE it spawns a bug from its bottom every SPAWN_EVERY seconds, at most MAX_ALIVE
## of its own alive at once (the first 1.5 s after he comes near), until it is destroyed. The level's `z` gates
## (scripts/gate.gd) open once every Retry Loop is gone (group "retry_loops"). Tough: 8 hp (× 3), 40 tokens.
## A voxel loading spinner, 15 x 15 px: a dim ring with a bright head of three segments running round it, faster
## just before a spawn.

const SIZE := Vector2(16, 16)
const RANGE := 300.0
const SPAWN_EVERY := 4.0
const MAX_ALIVE := 3
const PALETTE := {"r": Color("#5A2E2C"), "R": Color("#E0605A"), "W": Color("#FFD6CF"), "k": Color("#2A1716")}
const DEPTH := {"r": 6, "R": 8, "W": 8, "k": 4}

static var FRAMES := _frames()

var timer := 1.5
var spawned: Array = []
var t := 0.0
var _body: MeshInstance3D


func _init() -> void:
	size = SIZE
	hp = 8
	tokens = 8 * TOKEN_FACTOR
	collision_layer = 0
	collision_mask = 0


func _ready() -> void:
	super()
	add_to_group("retry_loops")
	_body = MeshInstance3D.new()
	_body.mesh = FRAMES[0]
	add_child(_body)


func _die(kind: StringName) -> void:
	remove_from_group("retry_loops")
	super(kind)


func _physics_process(dt: float) -> void:
	if Game.frozen() or held():
		return
	tick(dt)
	t += dt
	spawned = spawned.filter(func(b): return is_instance_valid(b) and not b.dead)
	var player: Player = get_tree().get_first_node_in_group("player")
	var near := player != null and player.in_play() and player.pos.distance_to(pos) < RANGE
	if near:
		timer -= dt
		if timer <= 0:
			timer = SPAWN_EVERY
			if spawned.size() < MAX_ALIVE:
				_spawn()
	else:
		timer = maxf(timer, 1.5)
	_update_visual()


## A bug drops out of its bottom (world 3's tough bug: 2 hp × 3).
func _spawn() -> void:
	var bug: Enemy = load("res://scenes/bug.tscn").instantiate()
	level.add_child(bug)
	bug.pos = pos
	bug.hp = 2.0 * HP_FACTOR
	bug.set("dir", -1.0 if randf() < 0.5 else 1.0)
	spawned.append(bug)
	Sound.play("shoot")
	Fx.burst(self, pos + Vector2(0, -2), {count = 10, speed = 70, life = 0.35, color = [PALETTE.R, PALETTE.W]})


func _update_visual() -> void:
	# Faster in the last second before a spawn.
	var speed := 14.0 if timer < 1.0 else 6.0
	_body.mesh = FRAMES[int(t * speed) % FRAMES.size()]
	set_tint(_body)
	set_rim(_body, 0.5)
	var snap := pos.round() - pos
	_body.position = Vector3(snap.x, -snap.y, 0) * Px.M


## Eight frames of the spinner: the ring (radius 6 round the middle of a 15 x 15 grid) with its head at 1/8 turns.
static func _frames() -> Array:
	var out := []
	for f in 8:
		var rows := []
		for y in 15:
			var r := ""
			for x in 15:
				var d := Vector2(x - 7, y - 7)
				var ch := "."
				if absf(d.length() - 6.0) < 0.75:
					var a := fposmod(d.angle() - f * TAU / 8, TAU)
					ch = "W" if a < 0.35 else "R" if a < 1.2 else "r"
				elif d.length() < 2.0:
					ch = "k"
				r += ch
			rows.append(r)
		out.append(Voxel.mesh(rows, PALETTE, DEPTH, Px.M, Voxel.material(1.4)))
	return out
