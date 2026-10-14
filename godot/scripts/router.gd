class_name Router
extends Enemy

## World 3's boss (3-B, not in TS): the Router, a switchboard hanging over the arena that every request goes through.
## 120 hp, but its core hides behind a FIREWALL of three bars, and while the firewall is up shots glance off it
## (blocks_direction()) and nothing hurts it. The Router is an anchor too (group "anchors", the Anchor interface):
## each time the Tool Call's hook catches it, a firewall bar tears off and Clawd zips up under it; with all three gone
## the core is EXPOSED for EXPOSED_TIME seconds, then the firewall grows back. Touching the Router does not hurt.
## Phases (at 2/3 and 1/3 of its hp it reroutes, 1.8 s untouchable, the firewall back up):
## 0 routing: packets run along its cables to the four ports in the walls, and each port fires a burst at Clawd;
## 1 loopback: also hostile echoes of Clawd (scripts/echo.gd, red) replaying his last 3 s, which hurt to touch;
## 2 timeout storm: faster packets, the arena's anchors become timeout anchors, the floor's edges turn to spikes.
## At 0 hp it goes down in bursts and Main.boss_defeated() opens the exit.
## A voxel model in 2 px cells: a dark switchboard with rows of blinking port LEDs round a glowing core, the firewall's
## red bars across it; its cables and the packets on them are drawn by the Overlay.

const MAX_HP := 120.0
const SIZE := Vector2(60, 36)
const TITLE := "THE ROUTER"
const EXPOSED_TIME := 6.0
const PACKET_TIME := 0.6
const PALETTE := {"c": Color("#1C2238"), "k": Color("#0E1222"), "e": Color("#2C3A66"), "g": Color("#3FD18A"),
	"b": Color("#5F8BFF"), "d": Color("#22305A"), "W": Color("#F0F6FF"), "B": Color("#8FB4FF")}
const FIREWALL := Color("#FF5C4A")
const PACKET := Color("#9CC2FF")
const SAYS := ["> routing table loaded", "REROUTING...", "LOOPBACK ENABLED", "TIMEOUT STORM"]

static var FRAMES := [_mesh(0), _mesh(1)]
static var BAR_MESH := Voxel.mesh(["rRrRrRrRrRrRrR", "RrRrRrRrRrRrRr"], {"r": FIREWALL, "R": Color("#FFB07A")}, {"r": 6, "R": 6}, 2 * Px.M, Voxel.material(1.6))

var mode := &"intro"
var timer := 3.0
var t := 0.0
var phase := 0
var cx := 0.0
var cy := 0.0
var floor_y := 0.0
var arena_w := 0.0
## Firewall bars left (3 = whole), and seconds left of an exposed core.
var firewall := 3
var exposed := 0.0
var say_text := ""
var say_t := 0.0
## The four ports: where packets go and bursts come from (level px).
var ports: Array[Vector2] = []
## Packets on their way: {port, t} (t 0..1 along the cable).
var packets: Array = []
var bursts_left := 0
var burst_port := 0
## Clawd's feet over the last 3 s, for the loopback echoes.
var trail: Array = []
## The Anchor interface.
var active := false
var targeted := false
var caught_flash := 0.0
var _model: Node3D
var _body: MeshInstance3D
var _bars: Array[MeshInstance3D] = []
var _light: GlowLight


## The Router over the arena's floor at `floor_top`, centred at `x`, in an arena `width` px wide.
static func create(parent: Level, x: float, floor_top: float, width: float) -> Router:
	var b := Router.new()
	b.name = "Router"
	b.cx = x
	b.cy = floor_top - 160
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
	add_to_group("anchors")
	add_to_group("world_text")
	ports = [Vector2(2 * 16 + 2, floor_y - 7 * 16), Vector2(arena_w - 2 * 16 - 2, floor_y - 7 * 16),
		Vector2(2 * 16 + 2, floor_y - 3 * 16), Vector2(arena_w - 2 * 16 - 2, floor_y - 3 * 16)]
	_model = Node3D.new()
	add_child(_model)
	_body = MeshInstance3D.new()
	_body.mesh = FRAMES[0]
	_model.add_child(_body)
	for i in 3:
		var bar := MeshInstance3D.new()
		bar.mesh = BAR_MESH
		bar.position = Vector3(0, 10 + i * 6, 8) * Px.M
		_model.add_child(bar)
		_bars.append(bar)
	_light = GlowLight.new()
	_light.radius = 3.5
	_light.energy = 0.7
	_light.position = Vector3(0, SIZE.y / 2, 2) * Px.M
	add_child(_light)
	_say(SAYS[0], 3.0)
	_update_visual()


func fighting() -> bool:
	return mode != &"dead"


## Where the hook catches it: the core.
func point() -> Vector2:
	return Vector2(cx, cy)


