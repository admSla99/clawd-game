# Explores levels with Clawd's movement and checks that the exit, every spark and every sub-agent can be reached:
# from every place he can stand it tries a set of walks and jumps (with and without hover) and sees where he lands.
# The level-design safety net that tests/reachability.test.ts was in the TS game (branch ts-legacy), on the port's
# rules: every jump is a full jump. Enemies are ignored, moving platforms and rate limiters are sampled as static
# ones along their path, and corrupted blocks count as already pounded through. Boss levels are skipped.
# The movement is a tile-based model of scripts/player.gd (its constants are read from it); the real player
# collides through move_and_slide(), so a target found here is reachable within a pixel or so.
# Run from godot/: godot --headless --script tools/reach.gd [-- <id>...]   (no ids = every level)
extends SceneTree

const TILE := 16.0
const STEP := 1.0 / 60
const EPS := 0.001
const W := 18.0
const H := 18.0
enum { EMPTY, SOLID, ONEWAY, SPIKE }

var K: Dictionary # scripts/player.gd's constants
var rows: PackedStringArray
var width := 0
var height := 0
var platforms: Array = [] # [x, y, w]


func _init() -> void:
	# scripts/player.gd uses the Game autoload, which exists only after the first frame.
	await process_frame
	K = load("res://scripts/player.gd").get_script_constant_map()
	assert(K.has("JUMP_VELOCITY"))
	var index: Array = JSON.parse_string(FileAccess.get_file_as_string("res://levels/index.json"))
	var ids := Array(OS.get_cmdline_user_args())
	if ids.is_empty():
		ids = index.filter(func(l): return not l.has("boss")).map(func(l): return l.id)
	var failed := false
	for id in ids:
		var t0 := Time.get_ticks_msec()
		var missing := check_level(id)
		var took := (Time.get_ticks_msec() - t0) / 1000.0
		if missing.is_empty():
			print("PASS %s: exit, every spark and every sub-agent can be reached (%.1f s)" % [id, took])
		else:
			print("FAIL %s: can't reach %s (%.1f s)" % [id, ", ".join(missing), took])
			failed = true
	quit(1 if failed else 0)


func check_level(id: String) -> Array:
	rows = FileAccess.get_file_as_string("res://levels/%s.txt" % id).trim_suffix("\n").split("\n")
	height = rows.size()
	width = 0
	for r in rows:
		width = maxi(width, r.length())
	platforms = []
	var start := Vector2.ZERO
	var targets := {} # name -> Rect2
	var counts := {"S": 0, "A": 0}
	for ty in height:
		for tx in rows[ty].length():
			var ch := rows[ty][tx]
			var x := tx * TILE + TILE / 2
			var y := (ty + 1) * TILE
			match ch:
				"@":
					start = Vector2(x, y)
				"S":
					targets["spark#%d (%d,%d)" % [counts.S, tx, ty]] = Rect2(x - 7, y - 15, 14, 14)
					counts.S += 1
				"A":
					targets["agent#%d (%d,%d)" % [counts.A, tx, ty]] = Rect2(x - 7, y - 12, 14, 12)
					counts.A += 1
				"G":
					targets["goal"] = Rect2(x - 8, y - 40, 16, 40)
				"M":
					for o in [-3.5, -1.75, 0.0, 1.75, 3.5]:
						platforms.append([x - 24 + o * TILE, ty * TILE, 48.0])
				"V":
					for o in [-3.5, -1.75, 0.0, 1.75, 3.5]:
						platforms.append([x - 24, ty * TILE + o * TILE, 48.0])
				"R":
					# Its top rides from the floor back up to where it hangs.
					var floor_y := ty + 2
					while floor_y < height and tile(tx, floor_y) != SOLID:
						floor_y += 1
					var py := ty * TILE
					while py <= (floor_y - 2) * TILE:
						platforms.append([tx * TILE, py, 32.0])
						py += TILE / 2
	var reached := explore(start, targets)
	return targets.keys().filter(func(n): return not reached.has(n))


## The tile at (tx, ty): SOLID left and right of the map, EMPTY above and below it; corrupted blocks are EMPTY.
func tile(tx: int, ty: int) -> int:
	if tx < 0 or tx >= width:
		return SOLID
	if ty < 0 or ty >= height or tx >= rows[ty].length():
		return EMPTY
	match rows[ty][tx]:
		"#":
			return SOLID
		"=":
			return ONEWAY
		"^":
			return SPIKE
	return EMPTY


# --- Plans: per stage [frames, func(frame, body) -> Array of held actions] ----------------------------------------

