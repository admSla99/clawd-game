extends RefCounted

## 2-B Codex (a section of tools/check.gd, which runs every tools/checks/<id>.gd; `c` is check.gd): the boss
## Codex (src/entities/boss/codex.ts) with its hands, shots and rm -rf columns, the phases, hits with the gun,
## its death, the exit and the last level's results; the code-monolith motif.

const TITLE := "2-B Codex: the boss (src/entities/boss/codex.ts), its attacks, phases, death and the motif"
const TILE := 16


func run(c) -> bool:
	var m = c.current_scene
	var p = m.player
	var snd = c.root.get_node("Sound")
	var progress = c.root.get_node("Progress")
	var weapons = load("res://scripts/weapons.gd")
	var bullet_script = load("res://scripts/bullet.gd")
	var codex_script := load("res://scripts/codex.gd")
	var code_shots := func() -> Array:
		return c.enemies_of("res://scripts/code_shot.gd")
	var clear_shots := func() -> void:
		for e in c.get_nodes_in_group("enemies"):
			if e.projectile:
				e.remove()
	if progress.weapons.is_empty():
		progress.grant_weapon("blaster")
	snd.played.clear()
	m.load_level("2-B")
	await c.frames(3)
	c.ok(m.info.theme == "codex" and m.info.boss == "codex" and snd.track == "codex", "2-B is the codex arena with its own tune")
	c.ok(m.motif_3d != null and m.motif_3d.get_script() == load("res://scripts/codex_motif.gd")
		and m.motif_3d.find_children("*", "MeshInstance3D", true, false).size() >= 6,
		"code monoliths stand in the depth behind it (the codex motif)")

	# Spawn: the B marker (column 20), 150 px over the floor (row 15), the arena as wide as the level.
	var b = m.boss
	c.ok(b != null and b.get_script() == codex_script, "2-B spawns Codex at its 'B'")
	# (It has drifted for three frames since.)
	c.ok(absf(b.cx - (20 * TILE + 8)) < 4 and absf(b.floor_y - 15 * TILE) < 0.01 and absf(b.cy - (15 * TILE - 150)) < 4
		and absf(b.arena_w - 40 * TILE) < 0.01, "150 px over the arena's floor, as wide as the level (%.1f, %.1f)" % [b.cx, b.cy])
	c.ok(b.hp == 90.0 and b.max_hp == 90.0 and not b.health_bar and b.TITLE == "CODEX",
		"90 hp (no HP_FACTOR), its name and hp on the HUD's boss bar, no enemy bar")
	c.ok(b.mode == &"intro" and not b.hurtbox().has_area() and not b.hit(&"shot", 5) and b.hp == 90.0,
		"while it types its intro it can't be hurt and doesn't hurt")
	await c.frames(30)
	var hands: Array = c.enemies_of("res://scripts/codex_hand.gd")
	c.ok(hands.size() == 2 and hands.all(func(h): return h.invincible and not h.stompable), "two invincible cursor hands beside it")
	c.ok(b.typed > 0 and "typing" in snd.played, "it types '> codex --ship-it' (%d chars)" % b.typed)
	p.invuln = 1000
	p.pos = Vector2(12 * TILE + 8, 15 * TILE)
	for i in 200:
		await c.physics_frame
		if b.mode != &"intro":
			break
	c.ok(b.mode == &"burst" and b.typed == b.INTRO_TEXT.length(), "after 3.2 s its first attack: a burst")
	for i in 40:
		await c.physics_frame
		if not code_shots.call().is_empty():
			break
	var burst: Array = code_shots.call()
	c.ok(burst.size() == 5 and burst.all(func(s): return s.cancellable and s.projectile and s.glyph in b.BURST_GLYPHS)
		and "shoot" in snd.played, "five code characters, which can be shot down (%d)" % burst.size())
	var aim: Vector2 = p.pos + Vector2(0, -9) - Vector2(b.cx, b.cy + 14)
	var mid: Vector2 = burst[2].vel
	c.ok(absf(angle_difference(mid.angle(), aim.angle())) < 0.2 and absf(mid.length() - 120) < 0.5, "fanned at Clawd at 120 px/s")
	for i in 120:
		await c.physics_frame
		if b.mode == &"idle":
			break
	c.ok(b.mode == &"idle" and b.volley == 3, "three volleys in phase 0, then a rest")

	# The slam: the hand nearest Clawd tracks him, drops, and sends two shockwaves along the floor.
	clear_shots.call()
	p.pos = Vector2(10 * TILE + 8, 15 * TILE)
	b.step = 1
	b._next_attack()
	var slammer = hands[0] if absf(hands[0].cx() - p.pos.x) < absf(hands[1].cx() - p.pos.x) else hands[1]
	c.ok(b.mode == &"slam" and slammer.busy and slammer.mode == &"track", "a slam: the hand nearer Clawd tracks him")
	snd.played.clear()
	for i in 120:
		await c.physics_frame
		if slammer.mode == &"stuck":
			break
	c.ok(slammer.mode == &"stuck" and absf(slammer.y + 32 - b.floor_y) < 0.01 and absf(slammer.cx() - p.pos.x) < 8 and "slam" in snd.played,
		"it drops onto the floor where Clawd stands (%.0f vs %.0f)" % [slammer.cx(), p.pos.x])
	var waves: Array = code_shots.call()
	c.ok(waves.size() == 2 and waves.all(func(s): return s.glyph == "≈" and not s.cancellable and s.span and absf(absf(s.vel.x) - 165) < 0.01),
		"two shockwaves roll away along the floor, too strong to shoot down")
	for i in 120:
		await c.physics_frame
		if b.mode == &"idle":
			break
	c.ok(b.mode == &"idle" and slammer.mode in [&"return", &"hover"], "the hand goes home, Codex rests")

	# The wall of ghost text with one gap.
	clear_shots.call()
	b._spawn_wall(p.pos.x)
	var wall: Array = code_shots.call()
	var ys: Array = wall.map(func(s): return s.rect().get_center().y)
	ys.sort()
	var gap := 0.0
	for i in ys.size() - 1:
		gap = maxf(gap, ys[i + 1] - ys[i])
	c.ok(wall.size() > 15 and wall.all(func(s): return not s.cancellable and s.vel.x < 0) and gap >= 44,
		"a wall of %d characters sweeps from the side away from Clawd, with a %.0f px gap" % [wall.size(), gap])
	clear_shots.call()

	# Phases: at 2/3 and 1/3 of its hp it refactors, untouchable for 1.8 s.
	b.mode = &"idle"
	b.timer = 5.0
	c.ok(b.hit(&"shot", 31.0) and b.phase == 1 and b.mode == &"refactor" and "bossHit" in snd.played,
		"at 2/3 of its hp it refactors (phase 1)")
	c.ok(not b.hit(&"shot", 5.0) and b.hp == 59.0, "and can't be hurt while it does")
	b.step = 1
	b._next_attack()
	var bugs: Array = c.bugs()
	c.ok(b.mode == &"tests" and bugs.size() == 3 and bugs.all(func(e): return e.hp == 6.0) and m.tokens_total == 30,
		"failing tests: 3 bugs of world 2 (6 hp) drop into the arena in phase 1, their tokens counted")
	for e in bugs:
		e.remove()
	b.mode = &"idle"
	b.hit(&"shot", 30.0)
	c.ok(b.phase == 2 and b.mode == &"refactor", "at 1/3 it enables --yolo mode (phase 2)")

	# rm -rf: three columns on Clawd, a warning and then a beam that only the middle of hurts.
	b.step = 0
	b._next_attack()
	c.ok(b.mode == &"rmrf", "phase 2 opens with rm -rf")
	var cols := func() -> Array:
		return c.enemies_of("res://scripts/column_beam.gd")
	for i in 60:
		await c.physics_frame
		if not cols.call().is_empty():
			break
	var col = cols.call()[0] if not cols.call().is_empty() else null
	c.ok(col != null and absf(col.pos.x - p.pos.x) < 0.01 and not col.hurtbox().has_area(), "a column warns where Clawd stands")
	var bl = bullet_script.fire(m.level, p.pos + Vector2(-40, -9), 0.0, 380, weapons.get_def("blaster"), 2.0)
	snd.played.clear()
	for i in 60:
		await c.physics_frame
		if col.active > 0:
			break
	c.ok(col.active > 0 and col.hurtbox().size.x == 12 and "laser" in snd.played and is_instance_valid(col) and not col.dead,
		"then fires (laser): a beam whose middle 12 px hurt, which bullets can't shoot down")
	for i in 120:
		await c.physics_frame
		if cols.call().size() >= 3 or b.mode == &"idle":
			break
	c.ok(b.volley == 3, "three columns in a row")
	clear_shots.call()
	if is_instance_valid(bl):
		bl._remove()

	# Phase 2 slams with both hands.
	b.step = 2
	b._next_attack()
	c.ok(hands.all(func(h): return h.busy) and hands.any(func(h): return h.delay > 0), "in phase 2 both hands slam, one 0.7 s later")
	for i in 240:
		await c.physics_frame
		if b.mode == &"idle":
			break
	clear_shots.call()

	# The gun: a token hits the monitor, shows its damage, a stomp hits it too.
	b.mode = &"idle"
	b.timer = 10.0
	await c.frames(2)
	var hp0: float = b.hp
	p.pos = Vector2(b.cx - 60, b.cy + 9)
	# Over the left hand's reach (it hangs from 13 px above the middle down).
	var shot = bullet_script.fire(m.level, Vector2(b.cx - 46, b.cy - 18), 0.0, 380, weapons.get_def("blaster"), 2.0)
	for i in 20:
		await c.physics_frame
		if b.hp < hp0:
			break
	c.ok(absf(b.hp - (hp0 - 2.0)) < 0.01 and m.overlay.numbers.any(func(n): return n.id == b.get_instance_id()),
		"a blaster token takes 2 hp off the monitor and shows the damage (%.0f -> %.0f)" % [hp0, b.hp])
	if is_instance_valid(shot):
		shot._remove()
	b.timer = 10.0
	hp0 = b.hp
	p.pos = Vector2(b.cx, b.cy - 25 - 30)
	p.vel = Vector2.ZERO
	for i in 40:
		await c.physics_frame
		if b.hp < hp0:
			break
	c.ok(absf(b.hp - (hp0 - 4.0)) < 0.01 and p.vel.y < 0, "a stomp on it takes 4 hp and bounces Clawd")

	# Death: SEGFAULT, the hands go, it sinks in bursts, then the Tool Call drops in the middle of the arena.
	b.mode = &"idle"
	b.timer = 10.0
	p.pos = Vector2(5 * TILE + 8, 15 * TILE)
	await c.frames(2)
	c.ok(b.hit(&"shot", 100.0) and b.mode == &"dead" and b.say_text == "SEGFAULT" and not b.fighting(), "its last hit point: SEGFAULT")
	await c.frames(2)
	c.ok(c.enemies_of("res://scripts/codex_hand.gd").is_empty(), "its hands vanish")
	var shots_left = load("res://scripts/column_beam.gd").create(m.level, 300, b.floor_y)
	for i in 240:
		await c.physics_frame
		if m.boss == null:
			break
	var pick = m.level.get_node_or_null("WeaponPickup")
	c.ok(m.boss == null and m.overlay.popups.any(func(q): return q.text == "CODEX HAS BEEN DEPRECATED"),
		"after 2.8 s it bursts: CODEX HAS BEEN DEPRECATED")
	c.ok(not is_instance_valid(shots_left) or shots_left.dead, "leftover projectiles vanish")
	c.ok(pick != null and pick.weapon == "hook" and absf(pick.feet().x - 20 * TILE) < 0.01 and absf(pick.feet().y - 15 * TILE) < 0.01
		and m.level.get_node_or_null("Goal") == null and snd.track == "map",
		"the Tool Call drops in the middle of the arena (no exit yet) and the map tune plays")
	var weapons0: Array = progress.weapons.duplicate()
	progress.tools.erase("hook")
	p.pos = pick.feet()
	await c.frames(3)
	c.ok(progress.has_tool("hook") and progress.weapons == weapons0 and "weaponGet" in snd.played
		and m.overlay.popups.any(func(q): return q.text == "TOOL CALL ACQUIRED!"),
		"touching it gives Clawd the Tool Call (a tool, saved; his weapons stay)")
	var goal = m.level.get_node_or_null("Goal")
	c.ok(goal != null and absf(goal.feet().x - (26 * TILE + 8)) < 0.01, "and the exit opens 6 tiles right of the middle")
	# A first clear names what it opened.
	progress.levels.erase("2-B")
	m.reach_goal(goal)
	for i in 180:
		await c.physics_frame
		if not m.overlay.results.is_empty():
			break
	var res: Dictionary = m.overlay.results
	c.ok(res.get("title", "") == "WORLD 2 CLEAR" and res.get("note", "") == "TOOL CALL FOUND · WORLD 3 UNLOCKED"
		and String(res.get("note_text", "")).begins_with("Codex has been deprecated."),
		"the results: WORLD 2 CLEAR, TOOL CALL FOUND · WORLD 3 UNLOCKED and the closing line")
	c.ok(progress.progress_for("2-B").completed and progress.is_unlocked(m.level_ids, m.level_ids.find("3-1")),
		"2-B counts as finished and world 3 is open")
	progress.tools.clear()
	progress.save()
	progress.load_file()
	c.ok(progress.has_tool("hook"), "a save from before world 3 with Codex beaten gets the Tool Call when loaded")
	m.load_level("1-1")
	await c.frames(3)
	p.invuln = 0
	return true
