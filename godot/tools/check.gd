# Headless checks for the port. Run from godot/: godot --headless --script tools/check.gd
# Exits non-zero if any check fails. Expected values come from the TS sources (see each check).
# Game scripts are loaded at runtime, not named as types: they use the Game autoload, which a
# --script file cannot see while it is being compiled.
extends SceneTree

const TILE := 16
const PLAYER_SIZE := Vector2(18, 18)
const TILE_CHARS := "#=^X"

var failures := 0
var tileset: TileSet


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
	tileset = load("res://tiles/terrain.tres")
	await process_frame
	await section("noise (golden values from src/core/noise.ts)", check_noise)
	await section("levels match levels/<id>.txt", check_levels)
	await section("terrain and parallax bakes match the TS renderer", check_bakes)
	await section("player physics (tests/player.test.ts)", check_physics)
	await section("level select and main scene", check_scenes)
	await section("hazards and enemies in 1-1", check_hazards)
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
		var level: TileMapLayer = load("res://levels/%s.tscn" % l.id).instantiate()
		var want_tiles := 0
		var want := {"@": 0, "E": 0, "o": 0}
		var bad := 0
		for y in rows.size():
			for x in rows[y].length():
				var ch := rows[y][x]
				if ch in want:
					want[ch] += 1
				var atlas := level.get_cell_atlas_coords(Vector2i(x, y))
				if TILE_CHARS.contains(ch):
					want_tiles += 1
					bad += int(atlas != Vector2i(TILE_CHARS.find(ch), 0))
				else:
					bad += int(atlas != Vector2i(-1, -1))
		var spawns := level.get_children()
		var bugs := spawns.filter(func(n): return n.is_in_group("enemies")).size()
		var tokens := spawns.filter(func(n): return n is Area2D).size()
		ok(bad == 0 and level.get_used_cells().size() == want_tiles and want["@"] == 1 and level.has_node("Start")
			and bugs == want["E"] and tokens == want["o"],
			"%s: %d tiles, 0 misplaced, 1 start, %d bugs, %d tokens" % [l.id, want_tiles, bugs, tokens])
		level.free()
	return true


## MD5 of the RGBA bytes TerrainRenderer.bake() / the Parallax layers produce in TS, rendered in
## Node with a canvas stub (whole pixels; partial coverage over two rows for the factory columns,
## which sit at fractional y and are antialiased by a real canvas).
const TS_BAKES := {
	"terrain 1-1 chunk 0,0": "28b78e0f10a450c91fd85d0f28c82267",
	"terrain 1-2 chunk 2,1": "e751a6078c8f179c8da4c3a2ee2280bc",
	"terrain 2-2 chunk 3,0": "c07fff5197a5c6e66abf40551cb2f7a1",
	"parallax plains 0": "0fef56dd57ef41b1f10f1d457c317840",
	"parallax caves 0": "4d5f182e689d9fa6b9242dc20bc76937",
	"parallax forge 0": "c986a8f1285a740145ccd5cb77f5ef50",
	"parallax towers 0": "2bd88e5cb4f5869ebc10c57a9104e1f7",
}


func check_bakes() -> bool:
	var index: Array = JSON.parse_string(FileAccess.get_file_as_string("res://levels/index.json"))
	var tv = load("res://scripts/terrain_view.gd").new()
	for spec in [["1-1", 0, 0], ["1-2", 2, 1], ["2-2", 3, 0]]:
		var l: Dictionary = index.filter(func(e): return e.id == spec[0])[0]
		var layer: TileMapLayer = load("res://levels/%s.tscn" % l.id).instantiate()
		tv.build(layer, l.terrainSeed)
		var name := "terrain %s chunk %d,%d" % spec
		ok(_md5(tv._bake(spec[1], spec[2])) == TS_BAKES[name], name)
		layer.free()
	tv.free()
	var par = load("res://scripts/parallax.gd").new()
	for theme in ["plains", "caves", "forge", "towers"]:
		par.setup(theme, null)
		var name := "parallax %s 0" % theme
		ok(_md5(par.layers[0].tex.get_image()) == TS_BAKES[name], name)
	par.free()
	return true


func _md5(img: Image) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	ctx.update(img.get_data())
	return ctx.finish().hex_encode()


