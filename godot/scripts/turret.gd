class_name Turret
extends Enemy

## The "lint" turret from `Turret` in src/entities/enemies2.ts: `T` stands on the floor, `Y` hangs from the
## ceiling (`ceiling`). It turns its barrel towards Clawd at up to 3 rad/s, floor turrets only into the upper
## half-plane and ceiling ones into the lower, and every 2.4 s, while he is within 250 px, fires a burst of
## three Shots 0.14 s apart at 135 px/s; the barrel blinks red for the last 0.45 s before a burst. Floor turrets
## can be stomped. Drawn at 1 px: a 16 x 12 grey dome with a dark lower half and a red sensor on a base plate
## (flipped for the ceiling), and a separate barrel that turns around the sensor, mounted on the dome's front so
## it reads (the 2D barrel is drawn behind the dome). A ceiling's underside is hidden behind the front face of
## its blocks, so a ceiling turret is drawn bolted to that front face, lifted by the oblique shift (z / 3) so it
## still shows where it is in play.

const SIZE := Vector2(16, 12)
const RANGE := 250.0
const TURN := 3.0
const RELOAD := 2.4
const BURST := 3
const BURST_GAP := 0.14
const SHOT_SPEED := 135.0
const WARN := 0.45
## The sensor the barrel turns around, px above the feet (`pivot` in TS: y + 7 standing, y + 5 hanging).
const PIVOT_FLOOR := 5.0
const PIVOT_CEILING := 7.0
const DOME := [
	"......wwww......",
	"....wwWWWWww....",
	"...wWLLWWWWWw...",
	"..wWLWWWWWWWWw..",
	"..wWWWWWWWWWWw..",
	".wWWWWWddWWWWWw.",
	".wWWWWdRRdWWWWw.",
	".wWWWWdRRdWWWWw.",
	".wgggggddgggggw.",
	"kkkkkkkkkkkkkkkk",
	"kKKKKKKKKKKKKKKk",
	"kkkkkkkkkkkkkkkk",
]
## Pointing right from the sensor: 11 px long, 2 px thick, with a dark muzzle.
const BARREL := ["BBBBBBBBBMM", "bbbbbbbbbMM"]
const PALETTE := {
	"W": Color8(180, 180, 180), # dome
	"L": Color8(226, 226, 226), # lit spot
	"w": Color8(110, 110, 110), # rim
	"g": Color8(130, 130, 130), # lower dome
	"d": Color8(58, 58, 58), # sensor housing
	"R": Color("#E0605A"), # sensor
	"k": Color8(74, 74, 74), # base plate
	"K": Color8(140, 140, 140),
	"B": Color8(200, 200, 200), # barrel
	"b": Color8(138, 138, 138),
	"M": Color8(90, 90, 90),
}
## Depth in px: a deep dome, a wide base plate, a thin barrel.
const DEPTH := {"W": 12, "L": 12, "w": 10, "g": 12, "d": 12, "R": 14, "k": 14, "K": 14, "B": 4, "b": 4, "M": 6}
## The barrel's middle, px in front of the dome's: just touching its front face.
const BARREL_Z := 8.0
## Where a ceiling turret's middle sits in depth (m): its back flush with the blocks' front face.
const CEILING_Z := Level.DEPTH / 2 + 6 * Px.M

## Its own material: the barrel and ceiling turrets reach past the see-through windows' REVEAL_FRONT, but a
## gameplay object must never be dithered away around Clawd (Main sets `reveal` on Voxel.MATERIAL only).
static var MATERIAL := Voxel.material()
static var DOMES := [Voxel.mesh(DOME, PALETTE, DEPTH, Px.M, MATERIAL), Voxel.mesh(_flipped(DOME), PALETTE, DEPTH, Px.M, MATERIAL)]
static var BARREL_MESH := Voxel.mesh(BARREL, PALETTE, DEPTH, Px.M, MATERIAL)

