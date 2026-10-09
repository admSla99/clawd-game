class_name GlowLayer
extends Node2D

## Soft additive halos behind glowing things, like the spark glow in src/entities/collectibles.ts
## (a translucent circle around the sprite). Draws one halo per node in the "glow" group, using the
## node's `glow_color` and `glow_radius`, and one per spike tile in view. Additive, so it only
## brightens, and it keeps the canvas blending of the TS version (no HDR needed).

const SPIKE_COLOR := Color(0.88, 0.38, 0.35)

## White radial falloff, 1 at the centre to 0 at the edge; tinted per halo.
static var FALLOFF: Texture2D = _make_falloff()

var terrain_view: TerrainView


static func _make_falloff() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color.WHITE)
	g.set_color(1, Color.BLACK)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t


func _ready() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m


func _physics_process(_dt: float) -> void:
	if not Game.frozen():
		queue_redraw()


func _draw() -> void:
	for n in get_tree().get_nodes_in_group("glow"):
		if n.visible:
			halo(n.global_position + n.get("glow_offset"), n.get("glow_radius"), n.get("glow_color"))
	if terrain_view == null or terrain_view.terrain == null:
		return
	var view := get_viewport().get_canvas_transform().affine_inverse() * get_viewport_rect()
	var tv := terrain_view
	for ty in range(maxi(0, floori(view.position.y / 16)), mini(tv.h, ceili(view.end.y / 16))):
		for tx in range(maxi(0, floori(view.position.x / 16)), mini(tv.w, ceili(view.end.x / 16))):
			if tv.tile_at(tx, ty) == TerrainView.SPIKE:
				halo(Vector2(tx * 16 + 8, ty * 16 + 12), 10, Color(SPIKE_COLOR.r * 0.35, SPIKE_COLOR.g * 0.35, SPIKE_COLOR.b * 0.35))


## Adds `c` (rgb; alpha ignored) at the centre, fading linearly to nothing at `radius`.
func halo(at: Vector2, radius: float, c: Color) -> void:
	draw_texture_rect(FALLOFF, Rect2(at - Vector2(radius, radius), Vector2(radius, radius) * 2), false, Color(c.r, c.g, c.b, 1.0))
