extends Area2D

## Token from src/entities/collectibles.ts: a spinning, bobbing coin that is collected on touch.

const COLOR := Color("#FFD34D")

# Halo drawn by GlowLayer (group "glow").
var glow_color := Color(COLOR.r * 0.3, COLOR.g * 0.3, COLOR.b * 0.3)
var glow_radius := 7.0
var glow_offset := Vector2.ZERO

var t := randf() * 10


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(dt: float) -> void:
	if Game.frozen():
		return
	t += dt
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		Fx.burst(self, global_position, {count = 4, speed = 40, life = 0.25, color = [COLOR]})
		queue_free()


func _draw() -> void:
	var w := absf(cos(t * 4))
	var y := sin(t * 3 + position.x) * 1.5
	var hw := maxf(0.5, 2 * w)
	draw_rect(Rect2(-hw, y - 1, hw * 2, 2), COLOR)
	draw_rect(Rect2(-maxf(0.5, w), y - 2, maxf(1, 2 * w), 4), COLOR)