## Tiny level from ASCII rows, like makeLevel() in tests/helpers.ts.
func make_level(rows: Array) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.tile_set = tileset
	for y in rows.size():
		for x in rows[y].length():
			if rows[y][x] == "#":
				layer.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))
	return layer


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
		top[0] = minf(top[0], pl.position.y)
		return ["jump"] if i >= 3 and (i == 3 or pl.velocity.y < 0) else [])
	var h: float = ground - top[0]
	ok(h > TILE * 4.2 and h < TILE * 5, "full jump height %.1f tiles (TS: 4.2..5)" % (h / TILE))
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
			if pl.position.x + PLAYER_SIZE.x / 2 > 9 * TILE - 1:
				state.phase = 1
				return ["right", "jump"]
			return ["right"]
		state.phase += 1
		if state.phase > 3 and pl.is_on_floor():
			state.landed = true
			return null
		if pl.position.y > 20 * TILE or state.phase > 240: return null
		return ["right", "jump"] if pl.velocity.y < 0 or hover else ["right"])
	var crossed: bool = state.landed and p.position.x - PLAYER_SIZE.x / 2 > (9 + gap) * TILE - PLAYER_SIZE.x
	cleanup(p)
	return crossed


func climb(height: int) -> bool:
	var state := {"phase": 0, "up": false}
	var p = await simulate(step_map(height), func(i, pl):
		if i < 3: return []
		if state.phase == 0:
			if pl.position.x + PLAYER_SIZE.x / 2 > 10 * TILE - 8:
				state.phase = 1
				return ["right", "jump"]
			return ["right"]
		state.phase += 1
		if pl.is_on_floor() and pl.position.x - PLAYER_SIZE.x / 2 > 10 * TILE:
			state.up = true
			return null
		if state.phase > 120: return null
		return ["right", "jump"] if pl.velocity.y < 0 else ["right"])
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
		var start: Vector2 = m.terrain.get_node("Start").position
		if m.level_id == id and m.player.position == start:
			opened += 1
		change_scene_to_file("res://scenes/level_select.tscn")
		await scene_ready("LevelSelect")
	ok(opened == 9, "every button opens its level with the player on '@' (%d/9)" % opened)

	load("res://scripts/main.gd").start_level = "1-1"
	change_scene_to_file("res://scenes/main.tscn")
	await scene_ready("Main")
	await frames(60)
	var m = current_scene
	ok(m.player.is_on_floor() and m.player.position == m.terrain.get_node("Start").position, "1-1: player stands on '@'")
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
	p.position = Vector2(175 * TILE, 15 * TILE)
	p.invuln = 0
	var hearts: int = p.hearts
	Input.action_press("right")
	for i in 120:
		await physics_frame
		if p.hearts < hearts: break
	Input.action_release("right")
	ok(p.hearts == hearts - 1 and p.velocity.y < 0, "spike costs a heart and knocks up")
	ok(root.get_node("Game").hitstop_left > 0, "hurt triggers hitstop")
	var h2: int = p.hearts
	Input.action_press("right")
	await frames(20)
	Input.action_release("right")
	ok(p.hearts == h2, "no second hit while invulnerable")

	m.load_level("1-1")
	await frames(3)
	var bug = get_nodes_in_group("enemies")[0]
	var bug_x: float = bug.position.x
	p.position = bug.position + Vector2(-40, 0)
	p.invuln = 0
	hearts = p.hearts
	for i in 180:
		await physics_frame
		if p.hearts < hearts: break
	ok(bug.position.x != bug_x and p.hearts == hearts - 1, "bug patrols and hurts on contact")

	m.load_level("1-1")
	await frames(3)
	var n := get_nodes_in_group("enemies").size()
	bug = get_nodes_in_group("enemies")[0]
	p.position = bug.position + Vector2(0, -40)
	p.velocity = Vector2.ZERO
	p.invuln = 0
	var bounced := false
	for i in 60:
		await physics_frame
		if get_nodes_in_group("enemies").size() < n:
			bounced = p.velocity.y < 0
			break
	ok(bounced, "stomping a bug kills it and bounces")
	ok(m.particles.list.size() > 0, "stomp emits particles")

	var tokens: Array = m.terrain.get_children().filter(func(c): return c is Area2D)
	p.position = tokens[0].position + Vector2(0, 8)
	await frames(5)
	ok(not is_instance_valid(tokens[0]) or tokens[0].is_queued_for_deletion(), "touching a token collects it")

	p.hearts = 1
	p.invuln = 0
	p.hurt(p.position.x + 10)
	ok(p.hearts == p.MAX_HEARTS and p.position == m.terrain.get_node("Start").position, "losing the last heart respawns on '@'")
	return true
