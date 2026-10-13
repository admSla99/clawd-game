class_name Scenery
extends Node3D

## The neural forest behind the level, drawn by shaders/scenery.gdshader: three layers at growing depth,
## fading further into the sky's depth fog (shaders/fog.gdshaderinc), of trunks (columns of a neuron layer with pulsing node sockets and
## signals climbing their fibres), sagging weight cables between neighbouring trunks that carry light
## pulses, and floating neurons. Between them and the level a midground layer at z = -3 m, anchored to the
## level and drawn with the true perspective of the level geometry (so it shifts against the level as the
## camera moves, like a real object behind it): big dark trunks with ledges sticking out of them, thick
## synapse bridges between them and a few neurons, less hazed than the forest so they read nearer, but
## enough that the ledges do not pass for platforms.
## In front of the level a faster layer of dark silhouettes: clusters of big swaying data ferns, broken trunk
## bases rising from the level's bottom (in dark levels also hanging from its top) and cables hanging into
## the view. Per-theme motifs to add on top are in docs/scenery-themes.md. The camera is orthographic, so
## depth alone gives no
## parallax: update() moves every layer with the camera by (1 - factor), and offsets it by its depth so
## its front faces land on the view where the same level pixel of the gameplay plane would. Positions
## are whole view pixels, so the box-local pixel pattern stays crisp.

const SHADER := preload("res://shaders/scenery.gdshader")
## Depth of every box in metres; the top band is DEPTH / GameCamera.ROW_Z view rows.
const DEPTH := 1.5
## z = depth of the front faces (a multiple of 3/16 m, so the depth offset is whole pixels), factor /
## factor_y = parallax factors, trunk = trunk width range in 4 px steps, gap = gap
## range between trunks in px, cables = range of cables between two neighbouring trunks, neurons =
## floating neurons per 480 px, fg = foreground silhouettes,
## anchored to the level vertically (factor_y 1).
const LAYERS := [
	{"z": -27.0, "factor": 0.15, "factor_y": 0.15, "trunk": [2, 4], "gap": [30, 70], "cables": [0, 1], "neurons": 0.0, "seed": 101},
	{"z": -15.0, "factor": 0.3, "factor_y": 0.3, "trunk": [3, 5], "gap": [50, 110], "cables": [0, 2], "neurons": 2.0, "seed": 202},
	{"z": -6.0, "factor": 0.5, "factor_y": 0.5, "trunk": [4, 7], "gap": [90, 190], "cables": [1, 2], "neurons": 2.5, "seed": 303},
	{"z": -3.0, "factor": 1.0, "factor_y": 1.0, "mid": true, "trunk": [6, 10], "gap": [220, 420], "seed": 505},
	{"z": 6.0, "factor": 1.35, "factor_y": 1.0, "fg": true, "seed": 404},
]
## Instance `kind` in shaders/scenery.gdshader.
const TRUNK := 0
const CABLE := 1
const NEURON := 2
const LEDGE := 3
## Cable thickness in px; the foreground's hanging cables are thicker.
const CABLE_PX := 2.0
const FG_CABLE_PX := 5.0

var _layers: Array[Node3D] = []
var _materials: Array[ShaderMaterial] = []


