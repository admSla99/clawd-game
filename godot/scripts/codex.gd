class_name Codex
extends Enemy

## World 2's boss from src/entities/boss/codex.ts (2-B): a rival coding model, a floating monitor whose screen
## is its face, flanked by two giant cursor hands (CodexHand). 90 hp; only the monitor takes damage (shots,
## stomps, spins, the jet; never while it types its intro or refactors). It drifts above the arena and runs
## through its phase's attack pattern: bursts of five code characters at Clawd (3 + phase volleys), a hand slam
## onto him (both hands in phase 2), a sweeping wall of ghost text with one gap, failing tests (2 + phase bugs
## dropped into the arena) and "rm -rf" (three ColumnBeams on Clawd). At 2/3 and 1/3 of its hp it refactors
## (1.8 s untouchable, a new phase: 20 % faster, quicker rests); at 0 it segfaults, sinks for 2.8 s in bursts,
## then Main.boss_defeated() opens the exit.
## Drawn in 2.5D as a voxel CRT monitor: the 2D bezel of 2 px dots stands proud of a dark casing whose tapered
## back reaches into the depth; the face (scrolling code, eyes, mouth, cracks, the intro prompt, x_x) is
## painted on the recessed screen every frame (CodexPaint), its eyes and prompt glowing, and the screen lights
## the arena round it (GlowLight). The whole model sits SCREEN_Z in front of the gameplay plane, lifted by a
## third of that against the oblique shift, so the screen lands where the 2D one was.

const MAX_HP := 90.0
const SIZE := Vector2(72, 50)
const TITLE := "CODEX"
const INTRO_TEXT := "> codex --ship-it"
const SUBTITLE := "a rival model has entered the chat"
const WALL_TEXT := "const answer = autocomplete(everything); // trust me "
const BURST_GLYPHS := "{}();=<>[]"
const PATTERNS := [
	[&"burst", &"slam", &"wall", &"burst", &"slam"],
	[&"burst", &"tests", &"slam", &"wall", &"burst", &"slam"],
	[&"rmrf", &"burst", &"slam", &"wall", &"tests", &"rmrf", &"slam"],
]
const CYAN := Color("#5FD0D8")
const PALE_CYAN := Color("#7FE3EA")
const RED := Color("#E0605A")
const ORANGE := Color("#D97757")
const SCREEN := Color("#0C1213")
## rgba(95,208,216,0.18) over the screen.
const CODE := Color8(27, 52, 54)
const TEXT := Color("#E6E6E6")
const TEXT_DIM := Color("#9A9A9A")
## Depth of the screen's face (px in front of the gameplay plane) and the lift that undoes its oblique shift.
const SCREEN_Z := 9.0
const LIFT := 3.0
## Monitor voxels: bezel dots, casing, screen, the back.
const PALETTE := {"B": Color8(215, 215, 215), "c": Color8(46, 52, 55), "S": SCREEN, "k": Color8(34, 39, 42), "v": Color8(20, 24, 26)}
## Depth in px around the model's z (MODEL_Z): the dots stand 1 px proud of the casing, the screen 1 px back.
const DEPTH := {"B": 18, "c": 16, "S": 14, "k": 12, "v": 12}
const MODEL_Z := 2.0

## Its own material: the model reaches z = 11 px, where the see-through windows would dither Voxel.MATERIAL.
static var MATERIAL := Voxel.material()
static var _monitor_meshes := {}

var mode := &"intro"
var timer := 3.2
var t := 0.0
var phase := 0
var step := 0
var volley := 0
## Centre of the monitor, level px.
var cx := 0.0
var cy := 0.0
var floor_y := 0.0
var arena_w := 0.0
var hands: Array[CodexHand] = []
var typed := 0
var type_t := 0.0
var say_text := ""
var say_t := 0.0
var _model: Node3D
var _monitor: MeshInstance3D
var _screen: CodexPaint
var _antenna: Node3D
var _tip: MeshInstance3D
var _light: GlowLight
static var _tip_on := Voxel.mesh(["cc", "cc"], {"c": CYAN}, {"c": 2}, 2 * Px.M, Voxel.material(1.8))
static var _tip_off := Voxel.mesh(["cc", "cc"], {"c": Color8(90, 90, 90)}, {"c": 2}, 2 * Px.M, MATERIAL)
static var _antenna_dots := Voxel.mesh(["gg", "gg", "..", "gg", "gg", "..", "gg", "gg", "..", "gg", "gg"], {"g": Color8(150, 150, 150)}, {"g": 2}, Px.M, MATERIAL)


