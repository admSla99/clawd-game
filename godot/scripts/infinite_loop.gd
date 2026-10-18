class_name InfiniteLoop
extends RetryLoop

## World 3's map boss (docs/endgame-plan.md E8): THE INFINITE LOOP, a Retry Loop grown SCALE times with LIFE hit
## points (before the map's scaling, Main.enter_map()), hanging RISE px over its marker. While Clawd is near it
## spawns bugs faster than a Retry Loop (no loot), and every RING_EVERY s it fires a ring of RING Overheat shots,
## turned a little each time so the gaps move. Its death completes the map.

const TITLE := "THE INFINITE LOOP"
const SCALE := 3.0
const LIFE := 360.0
const RISE := 64.0
const RING := 10
const RING_EVERY := 2.6
const SHOT_SPEED := 110.0

var ring_t := 2.0
var turn := 0.0


func _init() -> void:
	super()
	size = SIZE * SCALE
	hp = LIFE
	tokens = 40 * TOKEN_FACTOR
	element = "fire"
	spawn_range = MapBoss.NEAR
	spawn_every = 2.5
	max_alive = 4


func _ready() -> void:
	super()
	scale = Vector3.ONE * SCALE
	health_bar = false


func fighting() -> bool:
	return MapBoss.near(self)


func _physics_process(dt: float) -> void:
	super(dt)
	if Game.frozen() or held() or dead or not fighting():
		return
	ring_t -= dt
	if ring_t <= 0:
		ring_t = RING_EVERY
		turn += 0.3
		var mid := pos + Vector2(0, -size.y / 2)
		for i in RING:
			var a := turn + TAU * i / RING
			Shot.fire(level, mid + Vector2.from_angle(a) * size.x * 0.4, Vector2.from_angle(a) * SHOT_SPEED, Stats.ELEMENT_COLOR[element]).element = element
		Sound.play("shoot")
