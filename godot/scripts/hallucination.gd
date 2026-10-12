class_name Hallucination
extends Enemy

## World 1's boss from src/entities/boss/hallucination.ts (1-B): a glitching cloud of dots. It teleports
## between three anchors away from Clawd, attacks (radial bursts of white shots, a rain of red shots onto
## warnings on the floor, fake platforms with a ring of cyan shots), then sinks to the floor dazed: only then
## can a stomp, spin, the jet or a pound hit it (3 hits, each phase faster). Its last hit starts a 2.2 s death,
## then Main.boss_defeated() drops the Token Blaster.
## Drawn in 2.5D: the 2D rings of 2 px dots (radius 3, 6, ... 15, floor(r * 1.1) dots each, turning alternately
## left and right, the outer one wobbling) each rock in depth about their own tilted axis, never edge-on, with a
## red and a cyan copy 2 px to the sides (the 2D chromatic split); red eyes at the front that flash white before an attack, crosses and three orange dots
## orbiting in depth while it is dazed. It fades in (intro, appear) by showing more of its dots.

const MAX_HP := 3
const SIZE := Vector2(34, 34)
const TITLE := "THE HALLUCINATION"
const SUBTITLE := "confidently wrong since forever"
const GREY := Color8(225, 225, 225)
const DAZED := Color8(120, 120, 120)
const RED := Color("#E0605A")
const RED_DARK := Color("#8F3A37")
const CYAN := Color("#5FD0D8")
const ORANGE := Color("#D97757")
const ORANGE_LIGHT := Color("#F0A585")
const WHITE_SHOT := Color("#E6E6E6")
## Ring radii in px (the 2D rings: 3, 6, ... R).
const SHELLS := [3.0, 6.0, 9.0, 12.0, 15.0]
## Eyes 9 px in front of the centre, lifted 3 px against the oblique shift (z / 3).
const EYE_Z := 9.0
const EYES := ["RRRR......RRRR", "RWRR......RWRR", "RRRR......RRRR", "RRRR......RRRR", "RRRR......RRRR"]
const DIZZY := [".X.X.......X.X", "..X.........X.", ".X.X.......X.X"]
## Its own material: the eyes sit in front of the see-through windows' REVEAL_FRONT.
static var MATERIAL := Voxel.material()
static var EYES_MESH := Voxel.mesh(EYES, {"R": RED, "W": Color.WHITE}, {"R": 2, "W": 2}, Px.M, MATERIAL)
static var EYES_FLASH := Voxel.mesh(EYES, {"R": Color.WHITE, "W": Color.WHITE}, {"R": 2, "W": 2}, Px.M, MATERIAL)
static var DIZZY_MESH := Voxel.mesh(DIZZY, {"X": Color8(220, 220, 220)}, {"X": 2}, Px.M, MATERIAL)
static var ORBIT_MESH := Voxel.mesh(["oo", "oo"], {"o": ORANGE_LIGHT}, {"o": 2}, Px.M, Voxel.material(1.6))
static var MARK_MESHES := [
	Voxel.mesh(["...rr...", "...rr...", "...rr...", "........", "rrrrrrrr"], {"r": RED}, {"r": 4}, Px.M, Voxel.material(1.5)),
	Voxel.mesh(["...rr...", "...rr...", "...rr...", "........", "rrrrrrrr"], {"r": RED_DARK}, {"r": 4}, Px.M, MATERIAL),
]

var max_hp := MAX_HP
var mode := &"intro"
var timer := 2.2
var t := 0.0
var attack_index := 0
var volley := 0
## Centre and where it glides to, level pixels.
var cx := 0.0
var cy := 0.0
var tx := 0.0
var ty := 0.0
## Floor warnings of the rain attack: {x, t}.
var warnings: Array = []
## 0..1 how much of it is there (TS `visible`).
var shown := 0.0
var floor_y := 0.0
var arena_w := 0.0
var _dirs: Array = [] # per dot: [ring, angle on the ring]
var _dots: Array[MultiMeshInstance3D] = []
var _eyes: MeshInstance3D
var _orbit: Array[MeshInstance3D] = []
var _marks: Array[MeshInstance3D] = []


