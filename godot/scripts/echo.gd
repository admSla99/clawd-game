class_name Echo
extends Node3D

## A sub-agent Clawd sent out (scripts/echo_control.gd): it replays `path`, his feet over the last few seconds, one
## entry a physics frame, then stands where the path ends (where Clawd was when he sent it) for STAND seconds and
## fades out. Standing, it is a platform (group "platforms": x, y, dx, dy, active, rect(), like MovingPlatform) that
## Clawd can stand on; replaying or standing, its feet press plates (scripts/plate.gd). Clawd's shots pass through
## it (Bullet.blocked() skips it). Drawn as Clawd, tinted cyan, its pose worked out from how it moves, flickering
## like a hologram while it replays and as it fades. Group "echoes".
## A `hostile` echo (the Router's loopback, scripts/router.gd) is red, presses nothing, is no platform, hurts Clawd
## to touch while it replays and fades as soon as its replay ends.

const STAND := 8.0
const FADE := 0.5
const TINT := Color(0.45, 0.92, 1.0, 0.6)
const HOSTILE_TINT := Color(1.0, 0.3, 0.3, 0.65)

var hostile := false
## Seconds it stands once its replay is over (STAND, longer with the prompt tree's Patience).
var stand := STAND

## [Vector2 feet, int facing] per physics frame.
var path: Array = []
var i := 0
var stand_t := 0.0
var fade_t := 0.0
var feet := Vector2.ZERO
var facing := 1
var t := 0.0
## The platform interface (Player rides what is in the group "platforms").
var x := 0.0
var y := 0.0
var dx := 0.0
var dy := 0.0
var active := false
var _body: MeshInstance3D
var _prev := Vector2.ZERO


func _ready() -> void:
	add_to_group("echoes")
	_body = MeshInstance3D.new()
	add_child(_body)
	feet = path[0][0]
	_prev = feet
	_update()


## Still around (not fading out).
func alive() -> bool:
	return fade_t == 0.0 and not hostile


func replaying() -> bool:
	return i < path.size() - 1


## Its body (level px); as a platform, its top.
func rect() -> Rect2:
	return Rect2(feet - Vector2(Player.SIZE.x / 2, Player.SIZE.y), Player.SIZE)


## Sent home (a newer one needed its slot, or Clawd left the level): it fades out now.
func recall() -> void:
	if fade_t == 0.0:
		fade_t = FADE
		Sound.play("agentGone")
		Fx.burst(self, feet + Vector2(0, -9), {count = 10, speed = 50, life = 0.4, color = [TINT, Color.WHITE]})


func _physics_process(dt: float) -> void:
	if Game.frozen():
		return
	t += dt
	_prev = feet
	if fade_t > 0:
		fade_t -= dt
		if fade_t <= 0:
			queue_free()
			return
	elif replaying():
		i += 1
		if hostile:
			var player: Player = get_tree().get_first_node_in_group("player")
			if player and player.in_play() and player.hitbox().intersects(rect().grow(-3)):
				player.hurt(feet.x)
	elif hostile:
		recall()
	else:
		stand_t += dt
		if stand_t >= stand:
			recall()
	feet = path[i][0]
	facing = path[i][1]
	_update()


func _update() -> void:
	var standing := not replaying() and alive() and not hostile
	var was := active
	active = standing
	if active and not was:
		add_to_group("platforms")
	elif was and not active:
		remove_from_group("platforms")
	x = feet.x - Player.SIZE.x / 2
	y = feet.y - Player.SIZE.y
	position = Px.to3(feet.round())
	# The pose from how it moves (Player._update_visual(), simplified).
	var v := (feet - _prev) * 60.0
	var o := {"arms": "mid", "legs": "stand", "eyes": "open", "look": Vector2i.ZERO}
	if absf(v.y) > 20:
		o.arms = "up" if v.y < 0 else "high"
		o.legs = "tuck" if v.y < 0 else "dangle"
	elif absf(v.x) > 12:
		var phase := floori(t * 12) % 4
		o.legs = "runA" if phase == 0 else "runB" if phase == 2 else "stand"
		o.arms = "swingA" if phase < 2 else "swingB"
	_body.mesh = ClawdSprite.mesh(o)
	_body.rotation.y = 0.0 if facing > 0 else PI
	var tint := HOSTILE_TINT if hostile else TINT
	var c := tint.srgb_to_linear()
	_body.set_instance_shader_parameter("tint", Vector4(c.r, c.g, c.b, tint.a))
	# A hologram: it flickers while replaying and as it fades, and blinks in its last second.
	var flicker := (replaying() and floori(t * 30) % 7 == 0) or (fade_t > 0 and floori(t * 24) % 2 == 0) \
		or (standing and stand_t > stand - 1.0 and floori(t * 10) % 2 == 0)
	_body.visible = not flicker
