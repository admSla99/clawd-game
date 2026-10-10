class_name Player
extends CharacterBody3D

## Clawd's movement, ported from src/entities/player.ts with the PLAYER constants from src/config.ts.
## The origin is at the feet, horizontally centred. Movement runs in level pixels (`pos`, `vel`, y down,
## see Px) like the TS game and is converted to metres only for move_and_slide().
## Not ported yet: spin, ground pound, hover beam, drop-through, corner correction.

## Moments the game reacts to with particles and camera shake (events in the TS player):
## jump, land, hard_land, hurt, stomp. `at` is where it happened, in level pixels.
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
const JUMP_CUT_MULT := 0.45
const COYOTE_TIME := 0.1
const JUMP_BUFFER := 0.12
const HOVER_DURATION := 0.85
const HOVER_FALL_SPEED := 18.0
const HOVER_ACCEL := 2600.0
const STOMP_BOUNCE := 330.0
const STOMP_BOUNCE_HELD := 450.0
const HURT_INVULN := 1.3
const HURT_STUN := 0.32
const HURT_KNOCK_X := 170.0
const HURT_KNOCK_Y := 250.0
const MAX_HEARTS := 3

const SIZE := Vector2(18, 18)
## Size of the voxel sprite in pixels (13 x 10 cells of 2 px).
const SPRITE_PX := Vector2(26, 20)
const HITBOX := Rect2(-7, -15, 14, 15)
const SPIKE_PROBE := Rect2(-6, -6, 12, 6)

const PALETTE := {"O": Color("#D97757"), "o": Color("#B35E40"), "E": Color("#1A1311")}
## Voxel depth per palette character: a thick body, thinner arms and legs, eyes on both faces.
const DEPTH := {"O": 6, "o": 2, "E": 6}
const ORANGE := Color("#D97757")
const ORANGE_LIGHT := Color("#F0A585")
const ARM_ROWS := {"mid": [4, 5], "up": [2, 3], "high": [1, 2]}
const LEGS := {
	"stand": ["..o.o...o.o..", "..o.o...o.o.."],
	"runA": ["..o.o...o.o..", "....o.....o.."],
	"runB": ["..o.o...o.o..", "..o.....o...."],
	"tuck": ["..o.o...o.o..", "............."],
	"dangle": ["...o.o...o.o.", "...o.o...o.o."],
}
## Frame name -> text grid; MESHES holds their voxel meshes.
static var FRAMES := {
	"idle": clawd_frame("mid", "stand"),
	"blink": clawd_frame("mid", "stand", true),
	"runA": clawd_frame("mid", "runA"),
	"runB": clawd_frame("mid", "runB"),
	"jump": clawd_frame("up", "tuck"),
	"fall": clawd_frame("high", "dangle"),
	"hover": clawd_frame("mid", "dangle"),
	"hurt": clawd_frame("high", "dangle", true),
}
static var MESHES := build_meshes()
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
var invuln := 0.0
var hurt_timer := 0.0
var coyote := 0.0
var jump_buffer := 0.0
var jumping := false
var hover_left := HOVER_DURATION
var hovering := false
var facing := 1
var anim := 0.0
var prev_pos: Vector2
## Scale of $Visual for squash & stretch; eases back to 1. The collision shape keeps its size.
var squash := Vector2.ONE
## Counts down; Clawd blinks while it is below 0 (0.12 s), then it restarts at 2..5 s.
var blink_timer := 2.5

@onready var visual: Node3D = $Visual
@onready var body: MeshInstance3D = $Visual/Body
@onready var jets: Array[Node] = $Visual/Jets.get_children()


