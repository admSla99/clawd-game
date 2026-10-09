class_name Player
extends CharacterBody2D

## Clawd's movement, ported from src/entities/player.ts with the PLAYER constants from src/config.ts.
## The origin is at the feet, horizontally centred.
## Not ported yet: spin, ground pound, hover beam, drop-through, corner correction.

## Moments the game reacts to with particles and camera shake (events in the TS player):
## jump, land, hard_land, hurt, stomp. `at` is where it happened, in level coordinates.
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
const HITBOX := Rect2(-7, -15, 14, 15)
const SPIKE_PROBE := Rect2(-6, -6, 12, 6)

const PALETTE := {"O": Color("#D97757"), "o": Color("#B35E40"), "E": Color("#1A1311")}
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

var terrain: TileMapLayer
var spawn_point: Vector2
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
var prev_position: Vector2
## Drawing scale for squash & stretch; eases back to 1. Applied in _draw, not to the body,
## so the collision shape keeps its size.
var squash := Vector2.ONE
## Counts down; Clawd blinks while it is below 0 (0.12 s), then it restarts at 2..5 s.
var blink_timer := 2.5
# Halo drawn by GlowLayer (group "glow").
var glow_color := Color(0.851 * 0.3, 0.467 * 0.3, 0.341 * 0.3)
var glow_radius := 22.0
var glow_offset := Vector2(0, -9)


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


func enter_level(level: TileMapLayer, start: Vector2, level_bottom: float) -> void:
	terrain = level
	spawn_point = start
	kill_y = level_bottom + 24
	hearts = MAX_HEARTS
	respawn()


func respawn() -> void:
	position = spawn_point
	prev_position = position
	velocity = Vector2.ZERO
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
	velocity = Vector2((-1.0 if position.x < from_x else 1.0) * HURT_KNOCK_X, -HURT_KNOCK_Y)
	jumping = false
	hovering = false
	event.emit(&"hurt", position)
	return true


func _physics_process(dt: float) -> void:
	if Game.frozen():
		return
	prev_position = position
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
		velocity.x = move_toward(velocity.x, 0.0, AIR_DECEL * dt)
	else:
		var accel: float
		if grounded:
			if dir == 0:
				accel = GROUND_DECEL
			elif velocity.x != 0 and signf(velocity.x) != dir:
				accel = TURN_ACCEL
			else:
				accel = GROUND_ACCEL
		else:
			accel = AIR_DECEL if dir == 0 else AIR_ACCEL
		velocity.x = move_toward(velocity.x, dir * RUN_SPEED, accel * dt)
		if dir != 0:
			facing = int(dir)
		if jump_buffer > 0 and (grounded or coyote > 0):
			velocity.y = -JUMP_VELOCITY
			jumping = true
			coyote = 0.0
			jump_buffer = 0.0
			squash = Vector2(0.72, 1.3)
			event.emit(&"jump", position)

	# Variable jump height.
	if jumping and velocity.y < 0 and not Input.is_action_pressed("jump"):
		velocity.y *= JUMP_CUT_MULT
		jumping = false
	if velocity.y >= 0:
		jumping = false

	# Hover: hold jump in the air once rising has (almost) stopped.
	hovering = hurt_timer <= 0 and not grounded and coyote <= 0 and hover_left > 0 \
		and Input.is_action_pressed("jump") and velocity.y > -40
	if hovering:
		hover_left -= dt
		velocity.y = move_toward(velocity.y, HOVER_FALL_SPEED, HOVER_ACCEL * dt)
	else:
		var g := GRAVITY
		if absf(velocity.y) < APEX_THRESHOLD and Input.is_action_pressed("jump"):
			g *= APEX_GRAVITY_MULT
		elif velocity.y > 0:
			g *= FALL_GRAVITY_MULT
		velocity.y = minf(velocity.y + g * dt, MAX_FALL)

	var fall_speed := velocity.y
	move_and_slide()
	if is_on_ceiling():
		jumping = false
	if not grounded and is_on_floor() and fall_speed > 120:
		var k := minf(1.0, fall_speed / MAX_FALL)
		squash = Vector2(1 + 0.35 * k, 1 - 0.3 * k)
		event.emit(&"hard_land" if fall_speed > 300 else &"land", position)
	_check_hazards()
	queue_redraw()


func _check_hazards() -> void:
	if position.y > kill_y:
		hearts -= 1
		if hearts <= 0:
			hearts = MAX_HEARTS
		respawn()
		return
	if invuln <= 0 and _touches_tile("spike", SPIKE_PROBE):
		if hurt(position.x + 10.0 * signf(velocity.x)):
			velocity.y = -HURT_KNOCK_Y * 1.3

	var hb := Rect2(position + HITBOX.position, HITBOX.size)
	for e in get_tree().get_nodes_in_group("enemies"):
		if not hb.intersects(e.rect()):
			continue
		# Stomp: falling onto the top part of an enemy.
		if velocity.y > 0 and prev_position.y <= e.stomp_line():
			event.emit(&"stomp", e.position)
			e.stomped()
			squash = Vector2(0.8, 1.25)
			var held := Input.is_action_pressed("jump")
			velocity.y = -(STOMP_BOUNCE_HELD if held else STOMP_BOUNCE)
			jumping = held
			hover_left = HOVER_DURATION
		elif hb.intersects(e.hurtbox()):
			hurt(e.position.x)


func _touches_tile(kind: String, probe: Rect2) -> bool:
	var a := terrain.local_to_map(position + probe.position)
	var b := terrain.local_to_map(position + probe.end - Vector2(0.001, 0.001))
	for y in range(a.y, b.y + 1):
		for x in range(a.x, b.x + 1):
			var data := terrain.get_cell_tile_data(Vector2i(x, y))
			if data and data.get_custom_data("kind") == kind:
				return true
	return false


## Frame choice and overlays follow drawClawd() in src/render/clawdView.ts.
func _draw() -> void:
	var t := Game.time
	if invuln > 0 and hurt_timer <= 0 and floori(t * 14) % 2 == 0:
		return
	var frame: Array = FRAMES.idle
	var y_off := 0.0
	if hurt_timer > 0:
		frame = FRAMES.hurt
	elif not is_on_floor():
		frame = FRAMES.hover if hovering else FRAMES.jump if velocity.y < 0 else FRAMES.fall
	elif absf(velocity.x) > 12:
		var phase := floori(anim * (6 + absf(velocity.x) / 14)) % 4
		frame = FRAMES.runA if phase == 0 else FRAMES.runB if phase == 2 else FRAMES.idle
		y_off = -1.0 if phase % 2 == 1 else 0.0
	else:
		frame = FRAMES.blink if blink_timer < 0 else FRAMES.idle
		y_off = -0.5 if sin(anim * 3) > 0.6 else 0.0

	# Hover jet: two flickering beams from the legs.
	if hovering:
		for i in 6:
			var c := ORANGE_LIGHT if randf() > 0.5 else ORANGE
			c.a = 1 - i / 7.0
			draw_rect(Rect2(-6, 1 + i * 3, 2, 2), c)
			draw_rect(Rect2(4, 1 + i * 3, 2, 2), c)

	PixelArt.draw(self, frame, PALETTE, Vector2(0, y_off), {
		px = 2,
		flip = facing < 0,
		sx = squash.x,
		sy = squash.y,
		tint = Color.WHITE if hurt_timer > 0 and floori(t * 20) % 2 == 0 else null,
	})
