class_name Player
extends CharacterBody3D

## Clawd's movement, ported from src/entities/player.ts with the PLAYER constants from src/config.ts.
## The origin is at the feet, horizontally centred. Movement runs in level pixels (`pos`, `vel`, y down,
## see Px) like the TS game and is converted to metres only for move_and_slide().
## States as in the TS player: normal, spin (attack around Clawd, a hop in the air), pound_windup / pound /
## pound_land (ground pound: down in the air; Main breaks corrupted blocks on landing and calls
## continue_pound()). Hurt is `hurt_timer`. Down + jump on a one-way platform drops through it.

## Moments the game reacts to with particles and camera shake (events in the TS player):
## jump, land, hard_land, hurt, stomp, spin, pound_start, pound_land, drop_through. `at` is where it happened, in level pixels.
signal event(kind: StringName, at: Vector2)

const RUN_SPEED := 150.0
const GROUND_ACCEL := 1500.0
const GROUND_DECEL := 1900.0
const TURN_ACCEL := 2800.0
const AIR_ACCEL := 1100.0
const AIR_DECEL := 520.0
const GRAVITY := 1500.0
const FALL_GRAVITY_MULT := 1.3
const APEX_GRAVITY_MULT := 0.55
const APEX_THRESHOLD := 70.0
const MAX_FALL := 430.0
const JUMP_VELOCITY := 470.0
const COYOTE_TIME := 0.1
const JUMP_BUFFER := 0.12
## Height of a one-way tile's collision strip in px (a quarter of a cell, tools/build_meshlib.gd).
const ONE_WAY_STRIP := 4.0
const HOVER_DURATION := 0.85
const HOVER_FALL_SPEED := 18.0
const HOVER_ACCEL := 2600.0
const CORNER_CORRECTION := 6
const DROP_THROUGH_TIME := 0.18
## The Tool Call's zip (world 3): its speed (px/s), the hop on arrival, and how long it may take at most.
const ZIP_SPEED := 440.0
const ZIP_POP := 250.0
const ZIP_MAX_TIME := 0.9
const SPIN_DURATION := 0.32
const SPIN_COOLDOWN := 0.12
const SPIN_HOP := 160.0
const SPIN_REACH := 10.0
const POUND_WINDUP := 0.14
const POUND_SPEED := 620.0
const STOMP_BOUNCE := 330.0
const STOMP_BOUNCE_HELD := 450.0
const HURT_INVULN := 1.3
const HURT_STUN := 0.32
const HURT_KNOCK_X := 170.0
const HURT_KNOCK_Y := 250.0
const MAX_HEARTS := 3
const SPIN_DOTS := 10
## Spin ring radius and height above the feet in px, like the ring drawn by drawClawd().
const SPIN_RING_R := 17.0
const SPIN_RING_Y := 10.0

const SIZE := Vector2(18, 18)
const HITBOX := Rect2(-7, -15, 14, 15)
const SPIKE_PROBE := Rect2(-6, -6, 12, 6)
## In the endgame: spikes take this share of the life, falling out of the level this share.
const SPIKE_LIFE := 0.15
const FALL_LIFE := 0.2

static var FLASH := flash_material()

var level: Level
var spawn_point: Vector2
## Position and velocity in level pixels, y down.
var pos: Vector2:
	get: return Px.of(position)
	set(v): position = Px.to3(v)
