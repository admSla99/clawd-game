class_name WindowMotif
extends Node3D

## The Context Window's scenery motif (docs/scenery-themes.md: floating windows), behind the level among the
## forest: text panels of prompt and code in three layers of depth that open, type their lines in, drift back
## into the depth and crumble into pixels as the context overflows, then reappear elsewhere with new text
## (shaders/motif_window.gdshader draws them; this places and ages them). Each window slot runs its own life
## of LIFE seconds or so on Game.time, so hitstop and pause hold them. Like Scenery, each layer moves with
## the camera by (1 - factor) and sits lower by its depth, so it shows where the gameplay plane would.

const SHADER := preload("res://shaders/motif_window.gdshader")
## z = depth (m) of the layer, factor = parallax, cell = one window slot per cell of layer pixels.
const LAYERS := [
	{"z": -21.0, "factor": 0.2, "cell": Vector2(170, 120), "seed": 11},
	{"z": -11.0, "factor": 0.32, "cell": Vector2(210, 150), "seed": 23},
	{"z": -8.0, "factor": 0.42, "cell": Vector2(260, 180), "seed": 37},
]
const LIFE := 14.0
## How far back (m) a window drifts over its life.
const DRIFT := 3.0

var _layers: Array[Node3D] = []
## Per window: {mesh, layer, cell (Rect2 in layer px), slot, period, offset}.
var _windows: Array[Dictionary] = []
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
		var span: Vector2 = view + max_cam * l.factor + Vector2(64, 64)
		var cell: Vector2 = l.cell
		for cy in ceili(span.y / cell.y):
			for cx in ceili(span.x / cell.x):
				var s: int = seed * 13 + l.seed
				if DotNoise.hash2(cx, cy, s) < 0.2:
					continue
				var mi := MeshInstance3D.new()
				mi.mesh = QuadMesh.new()
				mi.material_override = _mat
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mi.extra_cull_margin = absf(l.z) / 3 + 2
				node.add_child(mi)
				_windows.append({
					"mesh": mi, "layer": li, "cell": Rect2(Vector2(cx, cy) * cell - Vector2(32, 32), cell),
					"slot": cy * 100 + cx, "period": LIFE * (0.8 + DotNoise.hash2(cx, cy, s + 1) * 0.5),
					"offset": DotNoise.hash2(cx, cy, s + 2) * LIFE, "seed": s, "life": -1,
				})


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
	for w in _windows:
		var t: float = Game.time + w.offset
		var life := floori(t / w.period)
		var age: float = fmod(t, w.period) / w.period
		var mi: MeshInstance3D = w.mesh
		if life != w.life:
			# A new life: a new size, place in its cell and text.
			w.life = life
			var h := func(k: int) -> float: return DotNoise.hash2(w.slot, life * 8 + k, w.seed)
			var size := Vector2(48 + 4 * floori(h.call(0) * 13), 28 + 4 * floori(h.call(1) * 7))
			var cell: Rect2 = w.cell
			var room := (cell.size - size).max(Vector2.ZERO)
			w.rect = Rect2((cell.position + Vector2(h.call(2), h.call(3)) * room).round(), size)
			(mi.mesh as QuadMesh).size = size * Px.M
			mi.set_instance_shader_parameter("win_size", size)
			mi.set_instance_shader_parameter("seed", float(w.slot * 31 + life))
		var r: Rect2 = w.rect
		var l: Dictionary = LAYERS[w.layer]
		mi.position = Vector3((r.position.x + r.size.x / 2) * Px.M, -(r.position.y + r.size.y / 2) * Px.M,
			l.z - DRIFT * age)
		mi.set_instance_shader_parameter("age", age)
