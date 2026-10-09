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
