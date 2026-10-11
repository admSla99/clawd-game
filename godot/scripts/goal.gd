class_name Goal
extends Node3D

## The exit gate from src/entities/collectibles.ts (`G` in the map). Touching it completes the level
## (Main.reach_goal()). Like the 2D gate it is a ring of 40 light dots on a 12 x 18 px ellipse that turn
## slowly, with bright waves running round, around a pulsing glow, sparks drifting up and "EXIT" above. Here
## the dots are 2 px voxels 6 px deep (Voxel.mesh(), rebuilt every frame), the glow is a dithered swirl
## (shaders/portal.gdshader), it stands on a dark pad with orange LEDs and lights the ground (GlowLight).
## Everything sits on the gameplay plane, so Clawd walks into it, and the swirl stays on whole pixels.

## Interaction box relative to the feet, the inner part of the 2D gate (16 x 40 px).
const RECT := Rect2(-8, -40, 16, 40)
## Centre of the ring above the feet, and its radii, in px.
const CENTRE_Y := 22
const RX := 12
const RY := 18
const DOTS := 40
const ORANGE := Color("#D97757")
const ORANGE_LIGHT := Color("#F0A585")
const PAD := [
	"...pppppppppppppppppppppppp...",
	".pp.ppp.ppp.pppppp.ppp.ppp.pp.",
	"pppppppppppppppppppppppppppppp",
]
const LEDS := [
	"..............................",
	"...l...l...l......l...l...l...",
	"..............................",
]

static var PAD_MESH := Voxel.mesh(PAD, {"p": Color8(52, 50, 58)}, {"p": 12}, Px.M)
static var LED_MESH := Voxel.mesh(LEDS, {"l": ORANGE_LIGHT}, {"l": 12}, Px.M, Voxel.material(1.8))
static var RING_MATERIAL := Voxel.material(1.7)

var t := 0.0
var reached := false
var _ring: MeshInstance3D
var _surface: MeshInstance3D
var _glow: GlowLight


func _ready() -> void:
	add_to_group("world_text")
	for m in [PAD_MESH, LED_MESH]:
		var mi := MeshInstance3D.new()
		mi.mesh = m
		add_child(mi)
	_ring = MeshInstance3D.new()
	# The ring grid's centre is RY + 1 px above its bottom.
	_ring.position.y = (CENTRE_Y - RY - 1) * Px.M
	add_child(_ring)
	var quad := QuadMesh.new()
	quad.size = Vector2(20, 32) * Px.M
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/portal.gdshader")
	quad.material = mat
	_surface = MeshInstance3D.new()
	_surface.mesh = quad
	_surface.position.y = CENTRE_Y * Px.M
	add_child(_surface)
	_glow = GlowLight.new()
	_glow.radius = 4.0
	_glow.position = Vector3(0, CENTRE_Y * Px.M, 0.6)
	add_child(_glow)
	_update_visual()


## Level pixels of the feet.
func feet() -> Vector2:
	return Px.of(position)


func _physics_process(dt: float) -> void:
	if Game.frozen():
		return
	t += dt
	# Sparks drifting up from the ring, about 20 a second.
	if randf() < dt * 20:
		var a := randf() * TAU
		Fx.burst(self, feet() + Vector2(cos(a) * RX, -CENTRE_Y + sin(a) * (RY - 2)), {count = 1, speed = 12, life = 0.8, color = [ORANGE], vy = -12})
	var player: Player = get_tree().get_first_node_in_group("player")
	if not reached and player and Rect2(feet() + RECT.position, RECT.size).intersects(player.hitbox()):
		reached = true
		var main := get_tree().get_first_node_in_group("main")
		if main:
			main.reach_goal(self)
	_update_visual()


func _update_visual() -> void:
	_ring.mesh = ring_mesh(t)
	(_surface.mesh.material as ShaderMaterial).set_shader_parameter("game_time", Game.time)
	_glow.energy = 1.0 + sin(t * 4) * 0.2


## The ring at time `time`: DOTS dots of 2 x 2 px on the ellipse, turning, light orange where a wave of
## brightness passes (the 2D gate's `b > 0.6`). The grid is (2 RX + 2) x (2 RY + 2) px.
static func ring_mesh(time: float) -> ArrayMesh:
	var w := RX * 2 + 2
	var h := RY * 2 + 2
	var grid := []
	for y in h:
		grid.append(".".repeat(w))
	for i in DOTS:
		var a := float(i) / DOTS * TAU + time * 1.5
		var ch := "L" if (sin(a * 3 - time * 5) + 1) / 2 > 0.6 else "o"
		var x := RX + roundi(cos(a) * RX)
		var y := RY + roundi(sin(a) * RY)
		for dy in 2:
			grid[y + dy] = grid[y + dy].substr(0, x) + ch + ch + grid[y + dy].substr(x + 2)
	return Voxel.mesh(grid, {"o": ORANGE, "L": ORANGE_LIGHT}, {"o": 6, "L": 6}, Px.M, RING_MATERIAL)


## "EXIT" above the gate (Overlay world text).
func overlay_draw(o: Overlay) -> void:
	var v := o.to_view(feet() + Vector2(0, -46))
	PixelFont.draw_centred(o, "EXIT", v.x, v.y - 3, ORANGE_LIGHT)
