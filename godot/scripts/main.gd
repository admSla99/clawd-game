class_name Main
extends Node

## Root of the game and its main scene. The game renders into a SubViewport at the view size (~480x270, see
## ViewScale) that the container scales up by a whole factor with nearest filtering, so the 3D pixel
## shaders, Clawd and the particles land on whole view pixels; the CRT overlay sits on top at window
## resolution. Level is a converted level (levels/<id>.tscn, see tools/convert_level.gd); load_level()
## swaps it and puts the player on its Start marker.
## Four modes, like the TS scenes: TITLE (src/scenes/title.ts), MAP (src/scenes/levelSelect.ts) and SHOP
## (src/scenes/shop.ts) draw their screens (FrontEnd, ShopScreen) over BACKDROP, a level the camera slowly drifts
## through with Clawd away; PLAY is the game.

const LEVELS_INDEX := "res://levels/index.json"
const PLAYER := preload("res://scenes/player.tscn")
## Extra pixels the SubViewport renders on every side, hidden by offsetting the container (see
## GameCamera.pad): the oblique projection draws block fronts up to 8 px below their real position.
const PAD := 16
## Blob shadow radii in metres (terrain_pixels.gdshader): Clawd is 18 px wide, a bug 16 px.
const PLAYER_SHADOW := 0.5
const ENEMY_SHADOW := 0.42
## Dark levels (`dark` in levels/index.json): the darkest the TS darkness gets (rgba(8,8,8,0.93) at the edge
## of drawDarkness()), Clawd's lamp radius in px (105, breathing by 3 px) and how far in front of him it
## hangs in metres (so the block fronts at z = 1.5 m catch it like the gameplay plane), and how bright the
## sky, the parallax ridges and the air light stay.
const DARK_AMOUNT := 0.93
const LAMP_RADIUS := 105.0
const LAMP_Z := 1.0
const DARK_SKY := 0.3
const ORANGE := Color("#D97757")
const RED := Color("#E0605A")
## PLAYER.tokensPerHeart and PLAYER.heartCap in src/config.ts. TS gives a heart per 100 tokens; with every enemy
## dropping 5× its tokens that would be 2-3 extra hearts in each world-2 level, so the port asks for 300.
const TOKENS_PER_HEART := 300
const HEART_CAP := 5

enum Mode { TITLE, MAP, PLAY, SHOP }

## The level behind the title and the map.
const BACKDROP := "1-1"
## Drift of the camera behind the title and the map, px/s (the 2D parallax scroll speeds).
const TITLE_DRIFT := 18.0
const MAP_DRIFT := 6.0

## What the scene opens with (tools/check.gd starts straight in PLAY on start_level).
static var start_mode := Mode.TITLE
static var start_level := "1-1"

var mode := Mode.PLAY
## Camera x of the drift behind the title and the map.
var drift_x := 0.0

var levels: Array
var level_ids: Array
var level_id: String
## Metadata of the current level from levels/index.json (theme, dark, risingVoid, terrainSeed, ...).
var info: Dictionary
var player: Player
## Tokens collected in this run of the level, and how many it has.
var tokens := 0
var tokens_total := 0
## Seconds since the exit was reached, or -1 while playing.
var complete_t := -1.0
## Sub-agents rescued in this run, one per `A` (SubAgent.index).
var agents: Array[bool] = []
## Sparks found in this run, one per `S` (Spark.index), and which were found on earlier runs.
var sparks: Array[bool] = []
var prev_sparks: Array[bool] = []
## Whether this run finished the level for the first time (the results say what it unlocked).
var first_clear := false
## A Double Tokens from the shop is active in this run (every token counts twice).
var double_tokens := false
## The darkness of the current level (`dark`): its amount and Clawd's lamp, as passed to the shaders' globals.
var dark_amount := 0.0
var dark_lamp := Vector4.ZERO
## The rising null of the current level (`risingVoid`: 1-3), or null.
var rising_void: RisingVoid = null
## The theme's 3D motif among the scenery (MOTIFS_3D), or null.
var motif_3d: Node3D = null
## The level's boss while it lives (1-B, 2-B), or null; and whether this run found a weapon.
var boss: Enemy = null
var weapon_found_run := false
## Clawd's weapon (armed in world 2) and the Attention Beam's flashes.
var gun: Gun
var beams: BeamFx