var vel := Vector2.ZERO
var kill_y := INF
var hearts := MAX_HEARTS
## Hearts after a refill and hover time: MAX_HEARTS and HOVER_DURATION raised by the shop's Extra Heart and Jet
## Tuning (loadoutFromSave() in src/weapons.ts); Main sets them per level.
var max_hearts := MAX_HEARTS
var hover_duration := HOVER_DURATION
## A Firewall from the shop is up: the next hit costs no heart.
var shield := false
## The endgame (Main.endgame, docs/endgame-plan.md E2): hit points instead of hearts. A hit costs the area level's
## enemy hit (Stats.enemy_hit()) less armour, evasion may avoid it, spikes take a share of the life and falling out
## more; life regenerates `regen` a second. Main sets these per level (_apply_loadout()).
var hp_mode := false
var life := 100.0
var max_life := 100.0
var armour := 0.0
var evasion := 0.0
var regen := 0.0
var area_level := 1
## What the last hit took (after armour), for the popup.
var last_damage := 0.0
## Enemies' hits times this (a map's mod).
var hit_mult := 1.0
## Resistances (element -> per cent, capped, after a map's penalty) and a map's elements added to enemies' hits
## (element -> per cent of the hit); set by Main._apply_loadout() (docs/endgame-plan.md E7).
var res := {}
var map_ele := {}
## The last hit's main element (the popup's colour), and the ailments on Clawd: burning, chilled, shocked.
var last_element := "physical"
var burn_dps := 0.0
var burn_t := 0.0
var chill_t := 0.0
var shock_t := 0.0
var invuln := 0.0
var hurt_timer := 0.0
var coyote := 0.0
var jump_buffer := 0.0
var jumping := false
var hover_left := HOVER_DURATION
var hovering := false
var facing := 1
## Holding a weapon (world 2): the attack button shoots instead of spinning, and the aim (radians, 0 = right,
## y down like the TS angle, set by Gun every frame) decides which way Clawd faces.
var armed := false
var aim := 0.0
var anim := 0.0
var prev_pos: Vector2
## Scale of $Visual for squash & stretch; eases back to 1. The collision shape keeps its size.
var squash := Vector2.ONE
## Counts down; Clawd blinks while it is below 0 (0.12 s), then it restarts at 2..5 s.
var blink_timer := 2.5
## &"normal", &"spin", &"pound_windup", &"pound", &"pound_land" or &"zip" (pulled to an anchor by the Tool Call).
var state := &"normal"
var state_timer := 0.0
var spin_cooldown := 0.0
var air_spin_used := false
var drop_timer := 0.0
## Standing on one-way tiles only (so down + jump drops through).
var on_one_way := false
## No input, only gravity and slowing down (the level is complete).
var frozen := false
## The platform Clawd stands on (a MovingPlatform or a RateLimiter: anything in the group "platforms" with
## x, y, dx, dy, active and rect()), or null.
var riding = null
## Standing on a tile floor or riding a platform (set after moving).
var on_ground := false
## Where the zip pulls his feet (level px); the Tool Call keeps it on a moving anchor.
var zip_target := Vector2.ZERO
## RUN_SPEED and ZIP_SPEED as the System Prompts change them (Main._apply_loadout()).
var run_speed := RUN_SPEED
var zip_speed := ZIP_SPEED

@onready var visual: Node3D = $Visual
@onready var body: MeshInstance3D = $Visual/Body
@onready var jets: Array[Node] = $Visual/Jets.get_children()
## The spin ring: SPIN_DOTS glowing cubes on a horizontal circle around Clawd (see _update_spin_ring()).
var spin_ring: MultiMeshInstance3D


func _ready() -> void:
	add_to_group("player")
	spin_ring = MultiMeshInstance3D.new()
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/particles.gdshader")
	var box := BoxMesh.new()
	box.size = Vector3.ONE * 2 * Px.M
	box.material = mat
	spin_ring.multimesh = MultiMesh.new()
	spin_ring.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	spin_ring.multimesh.use_colors = true
	spin_ring.multimesh.mesh = box
	spin_ring.multimesh.instance_count = SPIN_DOTS
	spin_ring.layers = 2
	spin_ring.visible = false
	add_child(spin_ring)


## Hit flash: replaces every colour with white, like `tint` in the 2D drawing.
static func flash_material() -> ShaderMaterial:
	var m := Voxel.material()
	m.set_shader_parameter("flash", true)
	return m


func enter_level(l: Level, start: Vector2, level_bottom: float) -> void:
	process_mode = Node.PROCESS_MODE_INHERIT
	collision_layer = 2
	visible = true
	level = l
	spawn_point = start
	kill_y = level_bottom + 24
	hearts = max_hearts
	life = max_life
	clear_ailments()
	respawn()


## Puts Clawd away behind the title and the map: hidden, not moving, and out of reach of the level's tokens,
## bugs and sub-agents. enter_level() brings him back.
func park() -> void:
	frozen = true
	hovering = false
	visible = false
	collision_layer = 0
	process_mode = Node.PROCESS_MODE_DISABLED


func respawn() -> void:
	pos = spawn_point
	prev_pos = pos
	vel = Vector2.ZERO
	velocity = Vector3.ZERO
	squash = Vector2.ONE
	hurt_timer = 0.0
	invuln = 1.0
	jumping = false
	hovering = false
	state = &"normal"
	frozen = false
	riding = null
	visual.scale = Vector3.ONE
	visual.visible = true