## Codex over the arena's floor at `floor_top`, centred at `x` and 150 px above the floor, in an arena
## `width` px wide.
static func create(parent: Level, x: float, floor_top: float, width: float) -> Codex:
	var b := Codex.new()
	b.name = "Codex"
	b.cx = x
	b.cy = floor_top - 150
	b.floor_y = floor_top
	b.arena_w = width
	b.position = Px.to3(Vector2(b.cx, b.cy + SIZE.y / 2))
	parent.add_child(b, true)
	return b


func _init() -> void:
	size = SIZE
	hp = MAX_HP
	max_hp = MAX_HP
	health_bar = false
	tokens = 0
	stompable = true
	collision_layer = 0
	collision_mask = 0


func _ready() -> void:
	super()
	add_to_group("world_text")
	_model = Node3D.new()
	add_child(_model)
	_monitor = MeshInstance3D.new()
	_monitor.position = Vector3(0, -1, MODEL_Z) * Px.M
	_model.add_child(_monitor)
	# The tapered back of the CRT, into the depth.
	for b in [[Vector2i(66, 48), -12.0], [Vector2i(50, 40), -23.0]]:
		var back := MeshInstance3D.new()
		back.mesh = _back_mesh(b[0])
		back.position = Vector3(0, (SIZE.y - b[0].y) / 2.0, b[1]) * Px.M
		_model.add_child(back)
	_screen = CodexPaint.new()
	# Screen paint in the 2D monitor's coordinates (its top-left corner), y down.
	_screen.position = Vector3(-SIZE.x / 2, SIZE.y, 0) * Px.M
	_model.add_child(_screen)
	_antenna = Node3D.new()
	add_child(_antenna)
	var dots := MeshInstance3D.new()
	dots.mesh = _antenna_dots
	# The 2D dots at y - 4 - i * 3 over the monitor's top, rising from the middle of the casing's top.
	dots.position = Vector3(0, SIZE.y + 2, MODEL_Z) * Px.M
	_antenna.add_child(dots)
	_tip = MeshInstance3D.new()
	_tip.position = Vector3(0, SIZE.y + 13, MODEL_Z) * Px.M
	_antenna.add_child(_tip)
	_light = GlowLight.new()
	_light.radius = 3.5
	_light.energy = 0.7
	_light.position = Vector3(0, SIZE.y / 2, SCREEN_Z + 6) * Px.M
	add_child(_light)
	_update_visual()


## Still fighting (the HUD shows its bar until it segfaults).
func fighting() -> bool:
	return mode != &"dead"


func hurtbox() -> Rect2:
	if mode == &"dead" or mode == &"intro":
		return Rect2()
	return Rect2(cx - SIZE.x / 2 + 4, cy - SIZE.y / 2 + 4, SIZE.x - 8, SIZE.y - 8)


## Codex.hit(): any hit but while it types its intro, refactors or dies; damage numbers as on every enemy.
func hit(_kind: StringName, damage := 1.0, _own := true) -> bool:
	if mode in [&"intro", &"refactor", &"dead"]:
		return false
	hp -= damage
	flash = 0.08
	var main := get_tree().get_first_node_in_group("main")
	if main:
		main.overlay.damage_number(self, damage, hp <= 0)
	if randf() < 0.3:
		Sound.play("hit")
	if hp <= 0:
		hp = 0
		mode = &"dead"
		timer = 2.8
		_say("SEGFAULT", 3)
		Sound.play("bossHit")
		Game.hitstop(0.2)
		for h in hands:
			if is_instance_valid(h):
				h.retire()
		return true
	var next := 2 if hp <= MAX_HP / 3 else (1 if hp <= MAX_HP * 2 / 3 else 0)
	if next > phase:
		phase = next
		mode = &"refactor"
		timer = 1.8
		step = 0
		_say("REFACTORING..." if phase == 1 else "ENABLING --YOLO MODE", 1.8)
		Sound.play("bossHit")
		if main:
			main.shake(0.6)
		Game.hitstop(0.15)
		Fx.burst(self, Vector2(cx, cy), {count = 60, speed = 180, life = 0.8, color = [Color.WHITE, CYAN, RED], size = 1.5, depth = 12})
	return true


