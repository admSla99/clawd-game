class_name CodexHand
extends Enemy

## One of Codex's giant cursor hands, `CodexHand` in src/entities/boss/codex.ts. It cannot be hurt and hurts
## on contact. It hovers beside the monitor; slam() makes it track Clawd 120 px over the floor for 0.85 s
## (after an optional delay at home), drop at 650 px/s, stick in the floor for 0.8 s (slam, shake, dust and a
## shockwave either way at 165 px/s) and go home. retire() removes it when Codex dies.
## Drawn as the 2D cursor sprite (10 x 16 cells of 2 px) in voxels, its outline deeper than its grey fill,
## pointing down while it slams, mirrored on the right; while it tracks, a blinking red target lies on the
## floor's top under it, and the shockwave rolls along the floor across its depth (CodeShot.span).

const SIZE := Vector2(20, 32)
const CURSOR := [
	"O.........",
	"OO........",
	"OwO.......",
	"OwwO......",
	"OwwwO.....",
	"OwwwwO....",
	"OwwwwwO...",
	"OwwwwwwO..",
	"OwwwwwwwO.",
	"OwwwwwwwwO",
	"OwwwwwOOOO",
	"OwwOwwO...",
	"OwO.OwwO..",
	"OO..OwwO..",
	"O....OwwO.",
	".....OOOO.",
]
const PALETTE := {"O": Color("#E6E6E6"), "w": Color("#6A6A6A")}
## Depth in 2 px cells: the outline stands 2 px proud of the fill on both sides.
const DEPTH := {"O": 4, "w": 2}
const RED := Color("#E0605A")
const RED_DARK := Color("#8F3A37")
const WAVE := Color("#7FE3EA")

## The cursor's four meshes: [pointing down][mirrored].
static var _meshes := {}

var head: Node
var side := -1
var floor_y := 0.0
var busy := false
var mode := &"hover"
var timer := 0.0
var delay := 0.0
var t := randf() * 5
var target_x := 0.0
## Top-left corner in level px, like the 2D entity's x / y.
var x := 0.0
var y := 0.0
var _body: MeshInstance3D
var _paint: CodexPaint


## A hand on `hand_side` (-1 left, 1 right) of `codex`, over a floor at `floor_top`.
static func create(parent: Level, codex: Node, hand_side: int, floor_top: float) -> CodexHand:
	var h := CodexHand.new()
	h.name = "CodexHand"
	h.head = codex
	h.side = hand_side
	h.floor_y = floor_top
	h.x = codex.cx + hand_side * 60 - 10
	h.y = codex.cy - codex.SIZE.y / 2 + 10
	h.position = Px.to3(Vector2(h.x + SIZE.x / 2, h.y + SIZE.y))
	parent.add_child(h, true)
	return h


func _init() -> void:
	size = SIZE
	invincible = true
	stompable = false
	health_bar = false
	tokens = 0
	collision_layer = 0
	collision_mask = 0


func _ready() -> void:
	super()
	_body = MeshInstance3D.new()
	add_child(_body)
	_paint = CodexPaint.new()
	level.add_child(_paint)
	_update_visual()


func _exit_tree() -> void:
	if is_instance_valid(_paint):
		_paint.queue_free()


func cx() -> float:
	return x + SIZE.x / 2


func slam(wait := 0.0) -> void:
	if mode == &"gone":
		return
	busy = true
	delay = wait
	mode = &"track"
	timer = 0.85 + wait


## Codex died: gone in a puff.
func retire() -> void:
	mode = &"gone"
	Fx.burst(self, Vector2(cx(), y + 16), {count = 30, speed = 120, life = 0.6, color = [Color.WHITE, Color8(150, 150, 150)]})
	remove()


func hurtbox() -> Rect2:
	if mode == &"gone":
		return Rect2()
	return Rect2(x + 3, y + 3, SIZE.x - 6, SIZE.y - 6)


func _physics_process(dt: float) -> void:
	if Game.frozen():
		return
	tick(dt)
	t += dt
	timer -= dt
	var home_x: float = head.cx + side * 62 - SIZE.x / 2
	var home_y: float = head.cy - head.SIZE.y / 2 + 12 + sin(t * 2) * 4
	match mode:
		&"hover":
			x += (home_x - x) * minf(1.0, dt * 5)
			y += (home_y - y) * minf(1.0, dt * 5)
		&"track":
			if delay > 0:
				delay -= dt
				x += (home_x - x) * minf(1.0, dt * 5)
			else:
				var player: Player = get_tree().get_first_node_in_group("player")
				if player:
					target_x = player.pos.x - SIZE.x / 2
				x += (target_x - x) * minf(1.0, dt * 6)
				y += (floor_y - 120 - y) * minf(1.0, dt * 6)
				if timer <= 0:
					mode = &"drop"
		&"drop":
			y += 650 * dt
			if y + SIZE.y >= floor_y:
				y = floor_y - SIZE.y
				mode = &"stuck"
				timer = 0.8
				Sound.play("slam")
				var main := get_tree().get_first_node_in_group("main")
				if main:
					main.shake(0.5)
				Fx.burst(self, Vector2(cx(), floor_y), {count = 30, speed = 140, angle = -PI / 2, spread = PI, life = 0.5, color = [Color8(220, 220, 220), Color("#5FD0D8")], gravity = 300, depth = 16})
				for s in [-1.0, 1.0]:
					CodeShot.fire_glyph(level, Vector2(cx() + s * 12, floor_y - 5), Vector2(s * 165, 0), "≈", WAVE, false, 2.6, true)
		&"stuck":
			if timer <= 0:
				mode = &"return"
		&"return":
			x += (home_x - x) * minf(1.0, dt * 4)
			y += (home_y - y) * minf(1.0, dt * 4)
			if absf(y - home_y) < 4:
				mode = &"hover"
				busy = false
	pos = Vector2(cx(), y + SIZE.y)
	_update_visual()


func _update_visual() -> void:
	var down := mode in [&"track", &"drop", &"stuck"]
	_body.mesh = cursor_mesh(down, side > 0)
	set_tint(_body)
	set_rim(_body, 1.0)
	# Whole pixels; the 2D sprite is drawn with its bottom at y + h.
	var snap := pos.round() - pos
	_body.position = Vector3(snap.x, -snap.y, 0) * Px.M
	# The target under a tracking hand, blinking at 16 Hz: a square of dashes on the floor's top.
	_paint.begin()
	if mode == &"track" and delay <= 0:
		var on := floori(Game.time * 16) % 2 == 0
		var c := RED if on else RED_DARK
		var left := roundf(x)
		for i in range(0, int(SIZE.x), 3):
			for z in [-12.0, 0.0, 12.0]:
				_paint.rect(Vector2(left + i, floor_y - 1), Vector2(2, 1), c, z - 1, z + 1, 1.4 if on else 1.0)
		for z in range(-12, 13, 3):
			for e in [0.0, SIZE.x - 1]:
				_paint.rect(Vector2(left + e, floor_y - 1), Vector2(1, 1), c, z - 1, z + 1, 1.4 if on else 1.0)
	_paint.end()


static func cursor_mesh(down: bool, mirrored: bool) -> ArrayMesh:
	var key := Vector2i(int(down), int(mirrored))
	if not _meshes.has(key):
		var rows: Array = CURSOR.duplicate()
		if down:
			rows.reverse()
		if mirrored:
			rows = rows.map(func(r: String) -> String: return r.reverse())
		_meshes[key] = Voxel.mesh(rows, PALETTE, DEPTH, 2 * Px.M)
	return _meshes[key]