func plans(dir: String) -> Array:
	var hold := func(n: int, acts: Array) -> Array: return [n, func(_f, _b): return acts]
	var until_apex := func(d: String, hover: bool) -> Array:
		return [260, func(_f, b):
			var a := [] if d == "" else [d]
			if b.vy < 0 or hover:
				a.append("jump")
			return a]
	return [
		[hold.call(6, [dir])],
		[hold.call(14, [dir])],
		[hold.call(30, [dir])],
		# Standing jumps, with and without hover.
		[hold.call(1, [dir, "jump"]), until_apex.call(dir, false)],
		[hold.call(1, [dir, "jump"]), until_apex.call(dir, true)],
		[hold.call(5, [dir, "jump"]), [260, func(_f, _b): return [dir]]],
		# Running jumps.
		[hold.call(12, [dir]), hold.call(1, [dir, "jump"]), until_apex.call(dir, false)],
		[hold.call(12, [dir]), hold.call(1, [dir, "jump"]), until_apex.call(dir, true)],
		# Jump straight up, drift later.
		[hold.call(1, ["jump"]), hold.call(14, ["jump"]), until_apex.call(dir, false)],
		[hold.call(1, ["jump"]), hold.call(14, ["jump"]), until_apex.call(dir, true)],
		# Short hop then hover drift.
		[hold.call(1, [dir, "jump"]), hold.call(8, [dir, "jump"]), until_apex.call(dir, true)],
	]


func explore(start: Vector2, targets: Dictionary) -> Dictionary:
	var reached := {}
	var seen := {}
	var queue: Array = [start]
	var key := func(x: float, bottom: float) -> Vector2i: return Vector2i(roundi(x / 6), roundi(bottom))
	seen[key.call(start.x, start.y)] = true
	var budget := 6000
	var all_plans := {"left": plans("left"), "right": plans("right")}
	while not queue.is_empty() and budget > 0:
		budget -= 1
		var s: Vector2 = queue.pop_front()
		for dir in ["left", "right"]:
			for plan in all_plans[dir]:
				var b := Body.new(s.x, s.y, K)
				b.step([], self)
				if not b.grounded:
					break
				var dead := false
				var was_air := false
				var stages: Array = plan + [[200, func(_f, _b): return []]]
				var done := false
				for si in stages.size():
					var stage: Array = stages[si]
					for i in stage[0]:
						b.step(stage[1].call(i, b), self)
						if b.y > height * TILE + 20 or touches(Rect2(b.x + 1, b.y + H - 6, W - 2, 6), SPIKE):
							dead = true
							done = true
							break
						var hb := Rect2(b.x + 2, b.y + 3, W - 4, H - 3)
						for n in targets:
							if not reached.has(n) and hb.intersects(targets[n]):
								reached[n] = true
						if not b.grounded:
							was_air = true
						# A jump ends when Clawd lands; walks run their full length.
						if b.grounded and (was_air or si == stages.size() - 1):
							done = true
							break
					if done:
						break
				var k: Vector2i = key.call(b.x + W / 2, b.y + H)
				if not dead and b.grounded and not seen.has(k):
					seen[k] = true
					queue.append(Vector2(b.x + W / 2, b.y + H))
		if reached.size() == targets.size():
			break
	return reached


func touches(r: Rect2, kind: int) -> bool:
	for ty in range(floori(r.position.y / TILE), floori((r.end.y - EPS) / TILE) + 1):
		for tx in range(floori(r.position.x / TILE), floori((r.end.x - EPS) / TILE) + 1):
			if tile(tx, ty) == kind:
				return true
	return false


func hits_solid(x: float, y: float) -> bool:
	for ty in range(floori(y / TILE), floori((y + H - EPS) / TILE) + 1):
		for tx in range(floori(x / TILE), floori((x + W - EPS) / TILE) + 1):
			if tile(tx, ty) == SOLID:
				return true
	return false