func _say(text: String, seconds: float) -> void:
	say_text = text
	say_t = seconds


func _physics_process(dt: float) -> void:
	if Game.frozen():
		return
	tick(dt)
	t += dt
	timer -= dt
	say_t -= dt
	if hands.is_empty():
		for side in [-1, 1]:
			hands.append(CodexHand.create(level, self, side, floor_y))
	# Drift above the arena.
	if mode != &"dead":
		var span := arena_w / 2 - 110
		var tx := arena_w / 2 + sin(t * (0.45 + phase * 0.12)) * span
		var ty := floor_y - 150 + sin(t * 1.3) * 6
		cx += (tx - cx) * minf(1.0, dt * 2)
		cy += (ty - cy) * minf(1.0, dt * 2)
	var speed := 1.0 + phase * 0.2
	var main := get_tree().get_first_node_in_group("main")
	match mode:
		&"intro":
			type_t += dt
			if type_t > 0.09 and typed < INTRO_TEXT.length():
				type_t = 0
				typed += 1
				Sound.play("typing")
			if timer <= 0:
				_next_attack()
		&"idle", &"refactor":
			if timer <= 0:
				_next_attack()
		&"burst":
			if timer <= 0:
				_fire_burst(speed)
				volley += 1
				timer = 0.5
				if volley >= 3 + phase:
					_rest()
		&"slam":
			if timer <= 0 or hands.all(func(h: CodexHand) -> bool: return not h.busy):
				_rest()
		&"wall", &"tests":
			if timer <= 0:
				_rest()
		&"rmrf":
			if timer <= 0:
				if volley < 3:
					var player: Player = get_tree().get_first_node_in_group("player")
					ColumnBeam.create(level, player.pos.x if player else cx, floor_y)
					volley += 1
					timer = 0.75
				else:
					_rest()
		&"dead":
			if randf() < dt * 30:
				Fx.burst(self, Vector2(cx + randf_range(-35, 35), cy + randf_range(-25, 25)), {count = 6, speed = 130, life = 0.7, color = [Color.WHITE, CYAN, ORANGE, RED], size = 1.5, depth = 12})
				if main:
					main.shake(0.08)
				if randf() < 0.3:
					Sound.play("explode")
			cy += 12 * dt
			if timer <= 0:
				Fx.burst(self, Vector2(cx, cy), {count = 160, speed = 260, life = 1.4, color = [Color.WHITE, CYAN, ORANGE], size = 2, drag = 1.4, depth = 16})
				Sound.play("explode")
				if main:
					main.shake(1.0)
					main.boss_defeated(self, Vector2(cx, floor_y))
				remove()
				return
	pos = Vector2(cx, cy + SIZE.y / 2)
	_update_visual()


func _rest() -> void:
	mode = &"idle"
	timer = maxf(0.45, 1.2 - phase * 0.3)


func _next_attack() -> void:
	var pattern: Array = PATTERNS[phase]
	var attack: StringName = pattern[step % pattern.size()]
	step += 1
	mode = attack
	volley = 0
	var player: Player = get_tree().get_first_node_in_group("player")
	var px: float = player.pos.x if player else cx
	match attack:
		&"burst":
			timer = 0.4
		&"slam":
			var hand: CodexHand = hands[0] if absf(hands[0].cx() - px) < absf(hands[1].cx() - px) else hands[1]
			hand.slam()
			if phase == 2:
				hands[1 - hands.find(hand)].slam(0.7)
			timer = 4.0
		&"wall":
			_spawn_wall(px)
			_say("autocompleting...", 1.5)
			timer = 2.2
		&"tests":
			var n := 2 + phase
			var main := get_tree().get_first_node_in_group("main")
			for i in n:
				var bug: Bug = load(Level.BUG).instantiate()
				bug.name = "Bug"
				bug.position = Px.to3(Vector2(16 * 4 + randf() * (arena_w - 16 * 8), 16 * 2))
				# Bug(x, TILE * 2, 2): world 2's tough bugs, times HP_FACTOR like every enemy in the port.
				bug.hp = 2 * HP_FACTOR
				level.add_child(bug, true)
				# The level's token total grows with what they drop.
				if main:
					main.tokens_total += bug.tokens * (2 if main.double_tokens else 1)
			_say("npm test → %d failing" % n, 1.6)
			timer = 1.4
		&"rmrf":
			_say("rm -rf ./clawd", 1.6)
			timer = 0.5