## Hangs from the ceiling (`Y` in the map).
@export var ceiling := false
## Barrel angle in radians, TS style (y down, 0 = right).
var angle := -PI / 2
var timer := 1.2 + randf()
var burst := 0
var burst_t := 0.0
var _visual: Node3D
var _dome: MeshInstance3D
var _pivot: Node3D
var _barrel: MeshInstance3D


func _init() -> void:
	size = SIZE
	hp = 6
	tokens = 4 * TOKEN_FACTOR
	collision_layer = 0
	collision_mask = 0


func _ready() -> void:
	super()
	stompable = not ceiling
	angle = PI / 2 if ceiling else -PI / 2
	if ceiling:
		# `new Turret(s.x, s.ty * TILE, true)`: its top is the top of its map cell, under the ceiling.
		pos += Vector2(0, -16 + SIZE.y)
		prev_pos = pos
	_visual = Node3D.new()
	add_child(_visual)
	_dome = MeshInstance3D.new()
	_dome.mesh = DOMES[int(ceiling)]
	_visual.add_child(_dome)
	_pivot = Node3D.new()
	_pivot.position = Vector3(0, _pivot_up() * Px.M, 0)
	_visual.add_child(_pivot)
	_barrel = MeshInstance3D.new()
	_barrel.mesh = BARREL_MESH
	# Voxel meshes hang from their bottom-centre: start the barrel 2 px out from the sensor, centred on it.
	_barrel.position = Vector3(BARREL[0].length() / 2.0 + 2, -1, BARREL_Z) * Px.M
	_pivot.add_child(_barrel)
	_update_visual()


func _pivot_up() -> float:
	return PIVOT_CEILING if ceiling else PIVOT_FLOOR


## The sensor in level pixels (`pivot` in TS).
func pivot() -> Vector2:
	return pos + Vector2(0, -_pivot_up())


## A ceiling turret's health bar hangs under it (over it would be inside the ceiling).
func bar_y() -> float:
	return pos.y + 4 if ceiling else super()


func _physics_process(dt: float) -> void:
	if Game.frozen():
		return
	tick(dt)
	var player: Player = get_tree().get_first_node_in_group("player")
	if player == null or not player.in_play():
		_update_visual()
		return
	var pv := pivot()
	var d := player.pos + Vector2(0, -Player.SIZE.y / 2) - pv
	var target := atan2(d.y, d.x)
	# Floor turrets aim into the upper half-plane, ceiling ones into the lower.
	if ceiling:
		target = clampf(target, 0.1, PI - 0.1)
	elif target > PI / 2:
		target = -PI + 0.1
	elif target > 0:
		target = -0.1
	else:
		target = clampf(target, -PI + 0.1, -0.1)
	angle += clampf(wrapf(target - angle, -PI, PI), -TURN * dt, TURN * dt)

	timer -= dt
	if timer <= 0 and d.length() < RANGE:
		burst = BURST
		burst_t = 0.0
		timer = RELOAD
	if burst > 0:
		burst_t -= dt
		if burst_t <= 0:
			var dir := Vector2.from_angle(angle)
			Shot.fire(level, pv + dir * 10, dir * SHOT_SPEED)
			Sound.play("shoot")
			burst -= 1
			burst_t = BURST_GAP
	_update_visual()


func _update_visual() -> void:
	_pivot.rotation.z = -angle
	var warn := timer < WARN and floori(Game.time * 20) % 2 == 0
	set_tint(_barrel, Color(PALETTE.R, 1.0) if warn else Color(0, 0, 0, 0))
	set_tint(_dome)
	var up := _pivot_up() * Px.M
	set_rim(_dome, up)
	set_rim(_barrel, up)
	var snap := pos.round() - pos
	_visual.position = Vector3(snap.x, -snap.y, 0) * Px.M
	if ceiling:
		_visual.position += Vector3(0, CEILING_Z / 3, CEILING_Z)


static func _flipped(rows: Array) -> Array:
	var out := rows.duplicate()
	out.reverse()
	return out
