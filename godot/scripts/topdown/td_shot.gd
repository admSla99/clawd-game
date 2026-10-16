class_name TdShot
extends Node3D

## A shot in the top-down prototype: Clawd's (the weapon's colour) or an enemy's (red), flying flat at chest
## height until a wall, its range, or something it hits. TdMain moves and resolves them.

const HEIGHT := 0.55

var pos := Vector2.ZERO
var vel := Vector2.ZERO
var damage := 1.0
var crit := false
var friendly := true
var life := 1.0
var dead := false


static func make(at: Vector2, v: Vector2, dmg: float, mine: bool, color: Color, t: float) -> TdShot:
	var s := TdShot.new()
	s.pos = at
	s.vel = v
	s.damage = dmg
	s.friendly = mine
	s.life = t
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3.ONE * (0.16 if mine else 0.22)
	m.mesh = b
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	m.material_override = mat
	s.add_child(m)
	s.position = Vector3(at.x, HEIGHT, at.y)
	return s


func place() -> void:
	position = Vector3(pos.x, HEIGHT, pos.y)