## Five code characters fanned at Clawd's middle from under the face, every other volley turned a little.
func _fire_burst(speed: float) -> void:
	var player: Player = get_tree().get_first_node_in_group("player")
	var from := Vector2(cx, cy + 14)
	var aim := player.pos + Vector2(0, -Player.SIZE.y / 2) if player else from + Vector2(0, 100)
	var base := (aim - from).angle()
	var n := 5
	for i in n:
		var a := base + (i - (n - 1) / 2.0) * 0.17 + (0.08 if volley % 2 else 0.0)
		var ch := BURST_GLYPHS[randi() % BURST_GLYPHS.length()]
		CodeShot.fire_glyph(level, from, Vector2(cos(a), sin(a)) * 120 * speed, ch, CYAN)
	Sound.play("shoot")


## A column of ghost text sweeping across the arena, with one gap to slip through.
func _spawn_wall(px: float) -> void:
	var from_right := px < arena_w / 2
	var start_x := arena_w - 16 * 2 if from_right else 16.0 * 2
	var vx := (-1.0 if from_right else 1.0) * (95 + phase * 15)
	var gap_centre := floor_y - 26 - randf() * 70
	var gap_half := 22.0
	var i := 0
	var y := 16.0
	while y < floor_y - 4:
		if absf(y - gap_centre) >= gap_half:
			var ch := WALL_TEXT[i % WALL_TEXT.length()]
			i += 1
			var life := (arena_w - 16 * 3) / absf(vx)
			CodeShot.fire_glyph(level, Vector2(start_x, y), Vector2(vx, 0), "·" if ch == " " else ch, PALE_CYAN, false, life)
		y += 9
	Sound.play("typing")


func _update_visual() -> void:
	var glitching := mode == &"refactor" or mode == &"dead" or phase == 2
	var glitch := 2.0 if glitching and DotNoise.hash2(floori(Game.time * 20), 1, 3) > 0.7 else 0.0
	var white := flash > 0
	# The model on whole pixels; the screen's face (SCREEN_Z in front) lifted back onto the 2D one.
	var snap := Vector2(cx, cy).round() - Vector2(cx, cy)
	_model.position = Vector3(snap.x + glitch, -snap.y + LIFT, 0) * Px.M
	_antenna.position = Vector3(snap.x, -snap.y + LIFT, 0) * Px.M
	_monitor.mesh = _monitor_mesh(white)
	_tip.mesh = _tip_on if floori(Game.time * 3) % 2 else _tip_off
	_light.energy = 0.0 if mode == &"dead" and floori(Game.time * 12) % 3 == 0 else (0.5 if glitch > 0 else 0.7)
	_draw_screen(white)


## The face, in the 2D draw()'s coordinates (the monitor's top-left corner, y down) on the screen's front.
func _draw_screen(white: bool) -> void:
	var z0 := SCREEN_Z
	var z1 := z0 + 0.25
	var s := _screen
	s.begin()
	# Scrolling code behind the face.
	for l in 6:
		var ly := 7 + l * 7
		var n := 10 + floori(DotNoise.hash2(l + floori(t * 2), 7, 1) * 40)
		var k := 0
		while k < n:
			var kx := 6 + k + (l % 3) * 4
			# Not under the name plate (x 24-47 of its rows).
			if ly != 42 or kx < 22 or kx > 47:
				s.rect(Vector2(kx, ly), Vector2(2, 1), CODE, z0, z1)
			k += 3
	if mode == &"intro":
		var shown := INTRO_TEXT.substr(0, typed)
		var end := s.text(shown, Vector2(5, 23), CYAN, z0, z1 + 0.25, 1.5, 1) if typed > 0 else 4.0
		if floori(Game.time * 3) % 2:
			s.rect(Vector2(end + 2, 27), Vector2(2, 1), CYAN, z0, z1 + 0.25, 1.5)
	else:
		# Eyes, looking at Clawd, blinking now and then.
		var player: Player = get_tree().get_first_node_in_group("player")
		var blink := sin(t * 1.7) > 0.97
		var eye_h := 1.0 if blink else 10.0
		var look := roundf(clampf(((player.pos.x if player else cx) - cx) / 60, -3, 3))
		var eye := RED if mode == &"dead" else (Color.WHITE if white else CYAN)
		for ex in [24.0, 42.0]:
			s.rect(Vector2(ex + look, 14 + floorf((10 - eye_h) / 2)), Vector2(6, eye_h), eye, z0, z1 + 0.25, 1.6)
		# Mouth.
		if mode == &"dead":
			s.text("x_x", Vector2(36 - CodexPaint.text_width("x_x") / 2.0, 33), RED, z0, z1 + 0.25, 1.4)
		elif mode in [&"burst", &"rmrf", &"wall"]:
			s.rect(Vector2(33 + look, 31), Vector2(6, 5), eye, z0, z1 + 0.25, 1.6)
		else:
			s.rect(Vector2(28 + look, 34), Vector2(16, 1), eye, z0, z1 + 0.25, 1.6)
		# Cracks in later phases.
		if phase >= 1:
			for i in 6 * phase:
				var at := Vector2(8 + floorf(DotNoise.hash2(i, 2, 9) * 56), 6 + floorf(DotNoise.hash2(i, 3, 9) * 36))
				s.rect(at, Vector2(2, 1) if i % 2 else Vector2(1, 2), RED, z0, z1 + 0.25)
	# Name plate.
	s.text(TITLE, Vector2(36 - CodexPaint.text_width(TITLE) / 2.0, 41), Color8(120, 120, 120), z0, z1)
	s.end()


