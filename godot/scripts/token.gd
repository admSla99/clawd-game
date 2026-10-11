extends Area3D

## Token from src/entities/collectibles.ts: a spinning, bobbing coin that is collected on touch. Drawn
## by TokenSprite; it bobs and spins in whole pixels.

const COLOR := Color("#F0A585")

var t := randf() * 10

@onready var coin: MeshInstance3D = $Coin


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	coin.mesh = TokenSprite.mesh(t * 4)


func _physics_process(dt: float) -> void:
	if Game.frozen():
		return
	t += dt
	# Spin as whole-pixel widths; the back half of the turn shows the coin mirrored (glint on the other side).
	coin.mesh = TokenSprite.mesh(t * 4)
	coin.rotation.y = PI if fmod(t * 4, TAU) > PI else 0.0
	coin.position.y = roundf(sin(t * 3 + position.x) * 1.5 - 3) * Px.M # -3: centre the 6 px coin


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		var main := get_tree().get_first_node_in_group("main")
		if main:
			main.tokens += 1
		Fx.burst(self, Px.of(global_position), {count = 4, speed = 40, life = 0.25, color = [COLOR]})
		# Sparks are 11 px tall and the coin 6 px: line their centres up.
		SpriteFx.spawn(get_parent(), position + coin.position + Vector3(0, -2.5, 0) * Px.M, TokenSprite.SPARK_MESHES, [0.05, 0.06, 0.07], false, 1.2)
		queue_free()