@onready var view: SubViewportContainer = $View
@onready var subviewport: SubViewport = $View/SubViewport
@onready var world: Node3D = $View/SubViewport/World
@onready var level: Level = $View/SubViewport/World/Level
@onready var camera: GameCamera = $View/SubViewport/World/Camera3D
@onready var particles: Particles = $View/SubViewport/World/Particles
@onready var parallax: Parallax = $View/SubViewport/World/Background/Parallax
@onready var haze: ColorRect = $View/SubViewport/World/Background/Haze
@onready var motif: ColorRect = $View/SubViewport/World/Background/Motif
@onready var scenery: Scenery = $View/SubViewport/World/Scenery
@onready var motes: Motes = $View/SubViewport/World/Motes
@onready var light_fx: ColorRect = $View/SubViewport/World/Foreground/LightFx
@onready var grade: ColorRect = $View/SubViewport/World/Grade/Grade
@onready var crt: ColorRect = $ScreenFx/Crt
@onready var overlay: Overlay = $View/SubViewport/World/Ui/Overlay
@onready var hud: Hud = $View/SubViewport/World/Ui/Hud
@onready var menu: GameMenu = $View/SubViewport/World/Ui/Menu
@onready var front: FrontEnd = $View/SubViewport/World/Ui/FrontEnd
@onready var shop: ShopScreen = $View/SubViewport/World/Ui/Shop


func _ready() -> void:
	add_to_group("main")
	levels = JSON.parse_string(FileAccess.get_file_as_string(LEVELS_INDEX))
	level_ids = levels.map(func(l): return l.id)
	player = PLAYER.instantiate()
	world.add_child(player)
	player.event.connect(_on_player_event)
	gun = Gun.new()
	gun.name = "GunControl"
	world.add_child(gun)
	gun.setup(self, player)
	beams = BeamFx.new()
	beams.name = "Beams"
	world.add_child(beams)
	hud.bind(player)
	menu.main = self
	crt.visible = Settings.crt
	camera.pad = PAD
	overlay.camera = camera
	get_tree().root.size_changed.connect(_resize)
	_resize()
	front.main = self
	shop.main = self
	if start_mode == Mode.PLAY:
		play(start_level)
	else:
		show_title()


## The menus (pause, controls, keybindings) get every event first; mouse positions move into SubViewport
## pixels, which start PAD px left of and above the window.
func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		event = event.duplicate()
		event.position += Vector2.ONE * PAD
	var screen: Variant = shop if mode == Mode.SHOP else front
	if menu.handle(event) or (mode != Mode.PLAY and not menu.is_open() and screen.handle(event)):
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if mode == Mode.PLAY and event.is_action_pressed("next_level"):
		next_level()


## Sizes the SubViewport to the view (ViewScale) plus PAD on every side and hides the padding.
func _resize() -> void:
	var v := get_viewport().get_visible_rect().size
	subviewport.size = Vector2i(v) + Vector2i.ONE * PAD * 2
	view.position = -Vector2.ONE * PAD
	view.size = Vector2(subviewport.size)


func next_level() -> void:
	load_level(level_ids[(level_ids.find(level_id) + 1) % level_ids.size()])


## Starts level `id` (startLevel() in src/app.ts).
func play(id: String) -> void:
	mode = Mode.PLAY
	front.close()
	shop.close()
	load_level(id)


## The title screen over the drifting backdrop.
func show_title() -> void:
	_backdrop()
	mode = Mode.TITLE
	front.open_title()
	Sound.play_music("title")


## The world map, on level index `focus` (or the first unfinished unlocked one), over the drifting backdrop.
func show_map(focus := -1) -> void:
	_backdrop()
	mode = Mode.MAP
	shop.close()
	front.open_map(focus)
	Sound.play_music("map")


## The shop, over the drifting backdrop (goToShop()).
func show_shop() -> void:
	_backdrop()
	mode = Mode.SHOP
	front.close()
	shop.open()
	Sound.play_music("shop")


