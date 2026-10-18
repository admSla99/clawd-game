class_name Parser
extends Enemy

## World 3's Parser (`P` in the map; not in TS): an armoured crawler that patrols its ground, turning at walls and
## ledges. While armoured nothing hurts it: shots and the Attention Beam glance off its shell from every side
## (blocks_direction(), like a shield bot's shield), and stomps, spins and the jet only clank (Clawd still bounces
## off its back). The Tool Call's hook tears the shell off (hook_hit(): the plates burst, break): bare, it is a
## soft pink grub that scurries twice as fast and takes damage like any enemy. Touching it hurts either way.
## A voxel shell of steel plates with dark seams and a cyan eye, on six stepping legs.

const SIZE := Vector2(18, 8)
const SPEED := 24.0
const BARE_SPEED := 50.0
const GRAVITY := 1400.0
const MAX_FALL := 400.0
const PALETTE := {
	"A": Color("#AEB8C2"), "a": Color("#6C7680"), "s": Color("#3A4048"), "e": Color("#5FF2FF"),
	"k": Color("#2E3238"), "l": Color("#22262B"), "c": Color("#C9567E"), "C": Color("#F08AB0"),
}
## Plates stand deeper than the body, legs are thin.
const DEPTH := {"A": 12, "a": 12, "s": 12, "e": 10, "k": 10, "l": 4, "c": 10, "C": 10}
const SHELL := [
	"....aAAAAAAAAa....",
	"..aAAAsAAAsAAAAa..",
	".aAAAAsAAAsAAAAAa.",
	"aAAAAAsAAAsAAAAeea",
	"aaaaaaaaaaaaaaaaaa",
	".kkkkkkkkkkkkkkkk.",
]
const BARE := [
	"..................",
	"......cccccc......",
	"....cccCCCCccc....",
	"...ccCCCCCCCCceek.",
	"..cccccccccccceek.",
	".kkkkkkkkkkkkkkkk.",
]
const LEGS := ["..l..l...l...l....", "...l..l...l...l..."]

static var MESHES := _meshes()

var armoured := true
## 1 = right, -1 = left.
var dir := -1.0
var vel := Vector2.ZERO
var t := randf() * 3
## Seconds of the white flash after something glanced off the shell.
var clank := 0.0
var _visual: Node3D
var _body: MeshInstance3D


func _init() -> void:
	size = SIZE
	hp = 4
	tokens = 4 * TOKEN_FACTOR
	collision_layer = 0
	collision_mask = 0


func _ready() -> void:
	super()
	_visual = Node3D.new()
	add_child(_visual)
	_body = MeshInstance3D.new()
	_visual.add_child(_body)
	_update_visual()


## Shots and the beam glance off the shell from every side while it is armoured.
func blocks_direction(_dir: Vector2) -> bool:
	if armoured:
		clank = 0.12
		return true
	return false


## The hook tears the shell off (once; after that it only hurts it).
func hook_hit(_dir: Vector2) -> bool:
	if not armoured:
		return false
	armoured = false
	Sound.play("break")
	Fx.burst(self, pos + Vector2(0, -6), {count = 18, speed = 110, life = 0.6, color = [PALETTE.A, PALETTE.a, Color.WHITE], gravity = 300})
	return true


## Armoured, every hit just clanks (stomps still bounce Clawd: Player bounces whatever hit() says).
func hit(kind: StringName, damage := 1.0, own := true) -> bool:
	if armoured:
		if clank <= 0:
			Sound.play("deflect")
		clank = 0.12
		return false
	return super(kind, damage, own)


func _physics_process(dt: float) -> void:
	if Game.frozen() or held():
		return
	tick(dt)
	t += dt
	clank = maxf(0.0, clank - dt)
	vel.x = dir * (SPEED if armoured else BARE_SPEED)
	vel.y = minf(vel.y + GRAVITY * dt, MAX_FALL)
	if move_x(vel.x * dt):
		dir = -dir
	if move_y(vel.y * dt) == 1:
		vel.y = 0.0
		if not floor_at(Vector2(pos.x + dir * (SIZE.x / 2 + 1), pos.y + 2)):
			dir = -dir
	if pos.y > level.pixel_size.y + 50:
		remove()
		return
	_update_visual()


func hurtbox() -> Rect2:
	return Rect2(pos + Vector2(-SIZE.x / 2 + 2, -SIZE.y + 2), SIZE - Vector2(4, 2))


func _update_visual() -> void:
	_body.mesh = MESHES[int(not armoured) * 2 + int(t * (8 if armoured else 14)) % 2]
	set_tint(_body, Color.WHITE if clank > 0 else Color(0, 0, 0, 0))
	set_rim(_body, 0.3)
	_body.rotation.y = 0.0 if dir > 0 else PI
	var snap := pos.round() - pos
	_visual.position = Vector3(snap.x, -snap.y, 0) * Px.M


## Shell and bare body, each with both leg frames: [shell 0, shell 1, bare 0, bare 1].
static func _meshes() -> Array:
	var out := []
	for body in [SHELL, BARE]:
		for legs in LEGS:
			out.append(Voxel.mesh(body + [legs], PALETTE, DEPTH, Px.M))
	return out