## In a level, not parked behind the title or the map (park()). Not `visible`: that blinks while invulnerable.
func in_play() -> bool:
	return process_mode != Node.PROCESS_MODE_DISABLED


## fellOut() in TS (out of the level's bottom, or caught by the rising void): a heart less, and back to the
## checkpoint ("die" when it was the last one, which refills them).
func fall_out() -> void:
	if hp_mode:
		last_damage = max_life * FALL_LIFE
		life -= last_damage
		event.emit(&"die" if life <= 0 else &"fell", pos)
		if life <= 0:
			life = max_life
		respawn()
		return
	hearts -= 1
	event.emit(&"die" if hearts <= 0 else &"fell", pos)
	if hearts <= 0:
		hearts = max_hearts
	respawn()


## Clawd's hurt and pick-up box in level pixels (hitbox in the TS player).
func hitbox() -> Rect2:
	return Rect2(pos + HITBOX.position, HITBOX.size)


## Knocks Clawd away from from_x. Returns false when invulnerable or when the last heart was lost
## (Clawd then respawns with full hearts).
## A Firewall takes the hit instead: Clawd is knocked back and briefly invulnerable, but keeps his hearts.
## In the endgame (hp_mode) the hit takes `damage` life (an enemy's hit of the area level when negative), less
## armour; an `evadable` one may be evaded ("evade": no damage, no knock-back, a short grace).
func hurt(from_x: float, damage := -1.0, evadable := true, element := "physical") -> bool:
	if invuln > 0:
		return false
	var blocked := shield
	if blocked:
		shield = false
	elif hp_mode:
		var dmg := damage if damage >= 0 else Stats.enemy_hit(area_level) * hit_mult
		if evadable and randf() < Stats.evade_chance(evasion, area_level):
			invuln = HURT_INVULN * 0.5
			event.emit(&"evade", pos)
			return false
		last_damage = _mitigate(dmg, element, damage < 0)
		life -= last_damage
		if life <= 0:
			event.emit(&"die", pos)
			life = max_life
			respawn()
			return false
	else:
		hearts -= 1
	if not hp_mode and hearts <= 0:
		event.emit(&"die", pos)
		hearts = max_hearts
		respawn()
		return false
	hurt_timer = HURT_STUN
	invuln = HURT_INVULN
	state = &"normal"
	riding = null
	vel = Vector2((-1.0 if pos.x < from_x else 1.0) * HURT_KNOCK_X, -HURT_KNOCK_Y)
	jumping = false
	hovering = false
	event.emit(&"shield" if blocked else &"hurt", pos)
	return true


## A hit of `dmg` in `element`, plus a map's added elements (`with_map`), each part less armour (physical) or its
## resistance; shocked, the total is more. Ailments from the parts. Returns what it takes.
func _mitigate(dmg: float, element: String, with_map: bool) -> float:
	var parts := {element: dmg}
	if with_map:
		for k in map_ele:
			parts[k] = parts.get(k, 0.0) + dmg * map_ele[k] / 100.0
	var total := 0.0
	var best := 0.0
	for k in parts:
		var p: float = parts[k]
		if k == "physical":
			p *= 1.0 - Stats.armour_reduction(armour, p)
		else:
			p *= 1.0 - res.get(k, 0.0) / 100.0
		parts[k] = p
		total += p
		if p > best:
			best = p
			last_element = k
	if shock_t > 0:
		total *= 1.0 + Stats.SHOCK_TAKEN
	if parts.get("fire", 0.0) > 0 and randf() < Stats.IGNITE_CHANCE:
		burn_t = Stats.BURN_TIME
		burn_dps = maxf(burn_dps, parts.fire * Stats.BURN_SHARE / Stats.BURN_TIME)
	if parts.get("cold", 0.0) > 0:
		chill_t = Stats.CHILL_TIME
	if parts.get("lightning", 0.0) > 0 and randf() < Stats.SHOCK_CHANCE:
		shock_t = Stats.SHOCK_TIME
	return total


## Ailments on Clawd in the endgame: burning takes life (and can kill), chill and shock run out.
func _tick_ailments(dt: float) -> void:
	chill_t = maxf(0.0, chill_t - dt)
	shock_t = maxf(0.0, shock_t - dt)
	if burn_t <= 0:
		return
	burn_t -= dt
	life -= burn_dps * dt
	if burn_t <= 0:
		burn_dps = 0.0
	if life <= 0:
		clear_ailments()
		event.emit(&"die", pos)
		life = max_life
		respawn()


