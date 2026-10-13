class_name RateLimiter
extends Enemy

## The "429" crusher from `RateLimiter` in src/entities/enemies.ts (`R` in the map, 2 x 2 tiles hanging from
## the map cell's top-left): when Clawd passes beneath it (or rides it up into a nook) it shakes, drops until
## it hits the floor, rests and slowly rises back. It cannot be hurt; its sides and bottom hurt Clawd and its
## top is a platform he can ride (group "platforms", same fields as MovingPlatform; it updates before him).
## Drawn as a heavy block at 1 px: a dark body with the 2D version's dot grid as studs (bright ones round the
## edge), a face plate with eyes that turn red and angry while it attacks, "429" below them, and the chain
## up to where it hangs.

const SIZE := Vector2(32, 32)
const TRIGGER_RANGE := 16 * 9
const GRAVITY := 1800.0
const MAX_FALL := 520.0
const RISE := 55.0
const PALETTE := {
	"b": Color8(40, 40, 46), # body
	"E": Color8(205, 205, 205), # edge studs
	"a": Color8(78, 78, 82), # inner studs
	"c": Color8(96, 96, 100),
	"e": Color8(150, 150, 150), # calm eyes
	"t": Color8(140, 140, 140), # calm text
	"R": Color("#E0605A"), # angry eyes and text
}
const DEPTH := {"b": 20, "E": 24, "a": 22, "c": 22, "e": 22, "t": 22, "R": 22}
const DIGITS := {
	"4": ["#.#", "#.#", "###", "..#", "..#"],
	"2": ["###", "..#", "###", "#..", "###"],
	"9": ["###", "#.#", "###", "..#", "###"],
}

## Its own material: the block reaches z = 0.75 m, past the see-through windows' REVEAL_FRONT, but it is a
## gameplay object that must never be dithered away around Clawd (Main sets `reveal` on Voxel.MATERIAL only).
static var MATERIAL := Voxel.material()
static var MESHES := [Voxel.mesh(_rows(false), PALETTE, DEPTH, Px.M, MATERIAL), Voxel.mesh(_rows(true), PALETTE, DEPTH, Px.M, MATERIAL)]
static var LINK := Voxel.mesh(["kk", "kk"], {"k": Color8(84, 84, 90)}, {"k": 2}, Px.M)

## Platform fields (MovingPlatform): top-left in level pixels and how far it moved this frame.
var x: float:
	get: return pos.x - SIZE.x / 2
var y: float:
	get: return pos.y - SIZE.y
var dx := 0.0
var dy := 0.0
var active := true
var mode := &"idle"
var timer := 0.0
var vel_y := 0.0
var home_y := 0.0
var _visual: Node3D
var _body: MeshInstance3D
var _chain: Array[MeshInstance3D] = []


func _init() -> void:
	size = SIZE
	invincible = true
	stompable = false
	tokens = 0
	collision_layer = 0
	collision_mask = 0
	process_physics_priority = -10


func _ready() -> void:
	super()
	add_to_group("platforms")
	# Placed like `new RateLimiter(s.tx * TILE, s.ty * TILE)`: its top-left is the map cell's top-left, and
	# the node (its feet) sits at the bottom-centre of the 2 x 2 block.
	pos += Vector2(8, 16)
	prev_pos = pos
	home_y = y
	_visual = Node3D.new()
	add_child(_visual)
	_body = MeshInstance3D.new()
	_visual.add_child(_body)
	_update_visual()


func _physics_process(dt: float) -> void:
	dx = 0.0
	dy = 0.0
	if Game.frozen():
		return
	tick(dt)
	var old_y := y
	var player: Player = get_tree().get_first_node_in_group("player")
	match mode:
		&"idle":
			if player and _below(player):
				mode = &"shake"
				timer = 0.3
			elif player and player.riding == self:
				# Clawd rode it up into a nook too narrow to walk off: carry him back down.
				mode = &"shake"
				timer = 0.6
		&"shake":
			timer -= dt
			if timer <= 0:
				mode = &"fall"
				vel_y = 0.0
		&"fall":
			vel_y = minf(vel_y + GRAVITY * dt, MAX_FALL)
			if _fall(vel_y * dt) or y > level.pixel_size.y:
				_crash(player)
		&"rest":
			timer -= dt
			if timer <= 0:
				mode = &"rise"
		&"rise":
			pos = Vector2(pos.x, maxf(home_y, y - RISE * dt) + SIZE.y)
			if y <= home_y:
				mode = &"idle"
	dy = y - old_y
	_update_visual()


