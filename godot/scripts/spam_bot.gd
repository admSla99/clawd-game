class_name SpamBot
extends Enemy

## The flying spam drone from `SpamBot` in src/entities/enemies.ts (`F` in the map): hovers around its post
## in a slow figure, turns to face Clawd, and every 2.4 s fires a Shot at him while he is within 210 px; it
## flickers red just before it fires. Drawn at 1 px from SPAMBOT in src/render/sprites.ts (10 x 8 cells of
## 2 px): a rounded grey box with a blinking antenna, red eyes with a glint, a dark speaker grille and two
## landing struts that swap pose between the frames.

const SIZE := Vector2(18, 15)
const SWAY := Vector2(26, 6)
const RANGE := 210.0
const SHOT_SPEED := 85.0
const RELOAD := 2.4
const FRAMES := [
	[
		"........PR..........",
		"........RR..........",
		".........w..........",
		".........w..........",
		"...wwwwwwwwwwwwww...",
		"..wWWWWWWWWWWWWWWw..",
		".wWWLLWWWWWWWWWWWWw.",
		"wWWLWWWWWWWWWWWWWWWw",
		"wWWWPRRRWWWWPRRRWWWw",
		"wWWWRRRRWWWWRRRRWWWw",
		"wWWWWWWWddddWWWWWWWw",
		"wWWWWWWWdWdWWWWWWWWw",
		".wWWWWWWWWWWWWWWWWw.",
		"..wwwwwwwwwwwwwwww..",
		"..kk............kk..",
		"..kk............kk..",
	],
	[
		"........rr..........",
		"........rr..........",
		".........w..........",
		".........w..........",
		"...wwwwwwwwwwwwww...",
		"..wWWWWWWWWWWWWWWw..",
		".wWWLLWWWWWWWWWWWWw.",
		"wWWLWWWWWWWWWWWWWWWw",
		"wWWWPRRRWWWWPRRRWWWw",
		"wWWWRRRRWWWWRRRRWWWw",
		"wWWWWWWWddddWWWWWWWw",
		"wWWWWWWWdWdWWWWWWWWw",
		".wWWWWWWWWWWWWWWWWw.",
		"..wwwwwwwwwwwwwwww..",
		"....kk........kk....",
		"....kk........kk....",
	],
]
const PALETTE := {
	"W": Color("#D6D6D6"), # body
	"L": Color("#F4F4F4"), # lit corner
	"w": Color("#8C8C8C"), # rim, antenna
	"d": Color("#555555"), # grille
	"R": Color("#E0605A"), # eyes, lit antenna tip
	"r": Color("#8F3A37"), # dark antenna tip
	"P": Color("#FFB0A8"), # glints
	"k": Color("#6A6A6A"), # struts
}
## Depth in px (even): a deep body, a shallower rim so it reads rounded, a thin antenna and struts.
const DEPTH := {"W": 14, "L": 14, "d": 14, "R": 14, "P": 14, "w": 10, "r": 2, "k": 4}

static var MESHES := [Voxel.mesh(FRAMES[0], PALETTE, DEPTH, Px.M), Voxel.mesh(FRAMES[1], PALETTE, DEPTH, Px.M)]

var t := randf() * 5
var fire_timer := 1.5 + randf()
var home := Vector2.ZERO
var _body: MeshInstance3D


func _init() -> void:
	size = SIZE
	collision_layer = 0
	collision_mask = 0


func _ready() -> void:
	super()
	home = pos
	_body = MeshInstance3D.new()
	add_child(_body)
	_move()
	_update_visual()


func _physics_process(dt: float) -> void:
	if Game.frozen():
		return
	tick(dt)
	t += dt
	_move()
	var player: Player = get_tree().get_first_node_in_group("player")
	fire_timer -= dt
	if player and player.visible:
		# From the bot's eyes to Clawd's middle, like dx / dy in SpamBot.update().
		var d := player.pos + Vector2(0, -9) - (pos + Vector2(0, -7))
		if fire_timer <= 0 and d.length() < RANGE:
			fire_timer = RELOAD
			Shot.fire(level, pos + Vector2(0, -5), d.normalized() * SHOT_SPEED)
			Sound.play("shoot")
	_update_visual()


func _move() -> void:
	pos = home + Vector2(sin(t * 0.8) * SWAY.x, sin(t * 2.1) * SWAY.y)


func _update_visual() -> void:
	_body.mesh = MESHES[int(t * 10) % 2]
	var player: Player = get_tree().get_first_node_in_group("player")
	_body.rotation.y = PI if player and player.pos.x > pos.x else 0.0
	var charging := fire_timer < 0.4 and floori(Game.time * 20) % 2 == 0
	set_tint(_body, Color(PALETTE.R, 1.0) if charging else Color(0, 0, 0, 0))
	set_rim(_body, 0.5)
	# The sprite's bottom is 1 px below the hitbox, like drawSprite(..., iy + 16).
	var snap := pos.round() - pos
	_body.position = Vector3(snap.x, -snap.y - 1, 0) * Px.M
