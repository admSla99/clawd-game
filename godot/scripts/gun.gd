class_name Gun
extends Node3D

## Clawd's weapon in world 2: `Gun` in src/entities/gun.ts with the weapon part of GameScene (updateWeapon(),
## computeAim()) in src/scenes/game.ts. Every shot adds context heat; filling the context window (Weapons.heat_cap())
## overflows the gun for 1.3 s while it cools. Heat drains 32 a second, three quarters of the cap a second while
## overflowed. It runs after the player (process_physics_priority), so Clawd faces where he aims.
## Aim: the mouse while it moved in the last 4 s or a mouse button is held (MouseAiming()), else the keys: up /
## down (down only in the air) with or without a side, else straight ahead. Switching: next / prev (R / Q, the
## wheel) through the owned weapons, 1-5 for a slot (not while a weapon item is equipped: then Clawd holds its gun); the weapon's name shows over Clawd for a moment.
## Drawn as the voxel gun (GunSprite) in Clawd's hands, turned to the aim around its grip (upside down when
## aiming left, like the 2D sprite), kicking back on each shot, with a muzzle flash.

const SHOT_SFX := {"token": "gunToken", "pellet": "gunPellet", "glyph": "gunGlyph", "beam": "gunBeam", "orb": "gunOrb"}
const CELL := 2.0
const MOUSE_AIM_MS := 4000
## The gun sits this far in front of Clawd (px), lifted by a third of it against the oblique shift.
const FRONT := 6.0
const FLASH := ["..o..o..", ".oWWWWo.", "..WWWW..", ".oWWWWo.", "..o..o.."]

static var MATERIAL := Voxel.material()
static var FLASH_MESH := Voxel.mesh(FLASH, {"W": Color.WHITE, "o": Color("#F0A585")}, {"W": 2, "o": 2}, Px.M, Voxel.material(1.8))

var main: Node
var player: Player
var armed := false
var weapon: Dictionary = Weapons.get_def("blaster")
var heat := 0.0
var overheated := 0.0
var cooldown := 0.0
var flash := 0.0
var recoil := 0.0
var shot_count := 0
## Size of the gun in his hands: Main shrinks it to 0 while Clawd is pulled into the exit (a port addition).
var shrink := 1.0
## Seconds the weapon's name still shows over Clawd.
var label_t := 0.0
## Last mouse position in the window's view pixels (= level pixels from the camera's top-left; the SubViewport is
## PAD larger on every side) and when it last moved (poll_mouse()).
var mouse_view := Vector2.ZERO
var mouse_moved := -1_000_000
var _hand: Node3D
var _gun: MeshInstance3D
var _flash: MeshInstance3D


func setup(m: Node, p: Player) -> void:
	main = m
	player = p
	process_physics_priority = 10
	_hand = Node3D.new()
	_hand.name = "Gun"
	player.add_child(_hand)
	_gun = MeshInstance3D.new()
	_hand.add_child(_gun)
	_flash = MeshInstance3D.new()
	_flash.mesh = FLASH_MESH
	player.add_child(_flash)
	arm(false)


## Arms Clawd with weapon `id` (world 2) or puts the gun away; a new level starts cool.
func arm(on: bool, id := "blaster") -> void:
	armed = on
	player.armed = on
	heat = 0.0
	overheated = 0.0
	cooldown = 0.0
	flash = 0.0
	recoil = 0.0
	shrink = 1.0
	label_t = 2.5 if on else 0.0
	# An equipped weapon item (Gear) decides the gun.
	if not Gear.weapon().is_empty():
		id = Items.BASES[Gear.weapon().base].weapon
	set_weapon(id if Weapons.WEAPONS.has(id) else "blaster")
	_update_visual()


func set_weapon(id: String) -> void:
	weapon = Weapons.get_def(id)
	cooldown = maxf(cooldown, 0.12)
	_gun.mesh = GunSprite.mesh(id, CELL, MATERIAL)


func heat_cap() -> float:
	return Weapons.heat_cap()


## Reads the mouse from the window's own viewport every frame. Events would not do: the gun lives inside the
## SubViewport, and its container (View) ignores the mouse, so no mouse event ever reaches it there. A press of
## a button counts as a move, like mouseButton() in src/core/input.ts.
func poll_mouse() -> void:
	if main == null:
		return
	var m: Vector2 = main.get_viewport().get_mouse_position()
	if m != mouse_view or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		mouse_view = m
		mouse_moved = Time.get_ticks_msec()


func _process(_dt: float) -> void:
	poll_mouse()


## Aiming with the mouse: it moved in the last 4 s or a button is held.
func mouse_aiming() -> bool:
	return Time.get_ticks_msec() - mouse_moved < MOUSE_AIM_MS or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) \
		or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)


## The mouse in level pixels.
func mouse_world() -> Vector2:
	return main.camera.top_left + mouse_view


## gunPivot(): Clawd's arm, 5 px ahead of his middle and 9 px above his feet.
func pivot() -> Vector2:
	return player.pos + Vector2(player.facing * 5, -9)


## computeAim() without the touch and stick parts.
func compute_aim() -> float:
	var pv := pivot()
	if mouse_aiming():
		var w := mouse_world()
		return atan2(w.y - pv.y, w.x - pv.x)
	var up := Input.is_action_pressed("up")
	var down := Input.is_action_pressed("down") and not player.on_ground
	var side := Input.is_action_pressed("left") or Input.is_action_pressed("right")
	var f := float(player.facing)
	if up:
		return atan2(-1, f) if side else -PI / 2
	if down:
		return atan2(1, f) if side else PI / 2
	return 0.0 if f > 0 else PI


