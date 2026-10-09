class_name Main
extends Node2D

## Root of the vertical slice. $Terrain is a converted level (levels/<id>.tscn, see
## tools/convert_level.gd); load_level() swaps it and puts the player on its Start marker.

const LEVELS_INDEX := "res://levels/index.json"
const PLAYER := preload("res://scenes/player.tscn")
const ORANGE := Color("#D97757")
const RED := Color("#E0605A")

## Level to load on start; set by the level select before it switches to this scene.
static var start_level := "1-1"

var levels: Array
var level_ids: Array
var level_id: String
## Metadata of the current level from levels/index.json (theme, dark, risingVoid, terrainSeed, ...).
var level: Dictionary
var player: Player

@onready var terrain: TileMapLayer = $Terrain
@onready var camera: GameCamera = $Camera2D
@onready var particles: Particles = $Particles
@onready var terrain_view: TerrainView = $TerrainView
@onready var parallax: Parallax = $Background/Parallax
@onready var screen_fx: ScreenFx = $ScreenFx
@onready var glow_layer: GlowLayer = $GlowLayer


func _ready() -> void:
	levels = JSON.parse_string(FileAccess.get_file_as_string(LEVELS_INDEX))
	level_ids = levels.map(func(l): return l.id)
	player = PLAYER.instantiate()
	add_child(player)
	player.event.connect(_on_player_event)
	load_level(start_level)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("next_level"):
		next_level()


func next_level() -> void:
	load_level(level_ids[(level_ids.find(level_id) + 1) % level_ids.size()])


func load_level(id: String) -> void:
	var layer: TileMapLayer = load("res://levels/%s.tscn" % id).instantiate()
	# The TileMapLayer keeps collision and the spawned nodes; TerrainView draws the tiles.
	layer.self_modulate = Color.TRANSPARENT
	# Free the old level at once, so its bugs leave the "enemies" group before the next physics frame.
	remove_child(terrain)
	terrain.free()
	terrain = layer
	add_child(terrain)
	move_child(terrain, terrain_view.get_index() + 1)
	level_id = id
	level = levels[level_ids.find(id)]
	terrain_view.build(terrain, level.terrainSeed)
	glow_layer.terrain_view = terrain_view
	parallax.setup(level.theme, camera)
	screen_fx.setup(level.get("dark", false), player, camera)
	RenderingServer.set_default_clear_color(Color("#111111") if level.theme == "caves" else Color("#161616"))
	Game.reset()
	particles.clear()

	# Level size like Level.pixelW / pixelH in TS: widest map row by number of rows.
	var cells := terrain.get_used_rect()
	camera.bounds = Vector2(cells.end) * 16
	camera.trauma = 0
	player.enter_level(terrain, terrain.get_node("Start").position, camera.bounds.y)
	camera.snap_to(player.position + Vector2(0, -Player.SIZE.y))


func shake(amount: float) -> void:
	camera.shake(amount)


func _physics_process(dt: float) -> void:
	if Game.frozen():
		return
	# Target is the player's centre, like camera.update(dt, p.cx, p.y + p.h / 2, ...) in game.ts.
	camera.follow(dt, player.position + Vector2(0, -Player.SIZE.y / 2), player.facing, player.is_on_floor(), player.velocity.y)


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
