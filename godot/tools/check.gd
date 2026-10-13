# Headless checks for the port. Run from godot/: godot --headless --script tools/check.gd
# Exits non-zero if any check fails. Expected values come from the TS sources (see each check).
# Game scripts are loaded at runtime, not named as types: they use the Game autoload, which a
# --script file cannot see while it is being compiled.
extends SceneTree

const TILE := 16
const PLAYER_SIZE := Vector2(18, 18)
const TILE_CHARS := "#=^X"

var failures := 0
var level_script: GDScript


func ok(cond: bool, what: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + what)
	if not cond:
		failures += 1


func frames(n: int) -> void:
	for i in n:
		await physics_frame


## Waits until a scene change has finished; several physics frames can pass inside one slow
## process frame (level baking), so counting physics frames is not enough.
func scene_ready(name: String) -> void:
	for i in 300:
		await process_frame
		if current_scene and current_scene.name == name and current_scene.is_node_ready():
			break
	await frames(2)


## The per-level sections: one file per level in tools/checks/ (`<id>.gd`, run in name order), so levels ported
## in parallel never edit this file. Each has `const TITLE` and `func run(c) -> bool`, where `c` is this script:
## c.ok(), await c.frames(), c.current_scene, c.enemies_of(), c.bugs(), await c.drive(), ... (see tools/checks/2-1.gd).
func level_sections() -> void:
	var files := Array(DirAccess.get_files_at("res://tools/checks")).filter(func(f: String) -> bool: return f.ends_with(".gd"))
	files.sort()
	for f in files:
		# A file that does not parse loads as a script that cannot be instanced: a failure, not a silent skip.
		var script: GDScript = load("res://tools/checks/" + f)
		if script == null or not script.can_instantiate():
			print("tools/checks/" + f)
			ok(false, "tools/checks/%s loads (a parse error above?)" % f)
			continue
		var level_check = script.new()
		await section(level_check.TITLE, level_check.run.bind(self))


## Runs one section. A section returns true at its end; a script error inside it makes the
## coroutine return early with null, which counts as a failure instead of passing silently.
func section(title: String, f: Callable) -> void:
	print(title)
	if await f.call() != true:
		ok(false, "section ended early (script error above)")