## Loads BACKDROP for the title and the map (unless it is already there, untouched) with Clawd put away.
func _backdrop() -> void:
	if mode == Mode.PLAY or level_id != BACKDROP:
		load_level(BACKDROP)
		drift_x = 0.0
	Game.paused = false
	hud.visible = false
	player.park()


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
	rising_void = RisingVoid.create(level, info.risingVoid) if info.has("risingVoid") else null
	boss = _spawn_boss()
	weapon_found_run = false
	level.set_param("row_z", GameCamera.ROW_Z)
	level.set_param("ambient", Themes.vec(Themes.palette(info.theme).light))
	for key in ["top", "mid", "haze"]:
		level.set_param("fog_" + key, Themes.vec(Themes.palette(info.theme)[key]))
	Game.reset()
	particles.clear()
	overlay.clear()
	tokens = 0
	first_clear = false
	# Sub-agents rescued on an earlier run come back as ghosts (`!!savedAgents[s.index]`).
	var saved: Array = Progress.progress_for(id).agents
	agents = []
	for a: SubAgent in level.get_children().filter(func(c: Node) -> bool: return c is SubAgent):
		a.ghost = a.index < saved.size() and saved[a.index]
		agents.append(false)
	# Sparks found on an earlier run are ghosts (`this.prevSparks`).
	var found: Array = Progress.progress_for(id).sparks
	sparks = []
	prev_sparks = []
	var spark_nodes := level.get_children().filter(func(c: Node) -> bool: return c is Spark)
	for i in spark_nodes.size():
		sparks.append(false)
		prev_sparks.append(i < found.size() and found[i])
	for sp: Spark in spark_nodes:
		sp.ghost = prev_sparks[sp.index]
	hud.reset(id, info.name)
	hud.agents = agents
	hud.sparks = sparks
	hud.visible = true
	Sound.play_music(info.get("music", ""))
	# Every token placed in the map plus what every enemy drops (twice that with Double Tokens).
	double_tokens = Progress.in_stock("double") > 0
	hud.double_tokens = double_tokens
	var dropped := 0
	for e: Enemy in get_tree().get_nodes_in_group("enemies"):
		dropped += e.token_total()
	tokens_total = (level.get_children().filter(func(c: Node) -> bool: return c is Token).size() + dropped) \
		* (2 if double_tokens else 1)
	complete_t = -1.0
	var texts: Array = info.get("signs", [])
	for s in level.get_children().filter(func(c: Node) -> bool: return c is Sign):
		s.text = texts[s.index] if s.index < texts.size() else "..."

	camera.bounds = level.size()
	camera.trauma = 0
	var start := Px.of(level.get_node("Start").position)
	_apply_loadout()
	player.enter_level(level, start, camera.bounds.y)
	beams.clear()
	# World 2 is armed; a level started there without a weapon gets the blaster (the TS dev shortcut).
	var armed: bool = mode == Mode.PLAY and int(info.world) == 2
	if armed and Progress.weapons.is_empty():
		Progress.grant_weapon("blaster")
	gun.arm(armed, Progress.equipped)
	# World 2's bugs and spam bots are tougher (`tough` in spawnEntities()), and every enemy has HP_FACTOR
	# times its TS hit points in the port (bosses keep theirs, projectiles have none to speak of).
	for e: Enemy in get_tree().get_nodes_in_group("enemies"):
		if int(info.world) == 2:
			if e is Bug:
				e.hp = 2.0
			elif e is SpamBot:
				e.hp = 3.0
		if e.health_bar and not e.projectile:
			e.hp *= Enemy.HP_FACTOR
	camera.snap_to(start + Vector2(0, -Player.SIZE.y))
	var palette := Themes.palette(info.theme)
	scenery.setup(info.terrainSeed, camera.bounds, camera.view_size(), palette, info.get("dark", false) == true)
	scenery.set_param("glitch", info.theme == "boss")
	if motif_3d:
		motif_3d.free()
		motif_3d = null
	var motif_script := motif_script_for(info.theme)
	if motif_script:
		motif_3d = motif_script.new()
		motif_3d.name = "Motif3D"
		world.add_child(motif_3d)
		motif_3d.setup(info.terrainSeed, camera.bounds, camera.view_size(), palette)
	Decor.populate(level, info.terrainSeed, palette, info.get("dark", false) == true)
	parallax.setup(info.theme, camera, palette)
	for key in ["top", "mid", "haze", "ray"]:
		haze.material.set_shader_parameter(key + "_color", Themes.vec(palette[key]))
	var dark: bool = info.get("dark", false) == true
	motes.setup(info.terrainSeed, camera.bounds, palette, dark)
	light_fx.material.set_shader_parameter("ray_color", Themes.vec(palette.ray))
	light_fx.material.set_shader_parameter("mist_color", Themes.vec(palette.haze))
	light_fx.material.set_shader_parameter("ray_strength", 0.05 if dark else 0.16)
	light_fx.material.set_shader_parameter("mist_strength", 0.14 if dark else 0.32)
	# The darkness (shaders/darkness.gdshaderinc): the terrain, scenery and sprites read these globals.
	dark_amount = DARK_AMOUNT if dark else 0.0
	RenderingServer.global_shader_parameter_set("dark_amount", dark_amount)
	haze.material.set_shader_parameter("dim", DARK_SKY if dark else 1.0)
	parallax.modulate = Color(DARK_SKY, DARK_SKY, DARK_SKY) if dark else Color.WHITE
	var motif_shader := motif_shader_for(info.theme)
	motif.visible = motif_shader != null
	if motif_shader:
		var mat := ShaderMaterial.new()
		mat.shader = motif_shader
		mat.set_shader_parameter("line_color", Themes.vec(palette.ray))
		mat.set_shader_parameter("haze_color", Themes.vec(palette.haze))
		mat.set_shader_parameter("mid_color", Themes.vec(palette.mid))
		mat.set_shader_parameter("strength", 1.0)
		motif.material = mat
	_update_lamp()
	grade.material.set_shader_parameter("shadow_tint", Themes.vec(palette.haze))
	scenery.update(camera.top_left)