## Clawd's middle within 10 px of its sides, his top below its bottom and less than 9 tiles below its top.
func _below(p: Player) -> bool:
	var top := p.pos.y - Player.SIZE.y
	return p.pos.x > x - 10 and p.pos.x < x + SIZE.x + 10 and top > y + SIZE.y and top - y < TRIGGER_RANGE


## moveY() downwards: stops on the first solid or corrupted tile under it, or a one-way tile it was above.
## Returns true when it landed.
func _fall(d: float) -> bool:
	var bottom := pos.y
	var ty := floori((bottom + d - 0.001) / 16)
	var floor := false
	for tx in range(floori(x / 16), floori((x + SIZE.x - 0.001) / 16) + 1):
		var t := level.tile(Vector2(tx * 16 + 8, ty * 16 + 8))
		if t == Level.SOLID or t == Level.CORRUPT or (t == Level.ONEWAY and bottom <= ty * 16 + 0.001):
			floor = true
	pos = Vector2(pos.x, ty * 16.0 if floor else bottom + d)
	return floor


## Hit the floor: rest, a crash, dust, and a shake when Clawd is near.
func _crash(player: Player) -> void:
	mode = &"rest"
	timer = 0.9
	Sound.play("crush")
	var mid := Vector2(pos.x, pos.y)
	if player and absf(player.pos.x - pos.x) < 140 and absf(player.pos.y - Player.SIZE.y - y) < 120:
		var main := get_tree().get_first_node_in_group("main")
		if main:
			main.shake(0.35)
	Fx.burst(self, mid, {count = 24, speed = 110, angle = -PI / 2, spread = PI, life = 0.5, color = [Color8(189, 189, 189), Color8(119, 119, 119)], gravity = 300, depth = 12})


## Only the sides and bottom hurt; the top is a platform.
func hurtbox() -> Rect2:
	return Rect2(x + 1, y + 6, SIZE.x - 2, SIZE.y - 6)


func _update_visual() -> void:
	var angry := mode != &"idle" and mode != &"rise"
	_body.mesh = MESHES[int(angry)]
	set_rim(_body, 1.0)
	var shake := float(randi_range(-1, 1)) if mode == &"shake" else 0.0
	var snap := pos.round() - pos
	_visual.position = Vector3(snap.x + shake, -snap.y, 0) * Px.M
	# The chain: 2 px links every 4 px from just above its top up to where it hangs.
	var links := 0
	var cy := roundf(y) - 3
	while cy > home_y - 2:
		links += 1
		cy -= 4
	while _chain.size() < links:
		var link := MeshInstance3D.new()
		link.mesh = LINK
		link.position = Vector3(0, (SIZE.y + 1 + 4 * _chain.size()) * Px.M, 0)
		_visual.add_child(link)
		_chain.append(link)
	for i in _chain.size():
		_chain[i].visible = i < links


## The 32 x 32 front: dark body, 8 x 8 studs (bright on the edge, two greys inside, from hash2(i, j, 4) like
## the 2D dots), a cleared face plate with the eyes (lowered and with brows when angry) and "429".
static func _rows(angry: bool) -> Array:
	var g := []
	for yy in 32:
		var row := []
		row.resize(32)
		row.fill("b")
		g.append(row)
	for j in 8:
		for i in 8:
			var edge := i == 0 or j == 0 or i == 7 or j == 7
			var ch := "E" if edge else ("c" if DotNoise.hash2(i, j, 4) > 0.5 else "a")
			for oy in 2:
				for ox in 2:
					g[j * 4 + 1 + oy][i * 4 + 1 + ox] = ch
	for yy in range(8, 14):
		for xx in range(6, 26):
			g[yy][xx] = "b"
	for yy in range(19, 26):
		for xx in range(10, 22):
			g[yy][xx] = "b"
	var eye := "R" if angry else "e"
	var ey := 11 if angry else 10
	for xx in range(7, 13) + range(19, 25):
		g[ey][xx] = eye
		g[ey + 1][xx] = eye
	if angry:
		for xx in [7, 8, 23, 24]:
			g[9][xx] = "R"
	var text := "R" if angry else "t"
	var cx := 11
	for d in "429":
		var glyph: Array = DIGITS[d]
		for yy in 5:
			for xx in 3:
				if glyph[yy][xx] == "#":
					g[20 + yy][cx + xx] = text
		cx += 4
	return g.map(func(r: Array) -> String: return "".join(PackedStringArray(r)))