## 13x10 Clawd frame facing right, same layout as clawdFrame() in src/render/sprites.ts.
## Blink and squint both keep only the lower eye row.
static func clawd_frame(arms: String, legs: String, squint := false) -> Array:
	var rows := []
	for r in 8:
		var row := "..ooooooooo.." if r == 7 else "..oOOOOOOOO.."
		if r == 3 or (r == 2 and not squint):
			row[5] = "E"
			row[9] = "E"
		if r in ARM_ROWS[arms]:
			row[0] = "o"
			row[1] = "o"
			row[11] = "O"
			row[12] = "O"
		rows.append(row)
	rows.append_array(LEGS[legs])
	return rows


static func build_meshes() -> Dictionary:
	var meshes := {}
	for f in FRAMES:
		meshes[f] = Voxel.mesh(FRAMES[f], PALETTE, DEPTH)
	return meshes


## Hit flash: replaces every colour with white, like `tint` in the 2D drawing.
static func flash_material() -> ShaderMaterial:
	var m := Voxel.material()
	m.set_shader_parameter("flash", true)
	return m


func enter_level(l: Level, start: Vector2, level_bottom: float) -> void:
	level = l
	spawn_point = start
	kill_y = level_bottom + 24
	hearts = MAX_HEARTS
	respawn()


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


## Knocks Clawd away from from_x. Returns false when invulnerable or when the last heart was lost
## (Clawd then respawns with full hearts).
func hurt(from_x: float) -> bool:
	if invuln > 0:
		return false
	hearts -= 1
	if hearts <= 0:
		hearts = MAX_HEARTS
		respawn()
		return false
	hurt_timer = HURT_STUN
	invuln = HURT_INVULN
	vel = Vector2((-1.0 if pos.x < from_x else 1.0) * HURT_KNOCK_X, -HURT_KNOCK_Y)
	jumping = false
	hovering = false
	event.emit(&"hurt", pos)
	return true


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
	jump_buffer = maxf(0.0, jump_buffer - dt)
	if Input.is_action_just_pressed("jump"):
		jump_buffer = JUMP_BUFFER

	var grounded := is_on_floor()
	if grounded:
		coyote = COYOTE_TIME
		hover_left = HOVER_DURATION
	else:
		coyote = maxf(0.0, coyote - dt)

	var dir := signf(Input.get_axis("left", "right"))
	if hurt_timer > 0:
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
		vel.x = move_toward(vel.x, dir * RUN_SPEED, accel * dt)
		if dir != 0:
			facing = int(dir)
		if jump_buffer > 0 and (grounded or coyote > 0):
			vel.y = -JUMP_VELOCITY
			jumping = true
			coyote = 0.0
			jump_buffer = 0.0
			squash = Vector2(0.72, 1.3)
			event.emit(&"jump", pos)

	# Variable jump height.
	if jumping and vel.y < 0 and not Input.is_action_pressed("jump"):
		vel.y *= JUMP_CUT_MULT
		jumping = false
	if vel.y >= 0:
		jumping = false

	# Hover: hold jump in the air once rising has (almost) stopped.
	hovering = hurt_timer <= 0 and not grounded and coyote <= 0 and hover_left > 0 \
		and Input.is_action_pressed("jump") and vel.y > -40
	if hovering:
		hover_left -= dt
		vel.y = move_toward(vel.y, HOVER_FALL_SPEED, HOVER_ACCEL * dt)
	else:
		var g := GRAVITY
		if absf(vel.y) < APEX_THRESHOLD and Input.is_action_pressed("jump"):
			g *= APEX_GRAVITY_MULT
		elif vel.y > 0:
			g *= FALL_GRAVITY_MULT
		vel.y = minf(vel.y + g * dt, MAX_FALL)

	var fall_speed := vel.y
	# One-way platforms block only a falling Clawd whose body is clear of them.
	# ponytail: checks all one-way tiles the body overlaps, not the one landed on; fine for 1-tile slabs.
	set_collision_mask_value(4, vel.y >= 0 and not _touches_tile(Level.ONEWAY, Rect2(-SIZE.x / 2, -SIZE.y, SIZE.x, SIZE.y)))
	velocity = Vector3(vel.x, -vel.y, 0) * Px.M
	move_and_slide()
	vel = Vector2(velocity.x, -velocity.y) / Px.M
	if is_on_ceiling():
		jumping = false
	if not grounded and is_on_floor() and fall_speed > 120:
		var k := minf(1.0, fall_speed / MAX_FALL)
		squash = Vector2(1 + 0.35 * k, 1 - 0.3 * k)
		event.emit(&"hard_land" if fall_speed > 300 else &"land", pos)
	_check_hazards()
	_update_visual()


