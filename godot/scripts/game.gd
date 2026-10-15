extends Node

## Autoload "Game": the game clock. Everything animated in a level reads Game.time and skips its
## update while Game.frozen(), so hitstop and pause stop the world like `this.time` and
## hitstopTimer in src/scenes/game.ts. Runs at the physics rate (60 Hz, STEP in src/config.ts).

## Seconds of unfrozen game time since the current level started.
var time := 0.0
var paused := false
var hitstop_left := 0.0


## Freezes the world for `seconds`; overlapping requests keep the longest.
func hitstop(seconds: float) -> void:
	hitstop_left = maxf(hitstop_left, seconds)


func frozen() -> bool:
	return paused or hitstop_left > 0


## A key held while the window loses the focus never sees its release (an alt-tab, a system prompt such as
## Windows' Sticky Keys after five quick Shifts, the editor taking the focus from the game embedded in it), and
## Clawd would keep walking that way: every action is let go then.
func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		release_all()


func release_all() -> void:
	for a in InputMap.get_actions():
		if Input.is_action_pressed(a):
			Input.action_release(a)


func reset() -> void:
	time = 0.0
	hitstop_left = 0.0
	paused = false


func _physics_process(dt: float) -> void:
	if paused:
		return
	if hitstop_left > 0:
		hitstop_left -= dt
		return
	time += dt