func shake(amount: float) -> void:
	camera.shake(amount)


func _physics_process(dt: float) -> void:
	# The jet's hiss while Clawd hovers (hoverStart() / hoverStop()); pausing stops it, like openPause().
	Sound.hover(mode == Mode.PLAY and player.hovering and not Game.paused and complete_t < 0)
	if mode != Mode.PLAY:
		_drift(dt)
		return
	if Game.frozen():
		return
	# Target is the player's centre, like camera.update(dt, p.cx, p.y + p.h / 2, ...) in game.ts.
	camera.follow(dt, player.pos + Vector2(0, -Player.SIZE.y / 2), player.facing, player.on_ground, player.vel.y)
	scenery.update(camera.top_left)
	_update_complete(dt)
	_update_shadows()
	_update_reveal()
	var decor: Decor = level.get_node_or_null("Decor")
	if decor:
		decor.interact(player.pos, dt)


func _process(_dt: float) -> void:
	crt.material.set_shader_parameter("view_scale", float(get_tree().root.size.y) / get_viewport().get_visible_rect().size.y)
	haze.material.set_shader_parameter("scroll", camera.top_left.x)
	haze.material.set_shader_parameter("game_time", Game.time)
	if motif.visible:
		motif.material.set_shader_parameter("scroll", camera.top_left)
		motif.material.set_shader_parameter("game_time", Game.time)
	light_fx.material.set_shader_parameter("scroll", camera.top_left.x)
	light_fx.material.set_shader_parameter("game_time", Game.time)
	# The level's bottom edge in SubViewport rows (the SubViewport starts PAD above the view).
	light_fx.material.set_shader_parameter("mist_y", camera.bounds.y - camera.top_left.y + PAD)
	_update_lights()
	_update_lamp()


## Clawd's lamp for the dark levels: on his middle, LAMP_Z in front of him, its radius breathing like
## `105 + Math.sin(this.time * 2) * 3` in drawDarkness().
func _update_lamp() -> void:
	var at := player.global_position + Vector3(0, Player.SIZE.y / 2 * Px.M, LAMP_Z)
	var radius := (LAMP_RADIUS + sin(Game.time * 2) * 3) * Px.M
	dark_lamp = Vector4(at.x, at.y, at.z, radius)
	RenderingServer.global_shader_parameter_set("dark_lamp", dark_lamp)


## Clawd's blob shadow and the enemies' nearest the view centre (Level.SHADOWS_MAX in all), as wide as they
## are; projectiles cast none.
func _update_shadows() -> void:
	var centre := camera.top_left + camera.view_size() / 2
	var enemies: Array = get_tree().get_nodes_in_group("enemies").filter(func(e: Enemy) -> bool: return not e.projectile)
	enemies.sort_custom(func(a: Node, b: Node) -> bool:
		return a.pos.distance_squared_to(centre) < b.pos.distance_squared_to(centre))
	var shadows := PackedVector4Array([level.shadow_at(player.pos, PLAYER_SHADOW)])
	for e in enemies.slice(0, Level.SHADOWS_MAX - 1):
		shadows.append(level.shadow_at(e.pos, ENEMY_SHADOW * e.size.x / 16))
	level.set_shadows(shadows)


## See-through windows in the foreground (shaders/reveal.gdshaderinc) around Clawd and the enemies and
## tokens nearest him, in SubViewport pixels.
func _update_reveal() -> void:
	var near: Array = get_tree().get_nodes_in_group("enemies") + level.get_children().filter(func(c: Node) -> bool: return c is Area3D)
	near.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.global_position.distance_squared_to(player.global_position) < b.global_position.distance_squared_to(player.global_position))
	var windows := [[player.global_position + Vector3(0, Player.SIZE.y / 2, 0) * Px.M, 16.0, 30.0]]
	for n: Node3D in near.slice(0, 5):
		windows.append([n.global_position + Vector3(0, 6, 0) * Px.M, 9.0, 17.0])
	var reveal := PackedVector4Array()
	for w in windows:
		var p := camera.unproject_position(w[0])
		reveal.append(Vector4(p.x, p.y, w[1], w[2]))
	_set_reveal(reveal)


