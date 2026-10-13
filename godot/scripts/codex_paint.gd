class_name CodexPaint
extends MultiMeshInstance3D

## Rectangles redrawn every frame as flat boxes, for what the 2D Codex drew with fillRect() each frame (its
## face on the screen, the floor telegraphs, the rm -rf column): rect() adds a box `size` px at `at` (px,
## relative to this node, y down like the 2D canvas) from depth z0 to z1 px, in an sRGB colour times `glow`
## (above 1 the WorldEnvironment glow picks it up); alpha blends. Call begin() before and end() after each
## frame's rects. Unshaded with the 2.5D projection (shaders/particles.gdshader).

const MAX := 2048

var _n := 0


func _init() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/particles.gdshader")
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	# Boxes crossing z = 0 need vertices there (the oblique projection bends at it).
	box.subdivide_depth = 1
	box.material = mat
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = box
	multimesh.instance_count = MAX
	multimesh.visible_instance_count = 0
	cast_shadow = SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 16.0


func begin() -> void:
	_n = 0


func rect(at: Vector2, size: Vector2, color: Color, z0 := 0.0, z1 := 1.0, glow := 1.0) -> void:
	if _n >= MAX or size.x <= 0 or size.y <= 0:
		return
	var c := color.srgb_to_linear()
	c = Color(c.r * glow, c.g * glow, c.b * glow, color.a)
	var centre := Vector3(at.x + size.x / 2, -(at.y + size.y / 2), (z0 + z1) / 2) * Px.M
	multimesh.set_instance_transform(_n, Transform3D(Basis.from_scale(Vector3(size.x, size.y, z1 - z0) * Px.M), centre))
	multimesh.set_instance_color(_n, c)
	_n += 1


## PixelFont text with its top-left at `at`, one box per font pixel; a space is `space` px wide (the font's
## is 2). Returns the x just past the last glyph.
func text(s: String, at: Vector2, color: Color, z0 := 0.0, z1 := 1.0, glow := 1.0, space := 2) -> float:
	var x := at.x
	for ch in s:
		if ch == " ":
			x += space + 1
			continue
		var rows := PixelFont.rows(ch)
		for y in rows.size():
			var row: String = rows[y]
			for i in row.length():
				if row[i] == "#":
					rect(Vector2(x + i, at.y + y), Vector2.ONE, color, z0, z1, glow)
		x += rows[0].length() + 1
	return x - 1


## Width of text() in px.
static func text_width(s: String, space := 2) -> int:
	return PixelFont.width(s) - s.count(" ") * (2 - space)


func end() -> void:
	multimesh.visible_instance_count = _n
