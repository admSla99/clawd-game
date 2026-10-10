extends Node

## Autoload "ViewScale": sizes the game view like Renderer.resize() in src/render/renderer.ts.
## Integer scale = max(1, round(min(h / 270, w / 420))), view = window / scale, so the view is
## about 270 tall and at least ~420 wide. canvas_items stretch keeps text and half-pixel detail sharp.

const BASE_VIEW_H := 270.0
const MIN_VIEW_W := 420.0


func _ready() -> void:
	get_tree().root.size_changed.connect(_resize)
	_resize()


func _resize() -> void:
	var root := get_tree().root
	var w := float(root.size.x)
	var h := float(root.size.y)
	if w <= 0 or h <= 0:
		return
	var scale := maxf(1, roundf(minf(h / BASE_VIEW_H, w / MIN_VIEW_W)))
	root.content_scale_size = Vector2i(roundi(w / scale), roundi(h / scale))