## The intro card under it (its name and a line) and what it says, as overlay text.
func overlay_draw(o: Overlay) -> void:
	var bottom := cy + SIZE.y / 2
	if say_t > 0 and say_text != "":
		var v := o.to_view(Vector2(cx, bottom + 9))
		var c := RED if mode == &"dead" else PALE_CYAN
		var a := minf(1.0, say_t * 3)
		# A dark shadow keeps it readable over the platforms it hangs over.
		PixelFont.draw_centred(o, say_text, v.x, v.y + 1, Color(0, 0, 0, 0.75 * a))
		PixelFont.draw_centred(o, say_text, v.x, v.y, Color(c, a))
	if mode == &"intro" and typed >= INTRO_TEXT.length():
		var v := o.to_view(Vector2(cx, bottom + 11))
		o.draw_set_transform(Vector2(roundf(v.x - PixelFont.width(TITLE)), v.y), 0, Vector2(2, 2))
		PixelFont.draw(o, TITLE, Vector2.ZERO, TEXT)
		o.draw_set_transform(Vector2.ZERO)
		PixelFont.draw_centred(o, SUBTITLE, v.x, v.y + 16, Color(0, 0, 0, 0.75))
		PixelFont.draw_centred(o, SUBTITLE, v.x, v.y + 15, TEXT_DIM)


## The front of the monitor (74 x 52 px): bezel dots on the casing round the recessed screen, the dots white
## while it flashes.
static func _monitor_mesh(white: bool) -> ArrayMesh:
	if _monitor_meshes.has(white):
		return _monitor_meshes[white]
	var w := int(SIZE.x) + 2
	var h := int(SIZE.y) + 2
	var rows := []
	for r in h:
		var row := ""
		for c in w:
			# Cell (c, r) is the 2D pixel (x - 1 + c, y - 1 + r); dots every 3 px, 2 px square, on the rim.
			var dot_x := c % 3 < 2
			var dot_y := r % 3 < 2
			var rim_x := c < 2 or c >= w - 2
			var rim_y := r < 2 or r >= h - 2
			if (rim_y and dot_x) or (rim_x and dot_y and r < h - 2):
				row += "B"
			elif c >= 4 and c < w - 4 and r >= 4 and r < h - 4:
				row += "S"
			else:
				row += "c"
		rows.append(row)
	var pal := PALETTE.duplicate()
	if white:
		pal["B"] = Color.WHITE
	_monitor_meshes[white] = Voxel.mesh(rows, pal, DEPTH, Px.M, MATERIAL)
	return _monitor_meshes[white]


## A block of the CRT's back, `s` px, with vent slits along its top edge.
static func _back_mesh(s: Vector2i) -> ArrayMesh:
	var rows := []
	for r in s.y:
		var row := ""
		for c in s.x:
			row += "v" if r == 0 and c % 4 == 1 and c > 3 and c < s.x - 4 else "k"
		rows.append(row)
	return Voxel.mesh(rows, PALETTE, DEPTH, Px.M, MATERIAL)
