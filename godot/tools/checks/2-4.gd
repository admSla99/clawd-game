extends RefCounted

## 2-4 The Diff Towers (a section of tools/check.gd, which runs every tools/checks/<id>.gd; `c` is check.gd:
## c.ok(), await c.frames(), c.current_scene, c.enemies_of(), c.bugs(), await c.drive(), ...). A climb up a shaft of
## one-way platforms: the real player with full jumps hops from support to support all the way to the exit.

const TITLE := "2-4 The Diff Towers: the transformer-stack motif, armed start and the full-jump climb"
const TILE := 16


func run(c) -> bool:
	var m = c.current_scene
	var p = m.player
	m.load_level("2-4")
	await c.frames(3)
	c.ok(m.info.theme == "towers" and int(m.info.world) == 2, "2-4 is in world 2, in the towers theme")
	c.ok(m.motif.visible and m.motif.material.shader.resource_path.ends_with("motif_towers.gdshader"),
		"the towers motif (transformer stacks with a residual stream) is behind the level")
	var pal: Dictionary = load("res://scripts/themes.gd").palette("towers")
	c.ok(m.motif.material.get_shader_parameter("haze_color") == Vector3(pal.haze.r, pal.haze.g, pal.haze.b)
		and m.motif.material.get_shader_parameter("line_color") == Vector3(pal.ray.r, pal.ray.g, pal.ray.b),
		"in the theme's haze, with the stream in its ray colour")
	c.ok(m.motif_3d == null, "and no 3D motif")
	c.ok(m.parallax.theme == "towers" and m.parallax.layers.size() == 1,
		"the parallax keeps its own towers background (the dotted columns and the data rain) in front of it")
	c.ok(p.armed and m.gun.armed, "Clawd starts armed")
	c.ok(c.enemies_of("res://scripts/shield_bot.gd").size() == 3 and c.enemies_of("res://scripts/drone.gd").size() == 4
		and c.enemies_of("res://scripts/turret.gd").size() == 4 and c.enemies_of("res://scripts/spam_bot.gd").size() == 2
		and c.bugs().is_empty(), "its enemies: 3 shield bots, 4 drones, 4 turrets, 2 spam bots, no bugs")
	var sign_script := load("res://scripts/sign.gd")
	var signs: Array = m.level.get_children().filter(func(n): return n.get_script() == sign_script)
	c.ok(signs.size() == 1 and signs[0].text.begins_with("CLIMB THE DIFF TOWERS"),
		"its sign keeps the TS text (↓ in the air aims down in the port too)")

	# Full jumps fit the map: there are no ceilings or spikes, so the climb is a chain of hops between one-way
	# platforms 3 rows apart (2 at the top). Each hop runs towards the next support up, taps jump once and steers.
	for e in c.get_nodes_in_group("enemies"):
		e.remove()
	await c.frames(2)
	p.invuln = 1000
	await c.frames(30)
	var scroll0: Vector2 = m.motif.material.get_shader_parameter("scroll")
	var plats := _platforms()
	var row := 92
	var hops := 0
	var fails := 0
	while row > 3:
		var next := _next_above(plats, row)
		if await _hop(c, p, next):
			hops += 1
			row = next[2]
		else:
			fails += 1
			break
	c.ok(row == 3 and fails == 0, "the real player climbs from the start to the exit's floor with tapped (full) jumps, %d hops" % hops)
	await c.frames(60)
	await c.process_frame
	await c.process_frame
	var scroll: Vector2 = m.motif.material.get_shader_parameter("scroll")
	c.ok(scroll.y < scroll0.y - 800 and scroll.distance_to(m.camera.top_left) < 2,
		"the motif follows the camera on both axes (scroll y %d at the start, %d at the top)" % [scroll0.y, scroll.y])

	# Then on to the exit, which ends the level.
	var goal := {"t": -1.0, "x": m.level.get_node("Goal").feet().x}
	await c.drive(func(_i):
		goal.t = m.complete_t
		if goal.t >= 0:
			return null
		return ["right"] if p.pos.x < goal.x else ["left"], 240)
	c.ok(goal.t >= 0, "and walks into the exit")
	m.load_level("2-4")
	await c.frames(3)
	for e in c.get_nodes_in_group("enemies"):
		e.remove()
	p.invuln = 1000

	# One-way platforms two rows apart (rows 3 and 5 by the exit): falling with the head still in row 3's tile, Clawd
	# lands on row 5 (only a tile's top strip collides, player.gd _in_one_way_strip()).
	p.pos = Vector2(260, 62)
	p.vel = Vector2(0, 100)
	await c.frames(20)
	c.ok(p.on_ground and absf(p.pos.y - 5 * TILE) < 0.5, "a fall with the head in row 3's platform lands on row 5's")

	# The sub-agents on the two ledges by the walls: from the left platform of row 44 to the ledge at row 41, and from
	# the right platform of row 62 to the ledge at row 59.
	for leg in [[44, 41, 2], [62, 59, 36]]:
		var from: Array = plats.filter(func(s): return s[2] == leg[0])[0]
		var to: Array = plats.filter(func(s): return s[2] == leg[1] and s[0] == leg[2] * TILE)[0]
		p.pos = Vector2((from[0] + from[1]) / 2, leg[0] * TILE)
		p.vel = Vector2.ZERO
		await c.frames(10)
		c.ok(await _hop(c, p, to), "a full jump reaches the sub-agent's ledge at row %d" % leg[1])
	c.ok(m.agents.count(true) == 2, "and both sub-agents are picked up")
	return true


## The one-way platforms of levels/2-4.txt as [left px, right px, row] (their top is row * TILE).
func _platforms() -> Array:
	var out := []
	var lines := FileAccess.get_file_as_string("res://levels/2-4.txt").split("\n")
	for y in lines.size():
		var line: String = lines[y].strip_edges(false, true)
		var x := 0
		while x < line.length():
			if line[x] == "=":
				var x0 := x
				while x < line.length() and line[x] == "=":
					x += 1
				out.append([x0 * TILE, x * TILE, y])
			else:
				x += 1
	return out


## The support a climber at `row` goes for: the nearest row above, its widest platform there (not a ledge).
func _next_above(plats: Array, row: int) -> Array:
	var best := []
	for s in plats:
		if s[2] < row and (best.is_empty() or s[2] > best[2] or (s[2] == best[2] and s[1] - s[0] > best[1] - best[0])):
			best = s
	return best


## Hops onto support `to` ([left, right, row]): runs until it is within reach, presses jump and lets go in the air
## (every jump is a full jump, and no hover), steers to a point 12 px inside it and returns whether Clawd lands on it.
func _hop(c, p, to: Array) -> bool:
	var top: float = to[2] * TILE
	var st := {"air": false, "landed": false}
	await c.drive(func(_i):
		var tx: float = clampf(p.pos.x, to[0] + 12, to[1] - 12)
		var dx: float = tx - p.pos.x
		var side := ["right"] if dx > 3 else (["left"] if dx < -3 else [])
		if not p.on_ground:
			st.air = true
			return side
		if st.air:
			st.landed = absf(p.pos.y - top) < 0.5 and p.pos.x > to[0] - 9 and p.pos.x < to[1] + 9
			return null
		return side if absf(dx) > 48 else side + ["jump"], 300)
	return st.landed
