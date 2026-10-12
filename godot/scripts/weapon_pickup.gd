class_name WeaponPickup
extends Node3D

## The Token Blaster lying in the arena after the first boss, from `WeaponPickup` in src/entities/pickups.ts:
## it hovers in a dithered beam of orange light from above, sparks rising round it and "?!" blinking over it;
## touching it (its 20 x 16 px box against Clawd's hitbox) calls Main.weapon_found(). In 2.5D the gun is a
## voxel model (GunSprite at 2 px cells) that bobs and turns slowly about its own middle, lit by a GlowLight.

const SIZE := Vector2(20, 16)
const ORANGE := Color("#D97757")
const ORANGE_LIGHT := Color("#F0A585")

var weapon := "blaster"
var t := 0.0
var taken := false
var _gun: MeshInstance3D
var _pivot: Node3D
var _beam: MeshInstance3D


## A pickup standing on `bottom` at `x` (level pixels), like `new WeaponPickup(x, bottom)`.
static func create(parent: Node3D, x: float, bottom: float, id := "blaster") -> WeaponPickup:
	var p := WeaponPickup.new()
	p.name = "WeaponPickup"
	p.weapon = id
	p.position = Px.to3(Vector2(x, bottom))
	parent.add_child(p, true)
	return p


func _ready() -> void:
	add_to_group("world_text")
	_pivot = Node3D.new()
	add_child(_pivot)
	_gun = MeshInstance3D.new()
	_gun.mesh = GunSprite.mesh(weapon)
	# Turn about the gun's middle, not its grip.
	_gun.position.x = 0.0
	_pivot.add_child(_gun)
	var quad := QuadMesh.new()
	quad.size = Vector2(18, 300) * Px.M
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/beam.gdshader")
	mat.set_shader_parameter("size", Vector2(18, 300))
	mat.set_shader_parameter("fade", 0.35)
	quad.material = mat
	_beam = MeshInstance3D.new()
	_beam.mesh = quad
	_beam.position = Vector3(0, (150 + 0) * Px.M, -0.3)
	add_child(_beam)
	var glow := GlowLight.new()
	glow.radius = 2.4
	glow.energy = 0.9
	glow.position = Vector3(0, 1.0, 0.6)
	add_child(glow)
	_update_visual()


func feet() -> Vector2:
	return Px.of(position)


## Its box, like the 2D pickup's (x - 10, bottom - 26, 20, 16).
func rect() -> Rect2:
	return Rect2(feet() + Vector2(-SIZE.x / 2, -26), SIZE)


func _physics_process(dt: float) -> void:
	if Game.frozen() or taken:
		return
	t += dt
	if randf() < dt * 25:
		Fx.burst(self, feet() + Vector2(randf_range(-8, 8), -10), {count = 1, speed = 10, vy = -40, life = 0.8, color = [ORANGE, ORANGE_LIGHT]})
	var player: Player = get_tree().get_first_node_in_group("player")
	if player and player.in_play() and rect().intersects(player.hitbox()):
		taken = true
		var main := get_tree().get_first_node_in_group("main")
		if main:
			main.weapon_found(self)
		queue_free()
		return
	_update_visual()


func _update_visual() -> void:
	# Bobbing like `cy = y + 8 + sin(2.5 t) * 2`, in whole pixels; turning about its middle.
	_pivot.position.y = (18 - roundf(sin(t * 2.5) * 2)) * Px.M
	_pivot.rotation.y = t * 1.2
	_pivot.rotation.z = sin(t) * 0.15


## "?!" over it, blinking.
func overlay_draw(o: Overlay) -> void:
	var a := 0.6 + sin(t * 5) * 0.4
	var v := o.to_view(feet() + Vector2(0, -18 - 16))
	PixelFont.draw_centred(o, "?!", v.x, v.y, Color(ORANGE_LIGHT, a))
