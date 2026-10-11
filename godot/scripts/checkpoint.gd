class_name Checkpoint
extends Node3D

## Checkpoint from src/entities/collectibles.ts: a terminal on a post. Touching it saves the respawn point
## and refills the hearts (Main.activate_checkpoint()). Drawn at 1 px like Clawd: an 18 x 12 px screen whose
## dark glass sits 1 px back in its bezel, a ribbed post and a foot, standing behind the gameplay plane so
## Clawd walks in front of it. Off: grey bezel and a blinking cursor. On: an orange bezel, "OK" for 1.2 s,
## then a glowing ">_", and a GlowLight that warms the ground around it.

## Interaction box relative to the feet, like the 2D checkpoint (16 x 28 px).
const RECT := Rect2(-8, -28, 16, 28)
## Behind Clawd (he is 12 px deep) on the top band of the block.
const Z := -0.6
const ORANGE := Color("#D97757")

static var _frame_meshes := {}
static var _screen_meshes := {}

var active := false
var t := 0.0
var _frame: MeshInstance3D
var _screen: MeshInstance3D
var _glow: GlowLight


func _ready() -> void:
	_frame = MeshInstance3D.new()
	_screen = MeshInstance3D.new()
	for m in [_frame, _screen]:
		m.position.z = Z
		add_child(m)
	_glow = GlowLight.new()
	_glow.radius = 2.2
	_glow.energy = 0.0
	_glow.position = Vector3(0, 22 * Px.M, Z + 0.4)
	add_child(_glow)
	_update_visual()


## Level pixels of the feet.
func feet() -> Vector2:
	return Px.of(position)


func _physics_process(dt: float) -> void:
	if Game.frozen():
		return
	t += dt
	var player: Player = get_tree().get_first_node_in_group("player")
	if not active and player and Rect2(feet() + RECT.position, RECT.size).intersects(player.hitbox()):
		active = true
		t = 0.0
		var main := get_tree().get_first_node_in_group("main")
		if main:
			main.activate_checkpoint(self)
	_update_visual()


func _update_visual() -> void:
	_frame.mesh = frame_mesh(active)
	var content := "idle_on" if floori(t * 2) % 2 == 0 else "idle_off"
	if active:
		content = "OK" if t < 1.2 else ">_"
	_screen.mesh = screen_mesh(content)
	_glow.energy = (0.9 if t < 1.2 else 0.6) if active else 0.0


## The terminal without what the screen shows; `on` gives the orange bezel.
static func frame_mesh(on: bool) -> ArrayMesh:
	if not _frame_meshes.has(on):
		var rows := []
		for y in 12:
			rows.append("b" + ("b" if y == 0 or y == 11 else "f").repeat(16) + "b")
		for y in 15:
			rows.append("........" + ("pp" if y % 2 == 0 else "qq") + "........")
		rows.append("....BBBBBBBBBB....")
		var palette := {
			"b": ORANGE if on else Color8(106, 106, 106),
			"f": Color8(18, 18, 20),
			"p": Color8(150, 150, 150) if on else Color8(95, 95, 95),
			"q": Color8(62, 60, 66),
			"B": Color8(80, 80, 84),
		}
		_frame_meshes[on] = Voxel.mesh(rows, palette, {"b": 6, "f": 4, "p": 2, "q": 2, "B": 6}, Px.M)
	return _frame_meshes[on]


## What the screen shows ("idle_on" / "idle_off" for the blinking cursor, or a text), on the same grid as
## frame_mesh(), 1 px in front of the glass so it sits flush with the bezel. Glows.
static func screen_mesh(content: String) -> ArrayMesh:
	if content == "idle_off":
		return null
	if not _screen_meshes.has(content):
		var grid := []
		for y in 28:
			grid.append(".".repeat(18))
		var put := func(x: int, y: int, ch: String) -> void:
			grid[y] = grid[y].substr(0, x) + ch + grid[y].substr(x + 1)
		if content == "idle_on":
			for x in 4:
				put.call(4 + x, 7, "c")
		else:
			var text := PixelFont.rows(content, "t")
			var x0: int = 9 - text[0].length() / 2
			for y in 5:
				for x in text[y].length():
					if text[y][x] == "t":
						put.call(x0 + x, 3 + y, "t")
		_screen_meshes[content] = Voxel.mesh(grid, {"c": Color8(130, 130, 130), "t": Color("#F0A585")}, {"c": 6, "t": 6}, Px.M, Voxel.material(1.5))
	return _screen_meshes[content]
