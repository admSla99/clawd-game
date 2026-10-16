class_name TdMain
extends Node

## The top-down prototype (branch topdown-prototype; the user's test of an isometric ARPG view, 2026-10-16):
## `scenes/topdown.tscn`, opened with Y on the world map. An isometric orthographic camera (45 degrees round, 35
## down) over a generated arena (TdRoom), rendered into a SubViewport of the view's size so pixels stay crisp; Clawd
## (TdPlayer) moves with WASD, aims with the mouse, shoots with the left button and dodges with Space; waves of bugs
## and spam bots (TdEnemy) come, bigger and of a higher area level each time. Everything counts like the endgame:
## Stats (life, armour, evasion, damage, crits), XP and levels, items and orbs straight into the inventory and the
## pouch, tokens into the wallet. Esc goes back to the world map; dying loses 10 % of the level's XP.

## View pixels per metre (a tile).
const PX_PER_M := 24.0
const AREA_START := 32
const ENEMY_TOKENS := 10
## How far a biting bug is thrown back (m).
const KNOCK := 1.4

var sub: SubViewport
var camera: Camera3D
var world: Node3D
var room: TdRoom
var player: TdPlayer
var hud: TdHud
var enemies: Array[TdEnemy] = []
var shots: Array[TdShot] = []
## [node, velocity, life]
var bits := []
var wave := 0
var kills := 0
var area := AREA_START
var dead_t := -1.0
var next_wave_t := 1.0
var shake := 0.0
var rng := RandomNumberGenerator.new()
var _cam_at := Vector3.ZERO


func _ready() -> void:
	rng.randomize()
	var c := SubViewportContainer.new()
	c.stretch = true
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	sub = SubViewport.new()
	c.add_child(sub)
	world = Node3D.new()
	sub.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#0C0908")
	world.add_child(env)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.rotation_degrees = Vector3(-35.264, 45, 0)
	camera.far = 200
	world.add_child(camera)
	camera.current = true
	var ui := CanvasLayer.new()
	sub.add_child(ui)
	hud = TdHud.new()
	hud.main = self
	ui.add_child(hud)
	Sound.play_music("plains")
	start_run()


## A new arena and Clawd in its middle, wave 0.
func start_run() -> void:
	for n in [room, player]:
		if n:
			n.queue_free()
	for e in enemies:
		e.queue_free()
	for s in shots:
		s.queue_free()
	enemies.clear()
	shots.clear()
	room = TdRoom.new()
	room.generate(rng.randi())
	# The room's colours are the theme's (sRGB); the sprites' are read as the main game's voxel shader reads them.
	var room_mat := TdActor.material()
	room_mat.vertex_color_is_srgb = true
	room.build(Themes.palette("hideout"), room_mat)
	world.add_child(room)
	player = TdPlayer.new()
	player.pos = Vector2(TdRoom.W / 2.0, TdRoom.H / 2.0)
	player.setup()
	world.add_child(player)
	wave = 0
	kills = 0
	area = AREA_START
	dead_t = -1.0
	next_wave_t = 1.0
	_cam_at = Vector3(player.pos.x, 0, player.pos.y)


func _physics_process(dt: float) -> void:
	camera.size = sub.size.y / PX_PER_M
	if Input.is_action_just_pressed("back"):
		Main.start_mode = Main.Mode.MAP
		get_tree().change_scene_to_file("res://scenes/main.tscn")
		return
	_update_bits(dt)
	_follow(dt)
	if dead_t >= 0:
		dead_t += dt
		if dead_t > 0.6 and Input.is_action_just_pressed("jump"):
			start_run()
		return
	var trigger := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_action_pressed("attack")
	for s in player.tick(dt, room, mouse_ground(), trigger, Input.is_action_just_pressed("jump")):
		_add_shot(s)
		Sound.play(Gun.SHOT_SFX.get(player.weapon.kind, "shoot"))
	for e: TdEnemy in enemies.duplicate():
		var s := e.tick(dt, room, player.pos)
		if s:
			_add_shot(s)
		if e.kind == "bug" and e.pos.distance_to(player.pos) < e.radius + player.radius:
			# A bug that bites is thrown back, so it cannot sit on Clawd.
			if _hurt_player() != 0.0:
				e.pos = room.slide(e.pos, (e.pos - player.pos).normalized() * KNOCK, e.radius)
	_separate()
	_update_shots(dt)
	if enemies.is_empty():
		next_wave_t -= dt
		if next_wave_t <= 0:
			spawn_wave()


func spawn_wave() -> void:
	wave += 1
	area = AREA_START + wave - 1
	next_wave_t = 1.5
	for i in 4 + wave * 2:
		var k := "spam" if rng.randf() < 0.3 else "bug"
		var e := TdEnemy.make(k, room.random_floor(player.pos, 7.0), area)
		world.add_child(e)
		e.place()
		enemies.append(e)
	hud.popup("WAVE %d" % wave, _at(player.pos, 1.6), Hud.ORANGE_LIGHT, 1.6)
	Sound.play("checkpoint")


func _add_shot(s: TdShot) -> void:
	world.add_child(s)
	shots.append(s)


