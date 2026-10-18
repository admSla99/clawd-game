class_name MapBoss
extends ShieldBot

## World 1's map boss (docs/endgame-plan.md E5): THE OVERFITTER, a shield bot grown SCALE times, with BOSS_HP times a
## shield bot's hit points (LIFE, before the map's scaling, Main.enter_map()), named for the HUD's boss bar instead
## of its own. Get behind its shield, or rip it off with the Tool Call. Its death completes the map
## (Main.enemy_died() -> map_complete()). Worlds 2 and 3 have their own (Maps.BOSSES: Jailbreak, InfiniteLoop); each
## has TITLE, LIFE, RISE (px over the chunk's 'B' it is put at) and fighting().

const TITLE := "THE OVERFITTER"
const SCALE := 1.8
const BOSS_HP := 40.0
const LIFE := 9 * BOSS_HP
const RISE := 0.0


func _init() -> void:
	super()
	size = SIZE * SCALE
	hp = LIFE
	tokens = 40 * TOKEN_FACTOR
	element = "lightning"


func _ready() -> void:
	super()
	scale = Vector3.ONE * SCALE
	health_bar = false


## The HUD's boss bar shows while it lives and Clawd is within NEAR px.
const NEAR := 320.0


func fighting() -> bool:
	return near(self)


## Whether boss `e` lives with Clawd within NEAR px of it, across.
static func near(e: Enemy) -> bool:
	var player: Player = e.get_tree().get_first_node_in_group("player")
	return not e.dead and player != null and absf(player.pos.x - e.pos.x) < NEAR
