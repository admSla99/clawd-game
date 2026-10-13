class_name ShieldBot
extends Enemy

## The "403" shield bot from `ShieldBot` in src/entities/enemies2.ts (`H` in the map). While Clawd is within
## 260 px (and 120 px up or down) it walks towards him at 30 px/s (not off ledges, and it stops 36 px short),
## turns round only after 0.7 s on the wrong side (the window to hit its back; the shield blinks grey), and
## every 2.6 s fires a Shot at 125 px/s straight ahead while he is level with it (within 40 px). Its shield
## stops shots from the front (blocks_direction(), asked by Bullet and Main.fire_beam()); stomps and spins
## hit it as usual. Drawn at 1 px: a 13 x 18 grey robot (a visor with a red eye on the side it faces, a seam, armour plates in two greys
## from hash2(i, j, 3) like the 2D draw) on two stepping feet, a glowing cyan shield standing across its depth
## in front of it, and a "403" hologram above it.

const SIZE := Vector2(16, 20)
const RANGE := Vector2(260, 120)
const SPEED := 30.0
const STOP := 36.0
const TURN_TIME := 0.7
const GRAVITY := 1400.0
const MAX_FALL := 400.0
const RELOAD := 2.6
const SHOT_SPEED := 125.0
const CYAN := Color("#5FD0D8")
const PALETTE := {
	"W": Color8(210, 210, 210), # visor
	"L": Color8(240, 240, 240), # lit corner
	"w": Color8(96, 96, 96), # outline
	"d": Color8(54, 54, 54), # seams
	"g": Color8(124, 124, 124), # plates
	"h": Color8(146, 146, 146),
	"R": Color("#E0605A"), # eye
	"k": Color8(150, 150, 150), # feet
}
const DEPTH := {"W": 14, "L": 14, "w": 12, "d": 12, "g": 14, "h": 14, "R": 16, "k": 8}
const DIGITS := {
	"4": ["#.#", "#.#", "###", "..#", "..#"],
	"0": ["###", "#.#", "#.#", "#.#", "###"],
	"3": ["###", "..#", "###", "..#", "###"],
}

## Shield colours: cyan, white while it stops a shot, grey while the bot turns round.
static var SHIELDS := [_shield(CYAN), _shield(Color.WHITE), _shield(Color8(90, 90, 90))]
static var BODIES := [Voxel.mesh(_body_rows(0), PALETTE, DEPTH, Px.M), Voxel.mesh(_body_rows(1), PALETTE, DEPTH, Px.M)]
static var LABEL := Voxel.mesh(_label_rows(), {"c": CYAN.darkened(0.3)}, {"c": 2}, Px.M, Voxel.material(1.4))

var vel := Vector2.ZERO
## 1 = facing right, -1 = left.
var facing := -1.0
var fire_timer := 2.0 + randf()
var turn_timer := 0.0
var shield_flash := 0.0
## The Tool Call tore its shield off (world 3): shots get through from every side.
var shieldless := false
var t := 0.0
var _visual: Node3D
var _body: MeshInstance3D
var _shield_mesh: MeshInstance3D
var _label: MeshInstance3D


func _init() -> void:
	size = SIZE
	hp = 9
	tokens = 6 * TOKEN_FACTOR
	collision_layer = 0
	collision_mask = 0


func _ready() -> void:
	super()
	_visual = Node3D.new()
	add_child(_visual)
	_body = MeshInstance3D.new()
	_visual.add_child(_body)
	_shield_mesh = MeshInstance3D.new()
	_visual.add_child(_shield_mesh)
	_label = MeshInstance3D.new()
	_label.mesh = LABEL
	# "403" centred 6 px above its top, like r.text('403', x + 8, y - 6).
	# It is 11 px wide: half a pixel right puts it on the pixel grid.
	_label.position = Vector3(0.5, SIZE.y + 4, 0) * Px.M
	_visual.add_child(_label)
	_update_visual()


## blocksDirection(): a shot travelling along `dir` hits the shield when it comes from the side the bot faces
## and is not too steep (from above it gets through). The shield flashes white.
func blocks_direction(dir: Vector2) -> bool:
	if not shieldless and dir.x * facing < 0 and absf(dir.y) < absf(dir.x) * 1.4:
		shield_flash = 0.15
		return true
	return false


## The Tool Call's hook strikes it: it tears the shield off (once; then the hook just hurts it).
func hook_hit(_dir: Vector2) -> bool:
	if shieldless:
		return false
	shieldless = true
	Fx.burst(self, pos + Vector2(facing * 8, -SIZE.y / 2), {count = 14, speed = 90, life = 0.4, color = [CYAN, Color.WHITE]})
	return true


