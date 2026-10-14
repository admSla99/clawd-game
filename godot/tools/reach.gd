# Explores levels with Clawd's movement and checks that the exit, every spark and every sub-agent can be reached:
# from every place he can stand it tries a set of walks and jumps (with and without hover) and sees where he lands.
# The level-design safety net that tests/reachability.test.ts was in the TS game (branch ts-legacy), on the
# game's rules: every jump is a full jump. Enemies are ignored, moving platforms and rate limiters are sampled as
# static ones along their path, corrupted and brittle blocks count as already broken, and gates as open (their
# puzzles have check sections of their own). Boss levels are skipped.
# World 3's anchors (`+`, `*`): from where he stands, and at the top of a jump, Clawd throws the Tool Call at every
# anchor in reach and in sight and zips there (scripts/tool_call.gd, Player._zip()); after the hop off an anchor he
# drifts (with and without hover) or zips on to the next anchor, so chains of anchors over a chasm count. A Webhook
# (`W`) counts as an anchor where it spawns. In levels with `subAgents` in index.json Clawd may also stand on a
# sub-agent (scripts/echo.gd) he left where he stood: every jump is tried from 18 px higher too.
# The movement is a tile-based model of scripts/player.gd (its constants are read from it and from tool_call.gd);
# the real player collides through move_and_slide(), so a target found here is reachable within a pixel or so.
# Run from godot/: godot --headless --script tools/reach.gd [-- <id>...]   (no ids = every level)
extends SceneTree

const TILE := 16.0
const STEP := 1.0 / 60
const EPS := 0.001
const W := 18.0
const H := 18.0
enum { EMPTY, SOLID, ONEWAY, SPIKE }

var K: Dictionary # scripts/player.gd's constants
var T: Dictionary # scripts/tool_call.gd's
var rows: PackedStringArray
var width := 0
var height := 0
var platforms: Array = [] # [x, y, w]
var anchors: Array[Vector2] = [] # the middles of the anchors' tiles
var targets := {} # name -> Rect2
var reached := {}
## Clawd can stand on his sub-agents in this level (index.json `subAgents`).
var echo_boost := false


func _init() -> void:
	# scripts/player.gd uses the Game autoload, which exists only after the first frame.
	await process_frame
	K = load("res://scripts/player.gd").get_script_constant_map()
	T = load("res://scripts/tool_call.gd").get_script_constant_map()
	assert(K.has("JUMP_VELOCITY") and K.has("ZIP_SPEED") and T.has("REACH"))
	var index: Array = JSON.parse_string(FileAccess.get_file_as_string("res://levels/index.json"))
	var ids := Array(OS.get_cmdline_user_args())
	if ids.is_empty():
		ids = index.filter(func(l): return not l.has("boss")).map(func(l): return l.id)
	var failed := false
	for id in ids:
		var t0 := Time.get_ticks_msec()
		var info: Array = index.filter(func(l): return l.id == id)
		echo_boost = not info.is_empty() and info[0].get("subAgents", false) == true
		var missing := check_level(id)
		var took := (Time.get_ticks_msec() - t0) / 1000.0
		if missing.is_empty():
			print("PASS %s: exit, every spark and every sub-agent can be reached (%.1f s)" % [id, took])
		else:
			print("FAIL %s: can't reach %s (%.1f s)" % [id, ", ".join(missing), took])
			failed = true
	quit(1 if failed else 0)


func check_level(id: String) -> Array:
	rows = FileAccess.get_file_as_string("res://levels/%s.txt" % id).replace("\r", "").trim_suffix("\n").split("\n")
	height = rows.size()
	width = 0
	for r in rows:
		width = maxi(width, r.length())
	platforms = []
	anchors = []
	targets = {}
	reached = {}
	var start := Vector2.ZERO
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
				"+", "*", "W":
					anchors.append(Vector2(x, y - TILE / 2))
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
	explore(start)
	return targets.keys().filter(func(n): return not reached.has(n))


## The tile at (tx, ty): SOLID left and right of the map, EMPTY above and below it; corrupted and brittle blocks,
## plates and gates are EMPTY.
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


## Drifts after the hop off an anchor: no key, or a side, each with and without hover.
func drifts() -> Array:
	var out := []
	for d in ["", "left", "right"]:
		for hover in [false, true]:
			out.append([[300, func(_f, b):
				var a := [] if d == "" else [d]
				if b.vy < 0 or hover:
					a.append("jump")
				return a]])
	return out


## Runs `plan` on `b` until he lands (a walk runs its full length): the Body where he stands, or null when he died
## or is still in the air. Marks the targets he touches.
func run(b: Body, plan: Array) -> Body:
	var was_air := not b.grounded
	var stages: Array = plan + [[200, func(_f, _b): return []]]
	for si in stages.size():
		var stage: Array = stages[si]
		for i in stage[0]:
			b.step(stage[1].call(i, b), self)
			if dead(b):
				return null
			touch(b)
			if not b.grounded:
				was_air = true
			if b.grounded and (was_air or si == stages.size() - 1):
				return b
	return b if b.grounded else null


func dead(b: Body) -> bool:
	return b.y > height * TILE + 20 or touches(Rect2(b.x + 1, b.y + H - 6, W - 2, 6), SPIKE)


func touch(b: Body) -> void:
	var hb := Rect2(b.x + 2, b.y + 3, W - 4, H - 3)
	for n in targets:
		if not reached.has(n) and hb.intersects(targets[n]):
			reached[n] = true