func clear_ailments() -> void:
	burn_t = 0.0
	burn_dps = 0.0
	chill_t = 0.0
	shock_t = 0.0


func _physics_process(dt: float) -> void:
	if Game.frozen():
		return
	prev_pos = pos
	anim += dt
	blink_timer -= dt
	if blink_timer < -0.12:
		blink_timer = 2 + randf() * 3
	squash = squash.lerp(Vector2.ONE, minf(1.0, dt * 12))
	invuln = maxf(0.0, invuln - dt)
	hurt_timer = maxf(0.0, hurt_timer - dt)
	if hp_mode:
		life = minf(max_life, life + regen * dt)
		_tick_ailments(dt)
	jump_buffer = maxf(0.0, jump_buffer - dt)
	spin_cooldown -= dt
	drop_timer -= dt
	if Input.is_action_just_pressed("jump") and not frozen:
		jump_buffer = JUMP_BUFFER
	if state == &"zip":
		_zip(dt)
		return

	# Ride the moving platform (they move before the player): carried sideways, kept on its top.
	if riding:
		var r: Rect2 = riding.rect()
		if not riding.active or pos.x + SIZE.x / 2 <= r.position.x or pos.x - SIZE.x / 2 >= r.end.x:
			riding = null
		else:
			move_and_collide(Vector3(riding.dx, 0, 0) * Px.M)
			# Carried up, a ceiling stops Clawd (moveY() in TS, which one-way tiles do not block); carried
			# down, he just follows.
			if riding.y < pos.y:
				var one_way := get_collision_mask_value(4)
				set_collision_mask_value(4, false)
				move_and_collide(Vector3(0, pos.y - riding.y, 0) * Px.M)
				set_collision_mask_value(4, one_way)
			else:
				pos = Vector2(pos.x, riding.y)
	var grounded := is_on_floor() or riding != null
	if grounded:
		coyote = COYOTE_TIME
		hover_left = hover_duration
		air_spin_used = false
	else:
		coyote = maxf(0.0, coyote - dt)

	var dir := 0.0 if frozen else signf(Input.get_axis("left", "right"))
	if state in [&"pound_windup", &"pound", &"pound_land"]:
		vel.x = 0.0
	elif hurt_timer > 0 or frozen:
		vel.x = move_toward(vel.x, 0.0, AIR_DECEL * dt)
	else:
		var accel: float
		if grounded:
			if dir == 0:
				accel = GROUND_DECEL
			elif vel.x != 0 and signf(vel.x) != dir:
				accel = TURN_ACCEL
			else:
				accel = GROUND_ACCEL
		else:
			accel = AIR_DECEL if dir == 0 else AIR_ACCEL
		vel.x = move_toward(vel.x, dir * run_speed * (Stats.CHILL_FACTOR if chill_t > 0 else 1.0), accel * dt)
		if dir != 0 and not armed:
			if int(dir) != facing and grounded:
				squash = Vector2(0.8, 1.1) # a quick pinch when turning around
			facing = int(dir)

	# Actions: down in the air pounds, spin (or attack, unarmed) spins; down + jump on a one-way drops.
	var can_act := (state == &"normal" or state == &"spin") and hurt_timer <= 0 and not frozen
	if can_act:
		var spin_pressed := Input.is_action_just_pressed("spin") or (not armed and Input.is_action_just_pressed("attack"))
		# Armed, down with the trigger held aims down instead of pounding.
		var down_pressed := Input.is_action_just_pressed("down") and not (armed and Input.is_action_pressed("attack"))
		if not grounded and (down_pressed or (Input.is_action_pressed("down") and spin_pressed)):
			_start_pound()
			can_act = false
		elif spin_pressed and spin_cooldown <= 0 and state != &"spin":
			_start_spin(grounded)
	if can_act:
		if grounded and on_one_way and Input.is_action_pressed("down") and jump_buffer > 0:
			drop_timer = DROP_THROUGH_TIME
			jump_buffer = 0.0
			coyote = 0.0
			grounded = false
			riding = null
			position.y -= Px.M
			event.emit(&"drop_through", pos)
		elif jump_buffer > 0 and (grounded or coyote > 0):
			vel.y = -JUMP_VELOCITY
			jumping = true
			grounded = false
			riding = null
			coyote = 0.0
			jump_buffer = 0.0
			squash = Vector2(0.72, 1.3)
			event.emit(&"jump", pos)

	# Every jump is a full jump: unlike the TS player, letting go of jump early does not cut it short.
	if vel.y >= 0:
		jumping = false

	# Hover: hold jump in the air once rising has (almost) stopped.
	hovering = state == &"normal" and hurt_timer <= 0 and not frozen and not grounded and coyote <= 0 \
		and hover_left > 0 and Input.is_action_pressed("jump") and vel.y > -40
	if state == &"pound_windup" or state == &"pound_land":
		vel.y = 0.0
	elif state == &"pound":
		vel.y = POUND_SPEED
	elif hovering:
		hover_left -= dt
		vel.y = move_toward(vel.y, HOVER_FALL_SPEED, HOVER_ACCEL * dt)
	else:
		var g := GRAVITY
		if absf(vel.y) < APEX_THRESHOLD and Input.is_action_pressed("jump"):
			g *= APEX_GRAVITY_MULT
		elif vel.y > 0:
			g *= FALL_GRAVITY_MULT
		vel.y = minf(vel.y + g * dt, MAX_FALL)

	# State timers.
	state_timer -= dt
	if state_timer <= 0:
		match state:
			&"spin":
				state = &"normal"
				spin_cooldown = SPIN_COOLDOWN
			&"pound_windup":
				state = &"pound"
				vel.y = POUND_SPEED
			&"pound_land":
				state = &"normal"

	var fall_speed := vel.y
	if vel.y < 0:
		_corner_correct(vel.y * dt)
	# One-way platforms block only a falling Clawd whose body is clear of their collision strips, and not while
	# dropping through.
	set_collision_mask_value(4, vel.y >= 0 and drop_timer <= 0 and not _in_one_way_strip())
	velocity = Vector3(vel.x, -vel.y, 0) * Px.M
	move_and_slide()
	vel = Vector2(velocity.x, -velocity.y) / Px.M
	if is_on_ceiling():
		jumping = false
	# Land on a moving platform from above (the platform loop in the TS player's update()).
	var ride = null
	if not is_on_floor() and vel.y >= 0 and drop_timer <= 0:
		for p in get_tree().get_nodes_in_group("platforms"):
			var r: Rect2 = p.rect()
			if not p.active or pos.x + SIZE.x / 2 <= r.position.x or pos.x - SIZE.x / 2 >= r.end.x:
				continue
			if prev_pos.y <= p.y - p.dy + 1.5 and pos.y >= p.y:
				pos = Vector2(pos.x, p.y)
				vel.y = 0.0
				ride = p
				break
	riding = ride
	# A fake platform starts to dissolve once stood on (`ride.onStand?.()`).
	if ride and ride.has_method("on_stand"):
		ride.on_stand()
	on_ground = is_on_floor() or riding != null
	on_one_way = riding != null or (is_on_floor() and _floor_is_one_way())
	if not grounded and on_ground:
		if state == &"pound":
			state = &"pound_land"
			state_timer = 0.16
			squash = Vector2(1.45, 0.6)
			event.emit(&"pound_land", pos)
		elif fall_speed > 120:
			var k := minf(1.0, fall_speed / MAX_FALL)
			squash = Vector2(1 + 0.35 * k, 1 - 0.3 * k)
			event.emit(&"hard_land" if fall_speed > 300 else &"land", pos)
	_check_hazards()
	_update_visual()