func _physics_process(dt: float) -> void:
	if Game.frozen():
		return
	tick(dt)
	t += dt
	shield_flash = maxf(0.0, shield_flash - dt)
	var player: Player = get_tree().get_first_node_in_group("player")
	var dx := player.pos.x - pos.x if player else 0.0
	# Both tops, like `Math.abs(p.y - this.y) < 120`.
	var near := player != null and player.in_play() and absf(dx) < RANGE.x \
		and absf(player.pos.y - Player.SIZE.y - (pos.y - SIZE.y)) < RANGE.y
	var want := 1.0 if dx > 0 else -1.0
	if near and want != facing:
		# Slow to turn around: that is the window to shoot its back.
		turn_timer += dt
		if turn_timer > TURN_TIME:
			facing = want
			turn_timer = 0.0
	else:
		turn_timer = 0.0
	vel.x = facing * SPEED if near and absf(dx) > STOP and turn_timer == 0 else 0.0
	if not floor_at(Vector2(pos.x + facing * (SIZE.x / 2 + 2), pos.y + 2)):
		vel.x = 0.0
	vel.y = minf(vel.y + GRAVITY * dt, MAX_FALL)
	move_x(vel.x * dt)
	if move_y(vel.y * dt) == 1:
		vel.y = 0.0

	fire_timer -= dt
	# Middles: Clawd's (p.y + 9) and its eye line (y + 9).
	if near and fire_timer <= 0 and absf(player.pos.y - Player.SIZE.y / 2 - (pos.y - SIZE.y + 9)) < 40 and want == facing:
		fire_timer = RELOAD
		Shot.fire(level, pos + Vector2(facing * 10, -SIZE.y + 9), Vector2(facing * SHOT_SPEED, 0))
		Sound.play("shoot")
	if pos.y > level.pixel_size.y + 50:
		remove()
		return
	_update_visual()


## The health bar goes over the "403" (whose top is 9 px over its box).
func bar_y() -> float:
	return pos.y - SIZE.y - 13


## Clawd is hurt by its body below the top 3 px and 2 px in from the sides.
func hurtbox() -> Rect2:
	return Rect2(pos + Vector2(-SIZE.x / 2 + 2, -SIZE.y + 3), SIZE - Vector2(4, 3))


func _update_visual() -> void:
	_body.mesh = BODIES[int(t * 6) % 2]
	var turning := turn_timer > 0 and floori(Game.time * 16) % 2 == 1
	_shield_mesh.mesh = SHIELDS[1 if shield_flash > 0 else (2 if turning else 0)]
	_shield_mesh.visible = not shieldless
	# The 2D shield's left edge is x + 15 facing right (x - 2 facing left): 7 px right of the middle, 3 wide,
	# from 2 px above its top down to its feet.
	_shield_mesh.position = Vector3(8.5 * facing, 0, 0) * Px.M
	set_tint(_body)
	set_rim(_body, 0.6)
	_body.rotation.y = 0.0 if facing > 0 else PI
	var snap := pos.round() - pos
	_visual.position = Vector3(snap.x, -snap.y, 0) * Px.M


## The 16 x 20 robot facing right (mirrored for the left): body columns 2..14, rows 0..17, feet on rows 18-19.
static func _body_rows(step: int) -> Array:
	var g := []
	for yy in 20:
		var row := []
		row.resize(16)
		row.fill(".")
		g.append(row)
	for yy in 18:
		for xx in range(2, 15):
			var edge := xx == 2 or xx == 14 or yy == 0 or yy == 17
			g[yy][xx] = "w" if edge else "d"
	# The visor (rows 1-4) with a lit corner and the eye at x + 9..11 (`x + 8 + facing * 2 - 1`), rows 2-3.
	for yy in range(1, 5):
		for xx in range(3, 14):
			g[yy][xx] = "W"
	g[1][3] = "L"
	g[1][4] = "L"
	g[2][3] = "L"
	for yy in [2, 3]:
		for xx in range(9, 12):
			g[yy][xx] = "R"
	# Armour: 3 x 3 plates at a 4 px pitch below the seam on row 5.
	for j in 3:
		for i in 3:
			var ch := "h" if DotNoise.hash2(i, j + 1, 3) > 0.5 else "g"
			for oy in 3:
				for ox in 3:
					g[6 + j * 4 + oy][3 + i * 4 + ox] = ch
	# Feet 2 px wide at x + 3 + step and x + 11 - step.
	for yy in [18, 19]:
		for xx in [3 + step, 4 + step, 11 - step, 12 - step]:
			g[yy][xx] = "k"
	return g.map(func(r: Array) -> String: return "".join(PackedStringArray(r)))


## Seven 3 px segments of 2.4 px at a 3.2 px pitch from 2 px above its top (22 px tall), glowing, deep.
static func _shield(c: Color) -> ArrayMesh:
	var rows := []
	for yy in 22:
		rows.append("sss" if fmod(yy, 3.2) < 2.4 else "...")
	return Voxel.mesh(rows, {"s": c}, {"s": 14}, Px.M, Voxel.material(1.6))


static func _label_rows() -> Array:
	var rows := []
	for yy in 5:
		var line := ""
		for d in "403":
			line += (DIGITS[d][yy] as String).replace("#", "c") + "."
		rows.append(line.trim_suffix("."))
	return rows
