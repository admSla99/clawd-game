class_name Drone
extends Enemy

## The overclocked drone from `Drone` in src/entities/enemies2.ts (`D` in the map): bobs at its post until
## Clawd comes within 230 px, then circles 70 px to one side of him and 46 px above, stops to aim (0.45 s, its
## eye flashing), dives at him at 270 px/s for 0.55 s (a wall or floor ends the dive and bounces it), recovers
## and circles on the other side. It moves through the tiles like moveX() / moveY(). Drawn at 1 px: an 18 x 12
## quadcopter, a grey shell with a dark lower half and one eye (dark red, flashing red and white while it aims
## and dives) and two thin rotor blades on masts, blurring between two frames.

const SIZE := Vector2(14, 10)
const RANGE := 230.0
const ORBIT := Vector2(70, 46)
const DIVE_SPEED := 270.0
const FRAMES := [
	[
		"kkkkkk......kkkkkk",
		"....mm......mm....",
		"....mm......mm....",
	],
	[
		"..kkkkkk..kkkkkk..",
		"....mm......mm....",
		"....mm......mm....",
	],
]
const BODY := [
	"...wwwwwwwwwwww...",
	"..wLLWWWWWWWWWWw..",
	"..wLWWWWWWWWWWWw..",
	"..wWWWWWWWWWWWWw..",
	"..wgggdEEEEdgggw..",
	"..wgggdEEEEdgggw..",
	"..wggggddddggggw..",
	"...wggggggggggw...",
	"....wggggggggw....",
	".....wwwwwwww.....",
]
const PALETTE := {
	"W": Color8(210, 210, 210), # shell
	"L": Color8(240, 240, 240), # lit corner
	"w": Color8(100, 100, 100), # rim
	"g": Color8(120, 120, 120), # lower half
	"d": Color8(50, 50, 50), # eye socket
	"k": Color8(160, 160, 160), # rotors
	"m": Color8(90, 90, 90), # rotor masts
}
## The eye: calm, then the two colours it flashes between while aiming and diving.
const EYES := [Color("#8F3A37"), Color("#E0605A"), Color.WHITE]
## Depth in px: thin rotor blades (deep discs showed big grey tops that hid the shell), the eye 1 px out of
## the shell. The blades sit 3 px above the shell (2 in the 2D draw) so its top face does not swallow the masts.
const DEPTH := {"W": 10, "L": 10, "w": 8, "g": 10, "d": 10, "E": 12, "k": 4, "m": 2}

static var _meshes := {}

var vel := Vector2.ZERO
var mode := &"idle"
var timer := 0.0
var side := -1.0 if randf() < 0.5 else 1.0
var t := randf() * 5
## The feet's height while it bobs at its post (homeY in TS).
var home_y := 0.0
var _body: MeshInstance3D


func _init() -> void:
	size = SIZE
	hp = 3
	tokens = 3 * TOKEN_FACTOR
	collision_layer = 0
	collision_mask = 0


func _ready() -> void:
	super()
	# `this.y = bottom - 12`: it hovers 2 px above the bottom of its map cell.
	pos += Vector2(0, -2)
	prev_pos = pos
	home_y = pos.y
	_body = MeshInstance3D.new()
	add_child(_body)
	_update_visual()


func _physics_process(dt: float) -> void:
	if Game.frozen():
		return
	tick(dt)
	t += dt
	timer -= dt
	var player: Player = get_tree().get_first_node_in_group("player")
	# Its middle, and Clawd's top (p.y) and middle (p.y + 9) like Drone.update().
	var c := pos + Vector2(0, -SIZE.y / 2)
	var p_top := player.pos + Vector2(0, -Player.SIZE.y) if player else c
	var dist := c.distance_to(p_top)
	match mode:
		&"idle":
			vel.x *= 0.9
			vel.y = (home_y + sin(t * 2) * 4 - pos.y) * 3
			if dist < RANGE and player and player.in_play():
				mode = &"orbit"
				timer = 1.6 + randf()
		&"orbit":
			var target := p_top + Vector2(side * ORBIT.x, -ORBIT.y + sin(t * 3) * 8)
			vel += ((target - c) * 5 - vel * 2.2) * dt
			if timer <= 0:
				mode = &"aim"
				timer = 0.45
		&"aim":
			vel *= 0.85
			if timer <= 0:
				var d := p_top + Vector2(0, Player.SIZE.y / 2) - c
				vel = (d.normalized() if d.length() > 0 else Vector2.RIGHT) * DIVE_SPEED
				mode = &"dive"
				timer = 0.55
		&"dive":
			if timer <= 0:
				mode = &"recover"
				timer = 0.6
		&"recover":
			vel.x *= 0.92
			vel.y = vel.y * 0.92 - 30 * dt
			if timer <= 0:
				mode = &"orbit"
				side = -side
				timer = 1.8 + randf() * 1.2
	var hit_x := move_x(vel.x * dt)
	var hit_y := move_y(vel.y * dt)
	if (hit_x or hit_y != 0) and mode == &"dive":
		mode = &"recover"
		timer = 0.6
		vel = Vector2(-vel.x * 0.3, -absf(vel.y) * 0.3)
	if mode == &"dive" and randf() < 0.6:
		Fx.burst(self, pos + Vector2(0, -SIZE.y / 2), {count = 1, speed = 10, life = 0.25, color = [EYES[1]]})
	_update_visual()


func _update_visual() -> void:
	var angry := mode == &"aim" or mode == &"dive"
	var eye := (2 if floori(Game.time * 24) % 2 else 1) if angry else 0
	_body.mesh = mesh(floori(Game.time * 30) % 2, eye)
	set_tint(_body)
	set_rim(_body, 0.3)
	var snap := pos.round() - pos
	_body.position = Vector3(snap.x, -snap.y, 0) * Px.M


## Rotor frame 0 / 1 with eye colour 0 (calm), 1 (red) or 2 (white). The rotors sit on top of the 10 px shell.
static func mesh(frame: int, eye: int) -> ArrayMesh:
	var key := frame * 3 + eye
	if not _meshes.has(key):
		var palette := PALETTE.duplicate()
		palette["E"] = EYES[eye]
		_meshes[key] = Voxel.mesh(FRAMES[frame] + BODY, palette, DEPTH, Px.M)
	return _meshes[key]