## The Tool Call caught an anchor: pulled in a straight line to `target` (his feet), no gravity, no control.
func start_zip(target: Vector2) -> void:
	state = &"zip"
	state_timer = ZIP_MAX_TIME
	zip_target = target
	riding = null
	hovering = false
	jumping = false
	coyote = 0.0
	event.emit(&"zip", pos)


## Ends a zip: with `pop` (he arrived) a hop up off the anchor, else he just lets go and keeps a little of his
## speed. Either way hover and the air spin are fresh.
func end_zip(pop: bool) -> void:
	if state != &"zip":
		return
	state = &"normal"
	vel = Vector2(clampf(vel.x, -RUN_SPEED, RUN_SPEED) * 0.5, -ZIP_POP) if pop else vel * 0.5
	hover_left = hover_duration
	air_spin_used = false
	coyote = 0.0
	if pop:
		squash = Vector2(0.75, 1.3)


## One frame of the zip: straight at zip_target at ZIP_SPEED; arriving (or running out of time) ends it with the
## hop, a wall in the way ends it where he is, and jump lets go with a jump.
func _zip(dt: float) -> void:
	state_timer -= dt
	var to := zip_target - pos
	if jump_buffer > 0 and not frozen:
		end_zip(false)
		jump_buffer = 0.0
		vel.y = -JUMP_VELOCITY
		jumping = true
		squash = Vector2(0.72, 1.3)
		event.emit(&"jump", pos)
	elif to.length() <= zip_speed * dt or state_timer <= 0:
		vel = to / dt if to.length() <= zip_speed * dt else to.normalized() * zip_speed
	else:
		vel = to.normalized() * zip_speed
		if absf(to.x) > 1:
			facing = 1 if to.x > 0 else -1
		squash = squash.lerp(Vector2(1.15, 0.85), 0.5)
	var before := pos
	var arriving := state == &"zip" and to.length() <= zip_speed * dt
	# One-way platforms let him through on the way up, like a jump.
	set_collision_mask_value(4, vel.y >= 0 and drop_timer <= 0 and not _in_one_way_strip())
	velocity = Vector3(vel.x, -vel.y, 0) * Px.M
	move_and_slide()
	vel = Vector2(velocity.x, -velocity.y) / Px.M
	on_ground = is_on_floor()
	on_one_way = is_on_floor() and _floor_is_one_way()
	if state == &"zip":
		if arriving or state_timer <= 0:
			end_zip(true)
			event.emit(&"zip_end", pos)
		elif (pos - before).length() < zip_speed * dt * 0.3:
			# Brittle blocks in the way break and he zips on; anything else solid stops him there.
			var ahead := Rect2(pos - Vector2(SIZE.x / 2, SIZE.y) + (zip_target - pos).normalized() * 4, SIZE)
			var smashed := false
			for ty in range(floori(ahead.position.y / 16), floori((ahead.end.y - 0.01) / 16) + 1):
				for tx in range(floori(ahead.position.x / 16), floori((ahead.end.x - 0.01) / 16) + 1):
					var b := Brittle.at(level, Vector2(tx * 16 + 8, ty * 16 + 8))
					if b:
						b.smash()
						smashed = true
			if not smashed:
				end_zip(false)
	_check_hazards()
	_update_visual()