func _init() -> void:
	await process_frame
	level_script = load("res://scripts/level.gd")
	# Progress goes to a file of its own, so the checks never touch the player's; one per process, as worktrees of
	# this project share user:// and may run their checks at the same time.
	var progress = root.get_node("Progress")
	var real_progress: String = progress.path
	progress.path = "user://progress_check_%d.json" % OS.get_process_id()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.path))
	progress.load_file()
	# The same for the settings: sections that press M or rebind keys save them, and parallel runs writing the
	# player's settings.cfg left the game muted.
	var settings = root.get_node("Settings")
	var real_settings: String = settings.path
	settings.path = "user://settings_check_%d.cfg" % OS.get_process_id()
	await section("noise (golden values from src/core/noise.ts)", check_noise)
	await section("levels match levels/<id>.txt", check_levels)
	await section("player physics (tests/player.test.ts)", check_physics)
	await section("title, world map and main scene (src/scenes/title.ts, levelSelect.ts)", check_scenes)
	await section("hazards and enemies in 1-1", check_hazards)
	await section("spin, ground pound and drop-through in 1-1 (src/entities/player.ts)", check_moves)
	await section("checkpoints, exit and signs in 1-1", check_objects)
	await section("moving platforms over the last gap of 1-1 (src/entities/platforms.ts)", check_platforms)
	await section("1-2 Gradient Caves: darkness and the caves motif (drawDarkness() in src/scenes/game.ts)", check_caves)
	await section("1-3 Context Window: the rising void and floating windows (updateVoid() in src/scenes/game.ts)", check_window)
	await section("1-B The Hallucination (src/entities/boss/hallucination.ts, pickups.ts)", check_boss)
	await level_sections()
	await section("aiming with the mouse (computeAim() in src/scenes/game.ts)", check_mouse_aim)
	await section("shooting (src/entities/gun.ts, bullets.ts, src/weapons.ts)", check_gun)
	await section("spam bots, shots and rate limiters (src/entities/enemies.ts, entity.ts)", check_enemies)
	await section("world 2's enemies: turrets, drones, shield bots, injectors (src/entities/enemies2.ts)", check_world2_enemies)
	await section("HUD: hearts and tokens (src/render/hud.ts)", check_hud)
	await section("pause, controls help and keybindings (src/scenes/game.ts, keybinds.ts)", check_menus)
	await section("sound and music (src/core/audio.ts)", check_sound)
	await section("sub-agents in 1-1 (src/entities/collectibles.ts)", check_agents)
	await section("sparks in 1-1 (src/entities/collectibles.ts)", check_sparks)
	await section("shop (src/scenes/shop.ts, src/weapons.ts)", check_shop)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.path))
	progress.path = real_progress
	progress.load_file()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(settings.path))
	settings.path = real_settings
	print("%s: %d failure(s)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures else 0)


func check_noise() -> bool:
	# node -e "import('./src/core/noise.ts').then(n => ...)" at the repo root gave these.
	ok(absf(DotNoise.hash2(5, 7, 0) - 0.9253859769087285) < 1e-12, "hash2(5, 7)")
	ok(absf(DotNoise.hash2(-1239, -4000, 1000007) - 0.4571708240546286) < 1e-12, "hash2 with negatives and big seed")
	ok(absf(DotNoise.value_noise2(1.37, 2.5, 10) - 0.5977193798180356) < 1e-12, "value_noise2")
	ok(absf(DotNoise.periodic_noise1(3.7, 10.67, 11) - 0.36797431311011314) < 1e-12, "periodic_noise1")
	var r: Callable = DotNoise.mulberry32(42)
	ok(absf(r.call() - 0.6011037519201636) < 1e-12 and absf(r.call() - 0.44829055899754167) < 1e-12, "mulberry32(42)")
	return true



func check_levels() -> bool:
	var index: Array = JSON.parse_string(FileAccess.get_file_as_string("res://levels/index.json"))
	ok(index.size() == 9, "9 levels in index.json")
	var spawns: Dictionary = level_script.SPAWNS
	for l in index:
		var rows := FileAccess.get_file_as_string("res://levels/%s.txt" % l.id).replace("\r", "").trim_suffix("\n").split("\n")
		var level: Node3D = load("res://levels/%s.tscn" % l.id).instantiate()
		var terrain: GridMap = level.get_node("Terrain")
		var oneway: GridMap = level.get_node("OneWay")
		var want_tiles := 0
		var want := {}
		var unported := {}
		var bad := 0
		for y in rows.size():
			for x in rows[y].length():
				var ch := rows[y][x]
				if spawns.has(ch):
					want[ch] = want.get(ch, 0) + 1
				elif ch != "." and ch != " " and not TILE_CHARS.contains(ch):
					unported[ch] = unported.get(ch, 0) + 1
				var c := Vector3i(x, -y - 1, 0)
				var item := oneway.get_cell_item(c) if ch == "=" else terrain.get_cell_item(c)
				if TILE_CHARS.contains(ch):
					want_tiles += 1
					bad += int(item != TILE_CHARS.find(ch))
				else:
					bad += int(terrain.get_cell_item(c) != -1 or oneway.get_cell_item(c) != -1)
		var got := {}
		for n in level.get_children():
			if n.has_meta("spawn"):
				got[n.get_meta("spawn")] = got.get(n.get_meta("spawn"), 0) + 1
		var boss: bool = l.has("boss")
		ok(bad == 0 and terrain.get_used_cells().size() + oneway.get_used_cells().size() == want_tiles,
			"%s: %d tiles, 0 misplaced" % [l.id, want_tiles])
		ok(got == want and want.get("@", 0) == 1 and level.has_node("Start") and (boss or want.get("G", 0) == 1),
			"%s: one start, %s, every ported spawn placed %s" % [l.id, "no exit (boss)" if boss else "one exit", want])
		if not unported.is_empty():
			print("       %s: not ported yet: %s" % [l.id, unported])
		level.free()
	return true


## Tiny level from ASCII rows, like makeLevel() in tests/helpers.ts.
func make_level(rows: Array) -> Node3D:
	return level_script.build(PackedStringArray(rows))


## Runs the player on `rows` from '@'. `script` is called once per physics frame with the frame
## number and returns the actions to hold, or null to stop. Input.action_press reaches the player
## one physics frame later, so a fresh press stays held one extra frame, as if the script had
## seen the player react (TS's FakeInput updates the player in the same call).
func simulate(rows: Array, script: Callable, max_frames := 600) -> Node:
	var layer := make_level(rows)
	root.add_child(layer)
	var start := Vector2.ZERO
	for y in rows.size():
		var x: int = rows[y].find("@")
		if x >= 0:
			start = Vector2(x * TILE + TILE / 2.0, (y + 1) * TILE)
	var p = load("res://scenes/player.tscn").instantiate()
	root.add_child(p)
	p.enter_level(layer, start, rows.size() * TILE)
	p.invuln = 0
	var held: Array = []
	var fresh: Array = []
	for i in max_frames:
		var want = script.call(i, p)
		if want == null:
			break
		want = want.duplicate()
		for a in fresh:
			if not a in want:
				want.append(a)
		for a in held:
			if not a in want:
				Input.action_release(a)
		fresh = []
		for a in want:
			if not a in held:
				Input.action_press(a)
				fresh.append(a)
		held = want
		await physics_frame
	for a in held:
		Input.action_release(a)
	p.set_meta("layer", layer)
	return p


func cleanup(p: Node) -> void:
	p.get_meta("layer").free()
	p.free()


func gap_map(gap: int) -> Array:
	var edge := 8
	var ground := "#".repeat(edge + 1) + " ".repeat(gap) + "#".repeat(30)
	var rows := []
	for i in 10: rows.append("")
	rows.append_array(["  @", ground, ground, ground])
	return rows


func step_map(height: int) -> Array:
	var rows := []
	for i in 13: rows.append(" ".repeat(20))
	for i in height:
		rows[12 - i] = " ".repeat(10) + "#".repeat(10)
	rows[12] = "  @" + rows[12].substr(3)
	rows.append("#".repeat(20))
	return rows


func check_physics() -> bool:
	var flat := []
	for i in 7: flat.append(" ".repeat(30))
	flat.append_array(["  @" + " ".repeat(27), "#".repeat(30)])

	# Full jump ~4.5 tiles (4.2..5), hold until the apex then let go so hover stays off.
	var ground := 8.0 * TILE
	var top := [ground]
	var p = await simulate(flat, func(i, pl):
		if i >= 63: return null
		top[0] = minf(top[0], pl.pos.y)
		return ["jump"] if i >= 3 and (i == 3 or pl.vel.y < 0) else [])
	var h: float = ground - top[0]
	ok(h > TILE * 4.2 and h < TILE * 5, "full jump height %.1f tiles (TS: 4.2..5)" % (h / TILE))
	cleanup(p)

	# Unlike TS, a tap is a full jump too (the port has no jump cut); only the apex float differs a little.
	var tap_top := [ground]
	p = await simulate(flat, func(i, pl):
		if i >= 63: return null
		tap_top[0] = minf(tap_top[0], pl.pos.y)
		return ["jump"] if i == 3 else [])
	var tap: float = ground - tap_top[0]
	ok(absf(tap - h) < 3, "a tapped jump is as high as a held one (%.1f vs %.1f px)" % [tap, h])
	cleanup(p)

	ok(await cross_gap(4, false), "clears a 4-tile gap with a running jump")
	ok(not await cross_gap(8, false), "cannot clear an 8-tile gap without hover")
	ok(await cross_gap(9, true), "clears a 9-tile gap with hover")
	ok(await climb(4), "climbs a 4-tile step")
	ok(not await climb(5), "cannot climb a 5-tile wall")
	return true


func cross_gap(gap: int, hover: bool) -> bool:
	var state := {"phase": 0, "landed": false}
	var p = await simulate(gap_map(gap), func(i, pl):
		if i < 3: return []
		if state.phase == 0:
			if pl.pos.x + PLAYER_SIZE.x / 2 > 9 * TILE - 1:
				state.phase = 1
				return ["right", "jump"]
			return ["right"]
		state.phase += 1
		if state.phase > 3 and pl.is_on_floor():
			state.landed = true
			return null
		if pl.pos.y > 20 * TILE or state.phase > 240: return null
		return ["right", "jump"] if pl.vel.y < 0 or hover else ["right"])
	var crossed: bool = state.landed and p.pos.x - PLAYER_SIZE.x / 2 > (9 + gap) * TILE - PLAYER_SIZE.x
	cleanup(p)
	return crossed


func climb(height: int) -> bool:
	var state := {"phase": 0, "up": false}
	var p = await simulate(step_map(height), func(i, pl):
		if i < 3: return []
		if state.phase == 0:
			if pl.pos.x + PLAYER_SIZE.x / 2 > 10 * TILE - 8:
				state.phase = 1
				return ["right", "jump"]
			return ["right"]
		state.phase += 1
		if pl.is_on_floor() and pl.pos.x - PLAYER_SIZE.x / 2 > 10 * TILE:
			state.up = true
			return null
		if state.phase > 120: return null
		return ["right", "jump"] if pl.vel.y < 0 else ["right"])
	var up: bool = state.up
	cleanup(p)
	return up


func check_scenes() -> bool:
	var progress = root.get_node("Progress")
	var snd = root.get_node("Sound")
	var main_script = load("res://scripts/main.gd")
	ok(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/main.tscn", "the main scene is main.tscn")
	main_script.start_mode = main_script.Mode.TITLE
	change_scene_to_file("res://scenes/main.tscn")
	await scene_ready("Main")
	var m = current_scene
	var front = m.front
	ok(m.mode == m.Mode.TITLE and front.state == front.TITLE and front.visible and not m.hud.visible and not m.player.visible,
		"it opens on the title, over the backdrop level with Clawd away")
	ok(snd.track == "title", "the title plays its tune")
	var x0: float = m.camera.top_left.x
	await frames(150)
	ok(m.camera.top_left.x > x0, "the camera drifts through the backdrop")
	var lt: Vector2 = front._logo_top_left()
	var placed := 0
	for i in front._dots.size():
		var d: Dictionary = front._dots[i]
		if front.dot(i)[0] == lt + Vector2(d.tx, d.ty) and front.dot(i)[1] == 1.0:
			placed += 1
	ok(front._dots.size() == 312 and placed == 312, "the logo's dots have flown into place (%d / %d)" % [placed, front._dots.size()])
	ok(front.handle(key(KEY_SPACE)) and m.mode == m.Mode.MAP and snd.track == "map", "Space opens the world map")
	ok(front.sel == 0, "a new game starts on 1-1")
	front.handle(key(KEY_RIGHT))
	ok(front.sel == 0 and "denied" in snd.played, "1-2 is locked until 1-1 is cleared")
	progress.record_run("1-1", [], [true, false], 61.25, 30)
	ok(progress.wallet == 30 and progress.progress_for("1-1").completed and progress.progress_for("1-1").best_time == 61.25,
		"a cleared run is recorded (wallet, best time)")
	front.handle(key(KEY_RIGHT))
	ok(front.sel == 1, "then right moves to 1-2")
	front.handle(key(KEY_ESCAPE))
	ok(m.mode == m.Mode.TITLE, "Escape goes back to the title")
	front.t = 1.0
	front.handle(key(KEY_ENTER))
	ok(m.mode == m.Mode.MAP and front.sel == 1, "the map opens on the first unfinished level")
	front.handle(key(KEY_ENTER))
	await frames(3)
	ok(m.mode == m.Mode.PLAY and m.level_id == "1-2" and m.player.collision_layer == 2 and m.player.can_process()
		and m.hud.visible and not front.visible and m.player.pos.distance_to(_start(m)) < 1, "Enter plays it, with Clawd on '@'")
	m.menu.handle(key(KEY_P))
	for i in 5:
		m.menu.handle(key(KEY_DOWN))
	m.menu.handle(key(KEY_ENTER))
	await frames(3)
	ok(m.mode == m.Mode.MAP and front.sel == 1 and not root.get_node("Game").paused, "QUIT TO MAP goes back to the map on that level")
	front.handle(click(front.node_pos(0)))
	ok(front.sel == 0, "clicking a node selects it")
	front.handle(click(front.node_pos(0)))
	await frames(3)
	ok(m.mode == m.Mode.PLAY and m.level_id == "1-1", "clicking it again plays it")

	# Finishing a level goes back to the map, on the next one.
	m.player.pos = m.level.get_node("Goal").feet()
	await frames(200)
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	await frames(3)
	ok(m.mode == m.Mode.MAP and front.sel == 1, "after the results Space goes to the map on the next level")

	main_script.start_mode = main_script.Mode.PLAY
	main_script.start_level = "1-1"
	change_scene_to_file("res://scenes/main.tscn")
	await scene_ready("Main")
	await frames(60)
	m = current_scene
	ok(m.mode == m.Mode.PLAY and m.player.is_on_floor() and m.player.pos.is_equal_approx(_start(m)), "1-1: player stands on '@'")
	var seen := []
	for i in 9:
		m.next_level()
		await frames(2)
		seen.append(m.level_id)
	ok(seen == ["1-2", "1-3", "1-B", "2-1", "2-2", "2-3", "2-4", "2-B", "1-1"], "next_level cycles all 9 levels")
	return true


func check_hazards() -> bool:
	var m = current_scene
	var p = m.player
	var events := []
	p.event.connect(func(k, _a): events.append(k))

	# Spikes start at column 179 in 1-1.
	m.load_level("1-1")
	await frames(3)
	p.pos = Vector2(175 * TILE, 15 * TILE)
	p.invuln = 0
	var hearts: int = p.hearts
	Input.action_press("right")
	for i in 120:
		await physics_frame
		if p.hearts < hearts: break
	Input.action_release("right")
	ok(p.hearts == hearts - 1 and p.vel.y < 0, "spike costs a heart and knocks up")
	ok(root.get_node("Game").hitstop_left > 0, "hurt triggers hitstop")
	var h2: int = p.hearts
	Input.action_press("right")
	await frames(20)
	Input.action_release("right")
	ok(p.hearts == h2, "no second hit while invulnerable")

	m.load_level("1-1")
	await frames(3)
	var bug = bugs()[0]
	var bug_x: float = bug.pos.x
	p.pos = bug.pos + Vector2(-40, 0)
	p.invuln = 0
	hearts = p.hearts
	for i in 180:
		await physics_frame
		if p.hearts < hearts: break
	ok(bug.pos.x != bug_x and p.hearts == hearts - 1, "bug patrols and hurts on contact")

	m.load_level("1-1")
	await frames(3)
	var n := bugs().size()
	var droppers: int = get_nodes_in_group("enemies").filter(func(e): return e.tokens > 0).size()
	bug = bugs()[0]
	p.pos = bug.pos + Vector2(0, -40)
	p.vel = Vector2.ZERO
	p.invuln = 0
	var bounced := false
	for i in 60:
		await physics_frame
		if bugs().size() < n:
			bounced = p.vel.y < 0
			break
	ok(bounced, "stomping a bug kills it and bounces")
	ok(m.particles.list.size() > 0, "stomp emits particles")
	var popped: Array = m.level.get_children().filter(func(c): return c is Area3D and c.popped)
	ok(popped.size() == 10, "a defeated bug drops 10 tokens (got %d)" % popped.size())
	ok(m.tokens_total == m.level.get_children().filter(func(c): return c is Area3D and not c.popped).size() + droppers * 10,
		"the level's token total counts what the enemies drop (%d of them)" % droppers)
	var had: int = m.tokens
	for i in 180:
		await physics_frame
		if m.tokens == had + 10: break
	ok(m.tokens == had + 10, "the dropped tokens fly to Clawd and are collected (%d of 10)" % (m.tokens - had))
	await frames(60)
	ok(m.hud.shown == m.tokens, "they all land on the HUD counter one after another (%d of %d)" % [m.hud.shown, m.tokens])

	# Walking left off the start: the map's edge is a wall, like the solid columns outside it in TS.
	m.load_level("1-1")
	await frames(3)
	Input.action_press("left")
	await frames(150)
	Input.action_release("left")
	ok(absf(p.pos.x - p.SIZE.x / 2) < 0.5 and absf(p.pos.y - _start(m).y) < 0.05 and p.on_ground,
		"Clawd stops at the left edge of the map instead of falling (%s)" % p.pos)
	ok(m.level.tile(Vector2(-1, 0)) == m.level.SOLID and m.level.tile(Vector2(m.level.width * 16, 100)) == m.level.SOLID,
		"tiles outside the map are solid")
	m.load_level("1-1")
	await frames(3)

	var tokens: Array = m.level.get_children().filter(func(c): return c is Area3D)
	p.pos = Px.of(tokens[0].position) + Vector2(0, 8)
	await frames(5)
	ok(not is_instance_valid(tokens[0]) or tokens[0].is_queued_for_deletion(), "touching a token collects it")

	p.hearts = 1
	p.invuln = 0
	p.hurt(p.pos.x + 10)
	ok(p.hearts == p.MAX_HEARTS and p.pos.is_equal_approx(_start(m)), "losing the last heart respawns on '@'")
	return true


## The bugs of the current level (the group "enemies" also holds spam bots, crushers and shots).
func bugs() -> Array:
	var script := load("res://scripts/bug.gd")
	return get_nodes_in_group("enemies").filter(func(e): return e.get_script() == script)


func _start(m: Node) -> Vector2:
	return Px.of(m.level.get_node("Start").position)


func check_moves() -> bool:
	var m = current_scene
	var p = m.player
	var events := []
	p.event.connect(func(k, _a): events.append(k))

	# Spin next to a bug kills it.
	m.load_level("1-1")
	await frames(3)
	var n := bugs().size()
	var bug = bugs()[0]
	p.pos = bug.pos + Vector2(-20, 0)
	p.vel = Vector2.ZERO
	p.invuln = 5
	await frames(2)
	Input.action_press("spin")
	await frames(2)
	Input.action_release("spin")
	ok(p.state == &"spin" and &"spin" in events, "spin starts the spin state")
	await frames(10)
	ok(bugs().size() == n - 1 and p.hearts == p.MAX_HEARTS, "spin defeats a bug next to Clawd")

	# A spin in the air hops once.
	p.pos = Vector2(10 * TILE, 10 * TILE)
	p.vel = Vector2(0, 100)
	p.air_spin_used = false
	p.spin_cooldown = 0
	p.state = &"normal"
	await frames(1)
	Input.action_press("spin")
	await frames(2)
	Input.action_release("spin")
	ok(p.vel.y < 0, "a spin in the air hops")
	await frames(60)

	# Ground pound onto the corrupted blocks (columns 220..223, row 15) breaks the cluster and falls through.
	var terrain: GridMap = m.level.terrain
	ok(terrain.get_cell_item(Vector3i(221, -16, 0)) == 3, "1-1 has corrupted blocks at 220..223")
	p.pos = Vector2(221.5 * TILE, 12 * TILE)
	p.vel = Vector2.ZERO
	p.state = &"normal"
	await frames(2)
	Input.action_press("down")
	await frames(2)
	Input.action_release("down")
	ok(p.state == &"pound_windup" or p.state == &"pound", "down in the air starts a ground pound")
	var t0 := Time.get_ticks_msec()
	for i in 90:
		await physics_frame
		if p.pos.y > 17 * TILE and p.is_on_floor():
			break
	var cleared := true
	for x in range(220, 224):
		cleared = cleared and terrain.get_cell_item(Vector3i(x, -16, 0)) == -1
	ok(cleared, "the pound breaks the whole corrupted cluster")
	ok(absf(p.pos.y - 18 * TILE) < 0.05 and p.is_on_floor(), "Clawd falls through to the floor below (y %.1f)" % p.pos.y)
	print("    pound sequence took %d ms" % (Time.get_ticks_msec() - t0))

	# Drop through the one-way platform at row 12, columns 23..27: down + jump.
	m.load_level("1-1")
	await frames(3)
	p.pos = Vector2(25.5 * TILE, 11 * TILE)
	p.vel = Vector2.ZERO
	await frames(20)
	ok(p.is_on_floor() and p.on_one_way and absf(p.pos.y - 12 * TILE) < 0.05, "Clawd stands on a one-way platform")
	Input.action_press("down")
	await frames(1)
	Input.action_press("jump")
	await frames(3)
	Input.action_release("jump")
	Input.action_release("down")
	await frames(30)
	ok(p.pos.y > 13 * TILE, "down + jump drops through it (y %.1f)" % p.pos.y)
	return true


func check_objects() -> bool:
	var m = current_scene
	var p = m.player
	m.load_level("1-1")
	await frames(3)
	var cp_script := load("res://scripts/checkpoint.gd")
	var cps: Array = m.level.get_children().filter(func(c): return c.get_script() == cp_script)
	ok(cps.size() == 3, "1-1 has 3 checkpoints ('C' at columns 107, 177, 247)")
	var cp = cps[0]
	ok(not cp.active, "a checkpoint starts inactive")
	p.pos = cp.feet() + Vector2(-30, 0)
	p.hearts = 1
	Input.action_press("right")
	for i in 60:
		await physics_frame
		if cp.active: break
	Input.action_release("right")
	ok(cp.active and p.spawn_point.is_equal_approx(cp.feet()) and p.hearts == p.MAX_HEARTS, "touching it saves the respawn point and refills the hearts")
	ok(m.overlay.popups.any(func(q): return q.text == "STATE SAVED"), "it pops up STATE SAVED")
	# Falling into the 9-tile gap at columns 112..120 respawns on the checkpoint.
	p.pos = Vector2(116 * TILE, 15 * TILE)
	p.vel = Vector2.ZERO
	for i in 120:
		await physics_frame
		if p.pos.is_equal_approx(cp.feet()): break
	ok(p.pos.distance_to(cp.feet()) < 1.0, "falling out respawns on the checkpoint")

	# Signs '?' at columns 8, 68, 104, 212 with the texts of levels/index.json, shown when Clawd is near.
	var signs: Array = m.level.get_children().filter(func(c): return String(c.name).begins_with("Sign"))
	signs.sort_custom(func(a, b): return a.index < b.index)
	ok(signs.size() == 4 and signs.map(func(g): return int(g.feet().x / TILE)) == [8, 68, 104, 212], "1-1 has 4 signs in map order")
	var missing := {}
	for l in JSON.parse_string(FileAccess.get_file_as_string("res://levels/index.json")):
		for t in l.get("signs", []) + [l.name, l.id]:
			for ch in t:
				if ch != "\n" and not PixelFont.GLYPHS.has(ch):
					missing[ch] = true
	ok(missing.is_empty(), "PixelFont has every character of the signs and level names %s" % [missing.keys()])
	ok(signs[1].text.begins_with("BUGS!") and signs[3].text.begins_with("IN THE AIR"), "signs get their texts from index.json")
	p.pos = signs[2].feet() + Vector2(-20, 0)
	await frames(30)
	ok(signs[2].show > 0.9 and signs[3].show < 0.01, "the sign near Clawd shows its bubble, the others don't")
	p.pos = signs[2].feet() + Vector2(-120, 0)
	await frames(30)
	ok(signs[2].show < 0.1, "the bubble hides when Clawd walks away")

	# The exit 'G' at column 303: walking into it completes the level and shows the results.
	m.load_level("1-1")
	await frames(3)
	var goals: Array = m.level.get_children().filter(func(c): return c.name == "Goal")
	ok(goals.size() == 1 and goals[0].feet().is_equal_approx(Vector2(303.5 * TILE, 15 * TILE)), "1-1 has the exit at column 303")
	p.pos = goals[0].feet() + Vector2(-40, 0)
	Input.action_press("right")
	for i in 60:
		await physics_frame
		if m.complete_t >= 0: break
	Input.action_release("right")
	ok(m.complete_t >= 0 and p.frozen, "touching the exit completes the level and stops Clawd")
	await frames(130)
	ok(not m.overlay.results.is_empty() and not p.visual.visible, "the gate draws Clawd in and the results panel shows")
	await frames(70)
	Input.action_press("jump")
	await frames(3)
	Input.action_release("jump")
	await frames(2)
	ok(m.mode == m.Mode.MAP and m.front.sel == 1, "jump on the results panel goes to the map, on the next level")
	m.play("1-2")
	await frames(2)
	ok(m.level_id == "1-2" and not p.frozen and p.visual.visible and p.collision_layer == 2 and p.can_process(), "playing again brings Clawd back")
	return true


## Whether an enemy is defeated or removed (its node may be freed already).
func gone(e) -> bool:
	return not is_instance_valid(e) or e.dead


## The level's enemies whose script is `path`, in map order.
func enemies_of(path: String) -> Array:
	var script := load(path)
	return get_nodes_in_group("enemies").filter(func(e): return e.get_script() == script)


func check_enemies() -> bool:
	var m = current_scene
	var p = m.player
	var snd = root.get_node("Sound")
	var shot_script := load("res://scripts/shot.gd")

	# The spam bot in 1-1 hovers around its post and fires at Clawd within 210 px.
	m.load_level("1-1")
	await frames(3)
	var bots := enemies_of("res://scripts/spam_bot.gd")
	ok(bots.size() == 1, "1-1 has one spam bot 'F'")
	var bot = bots[0]
	ok(bot.hp == 3 and bot.tokens == 10 and bot.stompable, "it has 3 hp (TS 1 × HP_FACTOR), drops 10 tokens and can be stomped")
	var at: Vector2 = bot.pos
	await frames(30)
	ok(bot.pos.distance_to(at) > 1 and absf(bot.pos.x - bot.home.x) <= 26 and absf(bot.pos.y - bot.home.y) <= 6,
		"it hovers around its post (26 x 6 px)")
	p.pos = bot.home + Vector2(-150, 0)
	p.vel = Vector2.ZERO
	p.invuln = 10
	bot.fire_timer = 0.05
	snd.played.clear()
	var shot = null
	for i in 10:
		await physics_frame
		var shots := get_nodes_in_group("enemies").filter(func(e): return e.get_script() == shot_script)
		if not shots.is_empty():
			shot = shots[0]
			break
	ok(shot != null and "shoot" in snd.played, "it fires a shot and plays shoot")
	if shot:
		var aim: Vector2 = p.pos + Vector2(0, -9) - (bot.pos + Vector2(0, -7))
		ok(absf(shot.vel.length() - 85) < 0.01 and shot.vel.normalized().dot(aim.normalized()) > 0.95,
			"the shot flies at Clawd at 85 px/s")
		ok(shot.projectile and not shot.stompable and shot.tokens == 0, "a shot is a projectile without tokens")
	bot.fire_timer = 100
	p.pos = bot.home + Vector2(-260, 0)
	bot.fire_timer = 0.0
	await frames(5)
	ok(bot.fire_timer <= 0, "it holds fire while Clawd is out of range")
	bot.fire_timer = 100

	# A shot hurts Clawd and vanishes; a spin destroys it; a wall stops it.
	m.load_level("1-1")
	await frames(3)
	for b in enemies_of("res://scripts/spam_bot.gd"):
		b.fire_timer = 100
	var start := _start(m)
	p.pos = start
	p.vel = Vector2.ZERO
	p.invuln = 0
	await frames(2)
	var hearts: int = p.hearts
	shot = shot_script.fire(m.level, p.pos + Vector2(-30, -9), Vector2(85, 0))
	for i in 60:
		await physics_frame
		if p.hearts < hearts: break
	ok(p.hearts == hearts - 1 and gone(shot), "a shot hurts Clawd and vanishes")
	await frames(90)
	p.invuln = 0
	p.pos = start
	p.vel = Vector2.ZERO
	await frames(2)
	hearts = p.hearts
	Input.action_press("spin")
	await frames(2)
	Input.action_release("spin")
	shot = shot_script.fire(m.level, p.pos + Vector2(-26, -9), Vector2(85, 0))
	for i in 20:
		await physics_frame
		if gone(shot): break
	ok(gone(shot) and p.hearts == hearts, "a spin destroys a shot without a hit")
	var wall_shot = shot_script.fire(m.level, start + Vector2(0, -4), Vector2(0, 200))
	await frames(10)
	ok(gone(wall_shot), "a shot dies on a solid tile")

	# Stomping the spam bot defeats it.
	m.load_level("1-1")
	await frames(3)
	bot = enemies_of("res://scripts/spam_bot.gd")[0]
	bot.fire_timer = 100
	p.invuln = 5
	var bounced := false
	for i in 90:
		p.pos = Vector2(bot.pos.x, p.pos.y) if i > 0 else bot.pos + Vector2(0, -30)
		if i == 0:
			p.vel = Vector2.ZERO
		await physics_frame
		if gone(bot):
			bounced = p.vel.y < 0
			break
	ok(bounced, "stomping a spam bot defeats it and bounces")
	var popped: Array = m.level.get_children().filter(func(c): return c is Area3D and c.popped)
	ok(popped.size() == 10, "it drops 10 tokens (got %d)" % popped.size())

	# The rate limiters of 1-2: the first hangs at tiles (36, 12) above a floor at row 18.
	m.load_level("1-2")
	await frames(3)
	var rls := enemies_of("res://scripts/rate_limiter.gd")
	ok(rls.size() == 4, "1-2 has 4 rate limiters 'R'")
	var rl = rls[0]
	ok(rl.x == 36 * TILE and rl.y == 12 * TILE and rl.is_in_group("platforms"), "a rate limiter hangs from its cell's top-left, 2 x 2 tiles")
	ok(rl.invincible and rl.tokens == 0 and not rl.stompable, "it cannot be hurt and drops nothing")
	p.pos = Vector2(rl.x + 32 + 24, 18 * TILE)
	p.vel = Vector2.ZERO
	await frames(30)
	ok(rl.mode == &"idle", "it waits while Clawd is beside it")
	p.pos = Vector2(rl.pos.x, 18 * TILE)
	p.vel = Vector2.ZERO
	p.invuln = 0
	hearts = p.hearts
	snd.played.clear()
	var modes := []
	for i in 120:
		await physics_frame
		if modes.is_empty() or modes.back() != rl.mode:
			modes.append(rl.mode)
		if rl.mode == &"rest": break
	ok(modes == [&"shake", &"fall", &"rest"] or modes == [&"idle", &"shake", &"fall", &"rest"], "under it, it shakes, drops and rests (%s)" % [modes])
	ok(rl.y == 18 * TILE - 32 and "crush" in snd.played, "it lands on the floor and plays crush")
	ok(p.hearts == hearts - 1, "it hurts Clawd beneath it")
	# Standing on it while it rests, Clawd rides it up without getting hurt.
	p.invuln = 0
	p.pos = Vector2(rl.pos.x, rl.y - 2)
	p.vel = Vector2.ZERO
	hearts = p.hearts
	await frames(20)
	ok(p.riding == rl and p.on_ground, "Clawd can stand on its top")
	for i in 120:
		await physics_frame
		if rl.mode == &"rise" and rl.y < 18 * TILE - 32 - 20: break
	ok(rl.mode == &"rise" and p.riding == rl and absf(p.pos.y - rl.y) < 0.01 and p.hearts == hearts,
		"it rises and carries Clawd up, its top does not hurt")
	p.pos = Vector2(rl.x - 60, 18 * TILE)
	p.vel = Vector2.ZERO
	for i in 120:
		await physics_frame
		if rl.mode == &"idle": break
	ok(rl.mode == &"idle" and rl.y == 12 * TILE, "and goes back up to where it hangs")
	ok(not rl.hit(&"spin", 3) and not rl.dead, "a spin does not hurt it")
	return true


## Holds Clawd at `feet` (level pixels), out of harm's way, for `n` physics frames, calling `each` after every
## frame with the frame number; stops early when it returns true.
func hold(p, feet: Vector2, n: int, each := Callable()) -> void:
	p.invuln = 100
	for i in n:
		p.pos = feet
		p.vel = Vector2.ZERO
		await physics_frame
		if each.is_valid() and each.call(i) == true:
			break


func check_world2_enemies() -> bool:
	var m = current_scene
	var p = m.player
	var snd = root.get_node("Sound")
	var shot_script := load("res://scripts/shot.gd")
	var bug_script := load("res://scripts/bug.gd")

	# World 2's bugs and spam bots are tougher; world 1's are not.
	m.load_level("2-1")
	await frames(3)
	var tough := true
	for b in enemies_of("res://scripts/bug.gd"):
		tough = tough and b.hp == 6
	for b in enemies_of("res://scripts/spam_bot.gd"):
		tough = tough and b.hp == 9
	ok(tough and not enemies_of("res://scripts/bug.gd").is_empty(), "2-1's bugs have 2 hp and its spam bots 3, times HP_FACTOR (6, 9)")
	var turrets := enemies_of("res://scripts/turret.gd")
	var drones := enemies_of("res://scripts/drone.gd")
	var bots := enemies_of("res://scripts/shield_bot.gd")
	ok(turrets.size() == 2 and drones.size() == 4 and bots.size() == 2, "2-1 has 2 turrets 'T', 4 drones 'D' and 2 shield bots 'H'")

	# A floor turret: 6 hp, 20 tokens, stompable, turns at 3 rad/s within the upper half-plane.
	var tu = turrets[0]
	ok(tu.hp == 18 and tu.tokens == 20 and tu.stompable and not tu.ceiling, "a turret has 6 hp × 3, drops 20 tokens and can be stomped")
	ok(tu.pivot() == tu.pos + Vector2(0, -5) and tu.rect().size == Vector2(16, 12), "it is 16 x 12 with its sensor 5 px above its feet")
	tu.timer = 100
	var a0: float = tu.angle
	await hold(p, tu.pivot() + Vector2(-60, -40 + 9), 1)
	ok(absf(tu.angle - a0) <= 3.0 / 60 + 0.001 and tu.angle < a0, "its barrel turns towards Clawd at 3 rad/s")
	await hold(p, tu.pivot() + Vector2(-60, -40 + 9), 40)
	ok(absf(tu.angle - atan2(-40, -60)) < 0.02, "and points at him (%.2f)" % tu.angle)
	await hold(p, tu.pivot() + Vector2(60, 40 + 9), 60)
	ok(absf(tu.angle - (-0.1)) < 0.02, "a floor turret never aims below the horizon (%.2f)" % tu.angle)
	# A burst: three shots 0.14 s apart at 135 px/s, then 2.4 s to reload.
	var seen := {}
	snd.played.clear()
	tu.timer = 0.01
	await hold(p, tu.pivot() + Vector2(-60, -40 + 9), 30, func(_i):
		for s in get_nodes_in_group("enemies"):
			if s.get_script() == shot_script and not seen.has(s):
				seen[s] = s.vel.length()
		return false)
	var speeds := seen.values()
	ok(seen.size() == 3 and speeds.all(func(v): return absf(v - 135) < 0.01) and "shoot" in snd.played,
		"it fires a burst of 3 shots at 135 px/s (%d)" % seen.size())
	ok(tu.timer > 1.8 and tu.timer < 2.4, "and reloads for 2.4 s")
	seen.clear()
	tu.timer = 0.01
	await hold(p, tu.pivot() + Vector2(-260, 0), 20)
	ok(tu.burst == 0 and tu.timer < 0, "it holds fire while Clawd is beyond 250 px")
	tu.timer = 100

	# A drone bobs at its post until Clawd comes within 230 px, circles, aims and dives at 270 px/s.
	var dr = drones[0]
	ok(dr.hp == 9 and dr.tokens == 15 and dr.stompable and dr.rect().size == Vector2(14, 10), "a drone has 3 hp × 3 and drops 15 tokens")
	var far: Vector2 = dr.pos + Vector2(-400, -200)
	# Lambdas capture locals by value: they write into `got`.
	var got := {"bob": 0.0}
	await hold(p, far, 60, func(_i):
		got.bob = maxf(got.bob, absf(dr.pos.y - dr.home_y))
		return false)
	ok(dr.mode == &"idle" and got.bob > 0.5 and got.bob < 4.5, "it bobs at its post while Clawd is far (%.1f px)" % got.bob)
	var near: Vector2 = dr.pos + Vector2(100, 70)
	await hold(p, near, 2)
	ok(dr.mode == &"orbit", "it starts circling when he comes near")
	var side: float = dr.side
	# Clawd hangs in the air here: a dive into him could end in a stomp.
	dr.hp = 1000
	dr.timer = 0.0
	var modes := []
	await hold(p, near, 150, func(_i):
		if modes.is_empty() or modes.back() != dr.mode:
			modes.append(dr.mode)
			if dr.mode == &"dive":
				got.dive = dr.vel
		return dr.mode == &"orbit" and modes.size() > 3)
	ok(modes.slice(0, 4) == [&"aim", &"dive", &"recover", &"orbit"], "then aims, dives, recovers and circles again (%s)" % [modes])
	ok(absf(got.get("dive", Vector2.ZERO).length() - 270) < 0.5, "it dives at 270 px/s (%s)" % got.get("dive"))
	ok(dr.side == -side, "on the other side")
	# A dive into the floor ends the dive and bounces it up.
	var start := _start(m)
	dr.pos = start + Vector2(0, -20)
	dr.mode = &"dive"
	dr.timer = 0.5
	dr.vel = Vector2(0, 270)
	await hold(p, far, 10, func(_i): return dr.mode != &"dive")
	ok(dr.mode == &"recover" and dr.vel.y < 0 and dr.pos.y == start.y, "a dive into the floor stops flush and bounces it")

	# A shield bot: 9 hp, 30 tokens; its shield stops shots from the front, not from behind or above.
	var sb = bots[0]
	ok(sb.hp == 27 and sb.tokens == 30 and sb.stompable and sb.facing == -1, "a shield bot has 9 hp × 3, drops 30 tokens and faces left")
	ok(sb.blocks_direction(Vector2(1, 0)) and sb.shield_flash > 0, "its shield stops a shot coming at its front (and flashes)")
	ok(not sb.blocks_direction(Vector2(-1, 0)) and not sb.blocks_direction(Vector2(0.3, 1)), "but not one from behind or from above")
	var level_y: float = sb.pos.y
	var x0: float = sb.pos.x
	sb.fire_timer = 100
	await hold(p, Vector2(x0 + 100, level_y), 30)
	ok(sb.facing == -1 and sb.pos.x == x0 and sb.turn_timer > 0, "it is slow to turn round, and stands still meanwhile")
	await hold(p, Vector2(x0 + 100, level_y), 20)
	ok(sb.facing == 1, "after 0.7 s it faces Clawd")
	x0 = sb.pos.x
	var ahead: bool = sb.floor_at(Vector2(x0 + 10, level_y + 2))
	await hold(p, Vector2(x0 + 100, level_y), 30)
	ok(sb.pos.x - x0 > 14 if ahead else sb.pos.x == x0, "it walks towards him at 30 px/s (%.1f px)" % (sb.pos.x - x0))
	seen.clear()
	snd.played.clear()
	sb.fire_timer = 0.01
	await hold(p, Vector2(sb.pos.x + 100, level_y), 5, func(_i):
		for s in get_nodes_in_group("enemies"):
			if s.get_script() == shot_script and not seen.has(s):
				seen[s] = s.vel
		return false)
	ok(seen.size() == 1 and seen.values()[0] == Vector2(125, 0) and "shoot" in snd.played, "it fires a shot straight ahead at 125 px/s")
	for s in seen:
		if not gone(s):
			s.remove()
	# Bullets ricochet off the front and hit from behind.
	var bullet_script := load("res://scripts/bullet.gd")
	var blaster: Dictionary = load("res://scripts/weapons.gd").get_def("blaster")
	sb.fire_timer = 100
	snd.played.clear()
	var hp0: float = sb.hp
	var bl = bullet_script.fire(m.level, sb.pos + Vector2(24, -10), PI, 380, blaster, 2.0)
	await hold(p, Vector2(sb.pos.x + 100, level_y), 6)
	ok(sb.hp == hp0 and "deflect" in snd.played and (gone(bl) or bl.vel.x > 0), "a bullet at its shield ricochets without a hit")
	bl = bullet_script.fire(m.level, sb.pos + Vector2(-24, -10), 0.0, 380, blaster, 2.0)
	await hold(p, Vector2(sb.pos.x + 100, level_y), 6)
	ok(sb.hp == hp0 - 2, "a bullet in its back hits (hp %s)" % sb.hp)

	# A ceiling turret in 2-2 hangs under a solid tile and aims into the lower half-plane.
	m.load_level("2-2")
	await frames(3)
	var cts: Array = enemies_of("res://scripts/turret.gd").filter(func(e): return e.ceiling)
	ok(cts.size() == 5, "2-2 has 5 ceiling turrets 'Y'")
	var ct = cts[0]
	ok(not ct.stompable and ct.pivot() == ct.pos + Vector2(0, -7), "a ceiling turret cannot be stomped; its sensor is 5 px below its top")
	ok(m.level.tile(ct.rect().position + Vector2(8, -1)) == 0 and m.level.tile(ct.rect().position + Vector2(8, 1)) != 0,
		"it hangs right under a solid tile")
	ct.timer = 100
	await hold(p, ct.pivot() + Vector2(60, 80 + 9), 40)
	ok(absf(ct.angle - atan2(80, 60)) < 0.02, "it aims down at Clawd (%.2f)" % ct.angle)
	await hold(p, ct.pivot() + Vector2(60, -80 + 9), 60)
	ok(absf(ct.angle - 0.1) < 0.02, "never above the horizon (%.2f)" % ct.angle)

	# An injector hops at Clawd, and splits into two bugs when destroyed.
	m.load_level("2-3")
	await frames(3)
	var injs := enemies_of("res://scripts/injector.gd")
	ok(injs.size() == 8, "2-3 has 8 injectors 'I'")
	# The one nearest the start stands on wide flat ground (others hop off pillars into pits).
	var start3 := _start(m)
	var inj = injs[0]
	for e in injs:
		if e.pos.distance_to(start3) < inj.pos.distance_to(start3):
			inj = e
	ok(inj.hp == 15 and inj.tokens == 15 and inj.token_total() == 35, "an injector has 5 hp × 3, drops 15 tokens and leaves 20 in bugs")
	inj.hp = 1000
	await hold(p, inj.pos + Vector2(100, 0), 30, func(_i): return inj.grounded)
	inj.timer = 0.01
	var tx: float = inj.pos.x + 100
	await hold(p, Vector2(tx, inj.pos.y), 10, func(_i):
		if inj.vel.y < 0:
			got.hop = inj.vel
			return true
		return false)
	ok(got.get("hop") == Vector2(110, -330), "it hops at Clawd: 330 px/s up, at most 110 across (%s)" % got.get("hop"))
	await hold(p, Vector2(tx, inj.pos.y), 90, func(_i): return inj.grounded)
	ok(inj.grounded and inj.vel == Vector2.ZERO, "and lands")
	var bugs_before := enemies_of("res://scripts/bug.gd").size()
	var tokens_before: int = m.level.get_children().filter(func(c): return c is Area3D and c.popped).size()
	var at: Vector2 = inj.pos
	inj.hp = 5
	inj.hit(&"shot", 99)
	await frames(2)
	var new_bugs := enemies_of("res://scripts/bug.gd").filter(func(b): return b.hp == 3)
	var popped: int = m.level.get_children().filter(func(c): return c is Area3D and c.popped).size() - tokens_before
	ok(gone(inj) and enemies_of("res://scripts/bug.gd").size() == bugs_before + 2 and new_bugs.size() == 2,
		"destroyed, it splits into two bugs of 1 hp × 3")
	ok(new_bugs.all(func(b): return b.speed == 40 and absf(b.pos.x - at.x) < 10) and new_bugs[0].dir != new_bugs[1].dir,
		"that run off left and right at 40 px/s")
	ok(popped == 15, "and drops 15 tokens (got %d)" % popped)

	m.load_level("1-1")
	await frames(3)
	ok(bugs().all(func(b): return b.hp == 3), "world 1's bugs keep 1 hp (× 3)")
	return true


## Drives the real player with the actions `f` returns each physics frame (null stops), like simulate() but in
## Main's level. Returns when `f` stops or after `max_frames`.
func drive(f: Callable, max_frames := 600) -> void:
	var held: Array = []
	for i in max_frames:
		var want = f.call(i)
		if want == null:
			break
		for a in held:
			if not a in want:
				Input.action_release(a)
		for a in want:
			if not a in held:
				Input.action_press(a)
		held = want
		await physics_frame
	for a in held:
		Input.action_release(a)


func check_caves() -> bool:
	var m = current_scene
	var p = m.player
	m.load_level("1-2")
	await frames(3)
	ok(m.info.get("dark", false) == true and m.info.theme == "caves", "1-2 is dark and uses the caves theme")
	ok(is_equal_approx(m.dark_amount, 0.93), "the darkness is as deep as the TS gradient's edge (0.93)")
	ok(m.haze.material.get_shader_parameter("dim") < 1.0 and m.parallax.modulate.r < 1.0, "the sky and the ridges dim")
	ok(m.motif.visible and m.motif.material.shader.resource_path.ends_with("motif_caves.gdshader"),
		"the caves motif (contour lines and rolling balls) is behind the level")
	p.pos = _start(m) + Vector2(40, 0)
	await frames(2)
	m._update_lamp()
	var lamp: Vector4 = m.dark_lamp
	var want: Vector3 = p.global_position + Vector3(0, 9.0 / 16, 1.0)
	ok(Vector3(lamp.x, lamp.y, lamp.z).distance_to(want) < 0.01, "Clawd's lamp follows him, 1 m in front of him")
	ok(lamp.w * 16 >= 102 - 0.01 and lamp.w * 16 <= 108 + 0.01, "its radius is 105 +- 3 px (%.1f)" % (lamp.w * 16))
	var radii := []
	for i in 40:
		await physics_frame
		radii.append(m.dark_lamp.w)
	ok(radii.max() - radii.min() > 0.01, "and breathes")
	m.load_level("1-1")
	await frames(3)
	ok(m.dark_amount == 0.0 and not m.motif.visible and m.haze.material.get_shader_parameter("dim") == 1.0
		and m.parallax.modulate == Color.WHITE, "1-1 is lit and has no caves motif")
	return true


func check_window() -> bool:
	var m = current_scene
	var p = m.player
	var game = root.get_node("Game")
	var events := []
	p.event.connect(func(k, _a): events.append(k))
	m.load_level("1-3")
	await frames(3)
	var v = m.rising_void
	ok(v != null and v.speed == 22 and is_equal_approx(v.delay, 4.0 - 3.0 / 60) or v.delay <= 4.0,
		"1-3 has a rising void (22 px/s after 4 s)")
	ok(absf(v.y - (m.level.pixel_size.y + 40)) < 0.01, "it starts 40 px below the level")
	ok(m.motif_3d != null and m.motif_3d.get_script() == load("res://scripts/window_motif.gd") and m.motif_3d._windows.size() > 6,
		"floating windows drift behind the level (%d)" % m.motif_3d._windows.size())
	var start: Vector2 = _start(m)
	var hold := func() -> void:
		p.pos = start
		p.vel = Vector2.ZERO
	var y0: float = v.y
	for i in 120:
		await physics_frame
		hold.call()
	ok(v.y == y0 and v.delay > 0, "it waits out its delay")
	v.delay = 0.0
	y0 = v.y
	for i in 60:
		await physics_frame
		hold.call()
	ok(absf((y0 - v.y) - 22.0) < 1.0, "then rises 22 px a second (%.1f)" % (y0 - v.y))
	# Never more than 14 tiles below Clawd.
	y0 = v.y
	p.pos = start + Vector2(0, -400)
	await physics_frame
	ok(v.y <= p.pos.y + 16 * 14 and v.y < y0 - 100, "it never falls more than 14 tiles behind Clawd (%.1f below him)" % (v.y - p.pos.y))
	hold.call()
	game.paused = true
	y0 = v.y
	await frames(30)
	ok(v.y == y0, "a paused world holds it")
	game.paused = false
	# Caught: a heart less, back to the checkpoint, the void 10 tiles below it with a 2 s grace.
	var hearts: int = p.hearts
	events.clear()
	v.y = start.y - 5.0
	await frames(2)
	ok(p.hearts == hearts - 1 and &"fell" in events, "sinking 4 px into it costs a heart and drops Clawd out")
	ok(p.pos.distance_to(p.spawn_point) < 2.0, "he is back at the checkpoint")
	ok(absf(v.y - (p.spawn_point.y + 160)) < 1.0 and v.delay > 1.9, "and the void is 10 tiles below it, 2 s behind")
	var font = load("res://scripts/pixel_font.gd")
	ok(font.GLYPHS.has("▲"), "the font has the ▲ of NULL ▲ RISING")
	m.load_level("1-1")
	await frames(3)
	ok(m.rising_void == null and m.motif_3d == null, "1-1 has neither")
	return true


func check_boss() -> bool:
	var m = current_scene
	var p = m.player
	var snd = root.get_node("Sound")
	var progress = root.get_node("Progress")
	var shot_script := load("res://scripts/shot.gd")
	var shots := func() -> Array:
		return get_nodes_in_group("enemies").filter(func(e): return e.get_script() == shot_script)
	m.load_level("1-B")
	await frames(3)
	var b = m.boss
	ok(b != null and b.get_script() == load("res://scripts/hallucination.gd"), "1-B spawns the Hallucination at its 'B'")
	ok(absf(b.floor_y - 15 * TILE) < 0.01 and absf(b.arena_w - 34 * TILE) < 0.01 and absf(b.cx - (17 * TILE + 8)) < 0.01,
		"over the arena's floor (row 15), as wide as the level")
	ok(m.scenery._materials[0].get_shader_parameter("glitch") == true, "the forest glitches (the boss motif)")
	ok(b.mode == &"intro" and b.invincible and not b.hurtbox().has_area(), "it fades in, untouchable")
	p.invuln = 1000
	for i in 200:
		await physics_frame
		if not shots.call().is_empty(): break
	ok(shots.call().size() >= 8 and shots.call()[0].color == Color("#E6E6E6"), "then fires a radial burst of white shots (%d)" % shots.call().size())
	for i in 400:
		await physics_frame
		if b.mode == &"vulnerable": break
	ok(b.mode == &"vulnerable" and b.stompable and not b.invincible and absf(b.cy - (b.floor_y - 18)) < 3,
		"after its attack it sinks to the floor, dazed")
	ok(not b.hurtbox().has_area(), "and does not hurt while dazed")
	# A stomp takes one hit point.
	snd.played.clear()
	p.pos = Vector2(b.cx, b.cy - 17 - 24)
	p.vel = Vector2.ZERO
	for i in 60:
		await physics_frame
		if b.hp < 3: break
	ok(b.hp == 2 and b.mode == &"hurt" and "bossHit" in snd.played and p.vel.y < 0, "a stomp while it is dazed hits it and bounces Clawd")
	ok(not b.hit(&"spin", 3) and b.hp == 2, "a hit while it is not dazed does nothing")
	for i in 120:
		await physics_frame
		if b.mode == &"appear": break
	ok(b.mode == &"appear" and "bossTeleport" in snd.played, "then it vanishes and teleports")
	# The rain: warnings on the floor, then red shots from the top of the view.
	for e in shots.call(): e.remove()
	b.attack_index = 1
	b.volley = 0
	b._next(&"attack", 0.0)
	await frames(2)
	ok(b.warnings.size() >= 8, "the rain marks the floor first (%d warnings)" % b.warnings.size())
	for i in 70:
		await physics_frame
		if not shots.call().is_empty(): break
	var rain: Array = shots.call()
	ok(rain.size() >= 8 and rain[0].vel.y > 150 and rain[0].color == Color("#E0605A"), "then red shots rain down onto them")
	# Fake platforms dissolve under Clawd.
	for e in shots.call(): e.remove()
	b.attack_index = 2
	b.volley = 0
	b._next(&"attack", 0.0)
	await frames(2)
	var fakes: Array = get_nodes_in_group("platforms").filter(func(n): return n.get_script() == load("res://scripts/fake_platform.gd"))
	ok(fakes.size() == 3 and shots.call().size() == 10, "it conjures 3 fake platforms and a ring of 10 cyan shots")
	# The TS spots sit just under the arena's one-way platforms; try one in the open (columns 11-14, row 12).
	var fp = load("res://scripts/fake_platform.gd").create(m.level, Vector2(176, 200), 64)
	p.pos = Vector2(fp.x + 32, fp.y - 20)
	p.vel = Vector2.ZERO
	for i in 40:
		await physics_frame
		if p.riding == fp: break
	ok(p.riding == fp, "Clawd can land on a fake platform")
	await frames(35)
	ok(not is_instance_valid(fp) or fp.is_queued_for_deletion(), "and it dissolves 0.45 s after he stands on it")
	# The last hit: it dies, the blaster drops, the exit opens when Clawd takes it.
	b.hp = 1
	b.mode = &"vulnerable"
	b.timer = 2.0
	b.invincible = false
	ok(b.hit(&"spin", 3) and b.mode == &"dead", "its last hit point starts its death")
	for i in 200:
		await physics_frame
		if m.boss == null: break
	var pick = m.level.get_node_or_null("WeaponPickup")
	ok(m.boss == null and pick != null and shots.call().is_empty(), "it bursts, drops the Token Blaster and its shots vanish")
	ok(pick != null and absf(pick.feet().x - 17 * TILE) < 0.01 and absf(pick.feet().y - 15 * TILE) < 0.01, "the blaster lies in the middle of the arena")
	snd.played.clear()
	p.pos = pick.feet()
	await frames(3)
	ok(progress.weapons == ["blaster"] and progress.equipped == "blaster" and "weaponGet" in snd.played,
		"touching it gives Clawd the Token Blaster (saved)")
	var goal = m.level.get_node_or_null("Goal")
	ok(goal != null and absf(goal.feet().x - (23 * TILE + 8)) < 0.01, "and the exit opens 6 tiles right of the middle")
	m.reach_goal(goal)
	for i in 180:
		await physics_frame
		if not m.overlay.results.is_empty(): break
	ok(m.overlay.results.get("title", "") == "WORLD 1 CLEAR", "the results say WORLD 1 CLEAR")
	ok(String(m.overlay.results.get("note", "")).begins_with("TOKEN BLASTER FOUND"), "and that the blaster was found")
	ok(progress.is_unlocked(m.level_ids, m.level_ids.find("2-1")), "world 2 is unlocked")
	m.load_level("1-1")
	await frames(3)
	ok(m.boss == null and m.scenery._materials[0].get_shader_parameter("glitch") == false, "1-1 has no boss and a calm forest")
	p.invuln = 0
	return true


func check_mouse_aim() -> bool:
	var m = current_scene
	var p = m.player
	var progress = root.get_node("Progress")
	if progress.weapons.is_empty():
		progress.grant_weapon("blaster")
	m.load_level("2-1")
	await frames(3)
	var g = m.gun
	ok(g.armed and p.armed, "world 2 is armed")
	# The gun lives in the SubViewport, whose container ignores the mouse: it must still see the mouse move.
	for target in [Vector2(100, 40), Vector2(400, 200)]:
		var e := InputEventMouseMotion.new()
		e.position = target
		e.global_position = target
		Input.parse_input_event(e)
		# Mouse motion is accumulated until the next event; let it through now.
		Input.flush_buffered_events()
		await frames(3)
		var want: Vector2 = m.camera.top_left + target - g.pivot()
		ok(g.mouse_view == target and g.mouse_aiming() and absf(angle_difference(p.aim, want.angle())) < 0.05,
			"moving the mouse to %s aims there (%.1f deg, want %.1f, mouse %s)" % [target, rad_to_deg(p.aim), rad_to_deg(want.angle()), g.mouse_view])
	ok(m.overlay.to_view(g.mouse_world()) == g.mouse_view + Vector2.ONE * m.PAD, "the mouse's level point is where the window shows it")
	g.mouse_moved = -1000000
	await frames(2)
	ok(not g.mouse_aiming() and absf(p.aim) < 0.01 or absf(absf(p.aim) - PI) < 0.01, "without the mouse Clawd aims ahead with the keys")
	m.load_level("1-1")
	await frames(3)
	ok(not g.armed and not p.armed, "world 1 is not armed")
	return true


## A bug that stands still at `at` (its middle) with `hp` hit points, a target for the gun.
func target(m, at: Vector2, hp: float):
	var bug = load(level_script.BUG).instantiate()
	m.level.add_child(bug)
	bug.set_physics_process(false)
	bug.pos = at + Vector2(0, bug.size.y / 2)
	bug.hp = hp
	return bug


func check_gun() -> bool:
	var m = current_scene
	var p = m.player
	var progress = root.get_node("Progress")
	var snd = root.get_node("Sound")
	var weapons = load("res://scripts/weapons.gd")
	var bullet_script = load("res://scripts/bullet.gd")
	var shot_script = load("res://scripts/shot.gd")
	progress.weapons = ["blaster", "spreader", "stream", "beam", "cannon"]
	progress.equipped = "blaster"
	for u in ["damage", "rate", "context"]:
		progress.upgrades.erase(u)
	m.load_level("2-1")
	await frames(3)
	var g = m.gun
	g.mouse_moved = -1000000
	p.invuln = 1000
	ok(g.weapon.id == "blaster" and g._hand.visible, "Clawd holds his equipped weapon, the Token Blaster")

	# Fire rate and damage: 6 shots a second of 2 damage; Bigger Model and Faster Inference add 25 % and 15 %.
	var count_shots := func(seconds: float) -> int:
		var n := 0
		for i in roundi(seconds * 60):
			if g.fire(1.0 / 60, true):
				n += 1
		return n
	for b in get_nodes_in_group("bullets"):
		b._remove()
	g.cooldown = 0.0
	g.heat = 0.0
	var n: int = count_shots.call(2.0)
	var bullets := get_nodes_in_group("bullets")
	# A cooldown of 1/6 s counted down in 1/60 s steps runs out on the 11th frame, as in TS: 11 shots in 2 s.
	ok(n == 11 and bullets.size() == 11 and bullets.all(func(b): return b.damage == 2.0 and b.kind == "token"),
		"the blaster fires 6 tokens a second (every 11th frame), 2 damage each (%d shots)" % n)
	for b in bullets:
		b._remove()
	progress.upgrades["damage"] = 1
	progress.upgrades["rate"] = 1
	g.cooldown = 0.0
	g.heat = 0.0
	n = count_shots.call(2.0)
	bullets = get_nodes_in_group("bullets")
	ok(n == 14 and bullets.all(func(b): return b.damage == 2.5), "Bigger Model and Faster Inference: 2.5 damage, 14 shots in 2 s (%d)" % n)
	for b in bullets:
		b._remove()
	progress.upgrades.erase("damage")
	progress.upgrades.erase("rate")

	# Context heat: the stream fills the 100 context in under 3 s and overflows; no shots for 1.3 s, then cool.
	g.set_weapon("stream")
	g.cooldown = 0.0
	g.heat = 0.0
	snd.played.clear()
	var t := 0.0
	while g.overheated <= 0 and t < 10:
		g.fire(1.0 / 60, true)
		t += 1.0 / 60
	# 4.5 context a shot every 5th frame, less 32 a second: full after 4.4 s.
	ok(t > 4.3 and t < 4.5 and "overheat" in snd.played, "Stream Output overflows the context after %.2f s" % t)
	n = count_shots.call(1.25)
	ok(n == 0 and g.overheated > 0, "an overflowed gun does not fire")
	count_shots.call(0.1)
	ok(g.overheated <= 0 and g.heat < 10, "after 1.3 s it has cooled down (heat %.1f)" % g.heat)
	ok(count_shots.call(0.1) > 0, "and fires again")
	progress.upgrades["context"] = 1
	ok(g.heat_cap() == 140.0, "Longer Context: 140 context")
	progress.upgrades.erase("context")
	for b in get_nodes_in_group("bullets"):
		b._remove()

	# A token hits the first enemy in its way and stops; the beam pierces every enemy in its line.
	var at: Vector2 = g.pivot()
	var clear := true
	for x in range(0, 140, 4):
		clear = clear and m.level.tile(at + Vector2(x, 0)) not in [level_script.SOLID, level_script.CORRUPT]
	ok(clear, "the 140 px ahead of Clawd at the start of 2-1 are open")
	var near = target(m, at + Vector2(50, 0), 10)
	var far = target(m, at + Vector2(100, 0), 10)
	var b1 = bullet_script.fire(m.level, at, 0.0, 380, weapons.get_def("blaster"), 2.0)
	snd.played.clear()
	await frames(25)
	ok(near.hp == 8.0 and far.hp == 10.0 and gone(b1) and "hit" in snd.played, "a token hits the first enemy and stops (%s, %s)" % [near.hp, far.hp])
	m.fire_beam(at, 0.0, 1.0)
	ok(near.hp == 7.0 and far.hp == 9.0, "the Attention Beam hits both")

	# Damage numbers and health bars (port additions).
	var ov = m.overlay
	var amounts := func(e) -> Array:
		var id: int = e.get_instance_id()
		return ov.numbers.filter(func(x): return x.id == id).map(func(x): return x.amount)
	ok(amounts.call(near) == [2.0, 1.0], "each hit shows its damage over the enemy (%s)" % [amounts.call(near)])
	for i in 3:
		near.hit(&"shot", 1.0)
	ok(amounts.call(near) == [2.0, 4.0], "quick hits add up in one number (%s)" % [amounts.call(near)])
	ok(ov.amount_text(2.5) == "2.5" and ov.amount_text(2.0) == "2", "2.5 shows as 2.5, 2 as 2")
	var fresh = target(m, at + Vector2(30, -40), 10)
	ok(ov.show_bar(near) and near.max_hp == 10.0 and not ov.show_bar(fresh), "a hurt enemy shows its health bar, one at full health doesn't")
	near.hit(&"shot", 100)
	ok(ov.numbers.any(func(x): return x.id == near.get_instance_id() and x.kill), "the killing blow's number is marked")
	ok(not ov.show_bar(near), "a dead enemy has no bar")
	far.hit(&"shot", 100)
	fresh.hit(&"shot", 100)
	await frames(2)

	# Platforms are cover (the port, the user's call): shots stop on a one-way plank from below and on a platform.
	var plank := Vector2i(-1, -1)
	for c: Vector3i in m.level.oneway.get_used_cells():
		# GridMap cell y is -(row + 1); the rows under the plank's cell must be open.
		var below := Vector2(c.x * 16 + 8, (-c.y - 1) * 16 + 16)
		var open := true
		for dy in range(4, 68, 8):
			open = open and m.level.tile(below + Vector2(0, dy)) not in [level_script.SOLID, level_script.CORRUPT, level_script.ONEWAY]
		if open:
			plank = Vector2i(c.x, -c.y - 1)
			break
	ok(plank.x >= 0, "2-1 has a one-way plank with room under it")
	var plank_top := Vector2(plank.x * 16 + 8, plank.y * 16)
	var over_plank = target(m, plank_top + Vector2(0, -20), 10)
	var cover_b = bullet_script.fire(m.level, plank_top + Vector2(0, 60), -PI / 2, 440, weapons.get_def("blaster"), 2.0)
	var last := Vector2.ZERO
	for i in 15:
		if gone(cover_b): break
		last = cover_b.pos
		await physics_frame
	ok(gone(cover_b) and last.y > plank_top.y and last.y < plank_top.y + 16 and over_plank.hp == 10.0,
		"a token fired up stops on the one-way plank (last seen at y %.1f, plank %d) and the bug above is safe" % [last.y, plank_top.y])
	m.fire_beam(plank_top + Vector2(0, 60), -PI / 2, 1.0)
	ok(over_plank.hp == 10.0, "so does the beam")
	over_plank.hit(&"shot", 100)
	var fake = load("res://scripts/fake_platform.gd").create(m.level, at + Vector2(40, -3), 32)
	var behind = target(m, at + Vector2(100, 0), 10)
	var cover_b2 = bullet_script.fire(m.level, at, 0.0, 380, weapons.get_def("blaster"), 2.0)
	for i in 15:
		if gone(cover_b2): break
		last = cover_b2.pos
		await physics_frame
	ok(gone(cover_b2) and last.x < at.x + 44 and behind.hp == 10.0, "a token stops on a platform in its way (x %.1f)" % (last.x - at.x))
	behind.hit(&"shot", 100)
	fake.queue_free()
	await frames(2)

	# Enemy shots that can be shot down vanish with the bullet; the others let it pass.
	var shot = shot_script.fire(m.level, at + Vector2(80, 0), Vector2(-40, 0), Color.RED, true, 4.0)
	var b2 = bullet_script.fire(m.level, at, 0.0, 380, weapons.get_def("blaster"), 2.0)
	await frames(15)
	ok(gone(shot) and gone(b2), "a token shoots down an enemy shot")
	var hard = shot_script.fire(m.level, at + Vector2(60, 0), Vector2.ZERO, Color.RED, false, 4.0)
	var b3 = bullet_script.fire(m.level, at, 0.0, 380, weapons.get_def("blaster"), 2.0)
	await frames(15)
	ok(not gone(hard) and (gone(b3) or b3.pos.x > at.x + 70), "but passes through one that can't be")
	hard.remove()

	# World 2 is tough (spawnEntities()): bugs have 2 hp, spam bots 3, times HP_FACTOR (3) as everywhere in the
	# port; a hurt one's bar drains to its hp.
	m.load_level("2-1")
	await frames(3)
	var bugs2 := enemies_of("res://scripts/bug.gd")
	var bots2 := enemies_of("res://scripts/spam_bot.gd")
	ok(bugs2.size() == 7 and bugs2.all(func(e): return e.hp == 6.0) and bots2.size() == 2 and bots2.all(func(e): return e.hp == 9.0),
		"2-1's bugs have 6 hp, its spam bots 9")
	bots2[0].hit(&"shot", 1.0)
	ok(m.overlay.show_bar(bots2[0]) and bots2[0].shown_hp == 9.0, "a hit spam bot shows its bar, the lost hp still light")
	await frames(60)
	ok(is_equal_approx(bots2[0].shown_hp, 8.0) and m.overlay.show_bar(bots2[0]), "then the light part drains to its hp")
	p.invuln = 1000
	g.mouse_moved = -1000000

	# Switching: next / prev through the owned weapons (wrapping), 1-5 for a slot; saved as the equipped one.
	g.set_weapon("blaster")
	var press := func(action: String) -> void:
		Input.action_press(action)
		await frames(1)
		Input.action_release(action)
		await frames(1)
	snd.played.clear()
	await press.call("next")
	ok(g.weapon.id == "spreader" and progress.equipped == "spreader" and g.label_t > 1 and "select" in snd.played, "next: the Context Spreader")
	await press.call("prev")
	await press.call("prev")
	ok(g.weapon.id == "cannon", "prev twice wraps around to the Opus Cannon")
	await press.call("slot3")
	ok(g.weapon.id == "stream" and progress.equipped == "stream", "3: Stream Output")
	progress.weapons = ["blaster", "spreader"]
	await press.call("slot4")
	ok(g.weapon.id == "stream", "a slot without a weapon does nothing")
	progress.weapons = ["blaster", "spreader", "stream", "beam", "cannon"]

	# Armed, attack shoots instead of spinning; spin still spins.
	g.set_weapon("blaster")
	g.cooldown = 0.0
	var before: int = g.shot_count
	Input.action_press("attack")
	await frames(4)
	ok(g.shot_count > before and p.state != &"spin", "armed, attack shoots and doesn't spin")
	Input.action_release("attack")
	await frames(2)

	# The Opus Cannon's orb explodes where it stops: splash damage, and it breaks corrupted blocks (1-1's at
	# columns 220..223, row 15).
	m.load_level("1-1")
	await frames(3)
	var block := Vector2(221 * 16 + 8, 15 * 16 + 8)
	var victim = target(m, block + Vector2(24, -30), 20)
	snd.played.clear()
	var orb = bullet_script.fire(m.level, block + Vector2(0, -40), PI / 2, 230, weapons.get_def("cannon"), 14.0)
	await frames(20)
	ok(gone(orb) and "explode" in snd.played, "the orb explodes on the blocks")
	ok(m.level.tile(block) != level_script.CORRUPT, "and breaks the corrupted cluster")
	ok(victim.hp == 12.0, "an enemy in the blast takes its 8 splash damage (hp %s)" % victim.hp)
	victim.hit(&"shot", 100)

	# Pulled into the exit, Clawd takes his gun with him (bug list #6: it stayed hanging in front of the gate).
	m.load_level("2-1")
	await frames(3)
	var g2 = m.gun
	var goal = m.level.get_node("Goal")
	m.player.pos = goal.feet()
	await frames(20)
	ok(m.complete_t >= 0 and g2._hand.visible and g2.shrink == 1.0, "at the exit Clawd still holds his gun")
	await frames(60)
	ok(not m.player.visual.visible and not g2._hand.visible and g2.shrink == 0.0, "pulled in, the gun vanishes with him")
	m.load_level("2-1")
	await frames(3)
	ok(g2._hand.visible and g2.shrink == 1.0 and m.player.visual.visible, "and the next level hands it back")
	m.load_level("1-1")
	await frames(3)
	return true


func check_platforms() -> bool:
	var m = current_scene
	var p = m.player
	m.load_level("1-1")
	await frames(3)
	var plats: Array = get_nodes_in_group("platforms")
	plats.sort_custom(func(a, b): return a.phase < b.phase)
	ok(plats.size() == 2 and plats[0].axis == "h" and is_equal_approx(plats[1].phase, 1.3), "1-1 has 2 horizontal platforms 'M', phases 0 and 1.3")
	var x0: float = plats[0].x
	await frames(30)
	ok(absf(plats[0].x - x0) > 10, "platforms move")

	# Dropped onto a platform, Clawd lands on it and rides along.
	var pl = plats[0]
	p.pos = Vector2(pl.x + 24, pl.y - 30)
	p.vel = Vector2.ZERO
	p.invuln = 5
	for i in 40:
		await physics_frame
		if p.riding: break
	var start: float = p.pos.x - pl.x
	await frames(40)
	ok(p.riding == pl and p.on_ground and absf(p.pos.y - pl.y) < 0.01, "Clawd lands on a platform from above and stands on it")
	ok(absf(p.pos.x - pl.x - start) < 1.0, "the platform carries him along")
	Input.action_press("down")
	await frames(1)
	Input.action_press("jump")
	await frames(3)
	Input.action_release("jump")
	Input.action_release("down")
	await frames(10)
	ok(p.riding == null and p.pos.y > pl.y + 4, "down + jump drops through a platform")

	# Cross the 26-tile gap (columns 251..276) on both platforms, jumping when the next one comes close.
	m.load_level("1-1")
	await frames(3)
	plats = get_nodes_in_group("platforms")
	plats.sort_custom(func(a, b): return a.x < b.x)
	p.pos = Vector2(251 * TILE - 10, 15 * TILE)
	p.vel = Vector2.ZERO
	p.invuln = 5
	await frames(5)
	var stage := 0
	var air := false
	for i in 1500:
		# Next landing spot's left edge, the edge Clawd jumps from, and whether the gap is closing.
		var target: float = [plats[0].x, plats[1].x, 277 * TILE][stage]
		var edge: float = [251 * TILE, plats[0].x + 48, plats[1].x + 48][stage]
		var closing: bool = [plats[0].dx < 0, plats[1].dx < plats[0].dx, plats[1].dx > 0][stage]
		var on_target: bool = (stage < 2 and p.riding == plats[stage]) or (stage == 2 and p.is_on_floor() and p.pos.x > 277 * TILE)
		if air and on_target:
			air = false
			Input.action_release("right")
			Input.action_release("jump")
			stage += 1
			if stage == 3: break
		elif not air:
			# Walk to the edge, then jump once the gap is small enough and closing.
			if p.pos.x < edge - 10:
				Input.action_press("right")
			else:
				Input.action_release("right")
			if target - edge < [24, 52, 60][stage] and closing:
				air = true
				Input.action_press("jump")
				Input.action_press("right")
		else:
			if p.vel.y > 0:
				Input.action_release("jump")
			# Stop pushing right once over the middle of the platform.
			if stage < 2 and p.pos.x > plats[stage].x + 24:
				Input.action_release("right")
		if p.pos.y > 16 * TILE:
			print("    fell at stage %d, x %.0f, platforms %.0f %.0f" % [stage, p.pos.x, plats[0].x, plats[1].x])
			break
		await physics_frame
	Input.action_release("right")
	Input.action_release("jump")
	ok(stage == 3, "1-1: Clawd crosses the last gap on the two platforms (reached stage %d of 3)" % stage)
	return true


func check_hud() -> bool:
	var m = current_scene
	var p = m.player
	var hud = m.hud
	m.load_level("1-1")
	await frames(3)
	ok(hud.label_id == "1-1" and hud.label_name == "token plains" and hud.shown == 0, "HUD shows the level and starts at 0 tokens")
	var missing := []
	for l in m.levels:
		for ch in (l.id + " · " + String(l.name).to_lower()):
			if not PixelFont.GLYPHS.has(ch) and ch != " " and ch not in missing:
				missing.append(ch)
	ok(missing.is_empty(), "PixelFont has every character of the HUD level labels %s" % [missing])

	# A token flies to the counter, and is counted when it lands.
	var token = m.level.get_children().filter(func(c): return c is Area3D)[0]
	p.pos = Px.of(token.position) + Vector2(0, 8)
	await frames(3)
	ok(m.tokens == 1 and hud.shown == 0 and hud._flights.size() == 1, "a collected token is in flight to the HUD")
	await frames(40)
	ok(hud.shown == 1 and hud._flights.is_empty(), "it lands on the counter (shown %d)" % hud.shown)

	# Losing a heart breaks it; losing the last one refills them all after a moment.
	p.invuln = 0
	p.hurt(p.pos.x + 10)
	await frames(2)
	ok(hud._hearts == 2 and hud._shards.size() > 0 and hud._hurt > 0, "a lost heart breaks into shards and shakes the panel")
	p.hearts = 1
	await frames(2)
	p.invuln = 0
	p.hurt(p.pos.x + 10)
	await frames(2)
	ok(hud._hearts == 0, "the last heart breaks before the refill")
	await frames(60)
	ok(hud._hearts == p.MAX_HEARTS, "then the hearts come back")

	# Every 300 tokens give a heart (100 in TS), up to 5, and a checkpoint keeps them.
	m.tokens = 98
	m.collect_token(p.pos)
	ok(p.hearts == p.MAX_HEARTS, "the 100th token gives none (the port asks for 300)")
	m.tokens = 299
	m.collect_token(p.pos)
	ok(p.hearts == p.MAX_HEARTS + 1, "the 300th token gives a heart")
	await frames(2)
	ok(hud._slots() == p.MAX_HEARTS + 1, "the HUD grows a slot for it")
	m.activate_checkpoint(m.level.get_children().filter(func(c): return c.get_script() == load("res://scripts/checkpoint.gd"))[0])
	ok(p.hearts == p.MAX_HEARTS + 1, "a checkpoint does not take it away")
	m.tokens = 899
	p.hearts = 5
	m.collect_token(p.pos)
	ok(p.hearts == 5, "no more than 5 hearts")
	m.load_level("1-1")
	await frames(3)
	return true


func key(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = true
	return e


func click(at: Vector2) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = at
	return e


func check_menus() -> bool:
	var m = current_scene
	var p = m.player
	var menu = m.menu
	var settings = root.get_node("Settings")
	# Never touch the player's own settings file.
	var real_path: String = settings.path
	settings.path = "user://settings_check_%d.cfg" % OS.get_process_id()
	settings.bindings = settings.defaults()
	settings.apply()
	m.load_level("1-1")
	await frames(5)

	menu.handle(key(KEY_P))
	ok(menu.state == menu.PAUSE and root.get_node("Game").frozen(), "P opens the pause menu and freezes the world")
	var at: Vector2 = p.pos
	Input.action_press("right")
	await frames(10)
	Input.action_release("right")
	ok(p.pos == at, "Clawd does not move while paused")
	menu.handle(key(KEY_ESCAPE))
	ok(menu.state == menu.NONE, "Escape resumes")
	await frames(3)
	ok(not root.get_node("Game").paused, "the world runs again")

	# Resuming with Space must not also jump.
	await frames(5)
	menu.handle(key(KEY_ESCAPE))
	ok(menu.state == menu.PAUSE, "Escape pauses too")
	var space := key(KEY_SPACE)
	Input.parse_input_event(space)
	await frames(1)
	var up := key(KEY_SPACE)
	up.pressed = false
	Input.parse_input_event(up)
	await frames(10)
	ok(menu.state == menu.NONE and p.on_ground and p.vel.y >= 0, "Space on RESUME resumes without a jump")

	# RESTART FROM CHECKPOINT, CRT FILTER, RESTART LEVEL.
	p.pos += Vector2(200, -40)
	menu.handle(key(KEY_P))
	menu.handle(key(KEY_DOWN))
	menu.handle(key(KEY_ENTER))
	ok(menu.state == menu.NONE and p.pos.is_equal_approx(p.spawn_point), "RESTART FROM CHECKPOINT puts Clawd back")
	await frames(3)
	var crt: bool = settings.crt
	menu.handle(key(KEY_P))
	for i in 3:
		menu.handle(key(KEY_DOWN))
	menu.handle(key(KEY_ENTER))
	ok(settings.crt != crt and m.crt.visible == settings.crt, "CRT FILTER toggles the filter")
	var cfg := ConfigFile.new()
	cfg.load(settings.path)
	ok(cfg.get_value("video", "crt") == settings.crt, "and saves it")
	menu.handle(key(KEY_ENTER))
	ok(settings.crt == crt, "and toggles it back")
	menu.handle(key(KEY_UP))
	m.tokens = 5
	menu.handle(key(KEY_ENTER))
	ok(menu.state == menu.NONE and m.tokens == 0, "RESTART LEVEL reloads the level")
	await frames(3)

	# The HUD buttons, at the usual 480 x 270 view (the headless window is smaller).
	var vp_size: Vector2i = m.subviewport.size
	m.subviewport.size = Vector2i(480, 270) + Vector2i.ONE * m.PAD * 2
	var b: Dictionary = m.hud.buttons()
	ok(b.controls.end.x < b.pause.position.x and b.pause.end.x < b.label.position.x, "HUD: CONTROLS, pause and the level label in a row at the top right")
	var view := Rect2(Vector2.ONE * m.PAD, Vector2(m.subviewport.size) - Vector2.ONE * m.PAD * 2)
	ok(view.encloses(b.controls) and view.encloses(b.label), "the HUD lies inside the part of the view on screen (%s in %s)" % [b.controls.merge(b.label), view])
	m.subviewport.size = vp_size
	b = m.hud.buttons()
	menu.handle(click(b.pause.get_center()))
	ok(menu.state == menu.PAUSE, "clicking the pause button pauses")
	menu.handle(click(b.pause.get_center()))
	ok(menu.state == menu.NONE, "clicking it again resumes")
	menu.handle(click(b.controls.get_center()))
	ok(menu.state == menu.CONTROLS, "clicking CONTROLS shows the controls help")
	var lines: Array = menu.control_lines()
	ok(lines[1][0] == "SPACE W K" and lines[0][0] == "← A → D", "the help lists the bound keys (%s, %s)" % [lines[0][0], lines[1][0]])
	var progress = root.get_node("Progress")
	var had: Array = progress.weapons
	progress.weapons = []
	var plain: int = menu.control_lines().size()
	progress.weapons = ["blaster"]
	var armed_lines: Array = menu.control_lines().map(func(l): return l[1])
	progress.weapons = had
	ok(plain == 8 and armed_lines.size() == 12 and "Switch weapon" in armed_lines and "World 2: aim and shoot" in armed_lines,
		"with a weapon found it adds shooting, aiming and switching")

	# Keybindings: rebind jump's second slot.
	menu.handle(key(KEY_ENTER))
	ok(menu.state == menu.KEYS, "Enter on the help opens the keybindings")
	for i in 4:
		menu.handle(key(KEY_DOWN))
	menu.handle(key(KEY_RIGHT))
	menu.handle(key(KEY_ENTER))
	ok(menu.listening and settings.BINDABLE[menu.key_row] == &"jump" and menu.key_slot == 1, "Enter on a slot listens for a key")
	menu.handle(key(KEY_X))
	ok(menu.listening and menu.error == "X ALREADY BOUND TO ATTACK (SPIN / SHOOT)", "a key of another action is refused (%s)" % menu.error)
	menu.handle(key(KEY_U))
	ok(not menu.listening and settings.bindings[&"jump"] == [KEY_SPACE, KEY_U, KEY_K], "a free key is bound")
	ok(InputMap.event_is_action(key(KEY_U), "jump") and not InputMap.event_is_action(key(KEY_W), "jump"), "the InputMap follows")
	cfg = ConfigFile.new()
	cfg.load(settings.path)
	ok(cfg.get_value("keys", "jump") == [KEY_SPACE, KEY_U, KEY_K], "and the binding is saved")
	menu.handle(key(KEY_ENTER))
	menu.handle(key(KEY_BACKSPACE))
	ok(settings.bindings[&"jump"] == [KEY_SPACE, KEY_K], "Backspace clears a slot")
	settings.bindings[&"pause"] = [KEY_P]
	settings.clear(&"pause", 0)
	ok(settings.bindings[&"pause"] == [KEY_P], "the last key of an action can't be cleared")
	ok(InputMap.event_is_action(key(KEY_ESCAPE), "pause"), "Escape always pauses")
	menu.handle(key(KEY_ENTER))
	menu.handle(key(KEY_ESCAPE))
	ok(not menu.listening and menu.state == menu.KEYS, "Escape cancels listening")
	menu.key_row = settings.BINDABLE.size()
	menu.handle(key(KEY_ENTER))
	ok(settings.bindings == settings.defaults() and InputMap.event_is_action(key(KEY_W), "jump"), "RESET DEFAULTS")
	menu.handle(key(KEY_ESCAPE))
	ok(menu.state == menu.CONTROLS, "back from the keybindings to the help")
	menu.handle(key(KEY_H))
	ok(menu.state == menu.NONE, "H closes the help")

	# Mouse in the keybindings: clicking a slot listens.
	menu.open_keys()
	var l: Dictionary = menu.layout()
	menu.handle(click(l.slots[6][0].get_center()))
	ok(menu.listening and settings.BINDABLE[menu.key_row] == &"spin" and menu.key_slot == 0, "clicking a slot listens for a key")
	menu.handle(click(Vector2(1, 1)))
	ok(not menu.listening, "a click cancels it")
	menu.handle(click(l.back.get_center()))
	ok(menu.state == menu.NONE, "BACK closes it")

	# Every text the menus draw is in the font.
	var texts: Array = menu.PAUSE_ITEMS + ["PAUSED", "CONTROLS", "KEYBINDINGS", "RESET DEFAULTS", "BACK", "...", ">",
		"ENTER — CHANGE KEYS", "PRESS A KEY · ESC CANCEL · BKSP CLEAR", "↑↓ ROW · ←→ SLOT · ENTER REBIND",
		"↑↓ SELECT · ENTER OK · ESC RESUME", "ON", "OFF", "ALREADY BOUND TO"] + settings.LABELS.values()
	for row in lines:
		texts += row
	for code in [KEY_A, KEY_Z, KEY_0, KEY_9, KEY_SEMICOLON, KEY_COMMA, KEY_PERIOD, KEY_SLASH, KEY_APOSTROPHE, KEY_QUOTELEFT, KEY_BACKSLASH, KEY_BRACKETLEFT, KEY_MINUS, KEY_EQUAL, KEY_SHIFT, KEY_TAB, KEY_F1, KEY_KP_1]:
		texts.append(settings.key_label(code))
	var missing := []
	for t in texts:
		for ch in t:
			if ch != " " and not PixelFont.GLYPHS.has(ch) and ch not in missing:
				missing.append(ch)
	ok(missing.is_empty(), "PixelFont has every character the menus and key names use %s" % [missing])

	DirAccess.remove_absolute(ProjectSettings.globalize_path(settings.path))
	settings.path = real_path
	settings._ready()
	await frames(3)
	return true


## Samples of a 16-bit mono AudioStreamWAV in [-1, 1].
func samples(w: AudioStreamWAV, from := 0.0, to := -1.0) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var n := w.data.size() / 2
	var a := int(from * w.mix_rate)
	var b := n if to < 0 else mini(n, int(to * w.mix_rate))
	for i in range(a, b):
		out.append(w.data.decode_s16(i * 2) / 32767.0)
	return out


## Frequency from the rising zero crossings of `x`.
func pitch(x: PackedFloat32Array, rate: float) -> float:
	var first := -1
	var last := -1
	var count := 0
	for i in range(1, x.size()):
		if x[i - 1] < 0 and x[i] >= 0:
			if first < 0:
				first = i
			last = i
			count += 1
	return 0.0 if count < 2 else (count - 1) * rate / (last - first)


func check_sound() -> bool:
	var m = current_scene
	var p = m.player
	var snd = root.get_node("Sound")
	for i in 120:
		if snd.sfx.has("_hover"):
			break
		await process_frame
	ok(snd.sfx.size() == snd.PRELOAD.size() + 1, "every effect the port uses is rendered at start-up (%d)" % snd.sfx.size())
	var loud := []
	for n in snd.PRELOAD:
		var x := samples(snd.sfx[n])
		var peak := 0.0
		for v in x:
			peak = maxf(peak, absf(v))
		if peak < 0.01 or peak > 0.99:
			loud.append("%s %.2f" % [n, peak])
	ok(loud.is_empty(), "each effect is audible and does not clip %s" % [loud])
	var token := pitch(samples(snd.sfx["token"], 0.005, 0.035), 44100)
	ok(absf(token - 1320) < 20, "token: a 1320 Hz blip first (%.0f Hz)" % token)
	var token2 := pitch(samples(snd.sfx["token"], 0.06, 0.1), 44100)
	ok(absf(token2 - 1760) < 25, "then 1760 Hz (%.0f Hz)" % token2)
	var j0 := pitch(samples(snd.sfx["jump"], 0.0, 0.02), 44100)
	var j1 := pitch(samples(snd.sfx["jump"], 0.09, 0.115), 44100)
	ok(j0 > 200 and j0 < 260 and j1 > 430 and j1 < 530, "jump sweeps up from 220 to 520 Hz (%.0f -> %.0f Hz)" % [j0, j1])
	var cp := pitch(samples(snd.sfx["checkpoint"], 0.01, 0.07), 44100)
	ok(absf(cp - 440) < 8, "checkpoint starts on A4 (%.0f Hz)" % cp)

	var plains: AudioStreamWAV = snd.render_track("plains")
	var secs := plains.data.size() / 2.0 / plains.mix_rate
	ok(absf(secs - 128 * 60.0 / 128 / 4) < 0.01 and plains.loop_mode == AudioStreamWAV.LOOP_FORWARD, "plains loops every 128 sixteenths at 128 bpm (%.2f s)" % secs)
	var map: AudioStreamWAV = snd.render_track("map")
	ok(absf(map.data.size() / 2.0 / map.mix_rate - 64 * 60.0 / 100 / 4) < 0.01, "map (no lead) loops every 64 sixteenths")

	m.load_level("1-1")
	await frames(3)
	ok(snd.track == "plains", "1-1 plays its track (%s)" % snd.track)
	snd.played.clear()
	p.vel = Vector2.ZERO
	Input.action_press("jump")
	await frames(2)
	ok("jump" in snd.played, "jumping plays jump")
	await frames(40)
	ok(snd._hover_on, "holding jump in the air starts the jet's hiss")
	Input.action_release("jump")
	await frames(3)
	ok(not snd._hover_on, "and letting go stops it")
	await frames(60)
	ok("land" in snd.played, "landing plays land")

	snd.played.clear()
	var bug = bugs()[0]
	p.pos = bug.pos + Vector2(0, -40)
	p.vel = Vector2.ZERO
	p.invuln = 1
	for i in 60:
		await physics_frame
		if "stomp" in snd.played: break
	ok("stomp" in snd.played and "enemyDie" in snd.played, "a stomp plays stomp and enemyDie")
	await frames(60)
	ok("token" in snd.played, "collected tokens play token")

	snd.played.clear()
	m.activate_checkpoint(m.level.get_children().filter(func(c): return c.get_script() == load("res://scripts/checkpoint.gd"))[0])
	ok("checkpoint" in snd.played, "a checkpoint plays checkpoint")
	p.invuln = 0
	p.hurt(p.pos.x + 10)
	ok("hurt" in snd.played, "getting hurt plays hurt")
	# After the hurt hitstop.
	await frames(10)
	p.pos = Vector2(p.pos.x, p.kill_y + 10)
	await frames(3)
	ok("die" in snd.played, "falling out plays die")

	# Relative to the player's own settings (this section runs on them, and several worktrees share them): two
	# presses leave them as they were.
	var was_muted: bool = root.get_node("Settings").muted
	m.menu.handle(key(KEY_M))
	ok(root.get_node("Settings").muted != was_muted and AudioServer.is_bus_mute(0) != was_muted, "M mutes (unmutes if muted)")
	m.menu.handle(key(KEY_M))
	ok(root.get_node("Settings").muted == was_muted and AudioServer.is_bus_mute(0) == was_muted, "and a second M undoes it")

	var goal = m.level.get_node("Goal")
	p.pos = goal.feet()
	await frames(3)
	ok("complete" in snd.played and snd.track == "", "the exit plays complete and stops the music")
	await frames(150)
	ok(snd.track == "map", "the results play the map tune (%s)" % snd.track)
	m.load_level("1-1")
	await frames(3)
	return true


func check_agents() -> bool:
	var m = current_scene
	var p = m.player
	var progress = root.get_node("Progress")
	var snd = root.get_node("Sound")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.path))
	progress.load_file()
	m.load_level("1-1")
	await frames(3)
	var agents: Array = m.level.get_children().filter(func(c): return c.get_script() == load("res://scripts/sub_agent.gd"))
	agents.sort_custom(func(a, b): return a.index < b.index)
	ok(agents.size() == 2 and agents.map(func(a): return int(a.feet().x / TILE)) == [168, 280] and agents[1].index == 1,
		"1-1 has 2 sub-agents ('A' at columns 168, 280)")
	ok(m.agents == [false, false] and m.hud.agents.size() == 2, "the HUD counts them")
	ok(not agents[0].ghost, "none is a ghost in a new game")
	snd.played.clear()
	var a = agents[1]
	p.pos = a.feet()
	await frames(2)
	ok(a.rescued and m.agents == [false, true] and "rescue" in snd.played, "touching one rescues it")
	ok(m.overlay.popups.any(func(q): return q.text == "SUB-AGENT RESCUED!"), "and pops up SUB-AGENT RESCUED!")
	await frames(50)
	ok(a._beam.visible and a._rise() > 0, "it rides a beam of light up")
	await frames(40)
	ok(not is_instance_valid(a), "and is gone after 1.1 s")
	ok(m.hud._rescued == 1, "the HUD shows 1 / 2")

	p.pos = m.level.get_node("Goal").feet()
	await frames(150)
	ok(m.overlay.results.get("agents") == [false, true], "the results show which were rescued")
	ok(progress.progress_for("1-1").agents == [false, true], "the save remembers it")
	m.load_level("1-1")
	await frames(3)
	agents = m.level.get_children().filter(func(c): return c.get_script() == load("res://scripts/sub_agent.gd"))
	agents.sort_custom(func(a1, b1): return a1.index < b1.index)
	ok(agents[1].ghost and not agents[0].ghost, "next time the rescued one is a ghost")
	return true


func check_sparks() -> bool:
	var m = current_scene
	var p = m.player
	var progress = root.get_node("Progress")
	var snd = root.get_node("Sound")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.path))
	progress.load_file()
	m.load_level("1-1")
	await frames(3)
	var spark_script = load("res://scripts/spark.gd")
	var sparks: Array = m.level.get_children().filter(func(c): return c.get_script() == spark_script)
	sparks.sort_custom(func(a, b): return a.index < b.index)
	ok(sparks.map(func(sp): return int(sp.feet().x / TILE)) == [160, 51, 116, 268, 221],
		"1-1 has 5 sparks ('S'), numbered in map order")
	ok(m.sparks == [false, false, false, false, false] and m.hud.sparks.size() == 5 and m.hud._sparks_w() > 0, "the HUD counts them")
	ok(m.hud.coin_centre().x > m.hud.ORIGIN.x + m.hud._hearts_w() + m.hud._sparks_w(), "the token counter moves right of the sparks")
	ok(sparks.all(func(sp): return not sp.ghost), "none is a ghost in a new game")
	var grid: Array = spark_script.rows(4)
	ok(grid.size() == 21 and grid[10][10] == "W" and grid[10][19] == "h" and grid[10][15] == "O" and grid[1][10] == "h"
		and grid[11][12] == "O" and grid[14][14] == "h", "the spark is a solid star: white core, tapering rays, diagonals")
	var dotted: Array = spark_script.rows(3, true)
	ok(spark_script.rows(3)[10][19] == "." and spark_script.rows(3)[10][17] == "h" and dotted[10].count("O") + dotted[10].count("L") < spark_script.rows(3)[10].count("O") + spark_script.rows(3)[10].count("L"),
		"its rays flicker between 7 and 9 px; a ghost is drawSpark()'s dotted star")

	snd.played.clear()
	var sp = sparks[1]
	p.pos = sp.feet()
	await frames(2)
	ok(m.sparks == [false, true, false, false, false] and "spark" in snd.played, "touching one collects it")
	ok(m.overlay.popups.any(func(q): return q.text == "SPARK 1/5") and m.hud._spark_flash > 0, "SPARK 1/5 pops up and the HUD counter flashes")
	ok(not is_instance_valid(sp) or sp.is_queued_for_deletion(), "the spark is gone")

	p.pos = m.level.get_node("Goal").feet()
	await frames(150)
	ok(m.overlay.results.get("sparks") == [false, true, false, false, false] and m.overlay.results.get("prev_sparks") == [false, false, false, false, false],
		"the results show the spark, new this time")
	ok(progress.progress_for("1-1").sparks == [false, true, false, false, false] and progress.total_sparks() == 1, "the save remembers it")
	progress.record_run("1-1", [true, false, false, false, false], [], 99.0, 0)
	ok(progress.progress_for("1-1").sparks == [true, true, false, false, false], "found sparks are merged, never lost")
	m.load_level("1-1")
	await frames(3)
	sparks = m.level.get_children().filter(func(c): return c.get_script() == spark_script)
	sparks.sort_custom(func(a, b): return a.index < b.index)
	ok(sparks[1].ghost and sparks[0].ghost and not sparks[2].ghost, "next time the found ones are ghosts")
	return true


