class_name Main
extends Node

## Root of the vertical slice. The game renders into a SubViewport at the view size (~480x270, see
## ViewScale) that the container scales up by a whole factor with nearest filtering, so the 3D pixel
## shaders, Clawd and the particles land on whole view pixels; the CRT overlay sits on top at window
## resolution. Level is a converted level (levels/<id>.tscn, see tools/convert_level.gd); load_level()
## swaps it and puts the player on its Start marker.

const LEVELS_INDEX := "res://levels/index.json"
const PLAYER := preload("res://scenes/player.tscn")
## Extra pixels the SubViewport renders on every side, hidden by offsetting the container (see
## GameCamera.pad): the oblique projection draws block fronts up to 8 px below their real position.
const PAD := 16
## Blob shadow radii in metres (terrain_pixels.gdshader): Clawd is 18 px wide, a bug 16 px.
const PLAYER_SHADOW := 0.5
const ENEMY_SHADOW := 0.42
const ORANGE := Color("#D97757")
const RED := Color("#E0605A")

## Level to load on start; set by the level select before it switches to this scene.
static var start_level := "1-1"

var levels: Array
var level_ids: Array
var level_id: String
## Metadata of the current level from levels/index.json (theme, dark, risingVoid, terrainSeed, ...).
var info: Dictionary
var player: Player

@onready var view: SubViewportContainer = $View
@onready var subviewport: SubViewport = $View/SubViewport
@onready var world: Node3D = $View/SubViewport/World
@onready var level: Level = $View/SubViewport/World/Level
@onready var camera: GameCamera = $View/SubViewport/World/Camera3D
@onready var particles: Particles = $View/SubViewport/World/Particles
@onready var parallax: Parallax = $View/SubViewport/World/Background/Parallax
@onready var haze: ColorRect = $View/SubViewport/World/Background/Haze
@onready var scenery: Scenery = $View/SubViewport/World/Scenery
@onready var crt: ColorRect = $ScreenFx/Crt


func _ready() -> void:
	levels = JSON.parse_string(FileAccess.get_file_as_string(LEVELS_INDEX))
	level_ids = levels.map(func(l): return l.id)
	player = PLAYER.instantiate()
	world.add_child(player)
	player.event.connect(_on_player_event)
	camera.pad = PAD
	get_tree().root.size_changed.connect(_resize)
	_resize()
	load_level(start_level)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("next_level"):
		next_level()


## Sizes the SubViewport to the view (ViewScale) plus PAD on every side and hides the padding.
func _resize() -> void:
	var v := get_viewport().get_visible_rect().size
	subviewport.size = Vector2i(v) + Vector2i.ONE * PAD * 2
	view.position = -Vector2.ONE * PAD
	view.size = Vector2(subviewport.size)


func next_level() -> void:
	load_level(level_ids[(level_ids.find(level_id) + 1) % level_ids.size()])


func load_level(id: String) -> void:
	var next: Level = load("res://levels/%s.tscn" % id).instantiate()
	# Free the old level at once, so its bugs leave the "enemies" group before the next physics frame.
	world.remove_child(level)
	level.free()
	level = next
	world.add_child(level)
	level_id = id
	info = levels[level_ids.find(id)]
	level.bake_cells(info.terrainSeed)
	level.set_param("row_z", GameCamera.ROW_Z)
	Game.reset()
	particles.clear()

	camera.bounds = level.size()
	camera.trauma = 0
	var start := Px.of(level.get_node("Start").position)
	player.enter_level(level, start, camera.bounds.y)
	camera.snap_to(start + Vector2(0, -Player.SIZE.y))
	var palette := Themes.palette(info.theme)
	scenery.setup(info.terrainSeed, camera.bounds, camera.view_size(), palette, info.get("dark", false) == true)
	Decor.populate(level, info.terrainSeed, palette)
	parallax.setup(info.theme, camera, palette)
	for key in ["top", "mid", "haze", "ray"]:
		haze.material.set_shader_parameter(key + "_color", Themes.vec(palette[key]))
	scenery.update(camera.top_left)