## Clawd's body: Player.update() from src/entities/player.ts on the port's rules (no jump cut), x / y its top-left.
class Body:
	var k: Dictionary
	var x: float
	var y: float
	var prev_y: float
	var vx := 0.0
	var vy := 0.0
	var grounded := false
	var on_one_way := false
	var coyote := 0.0
	var jump_buffer := 0.0
	var hover_left: float
	var drop_timer := 0.0
	var riding = null
	var held: Array = []

	func _init(feet_x: float, bottom: float, constants: Dictionary) -> void:
		k = constants
		x = feet_x - W / 2
		y = bottom - H
		prev_y = y
		hover_left = k.HOVER_DURATION

	func step(acts: Array, r) -> void:
		var pressed := func(a: String) -> bool: return acts.has(a) and not held.has(a)
		prev_y = y
		drop_timer -= STEP
		jump_buffer = maxf(0.0, jump_buffer - STEP)
		if pressed.call("jump"):
			jump_buffer = k.JUMP_BUFFER
		if riding != null and (x + W <= riding[0] or x >= riding[0] + riding[2]):
			riding = null
		if grounded:
			coyote = k.COYOTE_TIME
			hover_left = k.HOVER_DURATION
		else:
			coyote = maxf(0.0, coyote - STEP)
		var dir := (1.0 if acts.has("right") else 0.0) - (1.0 if acts.has("left") else 0.0)
		var accel: float
		if grounded:
			if dir == 0:
				accel = k.GROUND_DECEL
			elif vx != 0 and signf(vx) != dir:
				accel = k.TURN_ACCEL
			else:
				accel = k.GROUND_ACCEL
		else:
			accel = k.AIR_DECEL if dir == 0 else k.AIR_ACCEL
		vx = move_toward(vx, dir * k.RUN_SPEED, accel * STEP)
		if grounded and on_one_way and acts.has("down") and jump_buffer > 0:
			drop_timer = k.DROP_THROUGH_TIME
			jump_buffer = 0.0
			grounded = false
			riding = null
			coyote = 0.0
			y += 1
		elif jump_buffer > 0 and (grounded or coyote > 0):
			vy = -k.JUMP_VELOCITY
			grounded = false
			coyote = 0.0
			jump_buffer = 0.0
			riding = null
		var hovering: bool = not grounded and coyote <= 0 and hover_left > 0 and acts.has("jump") and vy > -40
		if hovering:
			hover_left -= STEP
			vy = move_toward(vy, k.HOVER_FALL_SPEED, k.HOVER_ACCEL * STEP)
		else:
			var g: float = k.GRAVITY
			if absf(vy) < k.APEX_THRESHOLD and acts.has("jump"):
				g *= k.APEX_GRAVITY_MULT
			elif vy > 0:
				g *= k.FALL_GRAVITY_MULT
			vy = minf(vy + g * STEP, k.MAX_FALL)
		held = acts
		if _move_x(vx * STEP, r):
			vx = 0.0
		var dy := vy * STEP
		if dy < 0:
			_corner_correct(dy, r)
		var res := _move_y(dy, r)
		if res.ceiling:
			vy = 0.0
		var landed: bool = res.floor
		var one_way: bool = res.one_way
		riding = null
		if not landed and vy >= 0 and drop_timer <= 0:
			for p in r.platforms:
				if x + W <= p[0] or x >= p[0] + p[2]:
					continue
				if prev_y + H <= p[1] + 1.5 and y + H >= p[1]:
					y = p[1] - H
					landed = true
					one_way = true
					riding = p
					break
		if landed:
			vy = 0.0
			grounded = true
			on_one_way = one_way
		else:
			grounded = false

	func _corner_correct(dy: float, r) -> void:
		if not r.hits_solid(x, y + dy):
			return
		for off in range(1, k.CORNER_CORRECTION + 1):
			for s in [1, -1]:
				var nx: float = x + off * s
				if not r.hits_solid(nx, y + dy) and not r.hits_solid(nx, y):
					x = nx
					return

	func _move_x(dx: float, r) -> bool:
		if dx == 0:
			return false
		var y0 := floori(y / TILE)
		var y1 := floori((y + H - EPS) / TILE)
		var tx := floori((x + W + dx - EPS) / TILE) if dx > 0 else floori((x + dx) / TILE)
		for ty in range(y0, y1 + 1):
			if r.tile(tx, ty) == SOLID:
				x = tx * TILE - W if dx > 0 else (tx + 1) * TILE
				return true
		x += dx
		return false

	func _move_y(dy: float, r) -> Dictionary:
		var res := {"floor": false, "ceiling": false, "one_way": false}
		if dy == 0:
			return res
		var x0 := floori(x / TILE)
		var x1 := floori((x + W - EPS) / TILE)
		if dy > 0:
			var bottom := y + H
			var ty := floori((bottom + dy - EPS) / TILE)
			var top := ty * TILE
			var any_solid := false
			for tx in range(x0, x1 + 1):
				var t: int = r.tile(tx, ty)
				if t == SOLID:
					any_solid = true
					res.floor = true
				elif t == ONEWAY and drop_timer <= 0 and bottom <= top + EPS:
					res.floor = true
			if res.floor:
				y = top - H
				res.one_way = not any_solid
				return res
		else:
			var ty := floori((y + dy) / TILE)
			for tx in range(x0, x1 + 1):
				if r.tile(tx, ty) == SOLID:
					y = (ty + 1) * TILE
					res.ceiling = true
					return res
		y += dy
		return res