func check_shop() -> bool:
	var m = current_scene
	var progress = root.get_node("Progress")
	var snd = root.get_node("Sound")
	var shop_items = load("res://scripts/shop.gd")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.path))
	progress.load_file()

	# Every sound the scripts play is rendered.
	var missing := []
	for f in DirAccess.get_files_at("res://scripts"):
		if not f.ends_with(".gd"):
			continue
		var src := FileAccess.get_file_as_string("res://scripts/" + f)
		var re := RegEx.create_from_string('Sound\\.play\\("([A-Za-z]+)"\\)')
		for r in re.search_all(src):
			if r.get_string(1) not in snd.PRELOAD and r.get_string(1) not in missing:
				missing.append(r.get_string(1))
	ok(missing.is_empty(), "every Sound.play() in the scripts has a rendered effect %s" % [missing])

	# The shop opens from the map once 1-1 is cleared.
	m.show_map(0)
	await frames(3)
	m.front.handle(key(KEY_B))
	ok(m.mode == m.Mode.MAP and "denied" in snd.played, "the shop is locked until 1-1 is cleared")
	progress.record_run("1-1", [true, true, true, false, false], [], 80.0, 300)
	m.front.handle(key(KEY_B))
	await frames(3)
	ok(m.mode == m.Mode.SHOP and m.shop.visible and snd.track == "shop", "then B on the map opens it, with its tune")
	var shop = m.shop
	ok(shop_items.ITEMS.map(func(it): return it.id) == ["hearts", "hover", "magnet", "radar", "fortune", "firewall", "double", "armory"],
		"it sells the world-1 upgrades, the tools, the consumables and a locked armory")
	# Balance (M12): as in TS, the sparks of every level buy everything that costs sparks, with none to spare.
	var spark_prices := 0
	for it in shop_items.ITEMS + load("res://scripts/weapons.gd").UPGRADES:
		for s in it.get("sparks", []):
			spark_prices += s
	for w in load("res://scripts/weapons.gd").WEAPONS.values():
		spark_prices += w.sparks
	var level_sparks := 0
	for l in JSON.parse_string(FileAccess.get_file_as_string("res://levels/index.json")):
		level_sparks += FileAccess.get_file_as_string("res://levels/%s.txt" % l.id).count("S")
	ok(spark_prices == level_sparks, "the shop's spark prices add up to the sparks in the levels (%d / %d)" % [spark_prices, level_sparks])

	# Extra Heart: 100 tokens.
	shop.sel = 0
	shop.handle(key(KEY_ENTER))
	ok(progress.upgrade("hearts") == 1 and progress.wallet == 200 and "buy" in snd.played, "buying Extra Heart costs 100 tokens")
	ok(shop.haiku == shop.THANKS[0], "HAIKU thanks you")
	shop.handle(key(KEY_ENTER))
	ok(progress.upgrade("hearts") == 1 and progress.wallet == 200 and shop.haiku == shop.DENIED[0],
		"its second level also needs 4 sparks: refused")
	# Jet Tuning, the radar, a fortune, a Firewall and a Double Tokens.
	shop.handle(key(KEY_DOWN))
	shop.handle(key(KEY_ENTER))
	ok(progress.upgrade("hover") == 1 and progress.wallet == 140, "Jet Tuning: 60 tokens")
	shop.sel = 3
	shop.handle(key(KEY_ENTER))
	ok(progress.upgrade("radar") == 1 and progress.wallet == 60 and progress.sparks_available() == 3, "Spark Radar: 80 tokens, no sparks")
	shop.sel = 4
	shop.handle(key(KEY_ENTER))
	var first: Array = progress.fortune
	ok(progress.wallet == 35 and first.size() == 3 and first[0].ends_with("1-1") and shop.haiku == first,
		"a fortune: HAIKU tells where something still hides (%s)" % [first])
	progress.wallet += 25
	shop.handle(key(KEY_ENTER))
	ok(progress.fortune != first and progress.hinted.size() == 2, "the next one tells about something else")
	var spark_hint: Array = shop_items.fortune_lines({"level": "1-1", "kind": "S", "index": 0, "x": 160, "y": 5})
	# Spark 0 of 1-1 sits on a one-way ledge between the first and second checkpoint (columns 107, 177).
	ok(spark_hint == ["a spark sleeps in 1-1", "past save number one", "right above a ledge"], "hints read the map: %s" % [spark_hint])
	progress.wallet = 150
	shop.sel = 5
	shop.handle(key(KEY_ENTER))
	shop.sel = 6
	shop.handle(key(KEY_ENTER))
	ok(progress.in_stock("firewall") == 1 and progress.in_stock("double") == 1 and progress.wallet == 10, "Firewall 40, Double Tokens 100")
	shop.sel = 7
	snd.played.clear()
	shop.handle(key(KEY_ENTER))
	ok("denied" in snd.played and shop.haiku == shop.LOCKED[0], "the armory is locked")
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(progress.path))
	ok(cfg.upgrades.hearts == 1 and cfg.stock.firewall == 1 and cfg.sparks_spent == 0, "purchases are saved")
	shop.handle(key(KEY_ESCAPE))
	ok(m.mode == m.Mode.MAP and not shop.visible, "Escape goes back to the map")

	# What they do in a level.
	m.play("1-1")
	await frames(3)
	await process_frame
	await process_frame
	var p = m.player
	ok(p.max_hearts == 4 and p.hearts == 4 and m.hud._slots() == 4, "Extra Heart: 4 hearts")
	ok(is_equal_approx(p.hover_duration, 0.85 * 1.3), "Jet Tuning: 30% longer hover")
	ok(p.shield and m.hud._shield_up, "a Firewall is up")
	ok(m.double_tokens and m.hud.double_tokens, "Double Tokens is on")
	var target = m.radar_target()
	ok(target != null and target.index >= 3, "the radar points to a spark never found (%s)" % [target.index if target else null])
	p.invuln = 0
	p.hurt(p.pos.x + 10)
	await frames(2)
	ok(p.hearts == 4 and not p.shield and progress.in_stock("firewall") == 0, "the Firewall takes the hit and is used up")
	var tokens: Array = m.level.get_children().filter(func(c): return c is Area3D and not c.popped)
	var had: int = m.tokens
	p.pos = Px.of(tokens[0].position) + Vector2(0, 8)
	await frames(5)
	ok(m.tokens == had + 2, "with Double Tokens a token counts twice")
	m.player.pos = m.level.get_node("Goal").feet()
	await frames(5)
	ok(progress.in_stock("double") == 0, "clearing the level uses the Double Tokens up")

	# Token Magnet.
	progress.upgrades["magnet"] = 1
	m.play("1-1")
	await frames(3)
	tokens = m.level.get_children().filter(func(c): return c is Area3D)
	tokens.sort_custom(func(a, b): return a.position.x < b.position.x)
	m.player.pos = Px.of(tokens[0].position) + Vector2(-50, 9)
	await frames(2)
	ok(tokens[0].popped, "Token Magnet: a token 50 px away comes loose and flies to Clawd")

	# The ARMORY opens once Clawd has a weapon (the blaster 1-B drops).
	var weapons = load("res://scripts/weapons.gd")
	# A world-2 level picked (world 2 is still locked here, so show_map() would not move there).
	m.front.sel = 4
	ok(m.front.map_gun() == "", "without a weapon the map's Clawd is unarmed in world 2")
	progress.grant_weapon("blaster")
	ok(m.front.map_gun() == "blaster", "with one he holds it on a world-2 level (levelSelect.ts: armed in world 2)")
	m.front.sel = 0
	progress.wallet = 1000
	progress.sparks_spent = 0
	m.show_map(0)
	await frames(3)
	ok(m.front.map_gun() == "", "and not on a world-1 level")
	m.front.handle(key(KEY_B))
	await frames(3)
	var ids: Array = shop.items.map(func(it): return it.id)
	ok(ids == ["hearts", "hover", "magnet", "radar", "fortune", "firewall", "double", "blaster", "spreader", "stream", "beam", "cannon",
		"damage", "rate", "context"], "then the ARMORY's weapons and the GUN MODS take the locked row's place")
	ok(not shop._shown(shop._rows()[-1]), "the list is taller than the screen")
	shop.sel = ids.size() - 1
	# The list follows the selection in _process(), which can lag behind the physics frames.
	await process_frame
	await process_frame
	ok(shop._shown(shop._rows()[-1]) and not shop._shown(shop._rows()[0]), "choosing the last row scrolls it into view")
	shop.handle(key(KEY_DOWN))
	await process_frame
	await process_frame
	ok(shop.sel == 0 and shop._scroll == 0.0, "down from there wraps to the top")
	shop.sel = ids.find("spreader")
	shop.handle(key(KEY_ENTER))
	ok(progress.weapons == ["blaster", "spreader"] and progress.equipped == "spreader" and progress.wallet == 880,
		"Context Spreader: 120 tokens, held at once")
	m.front.sel = 4
	ok(m.front.map_gun() == "spreader", "the map's Clawd holds the equipped weapon")
	m.front.sel = 0
	shop.sel = ids.find("stream")
	shop.handle(key(KEY_ENTER))
	ok(progress.weapons.has("stream") and progress.wallet == 660 and progress.sparks_available() == 0, "Stream Output: 220 tokens and 3 sparks")
	shop.sel = ids.find("beam")
	shop.handle(key(KEY_ENTER))
	ok(not progress.weapons.has("beam") and shop.haiku == shop.DENIED[0], "the Attention Beam needs 8 sparks: refused")
	snd.played.clear()
	shop.sel = ids.find("blaster")
	shop.handle(key(KEY_ENTER))
	ok(progress.equipped == "blaster" and progress.wallet == 660 and "select" in snd.played, "an owned weapon is equipped for free")
	for u in ["damage", "rate", "context"]:
		shop.sel = ids.find(u)
		shop.handle(key(KEY_ENTER))
	ok(progress.wallet == 390 and weapons.damage_mult() == 1.25 and weapons.rate_mult() == 1.15 and weapons.heat_cap() == 140.0,
		"Bigger Model 100, Faster Inference 90, Longer Context 80")
	cfg = JSON.parse_string(FileAccess.get_file_as_string(progress.path))
	ok(cfg.weapons == ["blaster", "spreader", "stream"] and cfg.equipped == "blaster" and cfg.upgrades.damage == 1, "and saved")
	shop.handle(key(KEY_ESCAPE))
	m.load_level("1-1")
	await frames(3)
	return true
