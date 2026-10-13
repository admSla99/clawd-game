class_name Motes
extends MultiMeshInstance3D

## Fireflies / data motes floating in the air of the level, at depths from behind the forest's nearest
## trunks to just in front of the gameplay plane: glowing 1-2 px cubes in the theme's light colour that
## drift on slow loops and blink. Every few carries a small GlowLight, so they light the terrain they pass.
## Generated from the level's terrainSeed; dark levels get a few more of them (dimmed away from Clawd's lamp). Runs on game time, so hitstop
## and pause hold them.

const SHADER := preload("res://shaders/motes.gdshader")
## Motes per 64 x 64 px of level.
const DENSITY := 0.45
## Every LIT-th mote carries a GlowLight.
const LIT := 10

var _motes: Array[Dictionary] = []
var _lights: Array[GlowLight] = []


func setup(seed: int, bounds: Vector2, palette: Dictionary, dark: bool) -> void:
	for l in _lights:
		l.free()
	_lights.clear()
	_motes.clear()
	var n := int(bounds.x * bounds.y / 4096.0 * DENSITY * (1.2 if dark else 1.0))
	var light: Color = palette.light
	for i in n:
		var h := func(k: int) -> float: return DotNoise.hash2(i, k, seed + 77)
		var warm: bool = h.call(7) > 0.85
		var c: Color = Color("#F0A585") if warm else light.lerp(Color.WHITE, 0.35)
		_motes.append({
			"base": Vector3(h.call(0) * bounds.x * Px.M, -h.call(1) * bounds.y * Px.M, lerpf(-5.0, 1.2, h.call(2))),
			"amp": Vector2(6 + h.call(3) * 18, 4 + h.call(4) * 10),
			"speed": 0.15 + h.call(5) * 0.35,
			"phase": h.call(6) * TAU,
			"blink": 0.4 + h.call(8) * 1.2,
			"size": 2.0 if h.call(9) > 0.8 else 1.0,
			# Far motes are dimmer, like the depth fog (shaders/fog.gdshaderinc) would make them.
			"color": c * (2.4 if warm else 1.8) * exp(-maxf(0, -lerpf(-5.0, 1.2, h.call(2))) * 0.08),
		})
		if i % LIT == 0:
			var g := GlowLight.new()
			g.radius = 1.4
			g.energy = 0.0
			add_child(g)
			_lights.append(g)
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = _glow_mesh(mat)
	multimesh.instance_count = n
	cast_shadow = SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3(-2, -bounds.y * Px.M - 2, -8), Vector3(bounds.x * Px.M + 4, bounds.y * Px.M + 4, 12))
	_update()


## A pixel glow: a bright 1 px core with a dimmer pixel on each side, as flat quads facing the camera
## (vertex colours scale the instance colour).
static func _glow_mesh(mat: Material) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p: Vector3 in [Vector3.ZERO, Vector3.LEFT, Vector3.RIGHT, Vector3.UP, Vector3.DOWN]:
		var c := Color.WHITE if p == Vector3.ZERO else Color(0.3, 0.3, 0.3)
		var o := (p - Vector3(0.5, 0.5, 0)) * Px.M
		var q := [Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 0, 0)]
		for i in [0, 1, 2, 0, 2, 3]:
			st.set_color(c)
			st.set_normal(Vector3.BACK)
			st.add_vertex(o + q[i] * Px.M)
	st.set_material(mat)
	return st.commit()


func _process(_dt: float) -> void:
	if not Game.frozen():
		_update()


func _update() -> void:
	var t := Game.time
	for i in _motes.size():
		var m: Dictionary = _motes[i]
		var a: float = t * m.speed + m.phase
		# A slow figure-eight loop around the base point, in whole pixels.
		var off := Vector2(sin(a) * m.amp.x, sin(a * 2.0 + 1.0) * m.amp.y).round()
		var p: Vector3 = m.base + Vector3(off.x, -off.y, 0) * Px.M
		var glow := clampf(0.55 + 0.45 * sin(t * m.blink * 2.0 + m.phase * 3.0), 0.0, 1.0)
		var c: Color = m.color
		c.a = glow
		multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * m.size), p))
		multimesh.set_instance_color(i, c)
		if i % LIT == 0:
			var g := _lights[i / LIT]
			g.position = p
			g.energy = 0.5 * glow
