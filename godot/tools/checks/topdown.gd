extends RefCounted

## The top-down prototype (branch topdown-prototype; a section of tools/check.gd, `c` is check.gd): the arena,
## Clawd moving and dodging, a shot killing a bug for XP, waves, a bite.

const TITLE := "top-down prototype: arena, moving, dodging, shooting, waves (branch topdown-prototype)"


func run(c) -> bool:
	var progress = c.root.get_node("Progress")
	var saved := {"level": progress.char_level, "xp": progress.xp, "wallet": progress.wallet}
	var td = load("res://scripts/topdown/td_main.gd").new()
	c.root.add_child(td)
	await c.frames(3)
	var room = td.room
	var p = td.player
	# Every free cell can be reached from the middle.
	var free := 0
	var seen := {Vector2i(room.W / 2, room.H / 2): true}
	var queue := [Vector2i(room.W / 2, room.H / 2)]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = cell + d
			if not room.is_solid(n) and not seen.has(n):
				seen[n] = true
				queue.append(n)
	for x in room.W:
		for y in room.H:
			if not room.is_solid(Vector2i(x, y)):
				free += 1
	c.ok(free == seen.size() and free > 300, "the arena: %d free cells, every one reachable from the middle" % free)
	c.ok(p.max_life > 0 and is_equal_approx(p.life, p.max_life), "Clawd starts with his endgame life (%d)" % p.max_life)
	# W moves him up on screen: away from the camera.
	var at: Vector2 = p.pos
	Input.action_press("up")
	await c.frames(20)
	Input.action_release("up")
	var moved: Vector2 = p.pos - at
	c.ok(moved.x < -0.3 and moved.y < -0.3, "W moves him up the screen (%.1f, %.1f m)" % [moved.x, moved.y])
	# Space dodges: fast, and he cannot be hit meanwhile.
	at = p.pos
	p.aim = Vector2(1, 1).normalized()
	Input.action_press("jump")
	await c.frames(2)
	Input.action_release("jump")
	c.ok(p.dodging() and p.hurt(-1.0, 32) == 0.0, "Space dodges, and a hit then does nothing")
	await c.frames(20)
	c.ok(p.pos.distance_to(at) > 1.5, "the dodge carries him %.1f m" % p.pos.distance_to(at))
	# A shot kills a bug: XP and tokens.
	td.next_wave_t = 1000.0
	var bug = load("res://scripts/topdown/td_enemy.gd").make("bug", p.pos + Vector2(2, 0), 32)
	bug.hp = 1.0
	td.world.add_child(bug)
	td.enemies.append(bug)
	var xp: int = progress.xp + progress.char_level * 100000
	var wallet: int = progress.wallet
	td._add_shot(load("res://scripts/topdown/td_shot.gd").make(p.pos + Vector2(0.5, 0), Vector2(20, 0), 5.0, true, Color.WHITE, 1.0))
	await c.frames(10)
	c.ok(td.enemies.is_empty() and td.kills == 1 and progress.wallet == wallet + td.ENEMY_TOKENS
		and progress.xp + progress.char_level * 100000 > xp, "a shot kills a bug: a kill, XP and tokens")
	# Waves grow.
	td.spawn_wave()
	var first: int = td.enemies.size()
	for e in td.enemies:
		e.queue_free()
	td.enemies.clear()
	td.spawn_wave()
	c.ok(td.wave == 2 and td.enemies.size() > first and td.area == 33, "waves grow (%d, then %d enemies) and their area level" % [first, td.enemies.size()])
	# A bug that bites is thrown back.
	var biter = td.enemies[0]
	biter.kind = "bug"
	p.grace = 0.0
	p.evasion = 0.0
	biter.pos = p.pos + Vector2(0.3, 0)
	var life: float = p.life
	await c.frames(2)
	c.ok(p.life < life and biter.pos.distance_to(p.pos) > 1.0, "a bite hurts and throws the bug back")
	td.queue_free()
	await c.frames(2)
	progress.char_level = saved.level
	progress.xp = saved.xp
	progress.wallet = saved.wallet
	progress.save()
	return true
