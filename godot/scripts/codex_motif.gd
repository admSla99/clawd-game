class_name CodexMotif
extends Node3D

## The codex theme's scenery motif (docs/scenery-themes.md: code monoliths), behind the 2-B arena among the
## forest: dark slabs in three layers of depth, rising from below the view, their fronts covered in code that
## scrolls up in syntax colours of the theme's cyan with a blinking cursor at the line being typed
## (shaders/codex_monolith.gdshader draws them; this places them). Like Scenery and WindowMotif, each layer
## moves with the camera by (1 - factor) and sits lower by its depth, so it shows where the gameplay plane
## would. Found by its file name (Main.motif_script_for()).

const SHADER := preload("res://shaders/codex_monolith.gdshader")
## z = depth (m) of the layer's fronts, factor = parallax, cell = one monolith slot per cell of layer px,
## w / h = width and height ranges in px (whole multiples of 4), deep = box depth (m).
const LAYERS := [
	{"z": -24.0, "factor": 0.18, "cell": 110.0, "w": [24, 40], "h": [260, 380], "deep": 1.0, "seed": 13},
	{"z": -13.0, "factor": 0.3, "cell": 160.0, "w": [28, 44], "h": [230, 330], "deep": 1.0, "seed": 29},
	{"z": -7.5, "factor": 0.42, "cell": 230.0, "w": [32, 48], "h": [200, 290], "deep": 0.75, "seed": 47},
]
## Monoliths stand on this line (layer px), below the bottom of any view of a level.
const GROUND := 360.0

var _layers: Array[Node3D] = []
var _mat: ShaderMaterial


## Fills the layers for a level of `bounds` px seen through `view`, in the palette's light colour.
func setup(seed: int, bounds: Vector2, view: Vector2, palette: Dictionary) -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("light_color", Themes.vec(palette.light))
	for key in ["top", "mid", "haze"]:
		_mat.set_shader_parameter("fog_" + key, Themes.vec(palette[key]))
	var max_cam := (bounds - view).max(Vector2.ZERO)
	for li in LAYERS.size():
		var l: Dictionary = LAYERS[li]
		var node := Node3D.new()
		add_child(node)
		_layers.append(node)
		var span: float = view.x + max_cam.x * l.factor + 64
		var s: int = seed * 17 + l.seed
		for i in ceili(span / l.cell) + 1:
			if DotNoise.hash2(i, 0, s) < 0.25:
				continue
			var w := 4 * roundi(lerpf(l.w[0], l.w[1], DotNoise.hash2(i, 1, s)) / 4)
			var h := 4 * roundi(lerpf(l.h[0], l.h[1], DotNoise.hash2(i, 2, s)) / 4)
			var x: float = i * l.cell - 32 + DotNoise.hash2(i, 3, s) * (l.cell - w)
			var box := BoxMesh.new()
			box.size = Vector3(w, h, l.deep * 16) * Px.M
			var mi := MeshInstance3D.new()
			mi.mesh = box
			mi.material_override = _mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.extra_cull_margin = absf(l.z) / 3 + 2
			mi.set_instance_shader_parameter("mono_size", Vector2(w, h))
			mi.set_instance_shader_parameter("seed", float(s * 31 + i))
			# The box's front at the layer's depth, its bottom on GROUND.
			mi.position = Vector3((roundf(x) + w / 2.0) * Px.M, -(GROUND - h / 2.0) * Px.M, l.z - l.deep / 2)
			node.add_child(mi)


func _process(_dt: float) -> void:
	var main := get_tree().get_first_node_in_group("main")
	if not main or not _mat:
		return
	_mat.set_shader_parameter("game_time", Game.time)
	var cam: Vector2 = main.camera.top_left
	for i in _layers.size():
		var l: Dictionary = LAYERS[i]
		var off: Vector2 = (cam * (1.0 - l.factor)).round()
		_layers[i].position = Vector3(off.x * Px.M, -off.y * Px.M + l.z * tan(GameCamera.PITCH), 0)