func _start_spin(grounded: bool) -> void:
	state = &"spin"
	state_timer = SPIN_DURATION
	if not grounded and not air_spin_used:
		vel.y = minf(vel.y, -SPIN_HOP)
		air_spin_used = true
		jumping = false
	hovering = false
	event.emit(&"spin", pos)


func _start_pound() -> void:
	state = &"pound_windup"
	state_timer = POUND_WINDUP
	vel = Vector2.ZERO
	jumping = false
	hovering = false
	event.emit(&"pound_start", pos)


## Called by Main when a ground pound broke through the floor: keep falling.
func continue_pound() -> void:
	state = &"pound"
	vel.y = POUND_SPEED


## Spin attack area in level pixels, or an empty rect when not spinning (attackBox in the TS player).
func attack_box() -> Rect2:
	if state != &"spin":
		return Rect2()
	return Rect2(pos.x - SIZE.x / 2 - SPIN_REACH, pos.y - SIZE.y - 2, SIZE.x + SPIN_REACH * 2, SIZE.y + 4)


## The hover jet that hurts what is below Clawd (hoverBeam in the TS player), or an empty rect.
func hover_beam() -> Rect2:
	return Rect2(pos.x - 6, pos.y, 12, 30) if hovering else Rect2()


## Nudges Clawd sideways (up to CORNER_CORRECTION px) when his head would clip a ceiling corner, like
## cornerCorrect() in the TS player.
func _corner_correct(dy: float) -> void:
	if not _hits_solid(pos + Vector2(0, dy)):
		return
	for off in range(1, CORNER_CORRECTION + 1):
		for side in [1, -1]:
			var p := pos + Vector2(off * side, 0)
			if not _hits_solid(p + Vector2(0, dy)) and not _hits_solid(p):
				pos = p
				return


## Does Clawd's body with its feet at `p` overlap a solid or corrupted tile (rectHitsSolid)?
func _hits_solid(p: Vector2) -> bool:
	var a := p - Vector2(SIZE.x / 2, SIZE.y)
	var b := p + Vector2(SIZE.x / 2, 0) - Vector2(0.001, 0.001)
	for y in range(floori(a.y / 16), floori(b.y / 16) + 1):
		for x in range(floori(a.x / 16), floori(b.x / 16) + 1):
			if level.tile(Vector2(x, y) * 16) in [Level.SOLID, Level.CORRUPT]:
				return true
	return false