## Builds the layers for a level of `bounds` pixels seen through a `view`-sized window, coloured with
## a Themes palette; `hanging` adds silhouettes hanging from the level's top.
func setup(seed: int, bounds: Vector2, view: Vector2, palette: Dictionary, hanging := false) -> void:
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
		mat.set_shader_parameter("row_z", GameCamera.ROW_Z)
		for key in ["top", "mid", "haze"]:
			mat.set_shader_parameter("fog_" + key, Themes.vec(palette[key]))
		mat.set_shader_parameter("light_color", Themes.vec(palette.light))
		mat.set_shader_parameter("silhouette", l.get("fg", false))
		mat.set_shader_parameter("world_perspective", l.get("mid", false))
		_materials.append(mat)
		var width := view.x + maxf(0, bounds.x - view.x) * f + 64
		if l.get("fg", false):
			_silhouettes(node, mat, s, width, bounds, view.y, hanging)
			_ferns(node, s, width, bounds, palette.light, hanging)
			continue
		if l.get("mid", false):
			_midground(node, mat, l, s, width, bounds, view.y)
			continue
		# Trunks run from below the view to above it wherever the camera is.
		var ground := view.y + max_cam_y * f + 24
		var band := Vector2(max_cam_y * f + view.y * 0.06, max_cam_y * f + view.y * 0.72) # cable heights
		var trunks: Array[Rect2] = []
		var x := -32.0 + floorf(DotNoise.hash2(0, 9, s) * 40)
		var i := 0
		while x < width:
			var w: float = 4.0 * (l.trunk[0] + floori(DotNoise.hash2(i, 0, s) * (l.trunk[1] - l.trunk[0] + 1)))
			var r := Rect2(x, -40, w, ground + 72)
			trunks.append(r)
			_box(node, mat, r, DotNoise.hash2(i, 2, s) * 1000, TRUNK)
			x += w + l.gap[0] + floorf(DotNoise.hash2(i, 3, s) * (l.gap[1] - l.gap[0]))
			i += 1
		# Weights between neighbouring trunks, nearly level (ends at most 30 px apart in height).
		for t in trunks.size() - 1:
			var a := trunks[t]
			var b := trunks[t + 1]
			for c in l.cables[0] + floori(DotNoise.hash2(t, 10, s) * (l.cables[1] - l.cables[0] + 1)):
				var y0 := roundf(lerpf(band.x, band.y, DotNoise.hash2(t, 11 + c, s)))
				var y1 := roundf(clampf(y0 + (DotNoise.hash2(t, 21 + c, s) - 0.5) * 60, band.x, band.y))
				var sag := (b.position.x - a.end.x) * (0.06 + DotNoise.hash2(t, 31 + c, s) * 0.14)
				_cable(node, mat, Vector2(a.end.x, y0), Vector2(b.position.x, y1), sag, DotNoise.hash2(t, 41 + c, s) * 1000)
		# Floating neurons in the upper part of the view (at the lowest camera position).
		for k in floori(width / 480 * l.neurons):
			var size := 6.0 if DotNoise.hash2(k, 4, s) < 0.6 else 8.0
			var bx := floorf(DotNoise.hash2(k, 6, s) * width)
			var by := roundf(max_cam_y * f + view.y * (0.08 + DotNoise.hash2(k, 7, s) * 0.45))
			_box(node, mat, Rect2(bx, by, size, size), DotNoise.hash2(k, 8, s) * 1000, NEURON, 0.0, size * Px.M)


## Big trunks every 220-420 px from below the level to above it, each with one or two ledges sticking
## out at the side, a thick synapse bridge to the next trunk now and then, and a neuron or two nearby.
## Heights are where the camera sits lowest (most of the level's play happens near its bottom).
func _midground(node: Node3D, mat: ShaderMaterial, l: Dictionary, s: int, width: float, bounds: Vector2, view_h: float) -> void:
	var low := maxf(0, bounds.y - view_h) # top of the view at the lowest camera position
	var trunks: Array[Rect2] = []
	var x := 40.0 + floorf(DotNoise.hash2(0, 9, s) * 120)
	var i := 0
	while x < width:
		var w: float = 4.0 * (l.trunk[0] + floori(DotNoise.hash2(i, 0, s) * (l.trunk[1] - l.trunk[0] + 1)))
		var r := Rect2(x, -40, w, bounds.y + 112)
		trunks.append(r)
		_box(node, mat, r, DotNoise.hash2(i, 2, s) * 1000, TRUNK)
		for k in 1 + int(DotNoise.hash2(i, 3, s) > 0.5):
			var lw := 4.0 * (5 + floori(DotNoise.hash2(i, 4 + k, s) * 5))
			var ly := roundf(low + view_h * (0.18 + DotNoise.hash2(i, 6 + k, s) * 0.45))
			var right := DotNoise.hash2(i, 8 + k, s) > 0.5
			var lx := r.end.x - 4 if right else r.position.x - lw + 4
			_box(node, mat, Rect2(lx, ly, lw, 6), DotNoise.hash2(i, 10 + k, s) * 1000, LEDGE, 0.02, 1.0)
		if DotNoise.hash2(i, 12, s) > 0.4:
			var size := 8.0
			var nx := r.position.x + (w + 30 + DotNoise.hash2(i, 13, s) * 80) * (1 if DotNoise.hash2(i, 14, s) > 0.5 else -1)
			var ny := roundf(low + view_h * (0.1 + DotNoise.hash2(i, 15, s) * 0.4))
			_box(node, mat, Rect2(nx, ny, size, size), DotNoise.hash2(i, 16, s) * 1000, NEURON, 0.0, size * Px.M)
		x += w + l.gap[0] + floorf(DotNoise.hash2(i, 17, s) * (l.gap[1] - l.gap[0]))
		i += 1
	for t in trunks.size() - 1:
		if DotNoise.hash2(t, 20, s) > 0.55:
			continue
		var a := trunks[t]
		var b := trunks[t + 1]
		var y0 := roundf(low + view_h * (0.12 + DotNoise.hash2(t, 21, s) * 0.35))
		var y1 := roundf(y0 + (DotNoise.hash2(t, 22, s) - 0.5) * 40)
		_cable(node, mat, Vector2(a.end.x, y0), Vector2(b.position.x, y1), (b.position.x - a.end.x) * 0.12, DotNoise.hash2(t, 23, s) * 1000, 4.0)


