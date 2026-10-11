class_name MovingPlatform
extends Node3D

## Moving platform from src/entities/platforms.ts (`M` horizontal, `V` vertical in the map): 3 tiles wide,
## it swings sin(t / PERIOD * TAU) * AMP around where it was placed. Like a one-way platform, Clawd lands on
## it only from above and rides it (Player checks the group "platforms" after moving); down + jump drops
## through. It updates before the player (process_physics_priority), so riders move with it in the same
## frame, like `isPlatform(e)` entities in src/scenes/game.ts.
## Drawn as a hovering slab at 1 px in the look of the level's one-way ledges: a white crust with an orange
## LED at each end and a row of them along its grey edge, a dark body tapering underneath, two small orange
## jets that flicker below, and a GlowLight. Snapped to whole pixels like Clawd.

const W := 48
const H := 6
const AMP := 16 * 3.5
const PERIOD := 4.0
const SLAB := [
	"occcccccccccccccccccccccccccccccccccccccccccccco",
	"gggggggggggggggggggggggggggggggggggggggggggggggg",
	"dddldddddddldddddddldddddddlddddddldddddddlddddd",
	".dddddddddddddddddddddddddddddddddddddddddddddd.",
	"...dddddddddddddddddddddddddddddddddddddddddd...",
]

static var SLAB_MESH := _slab_mesh()
static var GLOW_MESH := _glow_mesh()
static var JET_MESHES := [_jet_mesh(2), _jet_mesh(3), _jet_mesh(4)]

## "h" or "v".
@export var axis := "h"
@export var phase := 0.0
## Top-left in level pixels, and how far it moved this frame.
var x := 0.0
var y := 0.0
var dx := 0.0
var dy := 0.0
var active := true
var _base := Vector2.ZERO
var _t := 0.0
var _visual: Node3D
var _jets: MeshInstance3D


func _ready() -> void:
	add_to_group("platforms")
	process_physics_priority = -10
	# Placed like `new MovingPlatform(s.x, s.ty * TILE, ...)`: the node sits on the tile's bottom-centre.
	var spawn := Px.of(position)
	_base = Vector2(spawn.x - W / 2.0, spawn.y - 16)
	_t = phase
	_visual = Node3D.new()
	add_child(_visual)
	for m in [SLAB_MESH, GLOW_MESH]:
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.position.y = -H * Px.M
		_visual.add_child(mi)
	_jets = MeshInstance3D.new()
	_jets.position.y = -(H + 3) * Px.M
	_visual.add_child(_jets)
	var glow := GlowLight.new()
	glow.radius = 1.6
	glow.energy = 0.45
	glow.position = Vector3(0, -(H + 3) * Px.M, 0.4)
	_visual.add_child(glow)
	_move(0.0)
	dx = 0.0
	dy = 0.0


func _physics_process(dt: float) -> void:
	if Game.frozen():
		dx = 0.0
		dy = 0.0
		return
	_move(dt)
	_jets.mesh = JET_MESHES[randi() % JET_MESHES.size()]


func _move(dt: float) -> void:
	_t += dt
	var o := sin(_t / PERIOD * TAU) * AMP
	var n := _base + (Vector2(o, 0) if axis == "h" else Vector2(0, o))
	dx = n.x - x
	dy = n.y - y
	x = n.x
	y = n.y
	# The node sits at the middle of the top edge; the slab hangs below it.
	position = Px.to3(Vector2(x + W / 2.0, y))
	var snap := Vector2(x, y).round() - Vector2(x, y)
	_visual.position = Vector3(snap.x, -snap.y, 0) * Px.M


func rect() -> Rect2:
	return Rect2(x, y, W, H)


static func _slab_mesh() -> ArrayMesh:
	var rows := SLAB.map(func(r: String) -> String: return r.replace("l", "d").replace("o", "c"))
	var top := {"c": Color8(150, 150, 156)}
	return Voxel.mesh(rows + [".".repeat(W)], {"c": Color8(225, 225, 225), "g": Color8(150, 150, 150), "d": Color8(46, 44, 52)}, {"c": 12, "g": 12, "d": 12}, Px.M, Voxel.MATERIAL, top)


## The LEDs, on the same grid, a separate glowing mesh.
static func _glow_mesh() -> ArrayMesh:
	var rows := []
	for r in SLAB:
		var s := ""
		for ch in r:
			s += ch if ch == "l" or ch == "o" else "."
		rows.append(s)
	rows.append(".".repeat(W))
	return Voxel.mesh(rows, {"l": Color("#F0A585"), "o": Color("#D97757")}, {"l": 12, "o": 12}, Px.M, Voxel.material(1.8))


## Two jets `n` px long under the slab, fading from light orange to orange.
static func _jet_mesh(n: int) -> ArrayMesh:
	var rows := []
	for i in 4:
		var ch := ("j" if i == 0 else "k") if i < n else "."
		rows.append(".".repeat(9) + ch + ch + ".".repeat(26) + ch + ch + ".".repeat(W - 39))
	return Voxel.mesh(rows, {"j": Color("#F0A585"), "k": Color("#D97757")}, {"j": 4, "k": 2}, Px.M, Voxel.material(1.8))