## The boss centred at `centre` (level pixels) over a floor at `floor_top`, in an arena `width` px wide.
static func create(parent: Level, centre: Vector2, floor_top: float, width: float) -> Hallucination:
	var b := Hallucination.new()
	b.name = "Hallucination"
	b.cx = centre.x
	b.cy = centre.y
	b.tx = centre.x
	b.ty = centre.y
	b.floor_y = floor_top
	b.arena_w = width
	b.position = Px.to3(centre + Vector2(0, SIZE.y / 2))
	parent.add_child(b, true)
	return b


func _init() -> void:
	size = SIZE
	hp = MAX_HP
	invincible = true
	stompable = false
	tokens = 0
	collision_layer = 0
	collision_mask = 0


func _ready() -> void:
	super()
	add_to_group("world_text")
	# The 2D rings' dots: floor(r * 1.1) per ring, evenly round it.
	for s in SHELLS.size():
		var n := floori(SHELLS[s] * 1.1)
		for i in n:
			_dirs.append([s, float(i) / n * TAU])
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/particles.gdshader")
	var box := BoxMesh.new()
	box.size = Vector3.ONE * 2 * Px.M
	box.material = mat
	for k in 3:
		var mm := MultiMeshInstance3D.new()
		mm.multimesh = MultiMesh.new()
		mm.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		mm.multimesh.use_colors = true
		mm.multimesh.mesh = box
		mm.multimesh.instance_count = _dirs.size()
		mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mm.extra_cull_margin = 4.0
		add_child(mm)
		_dots.append(mm)
	_eyes = MeshInstance3D.new()
	add_child(_eyes)
	for i in 3:
		var o := MeshInstance3D.new()
		o.mesh = ORBIT_MESH
		add_child(o)
		_orbit.append(o)
	_update_visual()


func _physics_process(dt: float) -> void:
	if Game.frozen():
		return
	tick(dt)
	t += dt
	timer -= dt
	for w in warnings:
		w.t -= dt
	warnings = warnings.filter(func(w: Dictionary) -> bool: return w.t > -0.2)
	# Glide towards the target.
	var k := minf(1.0, dt * (5.0 if mode == &"descend" else 8.0))
	cx += (tx - cx) * k
	cy += (ty - cy) * k
	var speed_up := 1.0 + phase() * 0.25
	match mode:
		&"intro":
			shown = minf(1.0, shown + dt * 0.8)
			if timer <= 0:
				_next(&"attack", 0.6)
		&"appear":
			shown = minf(1.0, shown + dt * 3)
			if timer <= 0:
				_next(&"attack", 0.5)
		&"attack":
			if timer <= 0:
				_attack(speed_up)
		&"descend":
			if absf(cy - ty) < 3:
				mode = &"vulnerable"
				timer = maxf(1.6, 2.8 - phase() * 0.4)
				stompable = true
				invincible = false
		&"vulnerable":
			cy = ty + sin(t * 3) * 1.5
			if randf() < dt * 8:
				Fx.burst(self, Vector2(cx + randf_range(-10, 10), cy - SIZE.y / 2), {count = 1, speed = 10, vy = -20, life = 0.6, color = [Color8(180, 180, 180)]})
			if timer <= 0:
				_vanish()
		&"hurt":
			cx += sin(t * 80) * 0.8
			if timer <= 0:
				_vanish()
		&"vanish":
			shown = maxf(0.0, shown - dt * 4)
			if timer <= 0:
				_pick_anchor()
				cx = tx
				cy = ty
				mode = &"appear"
				timer = 0.6
				Sound.play("bossTeleport")
		&"dead":
			var main := get_tree().get_first_node_in_group("main")
			if randf() < dt * 30:
				Fx.burst(self, Vector2(cx + randf_range(-15, 15), cy + randf_range(-15, 15)), {count = 6, speed = 120, life = 0.6, color = [Color.WHITE, RED, CYAN, ORANGE], size = 1.5})
				if main:
					main.shake(0.06)
			shown = maxf(0.0, timer / 2.2)
			if timer <= 0:
				Fx.burst(self, Vector2(cx, cy), {count = 120, speed = 220, life = 1.2, color = [Color.WHITE, ORANGE, ORANGE_LIGHT], size = 2, drag = 1.5})
				if main:
					main.shake(0.8)
					main.boss_defeated(self, Vector2(cx, floor_y))
				remove()
				return
	pos = Vector2(cx, cy + SIZE.y / 2)
	_update_visual()