## Clusters of 2-4 big dark ferns every 240-520 px along the level's bottom (in dark levels also hanging
## from its top), drawn as 2 px voxels so they read close, with a faint rim in the theme's light colour on
## the leaflet tips. They sway in shaders/voxel.gdshader.
func _ferns(node: Node3D, s: int, width: float, bounds: Vector2, light: Color, hanging: bool) -> void:
	var l: Dictionary = LAYERS[_layers.find(node)]
	var palette := {"f": Color8(3, 3, 5), "r": Color8(3, 3, 5).lerp(light, 0.22)}
	var x := floorf(DotNoise.hash2(0, 70, s) * 200)
	var i := 0
	while x < width:
		for side in ([1, -1] if hanging and DotNoise.hash2(i, 71, s) > 0.5 else [1]):
			for k in 2 + floori(DotNoise.hash2(i, 72 + side, s) * 3):
				var cells := 28 + floori(DotNoise.hash2(i * 5 + k, 73 + side, s) * 28)
				var rows := _fern_rows(cells, DotNoise.hash2(i * 5 + k, 74 + side, s) * 2 - 1, s + i * 13 + k)
				if side < 0:
					rows.reverse()
				var mi := MeshInstance3D.new()
				mi.mesh = Voxel.mesh(rows, palette, {"f": 2, "r": 2})
				var h := rows.size() * 2 * Px.M
				var fx := x + k * 14 + floorf(DotNoise.hash2(i, 75 + k, s) * 10)
				var base_y := bounds.y + 6 if side > 0 else -6.0
				mi.position = Vector3(fx * Px.M, -base_y * Px.M - (h if side < 0 else 0.0), l.z + k * 0.01)
				mi.set_instance_shader_parameter("sway", Vector4(2.5, DotNoise.hash2(i, 76 + k, s), h, 0 if side > 0 else 1))
				mi.extra_cull_margin = 2.0
				node.add_child(mi)
		x += 240 + floorf(DotNoise.hash2(i, 77, s) * 280)
		i += 1


## One fern frond `cells` tall (2 px cells), leaning by `lean` (-1..1): a curving stem with leaflets on both
## sides that shorten towards the tip, rows top first.
static func _fern_rows(cells: int, lean: float, seed: int) -> Array:
	var w := 23
	var grid := []
	for y in cells:
		var row := []
		row.resize(w)
		row.fill(".")
		grid.append(row)
	for y in cells:
		var t := float(cells - 1 - y) / cells # 0 at the base, 1 at the tip
		var cx := 11 + roundi(lean * 6.0 * t * t)
		grid[y][cx] = "f"
		if y % 2 == 0 and t > 0.08:
			var reach := roundi((1.0 - t) * 6.0 + 1.0)
			for side in [-1, 1]:
				for k in range(1, reach + 1):
					var lx: int = cx + side * k
					var ly: int = y + (k / 3)
					if lx >= 0 and lx < w and ly < cells:
						grid[ly][lx] = "r" if k == reach else "f"
	return grid.map(func(row: Array) -> String: return "".join(PackedStringArray(row)))


## Broken dark trunk bases every 450-900 px, rising from the level's bottom 64-180 px in up to three
## narrowing steps (the taller ones poke above the floor into the haze, where a dark shape reads; over the
## black terrain it would not), with `hanging` the same hanging from its top, and between them dark cables
## that hang 30-110 px into the view at the lowest camera position.
func _silhouettes(node: Node3D, mat: ShaderMaterial, s: int, width: float, bounds: Vector2, view_h: float, hanging: bool) -> void:
	var x := floorf(DotNoise.hash2(0, 19, s) * 300)
	var i := 0
	while x < width:
		for side in ([1, -1] if hanging else [1]):
			var w := 4.0 * (6 + floori(DotNoise.hash2(i, 10 + side, s) * 9))
			var h := 4.0 * (16 + floori(DotNoise.hash2(i, 12 + side, s) * 20))
			var bx := x + (0.0 if side > 0 else floorf(DotNoise.hash2(i, 14, s) * 120))
			# Up to three steps, each narrower and shorter.
			for k in 3:
				if k > 0 and DotNoise.hash2(i, 20 + k * 2 + side, s) < 0.15:
					break
				var r := Rect2(bx, bounds.y - h, w, h + 200) if side > 0 else Rect2(bx, -200, w, h + 200)
				# Each step a hair in front of the last, so overlapping steps don't z-fight.
				_box(node, mat, r, DotNoise.hash2(i, side, s) * 1000, TRUNK, k * 0.01)
				bx += 4.0 * floori(DotNoise.hash2(i, 30 + k, s) * w / 8)
				w = maxf(8, 4.0 * floori(w * 0.6 / 4))
				h += 4.0 * (1 + floori(DotNoise.hash2(i, 40 + k, s) * 3))
		if DotNoise.hash2(i, 60, s) > 0.35:
			var cx := x + 140 + floorf(DotNoise.hash2(i, 61, s) * 120)
			var span := 120 + floorf(DotNoise.hash2(i, 62, s) * 160)
			var top := maxf(0, bounds.y - view_h) - 12
			_cable(node, mat, Vector2(cx, top), Vector2(cx + span, top), 30 + DotNoise.hash2(i, 63, s) * 80, 0, FG_CABLE_PX)
		x += 450 + floorf(DotNoise.hash2(i, 50, s) * 450)
		i += 1


