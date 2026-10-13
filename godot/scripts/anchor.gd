class_name Anchor
extends Node3D

## An API endpoint (`+` in a world-3 map): a glowing node in the middle of its tile that the Tool Call
## (scripts/tool_call.gd) catches and zips Clawd to. A voxel ring round a white core that turns slowly and pulses,
## lit by a small GlowLight; while it is the hook's aim-assist pick, the Overlay draws orange brackets round it,
## and a caught one flashes. Group "anchors"; the origin is the tile's bottom middle like every spawn.

const ROWS := ["..LhL..", ".h...h.", "L..W..L", "h.WOW.h", "L..W..L", ".h...h.", "..LhL.."]
const PALETTE := {"W": Color("#F2FFFF"), "O": Color("#FFB28F"), "L": Color("#7FE8F0"), "h": Color("#3F9AA6")}
const CYAN := Color("#7FE8F0")
const ORANGE_LIGHT := Color("#F0A585")

static var MATERIAL := Voxel.material(1.8)
static var MESH := Voxel.mesh(ROWS, PALETTE, {"W": 2, "O": 4, "L": 2, "h": 2}, Px.M, MATERIAL)

var t := 0.0
## Can the hook catch it now (timeout anchors switch this off for a while).
var active := true
## The Tool Call aims at it this frame (set by ToolCall every frame).
var targeted := false
## Seconds of the flash after a catch.
var caught_flash := 0.0
var _pivot: Node3D
var _mesh: MeshInstance3D
var _glow: GlowLight


func _ready() -> void:
	add_to_group("anchors")
	add_to_group("world_text")
	t = position.x * 0.37
	_pivot = Node3D.new()
	add_child(_pivot)
	_mesh = MeshInstance3D.new()
	_mesh.mesh = MESH
	_mesh.position.y = -3.5 * Px.M
	_pivot.add_child(_mesh)
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


func _physics_process(dt: float) -> void:
	if Game.frozen():
		return
	t += dt
	caught_flash = maxf(0.0, caught_flash - dt)
	# Turns slowly about its middle, a little faster and brighter while aimed at or just caught.
	_pivot.rotation.y = t * (2.4 if targeted else 0.9)
	_pivot.scale = Vector3.ONE * (1.25 if caught_flash > 0 else 1.0)
	_mesh.visible = active
	_glow.energy = 0.0 if not active else 0.45 + 0.15 * sin(t * 3) + (0.4 if targeted or caught_flash > 0 else 0.0)


## Orange brackets round it while the hook would catch it (the aim assist's pick).
func overlay_draw(o: Overlay) -> void:
	if not targeted or not active:
		return
	var v := o.to_view(point()).round()
	var r := 7 + roundf(absf(sin(t * 6)))
	var c := Color(ORANGE_LIGHT, 0.9)
	for sx in [-1, 1]:
		for sy in [-1, 1]:
			# An L in each corner, its arms 3 px long pointing inwards.
			var k := v + Vector2(sx * r, sy * r)
			o.draw_rect(Rect2(k.x - (2 if sx > 0 else 0), k.y, 3, 1), c)
			o.draw_rect(Rect2(k.x, k.y - (2 if sy > 0 else 0), 1, 3), c)