## Standing on one-way tiles only (probeGround().oneWayOnly in src/world/collision.ts).
func _floor_is_one_way() -> bool:
	var ty := floori((pos.y + 0.5) / 16)
	var one_way := false
	for x in range(floori((pos.x - SIZE.x / 2) / 16), floori((pos.x + SIZE.x / 2 - 0.001) / 16) + 1):
		var item := level.tile(Vector2(x, ty) * 16)
		if item == Level.SOLID or item == Level.CORRUPT:
			return false
		one_way = one_way or item == Level.ONEWAY
	return one_way


func _check_hazards() -> void:
	if frozen:
		return
	if pos.y > kill_y:
		fall_out()
		return
	if invuln <= 0 and _touches_tile(Level.SPIKE, SPIKE_PROBE):
		if hurt(pos.x + 10.0 * signf(vel.x), max_life * SPIKE_LIFE, false):
			vel.y = -HURT_KNOCK_Y * 1.3

	var hb := Rect2(pos + HITBOX.position, HITBOX.size)
	var attack := attack_box()
	var beam := hover_beam()
	# checkEnemies() in src/scenes/game.ts.
	for e: Enemy in get_tree().get_nodes_in_group("enemies"):
		if e.dead:
			continue
		var er := e.rect()
		# Stomp: falling (or pounding) onto the top part of an enemy. Stomping always bounces, even if
		# the enemy is briefly immune.
		if e.stompable and not e.invincible and (vel.y > 0 or state == &"pound") and hb.intersects(er) \
				and prev_pos.y <= e.stomp_line():
			var pound := state == &"pound"
			e.hit(&"pound" if pound else &"stomp", Enemy.POUND_STOMP_DAMAGE if pound else Enemy.STOMP_DAMAGE)
			event.emit(&"stomp", e.pos)
			_bounce()
			continue
		if attack.has_area() and attack.intersects(er) and e.hit(&"spin", Enemy.SPIN_DAMAGE):
			continue
		if beam.has_area() and not e.projectile and beam.intersects(er) and e.hit(&"beam", Enemy.BEAM_DAMAGE):
			continue
		var hurt_box := e.hurtbox()
		if hurt_box.has_area() and hb.intersects(hurt_box):
			if e.projectile and e.consume_on_hit:
				e.remove()
			hurt(er.get_center().x, -1.0, true, e.element)


## Bounce off an enemy's head (bounce() in the TS player).
func _bounce() -> void:
	var held := Input.is_action_pressed("jump")
	vel.y = -(STOMP_BOUNCE_HELD if held else STOMP_BOUNCE)
	jumping = held
	hover_left = hover_duration
	air_spin_used = false
	riding = null
	if state == &"pound" or state == &"pound_windup":
		state = &"normal"
	squash = Vector2(0.8, 1.25)


func _touches_tile(item: int, probe: Rect2) -> bool:
	var a := pos + probe.position
	var b := pos + probe.end - Vector2(0.001, 0.001)
	for y in range(floori(a.y / 16), floori(b.y / 16) + 1):
		for x in range(floori(a.x / 16), floori(b.x / 16) + 1):
			if level.tile(Vector2(x, y) * 16) == item:
				return true
	return false


## Whether the body overlaps the collision strip of a one-way tile, its top ONE_WAY_STRIP px (the shape in
## tools/build_meshlib.gd). Not the whole tile: where one-way platforms are two rows apart (2-4), the head is
## still in the tile above while the feet reach the one below, and Clawd must land there (moveY() in TS).
func _in_one_way_strip() -> bool:
	var top := pos.y - SIZE.y
	for y in range(floori(top / 16), floori((pos.y - 0.001) / 16) + 1):
		if y * 16 + ONE_WAY_STRIP <= top or y * 16 >= pos.y - 0.001:
			continue
		for x in range(floori((pos.x - SIZE.x / 2) / 16), floori((pos.x + SIZE.x / 2 - 0.001) / 16) + 1):
			if level.tile(Vector2(x, y) * 16) == Level.ONEWAY:
				return true
	return false