## Sets a uniform on every layer's material (the boss theme's `glitch`).
func set_param(param: StringName, value: Variant) -> void:
	for mat in _materials:
		mat.set_shader_parameter(param, value)


## The material of the foreground layer (for the see-through windows, shaders/reveal.gdshaderinc).
func foreground_material() -> ShaderMaterial:
	for i in LAYERS.size():
		if LAYERS[i].get("fg", false) and i < _materials.size():
			return _materials[i]
	return null


## Moves the layers for the camera's top-left corner (level pixels).
func update(cam: Vector2) -> void:
	for i in _layers.size():
		var l: Dictionary = LAYERS[i]
		var off: Vector2 = (cam * (Vector2.ONE - Vector2(l.factor, l.factor_y))).round()
		# Seen down the pitched view, a point -l.z metres behind the gameplay plane must sit -l.z * tan(PITCH)
		# lower to show where the matching plane point would.
		_layers[i].position = Vector3(off.x * Px.M, -off.y * Px.M + l.z * tan(GameCamera.PITCH), 0)


func _process(_dt: float) -> void:
	for mat in _materials:
		mat.set_shader_parameter("game_time", Game.time)


## A box whose front face covers `r` (layer pixels, y down) at the layer's depth (+ `dz` metres),
## `depth` metres deep; `kind` picks its look in the shader.
func _box(layer: Node3D, mat: ShaderMaterial, r: Rect2, seed: float, kind: int, dz := 0.0, depth := DEPTH) -> void:
	var l: Dictionary = LAYERS[_layers.find(layer)]
	var size := Vector3(r.size.x * Px.M, r.size.y * Px.M, depth)
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The oblique projection draws the box -l.z / 3 m higher than it is (and the midground's perspective
	# moves it towards the view centre); keep it from being culled.
	mi.extra_cull_margin = absf(l.z) / 3 + (4.0 if l.get("mid", false) else 1.0)
	mi.position = Vector3((r.position.x + r.size.x / 2) * Px.M, -(r.position.y + r.size.y / 2) * Px.M, l.z - depth / 2 + dz)
	mi.set_instance_shader_parameter("box_size", size)
	mi.set_instance_shader_parameter("seed", floorf(seed))
	mi.set_instance_shader_parameter("kind", float(kind))
	layer.add_child(mi)


## A flat cable from `a` to `b` (layer pixels, y down) sagging `sag` px in the middle, `thickness` px, just
## in front of the layer's trunks; UV.x runs 0..1 along it for the pulse.
func _cable(layer: Node3D, mat: ShaderMaterial, a: Vector2, b: Vector2, sag: float, seed: float, thickness := CABLE_PX) -> void:
	var l: Dictionary = LAYERS[_layers.find(layer)]
	var n := maxi(8, int(a.distance_to(b) / 6))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := thickness / 2
	for i in n:
		var t0 := float(i) / n
		var t1 := float(i + 1) / n
		var p0 := a.lerp(b, t0) + Vector2(0, sag * 4 * t0 * (1 - t0))
		var p1 := a.lerp(b, t1) + Vector2(0, sag * 4 * t1 * (1 - t1))
		# Clockwise from the front: top-left, top-right, bottom-right, bottom-left (y down in px).
		var corners := [p0 + Vector2(0, -h), p1 + Vector2(0, -h), p1 + Vector2(0, h), p0 + Vector2(0, h)]
		var ts := [t0, t1, t1, t0]
		for k in [0, 1, 2, 0, 2, 3]:
			var v: Vector2 = corners[k]
			st.set_uv(Vector2(ts[k], 0))
			st.set_normal(Vector3.BACK)
			st.add_vertex(Vector3(v.x * Px.M, -v.y * Px.M, 0))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = absf(l.z) / 3 + (4.0 if l.get("mid", false) else 1.0)
	mi.position = Vector3(0, 0, l.z + 0.02)
	mi.set_instance_shader_parameter("box_size", Vector3.ZERO)
	mi.set_instance_shader_parameter("seed", floorf(seed))
	mi.set_instance_shader_parameter("kind", float(CABLE))
	layer.add_child(mi)
