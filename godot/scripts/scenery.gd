class_name Scenery
extends Node3D

## Towers and floating blocks behind the level, drawn by shaders/scenery.gdshader. Three layers at
## growing depth, each mixed further into the haze. The camera is orthographic, so depth alone gives no
## parallax: update() moves every layer with the camera by (1 - factor), and offsets it by its depth so
## its front faces land on the view where the same level pixel of the gameplay plane would. Positions
## are whole view pixels, so the box-local pixel pattern stays crisp.

const SHADER := preload("res://shaders/scenery.gdshader")
## Depth of every box in metres; the top band is DEPTH / GameCamera.ROW_Z view rows.
const DEPTH := 1.5
## z = depth of the front faces (a multiple of 3/16 m, so the depth offset is whole pixels), factor =
## parallax factor, haze = haze_amount, floating = number of floating blocks per 480 px.
const LAYERS := [
	{"z": -27.0, "factor": 0.15, "haze": 0.72, "floating": 0.0, "seed": 101},
	{"z": -15.0, "factor": 0.3, "haze": 0.5, "floating": 1.5, "seed": 202},
	{"z": -6.0, "factor": 0.5, "haze": 0.3, "floating": 2.0, "seed": 303},
]

var _layers: Array[Node3D] = []
var _materials: Array[ShaderMaterial] = []


## Builds the layers for a level of `bounds` pixels seen through a `view`-sized window, coloured with
## a Themes palette.
func setup(seed: int, bounds: Vector2, view: Vector2, palette: Dictionary) -> void:
	for c in get_children():
		c.free()
	_layers.clear()
	_materials.clear()
	var max_cam_y := maxf(0, bounds.y - view.y)
	for l: Dictionary in LAYERS:
		var f: float = l.factor
		var s: int = seed * 7 + l.seed
		var node := Node3D.new()
		add_child(node)
		_layers.append(node)
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		mat.set_shader_parameter("haze_amount", l.haze)
		mat.set_shader_parameter("row_z", GameCamera.ROW_Z)
		mat.set_shader_parameter("haze", Themes.vec(palette.haze))
		mat.set_shader_parameter("light_color", Themes.vec(palette.light))
		_materials.append(mat)
		var width := view.x + maxf(0, bounds.x - view.x) * f + 64
		# Towers stand on a ground line below the view wherever the camera is.
		var ground := view.y + max_cam_y * f + 24
		var x := -32.0 + floorf(DotNoise.hash2(0, 9, s) * 40)
		var i := 0
		while x < width:
			var w := 4.0 * (5 + floori(DotNoise.hash2(i, 0, s) * 11))
			var h := view.y * (0.25 + DotNoise.hash2(i, 1, s) * 0.5)
			_box(node, mat, Rect2(x, roundf(ground - h), w, h + 32), DotNoise.hash2(i, 2, s) * 1000)
			x += w + 4.0 * floori(DotNoise.hash2(i, 3, s) * 12)
			i += 1
		# Floating blocks in the upper half of the view (at the lowest camera position).
		for k in floori(width / 480 * l.floating):
			var w := 4.0 * (4 + floori(DotNoise.hash2(k, 4, s) * 9))
			var h := 4.0 * (2 + floori(DotNoise.hash2(k, 5, s) * 4))
			var bx := floorf(DotNoise.hash2(k, 6, s) * width)
			var by := roundf(max_cam_y * f + view.y * (0.1 + DotNoise.hash2(k, 7, s) * 0.4))
			_box(node, mat, Rect2(bx, by, w, h), DotNoise.hash2(k, 8, s) * 1000)


## Moves the layers for the camera's top-left corner (level pixels).
func update(cam: Vector2) -> void:
	for i in _layers.size():
		var l: Dictionary = LAYERS[i]
		var off: Vector2 = (cam * (1.0 - l.factor)).round()
		# Seen down the pitched view, a point -l.z metres behind the gameplay plane must sit -l.z * tan(PITCH)
		# lower to show where the matching plane point would.
		_layers[i].position = Vector3(off.x * Px.M, -off.y * Px.M + l.z * tan(GameCamera.PITCH), 0)


func _process(_dt: float) -> void:
	for mat in _materials:
		mat.set_shader_parameter("game_time", Game.time)


## A box whose front face covers `r` (layer pixels, y down) at the layer's depth.
func _box(layer: Node3D, mat: ShaderMaterial, r: Rect2, seed: float) -> void:
	var l: Dictionary = LAYERS[_layers.find(layer)]
	var size := Vector3(r.size.x * Px.M, r.size.y * Px.M, DEPTH)
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3((r.position.x + r.size.x / 2) * Px.M, -(r.position.y + r.size.y / 2) * Px.M, l.z - DEPTH / 2)
	mi.set_instance_shader_parameter("box_size", size)
	mi.set_instance_shader_parameter("seed", floorf(seed))
	layer.add_child(mi)