## 0, 1, 2: faster as it is hurt.
func phase() -> int:
	return MAX_HP - ceili(hp)


## Still fighting (the HUD shows its bar until it starts dying).
func fighting() -> bool:
	return mode != &"dead"


func hurtbox() -> Rect2:
	if mode in [&"vulnerable", &"dead", &"hurt"] or shown < 0.6:
		return Rect2()
	return Rect2(cx - SIZE.x / 2 + 4, cy - SIZE.y / 2 + 4, SIZE.x - 8, SIZE.y - 8)


## Hallucination.hit(): only while dazed, one hit point per hit whatever it was.
func hit(_kind: StringName, _damage := 1.0) -> bool:
	if mode != &"vulnerable":
		return false
	hp -= 1
	flash = 0.4
	stompable = false
	invincible = true
	Sound.play("bossHit")
	var main := get_tree().get_first_node_in_group("main")
	if main:
		main.shake(0.5)
	Game.hitstop(0.12)
	Fx.burst(self, Vector2(cx, cy), {count = 40, speed = 160, life = 0.7, color = [Color.WHITE, RED, CYAN], gravity = 200, size = 1.5})
	if hp <= 0:
		_next(&"dead", 2.2)
	else:
		_next(&"hurt", 0.8)
	return true


func _next(m: StringName, time: float) -> void:
	mode = m
	timer = time


func _vanish() -> void:
	mode = &"vanish"
	timer = 0.35
	stompable = false
	invincible = true
	Fx.burst(self, Vector2(cx, cy), {count = 30, speed = 90, life = 0.5, color = [Color8(220, 220, 220), CYAN, RED]})


## One of three anchors across the arena, away from Clawd when it can, 5.5-7.5 tiles above the floor.
func _pick_anchor() -> void:
	var player: Player = get_tree().get_first_node_in_group("player")
	var choices := [0.22, 0.5, 0.78].map(func(f: float) -> float: return f * arena_w)
	var far := choices.filter(func(x: float) -> bool: return not player or absf(x - player.pos.x) > 60)
	var pool: Array = far if not far.is_empty() else choices
	tx = pool.pick_random()
	ty = floor_y - 16 * (5.5 + randf() * 2)


func _attack(speed_up: float) -> void:
	var lvl := level
	var pattern := attack_index % 3
	if pattern == 0:
		# Radial bursts.
		var n := 8 + phase() * 2
		var off := volley * 0.35
		for i in n:
			var a := float(i) / n * TAU + off
			Shot.fire(lvl, Vector2(cx, cy), Vector2(cos(a), sin(a)) * 80 * speed_up, WHITE_SHOT)
		Sound.play("shoot")
		volley += 1
		if volley < 2 + (1 if phase() > 0 else 0):
			timer = 0.7 / speed_up
			return
	elif pattern == 1:
		# Rain from above onto warnings on the floor (and one under Clawd).
		if volley == 0:
			var player: Player = get_tree().get_first_node_in_group("player")
			for i in 6 + phase() * 2:
				warnings.append({"x": 32 + randf() * (arena_w - 64), "t": 0.9})
			if player:
				warnings.append({"x": player.pos.x, "t": 0.9})
			volley = 1
			timer = 0.9
			return
		var main := get_tree().get_first_node_in_group("main")
		var top: float = main.camera.top_left.y if main else 0.0
		for w in warnings:
			Shot.fire(lvl, Vector2(w.x, top - 4), Vector2(0, 190 * speed_up), RED)
		Sound.play("shoot")
	else:
		# Fake platforms and one ring.
		for spot in [Vector2(16 * 5, floor_y - 16 * 3.5), Vector2(arena_w / 2 - 32, floor_y - 16 * 6.5), Vector2(arena_w - 16 * 9, floor_y - 16 * 3.5)]:
			FakePlatform.create(lvl, spot, 64)
		for i in 10:
			var a := float(i) / 10 * TAU
			Shot.fire(lvl, Vector2(cx, cy), Vector2(cos(a), sin(a)) * 70 * speed_up, CYAN)
		Sound.play("bossTeleport")
	# Done attacking: sink to the floor, dazed.
	attack_index += 1
	volley = 0
	mode = &"descend"
	tx = clampf(cx, 48, arena_w - 48)
	ty = floor_y - SIZE.y / 2 - 1


