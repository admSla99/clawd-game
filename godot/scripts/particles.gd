class_name Particles
extends MultiMeshInstance3D

## CPU particle list ported from src/render/particles.ts: squares that fly, fall, slow down with
## drag, fade out and shrink near the end of their life. Capped at 1500 like the TS version.
## Simulated in level pixels like the TS version (plus a random drift in depth), drawn as cubes.

const MAX := 1500
## Particles start this far in front of the gameplay plane (pixels), just ahead of Clawd's and the
## bugs' front faces, so they draw over the characters like the 2D overlay did.
const FRONT := 8.0

var list: Array[Dictionary] = []


func _ready() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/particles.gdshader")
	var box := BoxMesh.new()
	box.size = Vector3.ONE * Px.M
	box.material = mat
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = box
	multimesh.instance_count = MAX
	multimesh.visible_instance_count = 0
	cast_shadow = SHADOW_CASTING_SETTING_OFF


## Same options and defaults as Particles.emit() in TS: count 8, speed 80 (x0.4..1), life 0.5
## (x0.6..1), all directions unless `spread` is given, color picked at random from `colors`. Extra
## option `depth`: start up to that many px in front of or behind the usual depth (breaking blocks).
func emit(at: Vector2, o: Dictionary = {}) -> void:
	var colors: Array = o.get("color", [Color.WHITE])
	for i in o.get("count", 8):
		var angle: float = o.get("angle", 0.0) + (randf() * TAU if not o.has("spread") else (randf() - 0.5) * o.spread)
		var speed: float = o.get("speed", 80.0) * (0.4 + randf() * 0.6)
		var life: float = o.get("life", 0.5) * (0.6 + randf() * 0.4)
		list.append({
			"p": at,
			"z": FRONT + randf_range(-1, 1) * o.get("depth", 0.0),
			"vz": randf_range(-0.5, 1) * speed,
			"v": Vector2(cos(angle), sin(angle)) * speed + Vector2(o.get("vx", 0.0), o.get("vy", 0.0)),
			"life": life,
			"max": life,
			"size": o.get("size", 1.0),
			"color": colors.pick_random(),
			"gravity": o.get("gravity", 0.0),
			"drag": o.get("drag", 0.0),
		})
	if list.size() > MAX:
		list = list.slice(list.size() - MAX)


func clear() -> void:
	list.clear()


func _physics_process(dt: float) -> void:
	if Game.frozen():
		return
	var alive: Array[Dictionary] = []
	for p in list:
		p.life -= dt
		if p.life <= 0:
			continue
		p.v.y += p.gravity * dt
		if p.drag:
			p.v *= maxf(0, 1 - p.drag * dt)
		p.p += p.v * dt
		p.z += p.vz * dt
		alive.append(p)
	list = alive
	multimesh.visible_instance_count = list.size()
	for i in list.size():
		var p: Dictionary = list[i]
		var t: float = p.life / p.max
		var s: float = p.size * (1.0 if t > 0.3 else 0.6)
		var c: Color = p.color
		c.a *= minf(1, t * 1.6)
		multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * s), Px.to3(p.p) + Vector3(0, 0, p.z * Px.M)))
		multimesh.set_instance_color(i, c)
