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


## Runs one section. A section returns true at its end; a script error inside it makes the
## coroutine return early with null, which counts as a failure instead of passing silently.
func section(title: String, f: Callable) -> void:
	print(title)
	if await f.call() != true:
		ok(false, "section ended early (script error above)")


func _init() -> void:
	await process_frame
	level_script = load("res://scripts/level.gd")
	await section("noise (golden values from src/core/noise.ts)", check_noise)
	await section("levels match levels/<id>.txt", check_levels)
	await section("player physics (tests/player.test.ts)", check_physics)
	await section("level select and main scene", check_scenes)
	await section("hazards and enemies in 1-1", check_hazards)
	await section("spin, ground pound and drop-through in 1-1 (src/entities/player.ts)", check_moves)
	await section("checkpoints, exit and signs in 1-1", check_objects)
	await section("moving platforms over the last gap of 1-1 (src/entities/platforms.ts)", check_platforms)
	await section("HUD: hearts and tokens (src/render/hud.ts)", check_hud)
	await section("pause, controls help and keybindings (src/scenes/game.ts, keybinds.ts)", check_menus)
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
	for l in index:
		var rows := FileAccess.get_file_as_string("res://levels/%s.txt" % l.id).trim_suffix("\n").split("\n")
		var level: Node3D = load("res://levels/%s.tscn" % l.id).instantiate()
		var terrain: GridMap = level.get_node("Terrain")
		var oneway: GridMap = level.get_node("OneWay")
		var want_tiles := 0
		var want := {"@": 0, "E": 0, "o": 0}
		var bad := 0
		for y in rows.size():
			for x in rows[y].length():
				var ch := rows[y][x]
				if ch in want:
					want[ch] += 1
				var c := Vector3i(x, -y - 1, 0)
				var item := oneway.get_cell_item(c) if ch == "=" else terrain.get_cell_item(c)
				if TILE_CHARS.contains(ch):
					want_tiles += 1
					bad += int(item != TILE_CHARS.find(ch))
				else:
					bad += int(terrain.get_cell_item(c) != -1 or oneway.get_cell_item(c) != -1)
		var spawns := level.get_children()
		var bugs := spawns.filter(func(n): return n.is_in_group("enemies")).size()
		var tokens := spawns.filter(func(n): return n is Area3D).size()
		ok(bad == 0 and terrain.get_used_cells().size() + oneway.get_used_cells().size() == want_tiles and want["@"] == 1
			and level.has_node("Start") and bugs == want["E"] and tokens == want["o"],
			"%s: %d tiles, 0 misplaced, 1 start, %d bugs, %d tokens" % [l.id, want_tiles, bugs, tokens])
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
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await scene_ready("LevelSelect")
	var buttons: Array = current_scene.get_node("%Levels").get_children().map(func(b): return String(b.name))
	ok(current_scene.name == "LevelSelect" and buttons.size() == 9, "start scene is the level select with 9 buttons")
	var opened := 0
	for id in buttons:
		current_scene.get_node("%Levels/" + id).pressed.emit()
		await scene_ready("Main")
		var m = current_scene
		if m.level_id == id and m.player.pos.is_equal_approx(_start(m)):
			opened += 1
		change_scene_to_file("res://scenes/level_select.tscn")
		await scene_ready("LevelSelect")
	ok(opened == 9, "every button opens its level with the player on '@' (%d/9)" % opened)

	load("res://scripts/main.gd").start_level = "1-1"
	change_scene_to_file("res://scenes/main.tscn")
	await scene_ready("Main")
	await frames(60)
	var m = current_scene
	ok(m.player.is_on_floor() and m.player.pos.is_equal_approx(_start(m)), "1-1: player stands on '@'")
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
	var bug = get_nodes_in_group("enemies")[0]
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
	var n := get_nodes_in_group("enemies").size()
	bug = get_nodes_in_group("enemies")[0]
	p.pos = bug.pos + Vector2(0, -40)
	p.vel = Vector2.ZERO
	p.invuln = 0
	var bounced := false
	for i in 60:
		await physics_frame
		if get_nodes_in_group("enemies").size() < n:
			bounced = p.vel.y < 0
			break
	ok(bounced, "stomping a bug kills it and bounces")
	ok(m.particles.list.size() > 0, "stomp emits particles")
	var popped: Array = m.level.get_children().filter(func(c): return c is Area3D and c.popped)
	ok(popped.size() == 10, "a defeated bug drops 10 tokens (got %d)" % popped.size())
	ok(m.tokens_total == m.level.get_children().filter(func(c): return c is Area3D and not c.popped).size() + n * 10,
		"the level's token total counts what the bugs drop")
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
	var n := get_nodes_in_group("enemies").size()
	var bug = get_nodes_in_group("enemies")[0]
	p.pos = bug.pos + Vector2(-20, 0)
	p.vel = Vector2.ZERO
	p.invuln = 5
	await frames(2)
	Input.action_press("spin")
	await frames(2)
	Input.action_release("spin")
	ok(p.state == &"spin" and &"spin" in events, "spin starts the spin state")
	await frames(10)
	ok(get_nodes_in_group("enemies").size() == n - 1 and p.hearts == p.MAX_HEARTS, "spin defeats a bug next to Clawd")

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
	ok(m.level_id == "1-2" and not p.frozen and p.visual.visible, "jump on the results panel goes to the next level")
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

	# Every 100 tokens give a heart, up to 5, and a checkpoint keeps them.
	m.tokens = 99
	m.collect_token(p.pos)
	ok(p.hearts == p.MAX_HEARTS + 1, "the 100th token gives a heart")
	await frames(2)
	ok(hud._slots() == p.MAX_HEARTS + 1, "the HUD grows a slot for it")
	m.activate_checkpoint(m.level.get_children().filter(func(c): return c.get_script() == load("res://scripts/checkpoint.gd"))[0])
	ok(p.hearts == p.MAX_HEARTS + 1, "a checkpoint does not take it away")
	m.tokens = 499
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
	settings.path = "user://settings_check.cfg"
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

	# Keybindings: rebind jump's second slot.
	menu.handle(key(KEY_ENTER))
	ok(menu.state == menu.KEYS, "Enter on the help opens the keybindings")
	for i in 4:
		menu.handle(key(KEY_DOWN))
	menu.handle(key(KEY_RIGHT))
	menu.handle(key(KEY_ENTER))
	ok(menu.listening and settings.BINDABLE[menu.key_row] == &"jump" and menu.key_slot == 1, "Enter on a slot listens for a key")
	menu.handle(key(KEY_X))
	ok(menu.listening and menu.error == "X ALREADY BOUND TO ATTACK (SPIN)", "a key of another action is refused (%s)" % menu.error)
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
