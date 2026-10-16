class_name TdEnemy
extends TdActor

## The prototype's enemies: "bug" (walks straight at Clawd, sliding round walls, and hurts on touch) and "spam" (a
## spam bot floating at chest height that keeps 4-6 m away, circles and fires a slow shot every RELOAD s while it
## sees him). Life and hits scale with the area level like a map's (Maps.life_mult(), Stats.enemy_hit()).

const BUG_SPEED := 2.4
const SPAM_SPEED := 1.8
const RELOAD := 2.2
const SHOT_SPEED := 4.5

var kind := "bug"
var hp := 1.0
var max_hp := 1.0
var worth := 3.0
var reload := 1.0
var t := randf() * 4
var orbit := 1.0 if randf() < 0.5 else -1.0
var dead := false


static func make(k: String, at: Vector2, area: int) -> TdEnemy:
	var e := TdEnemy.new()
	e.kind = k
	e.pos = at
	var base := 2.0 if k == "bug" else 3.0
	e.worth = base * Enemy.HP_FACTOR * Maps.life_mult(area)
	e.hp = e.worth
	e.max_hp = e.hp
	e.radius = 0.35 if k == "bug" else 0.4
	e.reload = randf_range(0.8, RELOAD)
	return e


func _ready() -> void:
	super()
	_update_mesh()


func _update_mesh() -> void:
	if kind == "bug":
		body.mesh = TdActor.sprite(BugSprite.rows(int(t * 6) % 2), BugSprite.PALETTE, BugSprite.DEPTH)
	else:
		body.mesh = TdActor.sprite(SpamBot.FRAMES[int(t * 4) % 2], SpamBot.PALETTE, SpamBot.DEPTH)
		height = 0.55 + sin(t * 3) * 0.08


## One step: moves (sliding on `room`), and returns a shot to fire at `target` or null.
func tick(dt: float, room: TdRoom, target: Vector2) -> TdShot:
	t += dt
	flash = maxf(0.0, flash - dt)
	var to := target - pos
	var dist := to.length()
	var dir := to / maxf(dist, 0.001)
	var shot: TdShot = null
	if kind == "bug":
		pos = room.slide(pos, dir * BUG_SPEED * dt, radius)
	else:
		var want := dir if dist > 6.0 else -dir if dist < 4.0 else Vector2.ZERO
		var side := Vector2(-dir.y, dir.x) * orbit * 0.7
		pos = room.slide(pos, (want + side).limit_length(1.0) * SPAM_SPEED * dt, radius)
		reload -= dt
		if reload <= 0 and dist < 9.0 and room.line_clear(pos, target):
			reload = RELOAD
			shot = TdShot.make(pos + dir * 0.4, dir * SHOT_SPEED, -1.0, false, Color("#E0605A"), 3.0)
	face(dir)
	_update_mesh()
	place()
	return shot
