class_name GlowLight
extends Node3D

## A warm point light for the pixel shaders (no Godot light): Main collects the visible ones in the
## group "lights" every frame and passes the nearest to Level.set_lights(). The terrain lights the pixels
## within `radius` metres in four discrete steps.

@export var radius := 3.0
@export var energy := 1.0


## How far beyond its radius a light still rims a character (shaders/voxel.gdshader).
const RIM_RANGE := 2.0


func _enter_tree() -> void:
	add_to_group("lights")


## The light that rims `owner` (a character at `at`, world space) most: {"light": Vector4(position, reach),
## "energy": float}. Lights inside `owner` itself (Clawd's own glow and jets) are skipped.
static func rim_for(owner: Node, at: Vector3) -> Dictionary:
	var best := {"light": Vector4.ZERO, "energy": 0.0}
	var strongest := 0.0
	for l: GlowLight in owner.get_tree().get_nodes_in_group("lights"):
		if l.energy <= 0 or not l.is_visible_in_tree() or owner.is_ancestor_of(l):
			continue
		var reach := l.radius * RIM_RANGE
		var p := l.global_position
		var e := l.energy * (1.0 - p.distance_to(at) / reach)
		if e > strongest:
			strongest = e
			best = {"light": Vector4(p.x, p.y, p.z, reach), "energy": l.energy}
	return best