func _update_shots(dt: float) -> void:
	for s in shots:
		s.pos += s.vel * dt
		s.life -= dt
		if s.life <= 0 or room.solid_at(s.pos):
			s.dead = true
		elif s.friendly:
			for e in enemies:
				if s.pos.distance_to(e.pos) < e.radius + 0.12:
					s.dead = true
					_hit_enemy(e, s.damage, s.crit)
					break
		elif s.pos.distance_to(player.pos) < player.radius + 0.12 and not player.dodging():
			s.dead = true
			_hurt_player()
		if s.dead:
			s.queue_free()
		else:
			s.place()
	shots = shots.filter(func(s): return not s.dead)


func _hit_enemy(e: TdEnemy, dmg: float, crit: bool) -> void:
	e.hp -= dmg
	e.flash = 0.1
	hud.popup(str(roundi(dmg)) + ("!" if crit else ""), _at(e.pos, e.height + 1.0), Color("#FFE45C") if crit else Color.WHITE, 0.6)
	Sound.play("hit")
	if e.hp <= 0 and not e.dead:
		_kill(e)


## A kill: a burst, XP (a level popping up), maybe an item into the inventory or an orb into the pouch, tokens.
func _kill(e: TdEnemy) -> void:
	e.dead = true
	enemies.erase(e)
	_burst(e.pos, e.height + 0.4, [Color.WHITE, Color("#BDBDBD"), Hud.RED])
	e.queue_free()
	kills += 1
	Sound.play("enemyDie")
	shake = 0.15
	if Progress.add_xp(Experience.kill_xp(e.worth, area, Progress.char_level)) > 0:
		hud.popup("LEVEL %d" % Progress.char_level, _at(player.pos, 1.8), Experience.COLOR, 2.0)
		Sound.play("levelUp")
	Progress.wallet += ENEMY_TOKENS
	if rng.randf() < minf(Main.DROP_MAX, Main.DROP_BASE + e.worth * Main.DROP_PER_HP):
		var it := Items.roll(area, rng, "", "", Stats.total("rarity"))
		if Gear.take(it):
			hud.popup(Items.name_of(it), _at(e.pos, 1.2), Items.color(it), 2.0)
			Sound.play("itemPick")
		else:
			hud.popup("INVENTORY FULL", _at(e.pos, 1.2), Hud.RED, 1.2)
	if rng.randf() < Currency.CHANCE:
		var id := Currency.roll(rng)
		Currency.add(id)
		hud.popup("+1 " + Currency.name_of(id).to_upper(), _at(e.pos, 1.5), Currency.LABEL, 1.6)
	Progress.save()


## Returns what was taken (-1 evaded, 0 nothing: dodging or still in his grace).
func _hurt_player() -> float:
	var taken := player.hurt(-1.0, area)
	if taken < 0:
		hud.popup("EVADE", _at(player.pos, 1.4), Color("#8CE0FF"), 0.8)
	elif taken > 0:
		hud.popup("-%d" % ceili(taken), _at(player.pos, 1.4), Hud.RED, 0.8)
		Sound.play("hurt")
		shake = 0.3
		if player.life <= 0:
			dead_t = 0.0
			var lost := Progress.lose_xp(Main.MAP_DEATH_XP)
			hud.popup("-%d XP" % lost, _at(player.pos, 1.8), Hud.RED, 2.5)
			Sound.play("die")
			_burst(player.pos, 0.5, [Hud.ORANGE, Color.WHITE])
			player.visible = false
	return taken


## Enemies push each other (and Clawd) apart a little.
func _separate() -> void:
	for i in enemies.size():
		for j in range(i + 1, enemies.size()):
			var a := enemies[i]
			var b := enemies[j]
			var d := b.pos - a.pos
			var min_d := a.radius + b.radius
			if d.length() < min_d and d.length() > 0.001:
				var push := d.normalized() * (min_d - d.length()) * 0.5
				a.pos = room.slide(a.pos, -push, a.radius)
				b.pos = room.slide(b.pos, push, b.radius)


func _burst(at: Vector2, h: float, colors: Array) -> void:
	for i in 10:
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3.ONE * 0.09
		m.mesh = b
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = colors[i % colors.size()]
		m.material_override = mat
		m.position = Vector3(at.x, h, at.y)
		world.add_child(m)
		var a := rng.randf() * TAU
		bits.append([m, Vector3(cos(a) * 2.5, rng.randf_range(2.0, 4.0), sin(a) * 2.5), 0.6])


func _update_bits(dt: float) -> void:
	for b in bits:
		b[1].y -= 9.0 * dt
		b[0].position += b[1] * dt
		b[2] -= dt
		if b[2] <= 0:
			b[0].queue_free()
	bits = bits.filter(func(b): return b[2] > 0)


## The camera eases after Clawd, shaking a little after hits.
func _follow(dt: float) -> void:
	var target := Vector3(player.pos.x, 0, player.pos.y)
	_cam_at = _cam_at.lerp(target, minf(1.0, dt * 8.0))
	shake = maxf(0.0, shake - dt)
	var jolt := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)) * shake * 0.25
	camera.position = _cam_at + jolt + camera.basis.z * 60.0


## The point on the ground (at shot height) under the mouse.
func mouse_ground() -> Vector2:
	var mp := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mp)
	var dir := camera.project_ray_normal(mp)
	if absf(dir.y) < 0.001:
		return player.pos
	var t := (TdShot.HEIGHT - from.y) / dir.y
	var p := from + dir * t
	return Vector2(p.x, p.z)


## A point of the world in the view's pixels.
func to_view(p: Vector3) -> Vector2:
	return camera.unproject_position(p).round()


func _at(p: Vector2, h: float) -> Vector3:
	return Vector3(p.x, h, p.y)
