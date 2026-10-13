class_name SubAgent
extends Node3D

## A lost sub-agent from src/entities/collectibles.ts (`A` in the map): a small Clawd, the 2D game's 13 x 10
## frame at 1 px as a voxel model 6 px deep, standing on the gameplay plane and facing Clawd. It waves (arms up
## and down three times a second) and a "HELP" bubble above it blinks on and off (Overlay world text). Touching
## it (its 14 x 12 px box against Clawd's hitbox) rescues it: Main.rescue_agent(), then it hops for 0.7 s and
## rides a dithered beam of orange light up out of the level, shedding sparks, gone after 1.1 s. One rescued
## on an earlier run (Progress) is a ghost: tinted #6E5A52, still rescuable.

const RECT := Rect2(-7, -12, 14, 12)
const GHOST := Color("#6E5A52")
const ORANGE := Color("#D97757")
const ORANGE_LIGHT := Color("#F0A585")

## Order among the level's sub-agents (Spawn.index), set by the level converter.
@export var index := 0
var ghost := false
var rescued := false
var t := randf() * 10
var rescue_t := 0.0
var _body: MeshInstance3D
var _beam: MeshInstance3D


func _ready() -> void:
	add_to_group("world_text")
	_body = MeshInstance3D.new()
	add_child(_body)
	var quad := QuadMesh.new()
	quad.size = Vector2(8, 300) * Px.M
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/beam.gdshader")
	quad.material = mat
	_beam = MeshInstance3D.new()
	_beam.mesh = quad
	_beam.visible = false
	# Just behind the sub-agent, so it rides in front of its own beam.
	_beam.position.z = -0.25
	add_child(_beam)
	_update_visual()


## Level pixels of the feet.
func feet() -> Vector2:
	return Px.of(position)


func _physics_process(dt: float) -> void:
	if Game.frozen():
		return
	t += dt
	var player: Player = get_tree().get_first_node_in_group("player")
	if not rescued and player and player.in_play() and Rect2(feet() + RECT.position, RECT.size).intersects(player.hitbox()):
		rescued = true
		var main := get_tree().get_first_node_in_group("main")
		if main:
			main.rescue_agent(self)
	if rescued:
		rescue_t += dt
		if rescue_t > 0.7 and rescue_t < 1.1:
			Fx.burst(self, feet() + Vector2(0, -6 - _rise()), {count = 3, speed = 30, angle = -PI / 2, spread = 0.4, vy = -140, life = 0.6, color = [ORANGE]})
		if rescue_t > 1.1:
			queue_free()
	_update_visual()


## How far it has risen on the beam, in px.
func _rise() -> float:
	return (rescue_t - 0.7) * 260 if rescue_t > 0.7 else absf(sin(rescue_t * 10)) * 5


func _update_visual() -> void:
	var player: Player = get_tree().get_first_node_in_group("player")
	var cheer := rescued or sin(t * 6) > 0
	_body.mesh = ClawdSprite.mini_mesh(cheer, GHOST if ghost and not rescued else Color(0, 0, 0, 0))
	_body.position.y = (roundf(_rise()) if rescued else 0.0) * Px.M
	if player and not rescued:
		_body.rotation.y = PI if player.pos.x < feet().x else 0.0
	_beam.visible = rescued and rescue_t > 0.7
	if _beam.visible:
		# The beam's bottom follows the sub-agent's feet.
		_beam.position.y = (_rise() + 150) * Px.M
		(_beam.mesh.material as ShaderMaterial).set_shader_parameter("fade", clampf((1.1 - rescue_t) / 0.4, 0.0, 1.0) * 0.6 + 0.4)


## The "HELP" bubble: a small panel above its head, on while sin(2t) > -0.3.
func overlay_draw(o: Overlay) -> void:
	if rescued or sin(t * 2) <= -0.3:
		return
	var v := o.to_view(feet() + Vector2(0, -12))
	var r := Rect2(v.x - 11, v.y - 13, 22, 9)
	o.panel(r, Color("#5A5A5A"), Color(0.08, 0.08, 0.08, 0.9))
	PixelFont.draw_centred(o, "HELP", v.x, v.y - 11, ORANGE_LIGHT)
