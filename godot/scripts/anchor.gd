class_name Anchor
extends Node3D

## An API endpoint (`+` in a world-3 map): a glowing node in the middle of its tile that the Tool Call
## (scripts/tool_call.gd) catches and zips Clawd to. A voxel ring round a white core (2 px cells, 14 px across, so
## it reads at a glance among the scenery) that bobs a pixel and pulses, lit by a small GlowLight (it does not turn:
## edge-on it would vanish); while it is the hook's aim-assist pick, the Overlay draws orange brackets round it, and
## a caught one glows brighter. Group "anchors"; the origin is the tile's bottom middle like every spawn.
## A timeout anchor (`*`, `timeout`): amber instead of cyan; FUSE seconds after the hook catches it, blinking faster
## and faster, it times out (no longer `active`, only a dim dotted ghost of it left) and comes back COME_BACK seconds
## later.

const ROWS := ["..LhL..", ".h...h.", "L..W..L", "h.WOW.h", "L..W..L", ".h...h.", "..LhL.."]
const PALETTE := {"W": Color("#F2FFFF"), "O": Color("#FFB28F"), "L": Color("#7FE8F0"), "h": Color("#3F9AA6")}
const TIMEOUT_PALETTE := {"W": Color("#FFF4E0"), "O": Color("#FF6F5C"), "L": Color("#FFB25C"), "h": Color("#A0602A")}
const GHOST := ["..L.L..", ".......", "L.....L", ".......", "L.....L", ".......", "..L.L.."]
const FUSE := 1.2
const COME_BACK := 3.0
const CYAN := Color("#7FE8F0")
const ORANGE_LIGHT := Color("#F0A585")

static var MATERIAL := Voxel.material(1.8)
static var MESH := Voxel.mesh(ROWS, PALETTE, {"W": 2, "O": 4, "L": 2, "h": 2}, 2 * Px.M, MATERIAL)
static var TIMEOUT_MESH := Voxel.mesh(ROWS, TIMEOUT_PALETTE, {"W": 2, "O": 4, "L": 2, "h": 2}, 2 * Px.M, MATERIAL)
static var GHOST_MESH := Voxel.mesh(GHOST, {"L": Color("#5A3A22")}, {"L": 2}, 2 * Px.M)

## A timeout anchor (`*`).
@export var timeout := false
## Seconds left before a caught timeout anchor goes quiet, and before a quiet one comes back.
var fuse := 0.0
var gone := 0.0

var t := 0.0
## Can the hook catch it now (timeout anchors switch this off for a while).
var active := true
## The Tool Call aims at it this frame (set by ToolCall every frame).
var targeted := false
## Seconds of the flash after a catch.
var caught_flash := 0.0
var _pivot: Node3D
var _mesh: MeshInstance3D
var _ghost: MeshInstance3D
var _glow: GlowLight


func _ready() -> void:
	add_to_group("anchors")
	add_to_group("world_text")
	t = position.x * 0.37
	_pivot = Node3D.new()
	add_child(_pivot)
	_mesh = MeshInstance3D.new()
	_mesh.mesh = TIMEOUT_MESH if timeout else MESH
	_mesh.position.y = -7 * Px.M
	_pivot.add_child(_mesh)
	if timeout:
		_ghost = MeshInstance3D.new()
		_ghost.mesh = GHOST_MESH
		_ghost.position.y = -7 * Px.M
		_ghost.visible = false
		_pivot.add_child(_ghost)
	_pivot.position.y = 8 * Px.M
	_glow = GlowLight.new()
	_glow.radius = 1.4
	_glow.energy = 0.45
	_glow.position = Vector3(0, 8 * Px.M, 0.5)
	add_child(_glow)


func feet() -> Vector2:
	return Px.of(position)


## Where the hook catches it and Clawd is pulled to: the middle of its tile (level px).
func point() -> Vector2:
	return feet() + Vector2(0, -8)


## Called by the Tool Call when the hook catches it.
func catch() -> void:
	caught_flash = 0.3
	if timeout and fuse <= 0:
		fuse = FUSE


func _physics_process(dt: float) -> void:
	if Game.frozen():
		return
	t += dt
	caught_flash = maxf(0.0, caught_flash - dt)
	if fuse > 0:
		fuse -= dt
		if fuse <= 0:
			active = false
			gone = COME_BACK
			Sound.play("plateOff")
			Fx.burst(self, point(), {count = 10, speed = 50, life = 0.4, color = [TIMEOUT_PALETTE.L, TIMEOUT_PALETTE.O]})
	elif gone > 0:
		gone -= dt
		if gone <= 0:
			active = true
			Fx.burst(self, point(), {count = 6, speed = 30, life = 0.3, color = [TIMEOUT_PALETTE.L, Color.WHITE]})
	# Bobs a whole pixel now and then.
	_pivot.position.y = (8 + (1 if sin(t * 2.2) > 0.3 else 0)) * Px.M
	# A burning fuse blinks, faster as it runs out.
	var blink := fuse > 0 and fmod(t * (4.0 + 14.0 * (1.0 - fuse / FUSE)), 1.0) > 0.5
	_mesh.visible = active and not blink
	if _ghost:
		_ghost.visible = not active
	_glow.energy = 0.0 if not active else 0.45 + 0.15 * sin(t * 3) + (0.4 if targeted or caught_flash > 0 else 0.0)


## Orange brackets round it while the hook would catch it (the aim assist's pick).
func overlay_draw(o: Overlay) -> void:
	if not targeted or not active:
		return
	var v := o.to_view(point()).round()
	var r := 10 + roundf(absf(sin(t * 6)))
	var c := Color(ORANGE_LIGHT, 0.9)
	for sx in [-1, 1]:
		for sy in [-1, 1]:
			# An L in each corner, its arms 3 px long pointing inwards.
			var k := v + Vector2(sx * r, sy * r)
			o.draw_rect(Rect2(k.x - (2 if sx > 0 else 0), k.y, 3, 1), c)
			o.draw_rect(Rect2(k.x, k.y - (2 if sy > 0 else 0), 1, 3), c)