func shake(amount: float) -> void:
	camera.shake(amount)


func _physics_process(dt: float) -> void:
	if Game.frozen():
		return
	# Target is the player's centre, like camera.update(dt, p.cx, p.y + p.h / 2, ...) in game.ts.
	camera.follow(dt, player.pos + Vector2(0, -Player.SIZE.y / 2), player.facing, player.is_on_floor(), player.vel.y)
	scenery.update(camera.top_left)
	_update_shadows()


func _process(_dt: float) -> void:
	crt.material.set_shader_parameter("view_scale", float(get_tree().root.size.y) / get_viewport().get_visible_rect().size.y)
	haze.material.set_shader_parameter("scroll", camera.top_left.x)
	haze.material.set_shader_parameter("game_time", Game.time)
	_update_lights()


## Clawd's blob shadow and the enemies' nearest the view centre (Level.SHADOWS_MAX in all).
func _update_shadows() -> void:
	var centre := camera.top_left + camera.view_size() / 2
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	enemies.sort_custom(func(a: Node, b: Node) -> bool:
		return a.pos.distance_squared_to(centre) < b.pos.distance_squared_to(centre))
	var shadows := PackedVector4Array([level.shadow_at(player.pos, PLAYER_SHADOW)])
	for e in enemies.slice(0, Level.SHADOWS_MAX - 1):
		shadows.append(level.shadow_at(e.pos, ENEMY_SHADOW))
	level.set_shadows(shadows)


## Passes the visible GlowLights nearest the view centre (at most Level.LIGHTS_MAX) to the terrain.
func _update_lights() -> void:
	var centre := Px.to3(camera.top_left + camera.view_size() / 2)
	var found: Array = get_tree().get_nodes_in_group("lights").filter(
		func(l: GlowLight) -> bool: return l.is_visible_in_tree() and l.energy > 0)
	found.sort_custom(func(a: GlowLight, b: GlowLight) -> bool:
		return a.global_position.distance_squared_to(centre) < b.global_position.distance_squared_to(centre))
	var lights := PackedVector4Array()
	var energy := PackedFloat32Array()
	for l: GlowLight in found.slice(0, Level.LIGHTS_MAX):
		var p := l.global_position
		lights.append(Vector4(p.x, p.y, p.z, l.radius))
		energy.append(l.energy)
	level.set_lights(lights, energy)


# Same counts, speeds and colors as the matching particles.emit() calls in src/scenes/game.ts.
func _on_player_event(kind: StringName, at: Vector2) -> void:
	match kind:
		&"jump":
			particles.emit(at, {count = 6, speed = 40, angle = -PI / 2, spread = PI, life = 0.3, color = [Color8(170, 170, 170)]})
		&"land", &"hard_land":
			var hard := kind == &"hard_land"
			particles.emit(at, {count = 12 if hard else 6, speed = 60, angle = -PI / 2, spread = PI * 0.9, life = 0.35, color = [Color8(200, 200, 200), Color8(130, 130, 130)], gravity = 200})
			if hard:
				shake(0.12)
		&"hurt":
			particles.emit(at + Vector2(0, -9), {count = 14, speed = 100, life = 0.5, color = [ORANGE, Color.WHITE], gravity = 300})
			shake(0.35)
			Game.hitstop(0.08)
		&"stomp":
			# Enemy death in src/entities/entity.ts: two bursts, hitstop and shake.
			particles.emit(at + Vector2(0, -5), {count = 22, speed = 140, life = 0.6, color = [Color.WHITE, Color("#BDBDBD"), RED], gravity = 300, size = 1.5})
			particles.emit(at + Vector2(0, -5), {count = 6, speed = 40, life = 0.4, color = [ORANGE], size = 2})
			shake(0.18)
			Game.hitstop(0.05)