## Pose choice follows drawClawd() in src/render/clawdView.ts; ClawdSprite draws it at 1 px with eyes
## that look where Clawd goes, swinging arms and squash & stretch as real body sizes.
func _update_visual() -> void:
	var t := Game.time
	visible = not (invuln > 0 and hurt_timer <= 0 and floori(t * 14) % 2 == 0)
	var o := {"arms": "mid", "legs": "stand", "eyes": "open"}
	var look := Vector2i.ZERO
	var y_off := 0.0
	var turn := 0.0
	if hurt_timer > 0:
		o.arms = "high"
		o.legs = "dangle"
		o.eyes = "squint"
	elif state in [&"pound_windup", &"pound", &"pound_land"]:
		# Arms up, legs tucked, eyes squeezed; a quick turn during the windup like `turn` in drawClawd().
		o.arms = "up"
		o.legs = "tuck"
		o.eyes = "squint"
		if state == &"pound_windup":
			turn = anim * 40
	elif state == &"spin":
		# The idle frame on the ground, the jump frame in the air, turning round and round.
		if not on_ground:
			o.arms = "up"
			o.legs = "tuck"
		turn = anim * 38
	elif state == &"zip":
		# Reaching for the anchor.
		o.arms = "up"
		o.legs = "dangle"
		look.x = 1
	elif frozen:
		o.arms = "high" # cheering at the exit
	elif not on_ground:
		if hovering:
			o.arms = "low"
			o.legs = "dangle"
		elif vel.y < 0:
			o.arms = "up"
			o.legs = "tuck"
		else:
			o.arms = "high"
			o.legs = "dangle"
		look.y = -1 if vel.y < -150 else 1 if vel.y > 150 else 0
	elif absf(vel.x) > 12:
		var phase := floori(anim * (6 + absf(vel.x) / 14)) % 4
		o.legs = "runA" if phase == 0 else "runB" if phase == 2 else "stand"
		o.arms = "swingA" if phase < 2 else "swingB"
		y_off = 1.0 if phase % 2 == 1 else 0.0
		look.x = 1
	else:
		o.eyes = "blink" if blink_timer < 0 else "open"
		y_off = 1.0 if sin(anim * 3) > 0.6 else 0.0
		# Now and then a glance back over the shoulder.
		look.x = -1 if fmod(anim, 7.0) > 5.6 else 0
	o.look = look
	o.bw = clampi(roundi(ClawdSprite.BODY_W * squash.x / 2) * 2, 12, 26)
	o.bh = clampi(roundi(ClawdSprite.BODY_H * squash.y), 10, 22)
	body.mesh = ClawdSprite.mesh(o)
	var rim := GlowLight.rim_for(self, global_position + Vector3(0, 0.5, 0))
	body.set_instance_shader_parameter("rim_light", rim.light)
	body.set_instance_shader_parameter("rim_energy", rim.energy)
	body.material_override = FLASH if hurt_timer > 0 and floori(t * 20) % 2 == 0 else null
	# Draw on whole view pixels: the camera is pixel-aligned, so the body follows `pos` rounded to the
	# pixel grid and never lands between pixels.
	var snap := pos.round() - pos
	visual.position = Vector3(snap.x, -snap.y + y_off, 0) * Px.M
	# Spin and pound windup turn the voxel body about its vertical axis: the 2.5D version of the 2D
	# sprite's horizontal flip by cos(turn).
	visual.rotation.y = (0.0 if facing > 0 else PI) + turn
	_update_spin_ring()
	# Hover jet: two flickering beams from the legs.
	for j: Node3D in jets:
		j.visible = hovering
		j.scale.y = randf_range(0.6, 1.0)


## The spin ring of drawClawd(): SPIN_DOTS dots, white and light orange, circling Clawd. Here they lie on a
## real horizontal circle SPIN_RING_R px around him; the oblique projection draws it as the 2D game's
## 17 x 6 px ellipse, with the front half over Clawd and the back half behind him.
func _update_spin_ring() -> void:
	spin_ring.visible = state == &"spin"
	if not spin_ring.visible:
		return
	var snap := pos.round() - pos
	for i in SPIN_DOTS:
		var a := anim * 25 + float(i) / SPIN_DOTS * TAU
		var p := Vector3(roundf(cos(a) * SPIN_RING_R) - 1 + snap.x, SPIN_RING_Y - snap.y, sin(a) * SPIN_RING_R) * Px.M
		spin_ring.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, p))
		var c := Color("#F0A585") if i % 2 else Color.WHITE
		spin_ring.multimesh.set_instance_color(i, Color(c.r * 1.6, c.g * 1.6, c.b * 1.6, 0.8))