## Sets the see-through windows (at most 6; none behind the title and the map, where the front layer must not
## thin out the title's Clawd, who stands in front of it).
func _set_reveal(reveal: PackedVector4Array) -> void:
	reveal.resize(6)
	for mat: ShaderMaterial in [Voxel.MATERIAL, scenery.foreground_material()]:
		if mat:
			mat.set_shader_parameter("reveal", reveal)


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
	_sound(kind)
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
		&"pound_land":
			_on_pound_land()
		&"die", &"fell":
			# respawn() in TS puts the rising void back below the checkpoint.
			if rising_void:
				rising_void.reset(player.spawn_point.y)
		&"shield":
			# The Firewall broke instead of a heart: a white and orange ring and it leaves the stock.
			particles.emit(at + Vector2(0, -9), {count = 24, speed = 120, life = 0.45, color = [Color.WHITE, Color("#F0A585")], drag = 3})
			shake(0.2)
			Game.hitstop(0.06)
			Progress.use_stock("firewall")
			overlay.popup("FIREWALL", at + Vector2(0, -30), Color("#F0A585"))


## Enemy.die() in src/entities/entity.ts: two bursts from the enemy's middle, enemyDie, hitstop and shake.
func enemy_died(_e: Enemy, at: Vector2) -> void:
	particles.emit(at, {count = 22, speed = 140, life = 0.6, color = [Color.WHITE, Color("#BDBDBD"), RED], gravity = 300, size = 1.5})
	particles.emit(at, {count = 6, speed = 40, life = 0.4, color = [ORANGE], size = 2})
	Sound.play("enemyDie")
	shake(0.18)
	Game.hitstop(0.05)


## The sound of a player event (handlePlayerEvents(), hurtPlayer(), die() and the stomp in src/scenes/game.ts;
## enemyDie from Enemy.die() in src/entities/entity.ts).
func _sound(kind: StringName) -> void:
	match kind:
		&"jump":
			Sound.play("jump")
		&"land", &"hard_land":
			Sound.play("land")
		&"spin":
			Sound.play("spin")
		&"pound_start":
			Sound.play("pound")
		&"pound_land":
			Sound.play("poundLand")
		&"hurt":
			Sound.play("hurt")
		&"shield":
			Sound.play("deflect")
		&"die", &"fell":
			Sound.play("die")
		&"stomp":
			Sound.play("stomp")


## Ground pound landing (onPoundLand() in src/scenes/game.ts): dust and shake, breaks the corrupted
## blocks under Clawd's feet (and keeps falling through them), and the shockwave hits the enemies nearby.
func _on_pound_land() -> void:
	var p := player.pos
	shake(0.3)
	particles.emit(p, {count = 24, speed = 120, angle = -PI / 2, spread = PI, life = 0.45, color = [Color8(220, 220, 220), Color8(140, 140, 140), ORANGE], gravity = 300})
	var ty := floori((p.y + 1) / 16)
	var broke := false
	for tx in range(floori((p.x - Player.SIZE.x / 2) / 16), floori((p.x + Player.SIZE.x / 2 - 0.01) / 16) + 1):
		broke = _break_corrupt(tx, ty) or broke
	if broke:
		Sound.play("break")
		Game.hitstop(0.06)
		player.continue_pound()
	var wave := Rect2(p.x - 30, p.y - 14, 60, 16)
	for e: Enemy in get_tree().get_nodes_in_group("enemies"):
		if not e.projectile and wave.intersects(e.rect()):
			e.hit(&"pound", Enemy.POUND_WAVE_DAMAGE)


## The theme's far background motif (docs/scenery-themes.md), drawn on Background/Motif between the haze and
## the parallax ridges: `shaders/motif_<theme>.gdshader`, found by its name so a new theme's motif needs no change
## here; null for themes without one (Background/Motif stays hidden). It gets the uniforms line_color,
## haze_color, mid_color, strength (load_level()), scroll and game_time (every frame).
static func motif_shader_for(theme: String) -> Shader:
	var path := "res://shaders/motif_%s.gdshader" % theme
	return load(path) if ResourceLoader.exists(path) else null


## The theme's motif built from 3D objects among the scenery layers: `scripts/<theme>_motif.gd`, found by its
## name, a Node3D class with setup(seed, bounds, view, palette); null for themes without one.
static func motif_script_for(theme: String) -> GDScript:
	var path := "res://scripts/%s_motif.gd" % theme
	return load(path) if ResourceLoader.exists(path) else null


