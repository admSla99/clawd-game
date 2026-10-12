class_name RisingVoid
extends Node3D

## The rising null of levels with `risingVoid` (1-3 Context Window), from updateVoid() / drawVoid() in
## src/scenes/game.ts. It starts 40 px below the level and, after `delay` seconds, rises at `speed` px/s;
## it is never more than 14 tiles below Clawd. When his feet sink 4 px into it he falls out (a heart, back
## to the checkpoint), and every respawn puts it 10 tiles below the checkpoint with a 2 s grace. It waits
## while the world is frozen and once the level is complete.
## Drawn in 2.5D as a slab of null across the level and through the whole block depth (shaders/void.gdshader):
## a dark front with a wavy, glitching top edge and a top face of flickering red / purple / grey bits, with
## bits fizzing up from it; "NULL ▲ RISING" blinks in red just below its edge (Overlay, group "world_text").

const SHADER := preload("res://shaders/void.gdshader")
const START_BELOW := 40.0
const RESPAWN_BELOW := 16 * 10.0
const RESPAWN_DELAY := 2.0
const MAX_BEHIND := 16 * 14.0
const KILL_DEPTH := 4.0
## Depth of the slab in metres, a little more than the blocks' 3 m so it swallows them whole.
const DEPTH := 4.0
const RED := Color("#E0605A")
const PURPLE := Color("#C25BD6")

var speed := 22.0
var delay := 4.0
## Top of the void in level pixels.
var y := INF
var level: Level
var _slab: MeshInstance3D
var _mat: ShaderMaterial


## Adds the void to `l` with the level's `risingVoid` settings.
static func create(l: Level, settings: Dictionary) -> RisingVoid:
	var v := RisingVoid.new()
	v.name = "RisingVoid"
	v.level = l
	v.speed = settings.get("speed", 22.0)
	v.delay = settings.get("delay", 4.0)
	v.y = l.pixel_size.y + START_BELOW
	l.add_child(v)
	return v


func _ready() -> void:
	add_to_group("world_text")
	var size := level.pixel_size * Px.M
	var box := BoxMesh.new()
	# Reaches past the level's sides and far below its bottom, wherever its top is.
	box.size = Vector3(size.x + 8, size.y + 24, DEPTH)
	box.subdivide_depth = 1
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("half_depth", DEPTH / 2)
	_mat.set_shader_parameter("row_z", GameCamera.ROW_Z)
	box.material = _mat
	_slab = MeshInstance3D.new()
	_slab.mesh = box
	_slab.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_slab.extra_cull_margin = 4.0
	add_child(_slab)
	_place()


func _physics_process(dt: float) -> void:
	var main := get_tree().get_first_node_in_group("main")
	var player: Player = get_tree().get_first_node_in_group("player")
	if Game.frozen() or not main or not player or main.complete_t >= 0 or player.frozen or not player.in_play():
		return
	if delay > 0:
		delay -= dt
	else:
		# Never too far behind Clawd.
		y = minf(y, player.pos.y + MAX_BEHIND) - speed * dt
		if player.pos.y > y + KILL_DEPTH:
			player.fall_out()
	_place()
	# Bits of null fizz up from its surface around the view.
	if randf() < 0.5 and main.camera:
		var x: float = main.camera.top_left.x + randf() * main.camera.view_size().x
		Fx.burst(self, Vector2(x, y + 2), {count = 1, speed = 20, angle = -PI / 2, spread = 0.6, life = 0.6,
			color = [RED, PURPLE, Color8(200, 200, 200)], depth = 24})


## Back below the checkpoint after a respawn (respawn() in TS).
func reset(spawn_y: float) -> void:
	y = spawn_y + RESPAWN_BELOW
	delay = RESPAWN_DELAY
	_place()


func _place() -> void:
	var top := roundf(y)
	var size := level.pixel_size * Px.M
	_slab.position = Vector3(size.x / 2, -top * Px.M - (size.y + 24) / 2, 0)
	_mat.set_shader_parameter("top", -top * Px.M)


func _process(_dt: float) -> void:
	_mat.set_shader_parameter("game_time", Game.time)


## "NULL ▲ RISING" blinking twice a second, 16 px below the edge but kept in the view.
func overlay_draw(o: Overlay) -> void:
	var main := get_tree().get_first_node_in_group("main")
	if not main or floori(Game.time * 2) % 2 != 0:
		return
	var view: Vector2 = main.camera.view_size()
	var cam: Vector2 = main.camera.top_left
	if y > cam.y + view.y + 10:
		return
	var v := o.to_view(Vector2(cam.x + view.x / 2, minf(y + 16, cam.y + view.y - 8)))
	PixelFont.draw_centred(o, "NULL ▲ RISING", v.x, v.y, RED)
