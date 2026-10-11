class_name Main
extends Node

## Root of the game and its main scene. The game renders into a SubViewport at the view size (~480x270, see
## ViewScale) that the container scales up by a whole factor with nearest filtering, so the 3D pixel
## shaders, Clawd and the particles land on whole view pixels; the CRT overlay sits on top at window
## resolution. Level is a converted level (levels/<id>.tscn, see tools/convert_level.gd); load_level()
## swaps it and puts the player on its Start marker.
## Three modes, like the TS scenes: TITLE (src/scenes/title.ts) and MAP (src/scenes/levelSelect.ts) draw their
## screens (FrontEnd) over BACKDROP, a level the camera slowly drifts through with Clawd away; PLAY is the game.

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
## PLAYER.tokensPerHeart and PLAYER.heartCap in src/config.ts.
const TOKENS_PER_HEART := 100
const HEART_CAP := 5

enum Mode { TITLE, MAP, PLAY }

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
## Whether this run finished the level for the first time (the results say what it unlocked).
var first_clear := false

@onready var view: SubViewportContainer = $View
@onready var subviewport: SubViewport = $View/SubViewport
@onready var world: Node3D = $View/SubViewport/World
@onready var level: Level = $View/SubViewport/World/Level
@onready var camera: GameCamera = $View/SubViewport/World/Camera3D
@onready var particles: Particles = $View/SubViewport/World/Particles
@onready var parallax: Parallax = $View/SubViewport/World/Background/Parallax
@onready var haze: ColorRect = $View/SubViewport/World/Background/Haze
@onready var scenery: Scenery = $View/SubViewport/World/Scenery
@onready var motes: Motes = $View/SubViewport/World/Motes
@onready var light_fx: ColorRect = $View/SubViewport/World/Foreground/LightFx
@onready var grade: ColorRect = $View/SubViewport/World/Grade/Grade
@onready var crt: ColorRect = $ScreenFx/Crt
@onready var overlay: Overlay = $View/SubViewport/World/Ui/Overlay
@onready var hud: Hud = $View/SubViewport/World/Ui/Hud
@onready var menu: GameMenu = $View/SubViewport/World/Ui/Menu
@onready var front: FrontEnd = $View/SubViewport/World/Ui/FrontEnd


func _ready() -> void:
	add_to_group("main")
	levels = JSON.parse_string(FileAccess.get_file_as_string(LEVELS_INDEX))
	level_ids = levels.map(func(l): return l.id)
	player = PLAYER.instantiate()
	world.add_child(player)
	player.event.connect(_on_player_event)
	hud.bind(player)
	menu.main = self
	crt.visible = Settings.crt
	camera.pad = PAD
	overlay.camera = camera
	get_tree().root.size_changed.connect(_resize)
	_resize()
	front.main = self
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
	if menu.handle(event) or (mode != Mode.PLAY and not menu.is_open() and front.handle(event)):
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
	front.open_map(focus)
	Sound.play_music("map")


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
	hud.reset(id, info.name)
	hud.agents = agents
	hud.visible = true
	Sound.play_music(info.get("music", ""))
	# Every token placed in the map plus what every bug drops.
	tokens_total = level.get_children().filter(func(c: Node) -> bool: return c is Token).size() \
		+ get_tree().get_nodes_in_group("enemies").size() * Bug.TOKENS
	complete_t = -1.0
	var texts: Array = info.get("signs", [])
	for s in level.get_children().filter(func(c: Node) -> bool: return c is Sign):
		s.text = texts[s.index] if s.index < texts.size() else "..."

	camera.bounds = level.size()
	camera.trauma = 0
	var start := Px.of(level.get_node("Start").position)
	player.enter_level(level, start, camera.bounds.y)
	camera.snap_to(start + Vector2(0, -Player.SIZE.y))
	var palette := Themes.palette(info.theme)
	scenery.setup(info.terrainSeed, camera.bounds, camera.view_size(), palette, info.get("dark", false) == true)
	Decor.populate(level, info.terrainSeed, palette, info.get("dark", false) == true)
	parallax.setup(info.theme, camera, palette)
	for key in ["top", "mid", "haze", "ray"]:
		haze.material.set_shader_parameter(key + "_color", Themes.vec(palette[key]))
	var dark: bool = info.get("dark", false) == true
	motes.setup(info.terrainSeed, camera.bounds, palette, dark)
	light_fx.material.set_shader_parameter("ray_color", Themes.vec(palette.ray))
	light_fx.material.set_shader_parameter("mist_color", Themes.vec(palette.haze))
	light_fx.material.set_shader_parameter("ray_strength", 0.1 if dark else 0.16)
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
	light_fx.material.set_shader_parameter("scroll", camera.top_left.x)
	light_fx.material.set_shader_parameter("game_time", Game.time)
	# The level's bottom edge in SubViewport rows (the SubViewport starts PAD above the view).
	light_fx.material.set_shader_parameter("mist_y", camera.bounds.y - camera.top_left.y + PAD)
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
		&"stomp", &"defeat":
			# Enemy death in src/entities/entity.ts: two bursts, hitstop and shake.
			particles.emit(at + Vector2(0, -5), {count = 22, speed = 140, life = 0.6, color = [Color.WHITE, Color("#BDBDBD"), RED], gravity = 300, size = 1.5})
			particles.emit(at + Vector2(0, -5), {count = 6, speed = 40, life = 0.4, color = [ORANGE], size = 2})
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
		&"die", &"fell":
			Sound.play("die")
		&"stomp":
			Sound.play("stomp")
			Sound.play("enemyDie")
		&"defeat":
			Sound.play("enemyDie")