## Breaks the corrupted cluster at tile (tx, ty) with debris through the blocks' depth; true if it broke any.
func _break_corrupt(tx: int, ty: int) -> bool:
	var broken := level.break_corrupt(tx, ty)
	for t in broken:
		particles.emit(Vector2(t) * 16 + Vector2(8, 8), {count = 10, speed = 90, life = 0.6, color = [Color8(200, 200, 200), Color("#C25BD6"), ORANGE], gravity = 400, size = 1.5, depth = 24})
	return not broken.is_empty()


## explode() in src/scenes/game.ts (the Opus Cannon's orb): a blast that hurts every enemy whose box comes
## within `radius`, shoots down enemy shots and breaks the corrupted data it reaches.
func explode(at: Vector2, radius: float, damage: float) -> void:
	Sound.play("explode")
	shake(0.3)
	particles.emit(at, {count = 40, speed = 160, life = 0.5, color = [ORANGE, Color("#F0A585"), Color.WHITE, Color8(160, 160, 160)], drag = 3, size = 1.5, depth = 12})
	for i in 24:
		var a := float(i) / 24 * TAU
		particles.emit(at + Vector2(cos(a), sin(a)) * radius * 0.8, {count = 1, speed = 20, life = 0.3, color = [Color("#F0A585")]})
	for e: Enemy in get_tree().get_nodes_in_group("enemies"):
		if e.dead:
			continue
		var r := e.rect()
		var near := Vector2(clampf(at.x, r.position.x, r.end.x), clampf(at.y, r.position.y, r.end.y))
		if near.distance_to(at) > radius:
			continue
		if e.projectile:
			if e.cancellable:
				e.remove()
		else:
			e.hit(&"shot", damage)
	var broke := false
	for ty in range(floori((at.y - radius) / 16), floori((at.y + radius) / 16) + 1):
		for tx in range(floori((at.x - radius) / 16), floori((at.x + radius) / 16) + 1):
			if level.tile(Vector2(tx * 16 + 8, ty * 16 + 8)) == Level.CORRUPT and Vector2(tx * 16 + 8, ty * 16 + 8).distance_to(at) <= radius + 8:
				broke = _break_corrupt(tx, ty) or broke
	if broke:
		Sound.play("break")


## fireBeam(): the Attention Beam hits everything along 300 px from the muzzle until a solid tile (in the port
## anything Bullet.blocked(): platforms too); shields
## block it, enemy shots it can shoot down vanish.
func fire_beam(from: Vector2, angle: float, damage: float) -> void:
	var dir := Vector2(cos(angle), sin(angle))
	var hit := []
	var end := from
	var d := 0.0
	while d < 300:
		end = from + dir * d
		if Bullet.blocked(level, end):
			break
		for e: Enemy in get_tree().get_nodes_in_group("enemies"):
			if not e.dead and not hit.has(e) and e.rect().has_point(end):
				hit.append(e)
		d += 2
	for e: Enemy in hit:
		if e.projectile:
			if e.cancellable:
				e.remove()
			continue
		if e.has_method("blocks_direction") and e.blocks_direction(dir):
			continue
		if e.hit(&"shot", damage) and randf() < 0.3:
			particles.emit(e.rect().get_center(), {count = 2, speed = 60, life = 0.2, color = [BeamFx.CYAN, Color.WHITE]})
	beams.add(from, end)
	particles.emit(end, {count = 1, speed = 40, life = 0.2, color = [BeamFx.CYAN, Color.WHITE]})


## Behind the title and the map the camera drifts right through the level at about the height of its start,
## and starts over at the end (FrontEnd fades it).
func _drift(dt: float) -> void:
	var v := camera.view_size()
	# drift_x is the view's centre: it starts with the level's left edge in view.
	drift_x = maxf(drift_x, v.x / 2) + (TITLE_DRIFT if mode == Mode.TITLE else MAP_DRIFT) * dt
	if drift_x > camera.bounds.x - v.x / 2 + 40:
		drift_x = 0.0
	var start := Px.of(level.get_node("Start").position)
	camera.snap_to(Vector2(drift_x, start.y - 30))
	scenery.update(camera.top_left)
	_update_shadows()
	_set_reveal(PackedVector4Array())


## The shop's upgrades for this level (loadoutFromSave() in src/weapons.ts): Extra Heart, Jet Tuning, and a
## Firewall up while one is in stock.
func _apply_loadout() -> void:
	player.max_hearts = Player.MAX_HEARTS + Progress.upgrade("hearts")
	player.hover_duration = Player.HOVER_DURATION * (1 + 0.3 * Progress.upgrade("hover"))
	player.shield = Progress.in_stock("firewall") > 0


## The Spark Radar's target: the nearest spark in the level that was never found (no ghost), or null.
func radar_target() -> Spark:
	if Progress.upgrade("radar") == 0 or mode != Mode.PLAY:
		return null
	var best: Spark = null
	for c in level.get_children():
		if c is Spark and not c.ghost and not c.is_queued_for_deletion():
			if best == null or c.feet().distance_to(player.pos) < best.feet().distance_to(player.pos):
				best = c
	return best


