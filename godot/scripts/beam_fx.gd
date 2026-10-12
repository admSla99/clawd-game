class_name BeamFx
extends MultiMeshInstance3D

## The Attention Beam's flashes (drawBeams() in src/scenes/game.ts): each fired beam shows for 0.06 s as a line
## of 2 px dots every 2 px from the muzzle to where it stopped, jittering sideways, white every 6 px, else
## cyan; glowing (colours above 1 for the WorldEnvironment glow). Drawn just in front of the gameplay plane.

const MAX := 600
const LIFE := 0.06
const CYAN := Color("#5FD0D8")

## {from, to, t} in level pixels.
var beams: Array = []


func _ready() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/particles.gdshader")
	var box := BoxMesh.new()
	box.size = Vector3.ONE * 2 * Px.M
	box.material = mat
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = box
	multimesh.instance_count = MAX
	multimesh.visible_instance_count = 0
	cast_shadow = SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 1000.0


func add(from: Vector2, to: Vector2) -> void:
	beams.append({"from": from, "to": to, "t": LIFE})


func clear() -> void:
	beams.clear()
	multimesh.visible_instance_count = 0


func _physics_process(dt: float) -> void:
	if Game.frozen():
		return
	for b in beams:
		b.t -= dt
	beams = beams.filter(func(b: Dictionary) -> bool: return b.t > 0)
	var n := 0
	for b in beams:
		var d: Vector2 = b.to - b.from
		var length := d.length()
		var dir := d / maxf(length, 0.001)
		var k := 0.0
		while k < length and n < MAX:
			var j := randf_range(-0.75, 0.75)
			var p: Vector2 = b.from + dir * k + Vector2(-dir.y, dir.x) * j
			multimesh.set_instance_transform(n, Transform3D(Basis.IDENTITY, Px.to3(p.round()) + Vector3(0, 0, 0.3)))
			var c := Color.WHITE if int(k) % 6 == 0 else CYAN
			multimesh.set_instance_color(n, Color(c.r * 1.6, c.g * 1.6, c.b * 1.6, 1.0))
			n += 1
			k += 2
	multimesh.visible_instance_count = n