## The hook caught it: a firewall bar tears off; the last one exposes the core.
func catch() -> void:
	caught_flash = 0.3
	if firewall <= 0:
		return
	firewall -= 1
	Sound.play("break")
	Fx.burst(self, Vector2(cx, cy + 6), {count = 20, speed = 120, life = 0.5, color = [FIREWALL, Color.WHITE], gravity = 200, depth = 8})
	if firewall == 0:
		exposed = EXPOSED_TIME
		active = false
		_say("FIREWALL DOWN", 1.5)


## Shots glance off the firewall.
func blocks_direction(_dir: Vector2) -> bool:
	return mode != &"dead" and exposed <= 0


## Touching it does not hurt; its attacks do.
func hurtbox() -> Rect2:
	return Rect2()


func hit(_kind: StringName, damage := 1.0) -> bool:
	if mode in [&"intro", &"reroute", &"dead"] or exposed <= 0:
		if mode != &"dead":
			flash = 0.05
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
		timer = 2.6
		packets.clear()
		_say("CONNECTION RESET", 3)
		Sound.play("bossHit")
		Game.hitstop(0.2)
		return true
	var next := 2 if hp <= MAX_HP / 3 else (1 if hp <= MAX_HP * 2 / 3 else 0)
	if next > phase:
		phase = next
		mode = &"reroute"
		timer = 1.8
		exposed = 0.0
		firewall = 3
		_say(SAYS[phase + 1], 1.8)
		Sound.play("bossHit")
		if main:
			main.shake(0.6)
		Game.hitstop(0.15)
		Fx.burst(self, Vector2(cx, cy), {count = 60, speed = 180, life = 0.8, color = [Color.WHITE, PACKET, FIREWALL], size = 1.5, depth = 12})
		if phase == 2:
			_timeout_storm()
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
	caught_flash = maxf(0.0, caught_flash - dt)
	var main := get_tree().get_first_node_in_group("main")
	var player: Player = get_tree().get_first_node_in_group("player")
	if player and player.in_play():
		trail.append([player.pos, player.facing])
		if trail.size() > 180:
			trail.pop_front()
	if exposed > 0:
		exposed -= dt
		if exposed <= 0:
			firewall = 3
			_say("FIREWALL RESTORED", 1.2)
	active = mode not in [&"intro", &"dead"] and firewall > 0
	# Drift over the arena.
	if mode != &"dead":
		var tx := arena_w / 2 + sin(t * (0.35 + phase * 0.1)) * (arena_w / 2 - 90)
		var ty := floor_y - 160 + sin(t * 1.1) * 8
		cx += (tx - cx) * minf(1.0, dt * 1.5)
		cy += (ty - cy) * minf(1.0, dt * 1.5)
	match mode:
		&"intro", &"reroute":
			if timer <= 0:
				mode = &"idle"
				timer = 0.6
		&"idle":
			if timer <= 0:
				_next_attack()
		&"route":
			if timer <= 0 and bursts_left > 0:
				_fire_port(burst_port)
				bursts_left -= 1
				timer = 0.18
			elif bursts_left <= 0 and packets.is_empty():
				mode = &"idle"
				timer = maxf(0.5, 1.4 - phase * 0.35)
		&"dead":
			if randf() < dt * 30:
				Fx.burst(self, Vector2(cx + randf_range(-30, 30), cy + randf_range(-18, 18)), {count = 6, speed = 130, life = 0.7, color = [Color.WHITE, PACKET, FIREWALL], size = 1.5, depth = 12})
				if main:
					main.shake(0.08)
				if randf() < 0.3:
					Sound.play("explode")
			cy += 14 * dt
			if timer <= 0:
				Fx.burst(self, Vector2(cx, cy), {count = 160, speed = 260, life = 1.4, color = [Color.WHITE, PACKET, FIREWALL], size = 2, drag = 1.4, depth = 16})
				Sound.play("explode")
				if main:
					main.shake(1.0)
					main.boss_defeated(self, Vector2(cx, floor_y))
				remove_from_group("anchors")
				remove()
				return
	# Packets along the cables; one that reaches its port makes it fire a burst.
	for pk in packets.duplicate():
		pk.t += dt / (PACKET_TIME / (1.0 + phase * 0.4))
		if pk.t >= 1.0:
			packets.erase(pk)
			burst_port = pk.port
			bursts_left = 3 + phase
			timer = 0.0
	pos = Vector2(cx, cy + SIZE.y / 2)
	_update_visual()


## The next attack: a packet to a port (two in the storm), and from phase 1 on a loopback echo every other time.
func _next_attack() -> void:
	mode = &"route"
	var player: Player = get_tree().get_first_node_in_group("player")
	var near := 0
	if player:
		var best := INF
		for i in ports.size():
			var d := ports[i].distance_to(player.pos)
			if d > best:
				continue
			best = d
			near = i
	# Mostly a port away from Clawd, so the burst has room to fly.
	var port := (near + 1 + randi() % 3) % ports.size()
	packets.append({"port": port, "t": 0.0})
	if phase == 2:
		packets.append({"port": (port + 2) % ports.size(), "t": -0.3})
	Sound.play("typing")
	if phase >= 1 and randf() < 0.5 and trail.size() > 30:
		_loopback()


