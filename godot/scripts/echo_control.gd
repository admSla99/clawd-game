class_name EchoControl
extends Node

## World 3's sub-agents (docs/world3-plan.md), once Progress has the "agents" tool (clearing 3-1 gives it): Clawd's
## feet are recorded every physics frame for the last REPLAY seconds, and the `agent` action (G / the middle mouse
## button) sends out a sub-agent (scripts/echo.gd) that replays them and then stands where he was. How many can be
## out at once grows with the sub-agents rescued in every level (slots()); sending one more recalls the oldest.
## The recording starts over when Clawd respawns. Runs after the player (process_physics_priority).

const REPLAY := 3.0
## Rescued sub-agents for the 2nd and 3rd slot.
const SLOT_AT := [10, 18]

var main: Node
var player: Player
## [Vector2 feet, int facing] per physics frame, newest last.
var trail: Array = []
var echoes: Array[Echo] = []
## Extra slots and how long a sub-agent stands (the prompt tree: Delegate., Orchestrator., Patience).
var extra := 0
var stand := Echo.STAND


func setup(m: Node, p: Player) -> void:
	main = m
	player = p
	process_physics_priority = 12


func available() -> bool:
	return Progress.has_tool("agents") and main.mode == Main.Mode.PLAY and player.in_play()


## Sub-agents that can be out at once.
func slots() -> int:
	var rescued := Progress.total_agents()
	return 1 + SLOT_AT.filter(func(n: int) -> bool: return rescued >= n).size() + extra


func out() -> Array[Echo]:
	echoes = echoes.filter(func(e: Echo) -> bool: return is_instance_valid(e) and e.alive())
	return echoes


## Free slots now.
func free_slots() -> int:
	return maxi(0, slots() - out().size())


## A new level or a respawn: the recording starts over; leaving the level sends every sub-agent home.
func reset(recall_all := true) -> void:
	trail.clear()
	if recall_all:
		for e in out():
			e.queue_free()
		echoes.clear()


func _physics_process(_dt: float) -> void:
	if not available() or Game.frozen():
		return
	trail.append([player.pos, player.facing])
	if trail.size() > int(REPLAY * 60):
		trail.pop_front()
	if Input.is_action_just_pressed("agent") and main.complete_t < 0 and not player.frozen:
		send()


## Sends out a sub-agent on the recording; at full slots the oldest goes home first.
func send() -> Echo:
	if trail.size() < 2:
		return null
	var live := out()
	if live.size() >= slots():
		live[0].recall()
	var e := Echo.new()
	e.name = "Echo"
	e.stand = stand
	e.path = _trimmed(trail)
	main.level.add_child(e, true)
	echoes.append(e)
	Sound.play("agentSend")
	Fx.burst(e, trail[0][0] + Vector2(0, -9), {count = 12, speed = 60, life = 0.4, color = [Echo.TINT, Color.WHITE]})
	return e


## The recording without the time Clawd stood still at its start and end, so a sub-agent sent after waiting stands
## at once instead of replaying the wait.
static func _trimmed(rec: Array) -> Array:
	var a := 0
	var b := rec.size() - 1
	while a < b and rec[a][0].is_equal_approx(rec[a + 1][0]):
		a += 1
	while b > a and rec[b][0].is_equal_approx(rec[b - 1][0]):
		b -= 1
	return rec.slice(a, b + 1)
