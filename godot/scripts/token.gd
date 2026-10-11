class_name Token
extends Area3D

## Token from src/entities/collectibles.ts: a spinning, bobbing coin that is collected on touch. Drawn
## by TokenSprite; it bobs and spins in whole pixels.
## A popped token (pop(), dropped by a defeated enemy) jumps out and then homes in on Clawd, like
## `new Token(x, y, true)`. Unlike TS it also flies sideways and starts homing only after a moment, so a
## handful of them burst out as a fountain instead of one clump, and they can't be picked up for a moment.

const COLOR := Color("#F0A585")
const SCENE := "res://scenes/token.tscn"
## Homing speed and the gravity before it takes over, px/s and px/s², like the TS token.
const HOMING := 260.0
const GRAVITY := 400.0
## Seconds until a popped token flies only towards Clawd.
const HOMING_RAMP := 0.6
## Seconds before a popped token can be picked up, so the burst is seen even when Clawd stands on it.
const PICKUP_DELAY := 0.3

var t := randf() * 10
var popped := false
var vel := Vector2.ZERO
var age := 0.0
## Where a popped token really is, in level pixels; the node sits on the nearest whole pixel.
var fpos := Vector2.ZERO
var collected := false

@onready var coin: MeshInstance3D = $Coin


## A popped token at `at` (level pixels) in `parent`, flying out at a random angle.
static func pop(parent: Node3D, at: Vector2) -> Token:
	var token: Token = load(SCENE).instantiate()
	token.popped = true
	token.vel = Vector2(randf_range(-90, 90), -120 - randf() * 60)
	token.fpos = at
	token.position = Px.to3(at.round())
	parent.add_child(token)
	return token


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	coin.mesh = TokenSprite.mesh(t * 4)


func _physics_process(dt: float) -> void:
	if Game.frozen():
		return
	t += dt
	# Token Magnet (the shop): a token within reach of Clawd comes loose and flies to him (`g.magnet` in TS).
	if not popped and Progress.upgrade("magnet") > 0:
		var player: Player = get_tree().get_first_node_in_group("player")
		if player and player.visible and Px.of(position).distance_to(player.pos + Vector2(0, -9)) < Shop.MAGNET:
			popped = true
			fpos = Px.of(position)
			age = HOMING_RAMP
	if popped:
		_home(dt)
	# Spin as whole-pixel widths; the back half of the turn shows the coin mirrored (glint on the other side).
	coin.mesh = TokenSprite.mesh(t * 4)
	coin.rotation.y = PI if fmod(t * 4, TAU) > PI else 0.0
	var bob := 0.0 if popped else sin(t * 3 + position.x) * 1.5
	coin.position.y = roundf(bob - 3) * Px.M # -3: centre the 6 px coin


## Token.update() for a free token: falls under gravity at first, then turns into a straight flight to
## Clawd's middle. Snapped to whole pixels like everything that moves.
func _home(dt: float) -> void:
	age += dt
	var player: Player = get_tree().get_first_node_in_group("player")
	if player == null or player.frozen:
		return
	var p := fpos
	var d := player.pos + Vector2(0, -8) - p
	var dir := d / maxf(d.length(), 1.0)
	var k := minf(1.0, age / HOMING_RAMP)
	vel.y += GRAVITY * dt
	p += (vel * (1 - k) + dir * HOMING * k) * dt
	fpos = p
	position = Px.to3(p.round())
	# A moving Area3D only notices bodies on the next physics step (and not one it already overlaps when the
	# pickup delay ends); check the hitbox itself.
	if age >= PICKUP_DELAY and Rect2(p - Vector2(4, 4), Vector2(8, 8)).intersects(player.hitbox()):
		collect()


func _on_body_entered(body: Node3D) -> void:
	if body is Player and not popped:
		collect()


func collect() -> void:
	if collected:
		return
	collected = true
	var main := get_tree().get_first_node_in_group("main")
	if main:
		main.collect_token(Px.of(global_position) - Vector2(0, coin.position.y / Px.M + 3))
	Fx.burst(self, Px.of(global_position), {count = 4, speed = 40, life = 0.25, color = [COLOR]})
	# Sparks are 11 px tall and the coin 6 px: line their centres up.
	SpriteFx.spawn(get_parent(), position + coin.position + Vector3(0, -2.5, 0) * Px.M, TokenSprite.SPARK_MESHES, [0.05, 0.06, 0.07], false, 1.2)
	queue_free()
