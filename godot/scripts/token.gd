extends Area3D

## Token from src/entities/collectibles.ts: a spinning, bobbing coin that is collected on touch.

const COLOR := Color("#FFD34D")
const ROWS := [".TT.", "TTTT", "TTTT", ".TT."]
static var MESH := Voxel.mesh(ROWS, {"T": COLOR}, {}, Px.M, Voxel.material(1.8))

var t := randf() * 10

@onready var coin: MeshInstance3D = $Coin


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	coin.mesh = MESH


func _physics_process(dt: float) -> void:
	if Game.frozen():
		return
	t += dt
	coin.rotation.y = t * 4
	coin.position.y = (sin(t * 3 + position.x) * 1.5 - 2) * Px.M


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		Fx.burst(self, Px.of(global_position), {count = 4, speed = 40, life = 0.25, color = [COLOR]})
		queue_free()
