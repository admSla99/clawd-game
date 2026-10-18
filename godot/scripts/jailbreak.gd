class_name Jailbreak
extends Injector

## World 2's map boss (docs/endgame-plan.md E8): THE JAILBREAK, a prompt injector grown SCALE times with LIFE hit
## points (before the map's scaling, Main.enter_map()). It hops at Clawd higher and farther than an injector, and
## every landing shakes the ground and sprays SHOTS Corruption shots up in a fan; every SPLIT_EVERY landings it
## spits out an injector too (no loot). Its death completes the map; it leaves no bugs behind.

const TITLE := "THE JAILBREAK"
const SCALE := 2.5
const LIFE := 360.0
const RISE := 0.0
const SHOTS := 7
const SHOT_SPEED := 150.0
const SPLIT_EVERY := 3

var landings := 0


func _init() -> void:
	super()
	size = SIZE * SCALE
	hp = LIFE
	tokens = 40 * TOKEN_FACTOR
	hop_range = MapBoss.NEAR
	hop = 430.0
	hop_x = 170.0


func _ready() -> void:
	super()
	scale = Vector3.ONE * SCALE
	health_bar = false


func fighting() -> bool:
	return MapBoss.near(self)


## A landing: the ground shakes, a fan of shots goes up from its top, and now and then an injector jumps out.
func _landed() -> void:
	if not fighting():
		return
	landings += 1
	var main := get_tree().get_first_node_in_group("main")
	if main:
		main.shake(0.25)
	Sound.play("poundLand")
	var top := pos + Vector2(0, -size.y * 0.6)
	for i in SHOTS:
		var a := lerpf(-PI * 0.9, -PI * 0.1, float(i) / (SHOTS - 1))
		Shot.fire(level, top, Vector2.from_angle(a) * SHOT_SPEED, Stats.ELEMENT_COLOR[element]).element = element
	if landings % SPLIT_EVERY == 0:
		var add := Injector.new()
		add.name = "Injector"
		add.position = Px.to3(pos + Vector2(signf(randf() - 0.5) * size.x * 0.4, -4))
		add.hp *= HP_FACTOR
		add.no_loot = true
		level.add_child(add, true)


## No split: a burst where it stood.
func _die(_kind: StringName) -> void:
	Fx.burst(self, pos + Vector2(0, -size.y / 2), {count = 40, speed = 160, life = 0.7, color = [MAGENTA, PINK, Color.WHITE], gravity = 200, size = 2})
	queue_free()
