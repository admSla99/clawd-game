class_name MapBoss
extends ShieldBot

## A map's boss (docs/endgame-plan.md E5): a shield bot grown SCALE times, with BOSS_HP times a shield bot's hit
## points (before the map's scaling, Main.enter_map()), named for the HUD's boss bar instead of its own. Get behind
## its shield, or rip it off with the Tool Call. Its death completes the map (Main.enemy_died() -> map_complete()).

const TITLE := "THE OVERFITTER"
const SCALE := 1.8
const BOSS_HP := 40.0


func _init() -> void:
	super()
	size = SIZE * SCALE
	hp = 9 * BOSS_HP
	tokens = 40 * TOKEN_FACTOR
	element = "lightning"


func _ready() -> void:
	super()
	scale = Vector3.ONE * SCALE
	health_bar = false


## The HUD's boss bar shows while it lives and Clawd is within NEAR px.
const NEAR := 320.0


func fighting() -> bool:
	var player: Player = get_tree().get_first_node_in_group("player")
	return not dead and player != null and absf(player.pos.x - pos.x) < NEAR