## Ground pound landing (onPoundLand() in src/scenes/game.ts): dust and shake, breaks the corrupted
## blocks under Clawd's feet (and keeps falling through them), and the shockwave defeats bugs nearby.
func _on_pound_land() -> void:
	var p := player.pos
	shake(0.3)
	particles.emit(p, {count = 24, speed = 120, angle = -PI / 2, spread = PI, life = 0.45, color = [Color8(220, 220, 220), Color8(140, 140, 140), ORANGE], gravity = 300})
	var ty := floori((p.y + 1) / 16)
	var broke := false
	for tx in range(floori((p.x - Player.SIZE.x / 2) / 16), floori((p.x + Player.SIZE.x / 2 - 0.01) / 16) + 1):
		for t in level.break_corrupt(tx, ty):
			broke = true
			# The blocks are 3 m deep: spread the debris through their depth.
			particles.emit(Vector2(t) * 16 + Vector2(8, 8), {count = 10, speed = 90, life = 0.6, color = [Color8(200, 200, 200), Color("#C25BD6"), ORANGE], gravity = 400, size = 1.5, depth = 24})
	if broke:
		Sound.play("break")
		Game.hitstop(0.06)
		player.continue_pound()
	var wave := Rect2(p.x - 30, p.y - 14, 60, 16)
	for e in get_tree().get_nodes_in_group("enemies"):
		if wave.intersects(e.rect()):
			_on_player_event(&"defeat", e.pos)
			e.hit(&"pound")


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


## A sub-agent was touched (rescueAgent() in src/scenes/game.ts).
func rescue_agent(a: SubAgent) -> void:
	if a.index < agents.size():
		agents[a.index] = true
	Sound.play("rescue")
	overlay.popup("SUB-AGENT RESCUED!", player.pos + Vector2(0, -32), Color("#F0A585"))


## A token was picked up at `at` (collectToken() in src/scenes/game.ts): count it, send it flying to the HUD
## counter, and every TOKENS_PER_HEART tokens give a heart, up to HEART_CAP.
func collect_token(at: Vector2) -> void:
	tokens += 1
	Sound.play("token")
	hud.collect_token(overlay.to_view(at))
	if tokens % TOKENS_PER_HEART == 0 and player.hearts < HEART_CAP:
		player.hearts += 1
		Sound.play("heart")
		overlay.popup("+1 HEART", player.pos + Vector2(0, -28), RED)


## A checkpoint was touched (activateCheckpoint() in src/scenes/game.ts): respawn there from now on and
## refill the hearts.
func activate_checkpoint(cp: Checkpoint) -> void:
	player.spawn_point = cp.feet()
	Sound.play("checkpoint")
	# Refill, but keep hearts won from tokens (`if (hearts < maxHearts)` in TS).
	player.hearts = maxi(player.hearts, Player.MAX_HEARTS)
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
	Progress.record_run(level_id, agents, Game.time, tokens)
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
		overlay.results = {
			"title": "LEVEL COMPLETE",
			"subtitle": "%s · %s" % [level_id, info.name],
			"agents": agents.duplicate(),
			"rows": [["TOKENS", "%d / %d" % [tokens, tokens_total]], ["TIME", Progress.format_time(secs)]],
			# The first clear names the level it opened (ResultsScene).
			"note": "%s UNLOCKED" % String(levels[i + 1].name).to_upper() if first_clear and i + 1 < levels.size() else "",
			"t": 0.0,
		}
