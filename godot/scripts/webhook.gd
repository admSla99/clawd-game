class_name Webhook
extends Enemy

## World 3's Webhook (`W` in the map; not in TS): a callback on wings that patrols a lazy figure around its post and
## now and then calls back: when Clawd is near and below it, it stops to aim (0.4 s, its core flashing) and dives at
## him, then flies home. It is also an anchor (group "anchors", the Anchor interface: point(), active, targeted,
## catch()): the Tool Call's hook catches it and zips Clawd to it, and a caught webhook is stunned for STUN seconds,
## hanging still and harmless, so he hops off it. Shots and stomps hurt it like any enemy.
## A voxel ring like the anchors' (2 px cells would be too big: 1 px, but the same colours) between two flapping
## wings, a little hook of a tail under it.

const SIZE := Vector2(14, 10)
const SPAN := Vector2(40, 6)
const RANGE := 120.0
const DIVE_SPEED := 230.0
const STUN := 1.4
const PALETTE := {"W": Color("#F2FFFF"), "O": Color("#FFB28F"), "L": Color("#7FE8F0"), "h": Color("#3F9AA6"),
	"w": Color("#B9C6CC"), "k": Color("#6C7680")}
const DEPTH := {"W": 4, "O": 6, "L": 6, "h": 6, "w": 2, "k": 4}

static var MESHES := [Voxel.mesh(_rows(0), PALETTE, DEPTH, Px.M, Voxel.material(1.5)),
	Voxel.mesh(_rows(1), PALETTE, DEPTH, Px.M, Voxel.material(1.5))]

var home := Vector2.ZERO
var mode := &"patrol"
var timer := 0.0
var cooldown := 1.5 + randf()
var vel := Vector2.ZERO
var t := randf() * 6
## The Anchor interface.
var active := true
var targeted := false
var caught_flash := 0.0
var _body: MeshInstance3D


func _init() -> void:
	element = "lightning"
	size = SIZE
	hp = 3
	tokens = 3 * TOKEN_FACTOR
	collision_layer = 0
	collision_mask = 0


func _ready() -> void:
	super()
	add_to_group("anchors")
	add_to_group("world_text")
	home = pos + Vector2(0, -3)
	pos = home
	prev_pos = pos
	_body = MeshInstance3D.new()
	add_child(_body)
	_update_visual()


## Where the hook catches it: its middle.
func point() -> Vector2:
	return pos + Vector2(0, -SIZE.y / 2)


## The hook caught it: stunned, still and harmless for a moment.
func catch() -> void:
	caught_flash = 0.3
	mode = &"stunned"
	timer = STUN
	vel = Vector2.ZERO


func hurtbox() -> Rect2:
	return Rect2() if mode == &"stunned" else super()


func _die(kind: StringName) -> void:
	remove_from_group("anchors")
	super(kind)


func _physics_process(dt: float) -> void:
	if Game.frozen() or held():
		return
	tick(dt)
	t += dt
	timer -= dt
	cooldown -= dt
	caught_flash = maxf(0.0, caught_flash - dt)
	var player: Player = get_tree().get_first_node_in_group("player")
	var p_mid := player.pos + Vector2(0, -Player.SIZE.y / 2) if player else point()
	match mode:
		&"patrol":
			var want := home + Vector2(sin(t * 0.8) * SPAN.x, sin(t * 1.6) * SPAN.y)
			pos = pos.move_toward(want, 90 * dt)
			if cooldown <= 0 and player and player.in_play() and point().distance_to(p_mid) < RANGE and p_mid.y > point().y + 8:
				mode = &"aim"
				timer = 0.4
		&"aim":
			if timer <= 0:
				vel = (p_mid - point()).normalized() * DIVE_SPEED
				mode = &"dive"
				timer = 0.5
		&"dive":
			if move_x(vel.x * dt) or move_y(vel.y * dt) != 0 or timer <= 0:
				mode = &"return"
		&"return", &"stunned":
			if mode == &"stunned":
				if timer <= 0:
					mode = &"return"
			else:
				pos = pos.move_toward(home, 110 * dt)
				if pos.distance_to(home) < 2:
					mode = &"patrol"
					cooldown = 2.5 + randf()
	_update_visual()


func _update_visual() -> void:
	var flap := 0 if mode == &"stunned" else int(t * (14 if mode == &"dive" else 8)) % 2
	_body.mesh = MESHES[flap]
	var angry := mode == &"aim" or mode == &"dive"
	set_tint(_body, Color(1, 0.4, 0.35, 0.6) if angry and floori(Game.time * 20) % 2 == 0 \
		else Color(1, 1, 1, 0.5) if caught_flash > 0 or (targeted and mode != &"stunned" and floori(Game.time * 6) % 2 == 0) \
		else Color(0, 0, 0, 0))
	set_rim(_body, 0.3)
	var snap := pos.round() - pos
	_body.position = Vector3(snap.x, -snap.y, 0) * Px.M


## Orange brackets round it while the hook would catch it (like Anchor.overlay_draw()).
func overlay_draw(o: Overlay) -> void:
	if not targeted:
		return
	var v := o.to_view(point()).round()
	var r := 10 + roundf(absf(sin(t * 6)))
	var c := Color(Anchor.ORANGE_LIGHT, 0.9)
	for sx in [-1, 1]:
		for sy in [-1, 1]:
			var k := v + Vector2(sx * r, sy * r)
			o.draw_rect(Rect2(k.x - (2 if sx > 0 else 0), k.y, 3, 1), c)
			o.draw_rect(Rect2(k.x, k.y - (2 if sy > 0 else 0), 1, 3), c)


## 17 x 10: the anchor's ring in the middle (columns 5-11, rows 1-7), wings up (`frame` 0) or down (1), a hook tail.
static func _rows(frame: int) -> Array:
	var ring := ["..LhL..", ".h...h.", "L..W..L", "h.WOW.h", "L..W..L", ".h...h.", "..LhL.."]
	var g := []
	for y in 10:
		g.append([])
		for x in 17:
			g[y].append(".")
	for y in 7:
		for x in 7:
			if ring[y][x] != ".":
				g[y + 1][x + 5] = ring[y][x]
	var wing := [[0, 0], [1, 0], [1, 1], [2, 1], [3, 2], [4, 3]] if frame == 0 else [[0, 6], [1, 6], [1, 5], [2, 5], [3, 4], [4, 4]]
	for w in wing:
		g[w[1]][w[0]] = "w"
		g[w[1]][16 - w[0]] = "w"
	g[8][8] = "k"
	g[9][8] = "k"
	g[9][9] = "k"
	return g.map(func(r: Array) -> String: return "".join(PackedStringArray(r)))
