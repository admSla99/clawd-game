class_name GameCamera
extends Camera3D

## Platformer camera ported from src/core/camera.ts: horizontal look-ahead, vertical deadzone,
## level bounds (levels smaller than the view are centred / bottom-aligned) and trauma shake.
## The logic runs in level pixels: `top_left` is the view's top-left corner on the gameplay plane,
## like Camera.x / Camera.y. Orthographic, looking straight down -z and sized so one level pixel is one
## view pixel on both axes (the view is ~480x270 like the 2D port, see ViewScale). Depth is drawn by the
## oblique projection in shaders/oblique.gdshaderinc, as if the camera were pitched down by PITCH. The
## SubViewport renders `pad` extra pixels on every side (Main hides them), so things the oblique shift
## moves into view are not frustum-culled at the edges.

## tan(PITCH) = 1/3 (OBLIQUE in the shaders): one view row covers exactly 3 px (ROW_Z) of depth on a top
## face, so a 3 m deep block shows a 16 px top band and a point 3/16 m further back shows one row higher.
const PITCH := atan(1.0 / 3.0)
const DISTANCE := 40.0
## Metres of depth per view row on horizontal faces (`row_z` in the terrain and scenery shaders).
const ROW_Z := Px.M * 3

var top_left := Vector2.ZERO
var bounds := Vector2.ZERO
var look_ahead := 0.0
var trauma := 0.0
## Extra rendered pixels on every side of the view (set by Main).
var pad := 0.0


func view_size() -> Vector2:
	return get_viewport().get_visible_rect().size - Vector2.ONE * pad * 2


func snap_to(target: Vector2) -> void:
	var v := view_size()
	top_left = Vector2(_clamp_x(target.x - v.x / 2), _clamp_y(target.y - v.y * 0.6))
	look_ahead = 0.0
	_apply()
	reset_physics_interpolation()


## Lowest the camera can go; parallax uses it as the reference height.
func max_y() -> float:
	return _clamp_y(INF)


func follow(dt: float, target: Vector2, facing: int, grounded: bool, vy: float) -> void:
	var v := view_size()
	look_ahead += (facing * 36 - look_ahead) * minf(1, dt * 2.5)
	top_left.x += (target.x - v.x / 2 + look_ahead - top_left.x) * minf(1, dt * 7)

	# Vertical: follow tightly when falling fast or grounded, keep a deadzone while jumping.
	var centre_y := top_left.y + v.y * 0.58
	var dz := 34.0
	var want_y := top_left.y
	if grounded or vy > 260:
		want_y = target.y - v.y * 0.58
	elif target.y < centre_y - dz:
		want_y = target.y + dz - v.y * 0.58
	elif target.y > centre_y + dz:
		want_y = target.y - dz - v.y * 0.58
	var rate := 10.0 if vy > 260 else 5.0 if grounded else 4.0
	top_left.y += (want_y - top_left.y) * minf(1, dt * rate)

	top_left = Vector2(_clamp_x(top_left.x), _clamp_y(top_left.y))
	trauma = maxf(0, trauma - dt * 1.6)
	_apply()


func shake(amount: float) -> void:
	trauma = minf(1, trauma + amount)


func _apply() -> void:
	var s := trauma * trauma * 7
	var full := view_size() + Vector2.ONE * pad * 2
	# Round the rendered area's corner, not its centre, so level pixels land on whole view pixels
	# even when the view is an odd number of pixels wide or tall.
	var corner := (top_left - Vector2.ONE * pad + Vector2(randf_range(-s, s), randf_range(-s, s))).round()
	var centre := Px.to3(corner + full / 2)
	size = full.y * Px.M
	rotation = Vector3.ZERO
	position = centre + Vector3(0, 0, DISTANCE)


func _clamp_x(x: float) -> float:
	var w := view_size().x
	if bounds.x <= w:
		return (bounds.x - w) / 2
	return clampf(x, 0, bounds.x - w)


func _clamp_y(y: float) -> float:
	var h := view_size().y
	if bounds.y <= h:
		return bounds.y - h
	return clampf(y, 0, bounds.y - h)