## The anchors the hook can catch from `b` now: in reach of his hand and in sight.
func anchors_from(b: Body) -> Array:
	var hand := Vector2(b.x + W / 2, b.y + H - 9)
	var out := []
	for i in anchors.size():
		if hand.distance_to(anchors[i]) <= T.REACH and clear_line(hand, anchors[i]):
			out.append(i)
	return out


func clear_line(a: Vector2, b: Vector2) -> bool:
	var n := ceili(a.distance_to(b) / 4.0)
	for i in range(1, n):
		var p := a.lerp(b, float(i) / n)
		if tile(floori(p.x / TILE), floori(p.y / TILE)) == SOLID:
			return false
	return true


## Zips `b` to anchor `i`: true when he got there (then he has hopped off it).
func zip(b: Body, i: int) -> bool:
	var target := anchors[i] + Vector2(0, T.ZIP_BELOW)
	var t := 0.0
	while t < K.ZIP_MAX_TIME:
		t += STEP
		var feet := Vector2(b.x + W / 2, b.y + H)
		var to := target - feet
		var d: Vector2 = to if to.length() <= K.ZIP_SPEED * STEP else to.normalized() * K.ZIP_SPEED * STEP
		var x0 := b.x
		var y0 := b.y
		b._move_x(d.x, self)
		b._move_y(d.y, self)
		if dead(b):
			return false
		touch(b)
		if to.length() <= K.ZIP_SPEED * STEP:
			break
		if Vector2(b.x - x0, b.y - y0).length() < d.length() * 0.3:
			return false
	b.vx = 0.0
	b.vy = -K.ZIP_POP
	b.grounded = false
	b.coyote = 0.0
	b.hover_left = K.HOVER_DURATION
	b.held = []
	return true


func explore(start: Vector2) -> void:
	var seen := {}
	var seen_anchor := {}
	# Entries: Vector2 = feet where he stands; int = the anchor he just hopped off.
	var queue: Array = [start]
	var key := func(x: float, bottom: float) -> Vector2i: return Vector2i(roundi(x / 6), roundi(bottom))
	seen[key.call(start.x, start.y)] = true
	var budget := 6000
	var all_plans := {"left": plans("left"), "right": plans("right")}
	var after := drifts()
	var enqueue := func(b: Body) -> void:
		if b == null or not b.grounded:
			return
		var k: Vector2i = key.call(b.x + W / 2, b.y + H)
		if not seen.has(k):
			seen[k] = true
			queue.append(Vector2(b.x + W / 2, b.y + H))
	var enqueue_anchor := func(i: int) -> void:
		if not seen_anchor.has(i):
			seen_anchor[i] = true
			queue.append(i)
	while not queue.is_empty() and budget > 0:
		budget -= 1
		var entry = queue.pop_front()
		if entry is int:
			# Hopped off anchor `entry`: drift down, or zip on from the hop.
			var at := anchors[entry] + Vector2(0, T.ZIP_BELOW)
			for plan in after:
				enqueue.call(run(Body.at_anchor(at, K), plan))
			var hop := Body.at_anchor(at, K)
			for f in 12:
				hop.step(["jump"], self)
			for i in anchors_from(hop):
				if i != entry and zip(Body.at_anchor(at, K).copy_from(hop), i):
					enqueue_anchor.call(i)
			continue
		var s: Vector2 = entry
		var probe := Body.new(s.x, s.y, K)
		probe.step([], self)
		if not probe.grounded:
			continue
		for dir in ["left", "right"]:
			for plan in all_plans[dir]:
				var b := Body.new(s.x, s.y, K)
				b.step([], self)
				enqueue.call(run(b, plan))
		# Standing on a sub-agent left where he stood: the same jumps from its top.
		if echo_boost:
			var top := [s.x - W / 2, s.y - H, W]
			platforms.append(top)
			for dir in ["left", "right"]:
				for plan in all_plans[dir].slice(3):
					var b := Body.new(s.x, s.y - H, K)
					b.step([], self)
					if b.grounded:
						enqueue.call(run(b, plan))
			platforms.erase(top)
		# The Tool Call, standing and at the top of a full jump.
		if not anchors.is_empty():
			for i in anchors_from(probe):
				var b := Body.new(s.x, s.y, K)
				b.step([], self)
				if zip(b, i):
					enqueue_anchor.call(i)
			var apex := Body.new(s.x, s.y, K)
			apex.step([], self)
			apex.step(["jump"], self)
			while apex.vy < 0:
				apex.step(["jump"], self)
			for i in anchors_from(apex):
				var b := Body.new(s.x, s.y, K).copy_from(apex)
				if zip(b, i):
					enqueue_anchor.call(i)
		if reached.size() == targets.size():
			break


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


## Clawd's body: Player.update() from src/entities/player.ts on the game's rules (no jump cut), x / y its top-left.
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

	## Just hopped off an anchor, his feet at `feet`.
	static func at_anchor(feet: Vector2, constants: Dictionary) -> Body:
		var b := Body.new(feet.x, feet.y, constants)
		b.vy = -constants.ZIP_POP
		return b

	func copy_from(o: Body) -> Body:
		x = o.x
		y = o.y
		prev_y = o.prev_y
		vx = o.vx
		vy = o.vy
		grounded = o.grounded
		on_one_way = o.on_one_way
		coyote = o.coyote
		jump_buffer = o.jump_buffer
		hover_left = o.hover_left
		drop_timer = o.drop_timer
		held = o.held.duplicate()
		return self

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