## A spark was touched (collectSpark() in src/scenes/game.ts): a big burst, a short hitstop and SPARK n/total.
func collect_spark(sp: Spark) -> void:
	if sp.index < sparks.size():
		sparks[sp.index] = true
	Sound.play("spark")
	Game.hitstop(0.05)
	var at := sp.feet() + Vector2(0, -Spark.CENTRE_Y)
	particles.emit(at, {count = 40, speed = 150, life = 0.8, color = [ORANGE, Color("#F0A585"), Color.WHITE], drag = 2, size = 1.5})
	overlay.popup("SPARK %d/%d" % [sparks.count(true), sparks.size()], at + Vector2(0, -10), Color("#F0A585"))
	hud.flash_sparks()


## A sub-agent was touched (rescueAgent() in src/scenes/game.ts).
func rescue_agent(a: SubAgent) -> void:
	if a.index < agents.size():
		agents[a.index] = true
	Sound.play("rescue")
	overlay.popup("SUB-AGENT RESCUED!", player.pos + Vector2(0, -32), Color("#F0A585"))


## A token was picked up at `at` (collectToken() in src/scenes/game.ts): count it, send it flying to the HUD
## counter, and every TOKENS_PER_HEART tokens give a heart, up to HEART_CAP.
## With Double Tokens each counts twice.
func collect_token(at: Vector2) -> void:
	var n := 2 if double_tokens else 1
	var before := tokens
	tokens += n
	Sound.play("token")
	hud.collect_token(overlay.to_view(at), n)
	if tokens / TOKENS_PER_HEART > before / TOKENS_PER_HEART and player.hearts < maxi(HEART_CAP, player.max_hearts):
		player.hearts += 1
		Sound.play("heart")
		overlay.popup("+1 HEART", player.pos + Vector2(0, -28), RED)


## The level's boss (`boss` in levels/index.json) at its 'B' marker, like the 'boss' spawn in spawnEntities():
## centred half a tile above the marker's bottom, over the first solid floor below it, in an arena as wide as the
## level. Null when the level has none.
func _spawn_boss() -> Enemy:
	var marker := level.get_node_or_null("Boss")
	if marker == null or not info.has("boss"):
		return null
	var at := Px.of(marker.position)
	var floor_top := level.floor_below(floori(at.x / 16), floori((at.y - 1) / 16))
	match info.boss:
		"hallucination":
			return Hallucination.create(level, at + Vector2(0, -8), floor_top, level.pixel_size.x)
		"codex":
			return Codex.create(level, at.x, floor_top, level.pixel_size.x)
	return null


## onBossDefeated() in src/scenes/game.ts: a popup, the Token Blaster drops into the middle of the arena (1-B)
## or the exit opens there (2-B), leftover shots vanish and the map tune plays.
func boss_defeated(_b: Enemy, at: Vector2) -> void:
	if info.boss == "codex":
		overlay.popup("CODEX HAS BEEN DEPRECATED", at + Vector2(0, -90), Color("#7FE3EA"), 3.0)
		var goal: Goal = load("res://scripts/goal.gd").new()
		goal.name = "Goal"
		goal.position = Px.to3(Vector2(level.pixel_size.x / 2, at.y))
		level.add_child(goal, true)
	else:
		overlay.popup("THE HALLUCINATION HAS BEEN GROUNDED", at + Vector2(0, -70), Color("#F0A585"), 3.0)
		WeaponPickup.create(level, level.pixel_size.x / 2, at.y)
	for e: Enemy in get_tree().get_nodes_in_group("enemies"):
		if e.projectile:
			e.remove()
	boss = null
	Sound.play_music("map")


## onWeaponFound(): the blaster is Clawd's (saved), a fanfare, and the exit opens 6 tiles right of the middle.
func weapon_found(p: WeaponPickup) -> void:
	Progress.grant_weapon(p.weapon)
	weapon_found_run = true
	Sound.play("weaponGet")
	Game.hitstop(0.3)
	shake(0.4)
	var at := p.feet() + Vector2(0, -18)
	particles.emit(at, {count = 90, speed = 200, life = 1.1, color = [ORANGE, Color("#F0A585"), Color.WHITE], drag = 2, size = 1.5})
	overlay.popup("TOKEN BLASTER ACQUIRED!", at + Vector2(0, -30), Color("#F0A585"), 3.5)
	overlay.popup("world 2 unlocked", at + Vector2(0, -18), Color("#9A9A9A"), 3.5)
	var gx := floori(level.pixel_size.x / 2 / 16) + 6
	var goal: Goal = load("res://scripts/goal.gd").new()
	goal.name = "Goal"
	goal.position = Px.to3(Vector2(gx * 16 + 8, level.floor_below(gx, 1)))
	level.add_child(goal, true)