func _update_visual() -> void:
	var dazed := mode == &"vulnerable"
	var flick := 0.3 if (mode == &"appear" or mode == &"intro") and randf() < 0.3 else 1.0
	var keep := shown * flick
	var base := Color.WHITE if flash > 0 else (DAZED if dazed else GREY)
	var r_out := 13.0 if dazed else 15.0
	# The centre on whole pixels, relative to the node (which sits at the feet, y up in the meshes).
	var snap := Vector2(cx, cy).round() - Vector2(cx, cy)
	var centre := Vector2(snap.x, SIZE.y / 2 - snap.y)
	for k in 3:
		var mm := _dots[k].multimesh
		var col: Color = [base, Color(RED, 0.45), Color(CYAN, 0.45)][k]
		var ox: float = [0.0, -2.0, 2.0][k]
		for i in _dirs.size():
			var s: int = _dirs[i][0]
			if DotNoise.hash2(i, k, 5) >= keep:
				mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
				continue
			# Round its ring like the 2D dots (odd rings one way, even the other); the outer ring wobbles.
			var a: float = _dirs[i][1] + t * (0.6 if int(SHELLS[s]) % 2 == 1 else -0.4)
			var rr: float = SHELLS[s] * (r_out / 15.0)
			if s == SHELLS.size() - 1:
				rr += sin(a * 3 + t * 2) * 2.5 + sin(a * 5 - t * 3) * 1.5
			# The ring rocks in depth about its own tilted axis, at most ~50 degrees, so it never goes edge-on.
			var axis := Vector3(cos(s * 1.3), sin(s * 1.3), 0)
			var p := Vector3(cos(a) * rr, -sin(a) * rr, 0).rotated(axis, sin(t * (0.7 + s * 0.13) + s * 1.7) * 0.9)
			var at := Vector3(roundf(p.x + ox), roundf(p.y), roundf(p.z))
			mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(centre.x + at.x, centre.y + at.y, at.z) * Px.M))
			mm.set_instance_color(i, col)
	# Eyes at the front, lifted against the oblique shift; crosses and an orbit while dazed.
	_eyes.visible = keep > 0.05
	var telegraph := mode == &"attack" and timer < 0.35 and floori(Game.time * 30) % 2 == 0
	_eyes.mesh = DIZZY_MESH if dazed else (EYES_FLASH if telegraph or flash > 0 else EYES_MESH)
	# The eyes' bottom row is the centre row (the crosses' one above it).
	_eyes.position = Vector3(centre.x, centre.y + (1.0 if dazed else 0.0) + EYE_Z / 3, EYE_Z) * Px.M
	for i in 3:
		var a := t * 5 + i * TAU / 3
		_orbit[i].visible = dazed
		_orbit[i].position = Vector3(centre.x + roundf(cos(a) * 12) + 1, centre.y + SIZE.y / 2, roundf(sin(a) * 12)) * Px.M
	# Blinking floor warnings of the rain.
	var live := warnings.filter(func(w: Dictionary) -> bool: return w.t > 0)
	while _marks.size() < live.size():
		var m := MeshInstance3D.new()
		level.add_child(m)
		_marks.append(m)
	for i in _marks.size():
		_marks[i].visible = i < live.size()
		if i < live.size():
			_marks[i].mesh = MARK_MESHES[0 if floori(live[i].t * 12) % 2 == 0 else 1]
			_marks[i].position = Px.to3(Vector2(roundf(live[i].x), floor_y - 1))


func _exit_tree() -> void:
	for m in _marks:
		if is_instance_valid(m):
			m.queue_free()


## The intro card over it while it fades in (its name and a line).
func overlay_draw(o: Overlay) -> void:
	if mode != &"intro":
		return
	var v := o.to_view(Vector2(cx, cy - SIZE.y / 2))
	PixelFont.draw_centred(o, TITLE, v.x, v.y - 18, Color(Color("#E6E6E6"), shown))
	PixelFont.draw_centred(o, SUBTITLE, v.x, v.y - 9, Color(Color("#9A9A9A"), shown))
