class_name ScreenFx
extends CanvasLayer

## Screen-space layers over the level: darkness for `dark` levels (game.ts drawDarkness) and the CRT
## scanlines + vignette (renderer.ts postFx). Glow targets are nodes in the "dark_glow" group.

var crt_enabled := true:
	set(v):
		crt_enabled = v
		$Crt.visible = v
var dark := false
var player: Node2D
var camera: GameCamera


func setup(is_dark: bool, p: Node2D, cam: GameCamera) -> void:
	dark = is_dark
	player = p
	camera = cam
	$Darkness.visible = dark
	$DarkGlow.visible = dark


func _process(_dt: float) -> void:
	var view := get_viewport().get_visible_rect().size
	$Crt.material.set_shader_parameter("view_scale", float(get_tree().root.size.y) / view.y)
	if not dark or player == null:
		return
	var to_view := func(world: Vector2) -> Vector2: return world - camera.top_left - camera.offset
	var dm: ShaderMaterial = $Darkness.material
	dm.set_shader_parameter("view_size", view)
	# Player centre; Clawd's origin is at his feet.
	dm.set_shader_parameter("player_pos", to_view.call(player.global_position + Vector2(0, -9)))
	dm.set_shader_parameter("radius", 105 + sin(Game.time * 2) * 3)
	var pts := PackedVector2Array()
	for n in get_tree().get_nodes_in_group("dark_glow"):
		if pts.size() < 32 and n.visible:
			pts.append(to_view.call(n.global_position))
	var gm: ShaderMaterial = $DarkGlow.material
	gm.set_shader_parameter("view_size", view)
	gm.set_shader_parameter("glow_count", pts.size())
	pts.resize(32)
	gm.set_shader_parameter("glows", pts)