func _check_hazards() -> void:
	if pos.y > kill_y:
		hearts -= 1
		if hearts <= 0:
			hearts = MAX_HEARTS
		respawn()
		return
	if invuln <= 0 and _touches_tile(Level.SPIKE, SPIKE_PROBE):
		if hurt(pos.x + 10.0 * signf(vel.x)):
			vel.y = -HURT_KNOCK_Y * 1.3

	var hb := Rect2(pos + HITBOX.position, HITBOX.size)
	for e in get_tree().get_nodes_in_group("enemies"):
		if not hb.intersects(e.rect()):
			continue
		# Stomp: falling onto the top part of an enemy.
		if vel.y > 0 and prev_pos.y <= e.stomp_line():
			event.emit(&"stomp", e.pos)
			e.stomped()
			squash = Vector2(0.8, 1.25)
			var held := Input.is_action_pressed("jump")
			vel.y = -(STOMP_BOUNCE_HELD if held else STOMP_BOUNCE)
			jumping = held
			hover_left = HOVER_DURATION
		elif hb.intersects(e.hurtbox()):
			hurt(e.pos.x)


func _touches_tile(item: int, probe: Rect2) -> bool:
	var a := pos + probe.position
	var b := pos + probe.end - Vector2(0.001, 0.001)
	for y in range(floori(a.y / 16), floori(b.y / 16) + 1):
		for x in range(floori(a.x / 16), floori(b.x / 16) + 1):
			if level.tile(Vector2(x, y) * 16) == item:
				return true
	return false


## Frame choice and overlays follow drawClawd() in src/render/clawdView.ts.
func _update_visual() -> void:
	var t := Game.time
	visible = not (invuln > 0 and hurt_timer <= 0 and floori(t * 14) % 2 == 0)
	var frame := &"idle"
	var y_off := 0.0
	if hurt_timer > 0:
		frame = &"hurt"
	elif not is_on_floor():
		frame = &"hover" if hovering else &"jump" if vel.y < 0 else &"fall"
	elif absf(vel.x) > 12:
		var phase := floori(anim * (6 + absf(vel.x) / 14)) % 4
		frame = &"runA" if phase == 0 else &"runB" if phase == 2 else &"idle"
		y_off = 1.0 if phase % 2 == 1 else 0.0
	else:
		frame = &"blink" if blink_timer < 0 else &"idle"
		y_off = 1.0 if sin(anim * 3) > 0.6 else 0.0
	body.mesh = MESHES[frame]
	body.material_override = FLASH if hurt_timer > 0 and floori(t * 20) % 2 == 0 else null
	# Draw on whole view pixels: the body follows `pos` rounded to the pixel grid (the camera is
	# pixel-aligned too) and squash & stretch keeps the sprite an even number of pixels wide and a
	# whole number tall, so the 2 px voxels don't shimmer between 1 and 3 px while moving.
	var snap := pos.round() - pos
	visual.position = Vector3(snap.x, -snap.y + y_off, 0) * Px.M
	var sx := roundf(SPRITE_PX.x * squash.x / 2) * 2 / SPRITE_PX.x
	var sy := roundf(SPRITE_PX.y * squash.y) / SPRITE_PX.y
	visual.scale = Vector3(sx, sy, sx)
	visual.rotation.y = 0.0 if facing > 0 else PI
	# Hover jet: two flickering beams from the legs.
	for j: Node3D in jets:
		j.visible = hovering
		j.scale.y = randf_range(0.6, 1.0)