## A checkpoint was touched (activateCheckpoint() in src/scenes/game.ts): respawn there from now on and
## refill the hearts.
func activate_checkpoint(cp: Checkpoint) -> void:
	player.spawn_point = cp.feet()
	Sound.play("checkpoint")
	# Refill, but keep hearts won from tokens (`if (hearts < maxHearts)` in TS).
	player.hearts = maxi(player.hearts, player.max_hearts)
	particles.emit(cp.feet() + Vector2(0, -22), {count = 24, speed = 90, life = 0.7, color = [ORANGE, Color("#F0A585")], gravity = 120})
	overlay.popup("STATE SAVED", cp.feet() + Vector2(0, -36), Color("#F0A585"), 1.5, Checkpoint.Z, 6.0)


## The exit was touched (reachGoal() in src/scenes/game.ts): Clawd stops and cheers, a big burst, then the
## gate draws him in and the results panel follows (_update_complete()).
func reach_goal(goal: Goal) -> void:
	if complete_t >= 0:
		return
	complete_t = 0.0
	player.frozen = true
	Sound.play("complete")
	Sound.play_music("")
	# recordRun(): the level counts as finished (and what it unlocks opens) as soon as Clawd is through.
	first_clear = not Progress.progress_for(level_id).completed
	Progress.record_run(level_id, sparks, agents, Game.time, tokens)
	# A Double Tokens is used up by a cleared level.
	if double_tokens:
		Progress.use_stock("double")
	particles.emit(goal.feet() + Vector2(0, -Goal.CENTRE_Y), {count = 80, speed = 200, life = 1, color = [ORANGE, Color("#F0A585"), Color.WHITE], drag = 2, size = 1.5})
	shake(0.2)
	set_meta("goal", goal)
	set_meta("time", Game.time)


func _update_complete(dt: float) -> void:
	if complete_t < 0:
		return
	var was := complete_t
	complete_t += dt
	if complete_t > 3.0 and (Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("confirm")):
		# ResultsScene.onClick(): back to the map, on the next level when it is open.
		Sound.play("confirm")
		var i := level_ids.find(level_id)
		show_map(i + 1 if i + 1 < level_ids.size() and Progress.is_unlocked(level_ids, i + 1) else i)
		return
	var goal: Goal = get_meta("goal")
	# Clawd drifts to the middle of the gate; 0.6 s after touching it he is pulled in: he stretches into a
	# thin beam and vanishes in a burst.
	if not Game.frozen():
		player.pos = Vector2(move_toward(player.pos.x, goal.feet().x, 60 * dt), player.pos.y)
	if was < 0.6 and complete_t >= 0.6:
		var tw := create_tween()
		tw.tween_property(player.visual, "scale", Vector3(0.15, 1.7, 0.15), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func() -> void:
			player.visual.visible = false
			particles.emit(goal.feet() + Vector2(0, -Goal.CENTRE_Y), {count = 30, speed = 90, life = 0.6, color = [Color("#F0A585"), Color.WHITE], drag = 3}))
	if was < 2.0 and complete_t >= 2.0:
		var secs: float = get_meta("time")
		# The results scene plays the map tune (src/scenes/results.ts).
		Sound.play_music("map")
		var i := level_ids.find(level_id)
		# The last level thanks the player (ResultsScene), whether or not it is the first clear.
		var last := i == level_ids.size() - 1
		overlay.results = {
			"title": "WORLD %d CLEAR" % info.world if info.has("boss") else "LEVEL COMPLETE",
			"subtitle": "%s · %s" % [level_id, info.name],
			"agents": agents.duplicate(),
			"sparks": sparks.duplicate(),
			"prev_sparks": prev_sparks.duplicate(),
			"rows": [["TOKENS", "%d / %d" % [tokens, tokens_total]], ["TIME", Progress.format_time(secs)]],
			# The first clear names the level it opened (ResultsScene).
			"note": "THANKS FOR PLAYING!" if last \
				else "TOKEN BLASTER FOUND · WORLD 2 UNLOCKED" if weapon_found_run and first_clear \
				else "%s UNLOCKED" % String(levels[i + 1].name).to_upper() if first_clear and i + 1 < levels.size() else "",
			"note_text": "Codex has been deprecated. Clawd ships the fix. The benchmarks are safe… for now." if last else "",
			"t": 0.0,
		}