## A port fires one shot at Clawd.
func _fire_port(i: int) -> void:
	var player: Player = get_tree().get_first_node_in_group("player")
	var from: Vector2 = ports[i]
	var aim := player.pos + Vector2(0, -Player.SIZE.y / 2) if player else from + Vector2(100, 0)
	var dir := (aim - from).normalized()
	dir = dir.rotated(randf_range(-0.08, 0.08))
	CodeShot.fire_glyph(level, from, dir * (130 + phase * 30), "#", PACKET)
	Sound.play("shoot")


## A hostile echo of Clawd replaying his last 3 s.
func _loopback() -> void:
	var e := Echo.new()
	e.name = "Loopback"
	e.hostile = true
	e.path = trail.duplicate()
	level.add_child(e, true)
	_say("loopback", 1.0)
	Sound.play("agentSend")


## Phase 2: the arena's anchors time out, and the floor's edges turn to spikes.
func _timeout_storm() -> void:
	for a in get_tree().get_nodes_in_group("anchors"):
		if a != self and a.has_method("make_timeout"):
			a.make_timeout()
	var terrain: GridMap = level.get_node("Terrain")
	var row := int(floor_y / 16) - 1
	for x in [2, 3, 4, 5, int(arena_w / 16) - 6, int(arena_w / 16) - 5, int(arena_w / 16) - 4, int(arena_w / 16) - 3]:
		terrain.set_cell_item(Vector3i(x, -row - 1, 0), Level.SPIKE)


func _update_visual() -> void:
	_body.mesh = FRAMES[int(t * 4) % 2]
	for i in 3:
		_bars[i].visible = mode != &"dead" and i < firewall and exposed <= 0
	var white := flash > 0 or caught_flash > 0
	set_tint(_body, Color(1, 1, 1, 0.6) if white else Color(0, 0, 0, 0))
	_light.energy = 1.2 if exposed > 0 else 0.7
	var snap := pos.round() - pos
	_model.position = Vector3(snap.x, -snap.y, 0) * Px.M


## Cables to the ports, packets on them, what it says; brackets while the hook would catch it.
func overlay_draw(o: Overlay) -> void:
	if mode == &"dead":
		return
	var from := o.to_view(Vector2(cx, cy + SIZE.y / 2 - 4))
	for i in ports.size():
		var to := o.to_view(ports[i])
		var n := int(from.distance_to(to) / 4)
		for k in n:
			o.draw_rect(Rect2(from.lerp(to, float(k) / n).round(), Vector2.ONE), Color(0.42, 0.55, 0.95, 0.85) if k % 2 == 0 else Color(0.25, 0.32, 0.6, 0.6))
		o.draw_rect(Rect2(to.round() - Vector2(3, 3), Vector2(6, 6)), Color(0.15, 0.2, 0.35))
		o.draw_rect(Rect2(to.round() - Vector2(1, 1), Vector2(2, 2)), PACKET if bursts_left > 0 and burst_port == i else Color(0.3, 0.4, 0.7))
	for pk in packets:
		if pk.t < 0:
			continue
		var p := from.lerp(o.to_view(ports[pk.port]), pk.t).round()
		o.draw_rect(Rect2(p - Vector2(1, 1), Vector2(3, 3)), PACKET)
	if say_t > 0 and say_text != "":
		var v := o.to_view(Vector2(cx, cy - SIZE.y / 2 - 14))
		PixelFont.draw_centred(o, say_text, v.x, v.y, Color(0.75, 0.85, 1.0))
	if targeted and active:
		var c := o.to_view(point()).round()
		var r := 14 + roundf(absf(sin(t * 6)))
		for sx in [-1, 1]:
			for sy in [-1, 1]:
				var k := c + Vector2(sx * r, sy * r)
				o.draw_rect(Rect2(k.x - (2 if sx > 0 else 0), k.y, 3, 1), Anchor.ORANGE_LIGHT)
				o.draw_rect(Rect2(k.x, k.y - (2 if sy > 0 else 0), 1, 3), Anchor.ORANGE_LIGHT)


## The switchboard, 30 x 18 cells (2 px): casing, rows of port LEDs (blinking between the frames), the core.
static func _mesh(frame: int) -> ArrayMesh:
	var rows := []
	for y in 18:
		var r := ""
		for x in 30:
			var d := Vector2(x - 14.5, y - 9.5)
			var ch := "c"
			if x == 0 or y == 0 or x == 29 or y == 17:
				ch = "e"
			elif d.length() < 3.2:
				ch = "W" if d.length() < 1.6 else "B"
			elif d.length() < 4.4:
				ch = "k"
			elif y % 3 == 1 and x % 3 == 1 and (x < 9 or x > 20):
				ch = "g" if (x * 7 + y * 3 + frame) % 4 == 0 else ("b" if (x + y + frame) % 3 == 0 else "d")
			r += ch
		rows.append(r)
	return Voxel.mesh(rows, PALETTE, {"c": 10, "e": 12, "k": 8, "g": 12, "b": 12, "d": 10, "W": 14, "B": 12}, 2 * Px.M)
