class_name FakePlatform
extends Node3D

## A hallucinated platform from `FakePlatform` in src/entities/platforms.ts, conjured by the Hallucination:
## it looks like a real hovering slab (MovingPlatform's look, without its jets, which is the tell), Clawd can
## land on it from above (group "platforms", same fields as MovingPlatform), and 0.45 s after he first stands
## on it, or after `lifetime` seconds, it dissolves in purple, white and cyan bits. It fades in over a third
## of a second and flickers once stood on.

const H := 6
const PURPLE := Color("#C25BD6")
const CYAN := Color("#5FD0D8")

static var _meshes := {}

## Top-left in level pixels and how far it moved this frame (always 0).
var x := 0.0
var y := 0.0
var w := 64.0
var dx := 0.0
var dy := 0.0
var active := true
var lifetime := 7.0
var age := 0.0
var stood := -1.0
var _slab: MeshInstance3D


## A fake platform `width` px wide with its top-left at `top_left` (level pixels), added to `parent`.
static func create(parent: Node3D, top_left: Vector2, width: float, seconds := 7.0) -> FakePlatform:
	var p := FakePlatform.new()
	p.name = "FakePlatform"
	p.x = top_left.x
	p.y = top_left.y
	p.w = width
	p.lifetime = seconds
	p.position = Px.to3(Vector2(top_left.x + width / 2, top_left.y))
	parent.add_child(p, true)
	return p


func _ready() -> void:
	add_to_group("platforms")
	process_physics_priority = -10
	_slab = MeshInstance3D.new()
	_slab.mesh = _mesh(int(w))
	_slab.position.y = -H * Px.M
	add_child(_slab)
	_slab.visible = false


func rect() -> Rect2:
	return Rect2(x, y, w, H)


## Clawd stands on it (Player calls this every frame he lands on or rides a platform that has it).
func on_stand() -> void:
	if stood < 0:
		stood = 0.0


func _physics_process(dt: float) -> void:
	if Game.frozen():
		return
	age += dt
	if stood >= 0:
		stood += dt
	if active and (stood > 0.45 or age > lifetime):
		active = false
		Fx.burst(self, Vector2(x + w / 2, y), {count = 20, speed = 50, life = 0.5, color = [PURPLE, Color.WHITE, CYAN], gravity = 100, depth = 10})
		queue_free()
		return
	# Fading in: more and more frames shown; once stood on it flickers at 30 Hz.
	var fade_in := minf(1.0, age * 3)
	_slab.visible = randf() < fade_in and not (stood >= 0 and floori(Game.time * 30) % 2 == 0)
	_slab.position.x = (randi_range(-1, 1) if stood >= 0 else 0) * Px.M


## The slab of MovingPlatform at `width` px: a white crust with orange end LEDs over a grey edge with a row of
## LEDs and a dark body tapering underneath.
static func _mesh(width: int) -> ArrayMesh:
	if not _meshes.has(width):
		var rows := []
		for r in 5:
			var s := ""
			for i in width:
				var edge := i == 0 or i == width - 1
				match r:
					0: s += "o" if edge else "c"
					1: s += "g"
					2: s += "l" if i % 8 == 3 else "d"
					3: s += "." if edge else "d"
					4: s += "." if i < 3 or i >= width - 3 else "d"
			rows.append(s)
		rows.append(".".repeat(width))
		var palette := {"c": Color8(225, 225, 225), "g": Color8(150, 150, 150), "d": Color8(46, 44, 52), "o": Color("#D97757"), "l": Color("#F0A585")}
		_meshes[width] = Voxel.mesh(rows, palette, {"c": 12, "g": 12, "d": 12, "o": 12, "l": 12}, Px.M, Voxel.MATERIAL, {"c": Color8(150, 150, 156)})
	return _meshes[width]