func _physics_process(dt: float) -> void:
	if not armed or main.mode != Main.Mode.PLAY or Game.frozen() or not player.in_play():
		return
	poll_mouse()
	_switch()
	label_t = maxf(0.0, label_t - dt)
	player.aim = compute_aim()
	if player.state != &"spin":
		player.facing = 1 if cos(player.aim) >= 0 else -1
	var can_shoot: bool = main.complete_t < 0 and player.state != &"spin" and player.hurt_timer <= 0 and not player.frozen
	fire(dt, can_shoot and Input.is_action_pressed("attack"))
	_update_visual()


## updateWeapon(): next / prev cycle through the owned weapons, 1-5 pick a slot.
func _switch() -> void:
	if not Gear.weapon().is_empty():
		return
	var owned := Weapons.owned()
	var cur := owned.find(weapon.id)
	var next := ""
	if Input.is_action_just_pressed("next") and owned.size() > 1:
		next = owned[(cur + 1) % owned.size()]
	if Input.is_action_just_pressed("prev") and owned.size() > 1:
		next = owned[(cur - 1 + owned.size()) % owned.size()]
	for i in 5:
		if Input.is_action_just_pressed("slot%d" % (i + 1)) and owned.has(Weapons.ORDER[i]):
			next = Weapons.ORDER[i]
	if next != "" and next != weapon.id:
		set_weapon(next)
		Progress.equipped = next
		Progress.save()
		label_t = 1.5
		Sound.play("select")


## Gun.update(): returns true when it fired this frame.
func fire(dt: float, trigger: bool) -> bool:
	cooldown -= dt
	flash = maxf(0.0, flash - dt)
	recoil = maxf(0.0, recoil - dt * 6)
	if overheated > 0:
		overheated -= dt
		heat = maxf(0.0, heat - heat_cap() * 0.75 * dt)
		if overheated <= 0:
			heat = 0.0
		return false
	heat = maxf(0.0, heat - 32 * dt)
	if not trigger or cooldown > 0:
		return false
	var w := weapon
	var angle := player.aim
	cooldown = 1.0 / (w.fire_rate * Weapons.rate_mult())
	heat += w.heat
	var muzzle := pivot() + Vector2(cos(angle), sin(angle)) * 16
	var damage: float = w.damage * Weapons.damage_mult()
	# Temperature 1.5 (a System Prompt): wilder aim, now and then a double hit.
	var temp := Prompts.on("temperature")
	if temp and randf() < Prompts.TEMP_CRIT:
		damage *= 2.0
	# Critical strikes (gear): the weapon item's base chance and `crit`, for 150 % plus `crit_multi`.
	if randf() < Stats.crit_chance():
		damage *= Stats.crit_mult()
	if w.kind == "beam":
		main.fire_beam(muzzle, angle, damage)
	else:
		for i in w.pellets:
			var fan_offset: float = -w.fan / 2 + w.fan * i / (w.pellets - 1) if w.pellets > 1 else 0.0
			var a: float = angle + fan_offset + (randf() - 0.5) * 2 * (w.spread + (Prompts.TEMP_SPREAD if temp else 0.0))
			var speed: float = w.speed * (0.85 + randf() * 0.3 if w.pellets > 1 else 1.0)
			Bullet.fire(main.level, muzzle, a, speed, w, damage)
	shot_count += 1
	if w.kind != "beam" or shot_count % 4 == 0:
		Sound.play(SHOT_SFX[w.kind])
	flash = 0.06
	recoil = 1.0 if w.kind == "orb" else 0.8 if w.kind == "pellet" else 0.35
	if w.kind == "orb":
		main.shake(0.15)
	if w.kind == "pellet":
		main.shake(0.08)
	main.particles.emit(muzzle, {count = 6 if w.kind == "pellet" else 2, speed = 60, angle = angle, spread = 0.8, life = 0.12, color = [Color.WHITE, w.color]})
	if heat >= heat_cap():
		overheated = 1.3
		Sound.play("overheat")
	return true


## The gun in Clawd's hands (drawArmedExtras()): turned to the aim about its grip at the pivot, upside down
## when aiming left, kicked back by the recoil; hidden while he spins and whenever his body is (pulled into the
## exit), shrunk towards his middle by `shrink`.
func _update_visual() -> void:
	_hand.visible = armed and player.state != &"spin" and player.visual.visible and shrink > 0
	_flash.visible = _hand.visible and flash > 0
	if not _hand.visible:
		return
	var a := player.aim
	var rows: int = GunSprite.SPRITES.get(weapon.id, GunSprite.SPRITES.blaster).size()
	var w := GunSprite.cells(weapon.id) * CELL
	var basis := Basis(Vector3.BACK, -a)
	if cos(a) < 0:
		basis = basis * Basis(Vector3.RIGHT, PI)
	_hand.transform = Transform3D(basis.scaled(Vector3.ONE * maxf(shrink, 0.01)), Vector3(player.facing * 5 * shrink, 9 + FRONT / 3, FRONT) * Px.M)
	_gun.position = Vector3(w / 2 - recoil * 2.5, CELL - rows * CELL, 0) * Px.M
	var m := Vector2(cos(a), sin(a)) * 17
	_flash.position = Vector3(player.facing * 5 + roundf(m.x), 9 - roundf(m.y) - 2 + FRONT / 3, FRONT) * Px.M
