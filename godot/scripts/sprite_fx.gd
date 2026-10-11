class_name SpriteFx
extends Node3D

## A short voxel-frame animation left behind by something that is already gone (a stomped bug's shell,
## a collected token's sparkle), so the game logic can free its node at once. Plays `frames` for
## `times` seconds each, optionally with a GlowLight that fades out, then frees itself. Runs on game
## time: hitstop and pause hold it.

var frames: Array
var times: Array
var t := 0.0
var light := 0.0
var _mesh: MeshInstance3D
var _glow: GlowLight


## Adds the effect to `parent` at `at`; `flip` mirrors it like a sprite facing the other way.
static func spawn(parent: Node, at: Vector3, frame_meshes: Array, frame_times: Array, flip := false, light_energy := 0.0) -> SpriteFx:
	var fx := SpriteFx.new()
	fx.frames = frame_meshes
	fx.times = frame_times
	fx.light = light_energy
	fx.position = at
	fx._mesh = MeshInstance3D.new()
	fx._mesh.mesh = frame_meshes[0]
	fx._mesh.rotation.y = PI if flip else 0.0
	fx.add_child(fx._mesh)
	if light_energy > 0:
		fx._glow = GlowLight.new()
		fx._glow.radius = 2.5
		fx._glow.energy = light_energy
		fx._glow.position.z = 1.0
		fx.add_child(fx._glow)
	parent.add_child(fx)
	return fx


func _physics_process(dt: float) -> void:
	if Game.frozen():
		return
	t += dt
	var end := 0.0
	for i in frames.size():
		end += times[i]
		if t < end:
			_mesh.mesh = frames[i]
			if _glow:
				_glow.energy = light * (1.0 - t / _total())
			return
	queue_free()


func _total() -> float:
	var s := 0.0
	for x in times:
		s += x
	return s
