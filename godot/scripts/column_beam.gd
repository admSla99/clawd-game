class_name ColumnBeam
extends Enemy

## Codex's "rm -rf" column, `ColumnBeam` in src/entities/boss/codex.ts: for 0.85 s a blinking warning line
## from the top of the level to the floor, then for 0.35 s a deadly beam 18 px wide (laser, shake), whose
## middle 12 px hurt. It cannot be shot down or spun away and does not vanish on Clawd.
## Drawn in 2.5D: the warning's red dashes come down the gameplay plane onto a blinking square of dashes on the
## floor's top; the beam is a column 18 px deep, translucent red round a glowing white core, with a GlowLight on
## the floor and sparks where it strikes.

const WIDTH := 18.0
const WARN := 0.85
const ACTIVE := 0.35
const RED := Color("#E0605A")
const RED_DARK := Color("#8F3A37")

var floor_y := 0.0
var timer := WARN
var active := 0.0
var _paint: CodexPaint
var _light: GlowLight


## A column at `x` (its middle) down to the floor top at `floor_top`, added to `parent`.
static func create(parent: Level, x: float, floor_top: float) -> ColumnBeam:
	var b := ColumnBeam.new()
	b.name = "ColumnBeam"
	b.floor_y = floor_top
	b.size = Vector2(WIDTH, floor_top)
	b.position = Px.to3(Vector2(x, floor_top))
	parent.add_child(b, true)
	return b


func _init() -> void:
	projectile = true
	cancellable = false
	consume_on_hit = false
	invincible = true
	stompable = false
	tokens = 0
	collision_layer = 0
	collision_mask = 0


func _ready() -> void:
	super()
	_paint = CodexPaint.new()
	add_child(_paint)
	_light = GlowLight.new()
	_light.radius = 3.0
	_light.energy = 0.0
	_light.position = Vector3(0, 6 * Px.M, 0)
	add_child(_light)
	_update_visual()


func hurtbox() -> Rect2:
	if active <= 0:
		return Rect2()
	return Rect2(pos.x - WIDTH / 2 + 3, 0, WIDTH - 6, floor_y)


func _physics_process(dt: float) -> void:
	if Game.frozen():
		return
	tick(dt)
	if timer > 0:
		timer -= dt
		if timer <= 0:
			active = ACTIVE
			Sound.play("laser")
			var main := get_tree().get_first_node_in_group("main")
			if main:
				main.shake(0.3)
	else:
		active -= dt
		Fx.burst(self, Vector2(pos.x, floor_y), {count = 3, speed = 90, angle = -PI / 2, spread = 1.2, life = 0.3, color = [RED, Color.WHITE], depth = 8})
		if active <= 0:
			remove()
			return
	_update_visual()


## Relative to the node (the middle of the column's foot), y down like the 2D canvas.
func _update_visual() -> void:
	var snap := pos.round() - pos
	_paint.position = Vector3(snap.x, -snap.y, 0) * Px.M
	_paint.begin()
	if timer > 0:
		var on := floori(Game.time * 14) % 2 == 0
		var c := RED if on else RED_DARK
		var y := -floor_y
		while y < 0:
			_paint.rect(Vector2(-1, y), Vector2(2, 3), c, -1, 1, 1.4 if on else 1.0)
			y += 6
		# A square of dashes on the floor's top, across its depth.
		for i in range(-9, 9, 3):
			for z in [-12.0, 12.0]:
				_paint.rect(Vector2(i, -1), Vector2(2, 1), c, z - 1, z + 1, 1.4 if on else 1.0)
		for z in range(-12, 13, 3):
			for x in [-9.0, 8.0]:
				_paint.rect(Vector2(x, -1), Vector2(1, 1), c, z - 1, z + 1, 1.4 if on else 1.0)
		_light.energy = 0.0
	else:
		_paint.rect(Vector2(-WIDTH / 2, -floor_y), Vector2(WIDTH, floor_y), Color(RED, 0.5), -9, 9, 1.2)
		_paint.rect(Vector2(-WIDTH / 2 + 6, -floor_y), Vector2(WIDTH - 12, floor_y), Color.WHITE, -3, 3, 2.2)
		_light.energy = 2.0 * clampf(active / ACTIVE * 1.5, 0.0, 1.0)
	_paint.end()
