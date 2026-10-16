class_name TdActor
extends Node3D

## Something that moves in the top-down prototype's arena: a position `pos` (x, z in metres) and a radius, a voxel
## sprite turned to face the isometric camera (the side-view sprites stand up like cut-outs, mirrored to face left
## or right on screen), a blob shadow, and a white hit flash.

## The camera's yaw: sprites turn this far to face it.
const FACE_YAW := 45.0
## Right on screen, as a direction on the ground.
const SCREEN_RIGHT := Vector2(0.7071, -0.7071)

static var MAT := material()
static var FLASH := flash_material()
static var SHADOW_MAT := shadow_material()

var pos := Vector2.ZERO
var radius := 0.35
var height := 0.0
var flash := 0.0
var facing := 1
var body: MeshInstance3D
var _shadow: MeshInstance3D


static func material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = false
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func flash_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color.WHITE
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func shadow_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0, 0, 0, 0.35)
	return m


## A voxel mesh at 1 px = 1/16 m in the prototype's unshaded material.
static func sprite(rows: Array, palette: Dictionary, depth: Dictionary, top := {}) -> ArrayMesh:
	return Voxel.mesh(rows, palette, depth, Px.M, MAT, top)


func _ready() -> void:
	body = MeshInstance3D.new()
	body.rotation_degrees.y = FACE_YAW
	add_child(body)
	_shadow = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(radius * 2.4, radius * 1.6)
	q.orientation = PlaneMesh.FACE_Y
	_shadow.mesh = q
	_shadow.material_override = SHADOW_MAT
	_shadow.position.y = 0.02
	add_child(_shadow)


func place() -> void:
	position = Vector3(pos.x, 0, pos.y)
	body.position.y = height
	body.scale.x = -1.0 if facing < 0 else 1.0
	body.material_override = FLASH if flash > 0 else null


## Faces left or right on screen by a direction on the ground.
func face(dir: Vector2) -> void:
	var s := dir.dot(SCREEN_RIGHT)
	if absf(s) > 0.05:
		facing = 1 if s > 0 else -1
