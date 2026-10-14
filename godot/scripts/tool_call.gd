class_name ToolCall
extends Node3D

## World 3's Tool Call (docs/world3-plan.md), Clawd's hook in every level once Progress has the "hook" (Codex
## drops it). The `tool` action throws a clawed hook from his hand along his aim (the gun's: the mouse, or the
## keys). The aim assist picks the anchor nearest the aim line within REACH and CONE that he can see (it shows
## brackets, Anchor.overlay_draw()); the hook flies to it, catches it and Player.start_zip() pulls Clawd there.
## With no pick the hook flies straight: a solid block stops it (clank), an enemy takes HOOK_DAMAGE (a shield bot
## loses its shield instead: `hook_hit()`), and at REACH it comes back. Jump or `tool` again lets go during the
## zip. Drawn as a voxel claw on a cable of glowing 1 px cubes. Runs after the gun (process_physics_priority).

enum { IDLE, OUT, HELD, BACK }
const REACH := 128.0
const CONE := deg_to_rad(35.0)
const SPEED := 900.0
const BACK_SPEED := 1400.0
const HOOK_DAMAGE := 2.0
## A shot thrown back with the Reflect prompt.
const REFLECT_DAMAGE := 4.0
const COOLDOWN := 0.15
## The zip pulls Clawd's feet this far under the anchor, so it ends at his chest.
const ZIP_BELOW := 12.0
const DOTS := 48
const CLAW := ["..OO..", ".O..W.", "OOOOOW", ".O..W.", "..OO.."]
const CLAW_PALETTE := {"O": Color("#D97757"), "W": Color("#F2FFFF")}
const CABLE := Color("#9FD8DE")

static var MATERIAL := Voxel.material(1.4)
static var CLAW_MESH := Voxel.mesh(CLAW, CLAW_PALETTE, {"O": 2, "W": 2}, Px.M, MATERIAL)

var main: Node
var player: Player
var state := IDLE
## The claw (level px) and the way it flies.
var head := Vector2.ZERO
var dir := Vector2.RIGHT
var travelled := 0.0
## The anchor it flies to or holds, and the aim assist's pick this frame: anything in the group "anchors" with
## point(), active, targeted and catch() (an Anchor, or a Webhook, which moves and can die).
var target: Node3D = null
var candidate: Node3D = null
var cooldown := 0.0
## Reach multiplier (the Stay on task prompt, W9).
var reach_mult := 1.0
var _claw: Node3D
var _cable: MultiMeshInstance3D


func setup(m: Node, p: Player) -> void:
	main = m
	player = p
	process_physics_priority = 11
	# The claw turns about its middle: its mesh (anchored bottom-centre) sits half its height down in a pivot.
	_claw = Node3D.new()
	add_child(_claw)
	var claw_mesh := MeshInstance3D.new()
	claw_mesh.mesh = CLAW_MESH
	claw_mesh.position.y = -CLAW.size() / 2.0 * Px.M
	_claw.add_child(claw_mesh)
	var box := BoxMesh.new()
	box.size = Vector3.ONE * Px.M
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/particles.gdshader")
	box.material = mat
	_cable = MultiMeshInstance3D.new()
	_cable.multimesh = MultiMesh.new()
	_cable.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_cable.multimesh.use_colors = true
	_cable.multimesh.mesh = box
	_cable.multimesh.instance_count = DOTS
	add_child(_cable)
	reset()


## Owned and in a level.
func available() -> bool:
	return Progress.has_tool("hook") and main.mode == Main.Mode.PLAY and player.in_play()


## Back in the hand (a new level, Clawd hurt or respawned).
func reset() -> void:
	state = IDLE
	target = null
	cooldown = 0.0
	if candidate:
		candidate.targeted = false
	candidate = null
	_update_visual()


## Clawd's hand: the gun's pivot (5 px ahead of his middle, 9 px over his feet).
func hand() -> Vector2:
	return player.pos + Vector2(player.facing * 5, -9)


## The aim: the gun's while armed (it sets player.aim), else worked out the same way.
func aim() -> float:
	return player.aim if player.armed else main.gun.compute_aim()


## The anchor the hook would catch thrown along `angle`: within reach and the cone, in sight, the best mix of
## small angle and short distance; or null.
func pick(angle: float) -> Node3D:
	var from := hand()
	var best: Node3D = null
	var best_score := INF
	for a: Node3D in get_tree().get_nodes_in_group("anchors"):
		if not a.active:
			continue
		var d: Vector2 = a.point() - from
		var dist: float = d.length()
		var off := absf(angle_difference(angle, d.angle()))
		if dist > REACH * reach_mult or off > CONE or not clear_line(from, a.point()):
			continue
		var score: float = off * 80.0 + dist * 0.3
		if score < best_score:
			best_score = score
			best = a
	return best


## No solid or corrupted block between `a` and `b` (sampled every 4 px).
func clear_line(a: Vector2, b: Vector2) -> bool:
	var n := ceili(a.distance_to(b) / 4.0)
	for i in range(1, n):
		if main.level.tile(a.lerp(b, float(i) / n)) in [Level.SOLID, Level.CORRUPT]:
			return false
	return true


func _physics_process(dt: float) -> void:
	if not available():
		if state != IDLE or candidate:
			reset()
		return
	if Game.frozen():
		return
	cooldown = maxf(0.0, cooldown - dt)
	var angle := aim()
	var pick_now: Node3D = pick(angle) if state == IDLE and main.complete_t < 0 else null
	if target and not is_instance_valid(target):
		target = null
	if candidate and not is_instance_valid(candidate):
		candidate = null
	if candidate and candidate != pick_now:
		candidate.targeted = false
	candidate = pick_now
	if candidate:
		candidate.targeted = true
	match state:
		IDLE:
			if Input.is_action_just_pressed("tool") and can_throw():
				throw(angle)
		OUT:
			_fly(dt)
		HELD:
			if player.state != &"zip" or target == null:
				if player.state == &"zip":
					player.end_zip(false)
				state = BACK
			elif Input.is_action_just_pressed("tool"):
				player.end_zip(false)
				state = BACK
			elif target:
				player.zip_target = target.point() + Vector2(0, ZIP_BELOW)
				head = target.point()
		BACK:
			var to := hand() - head
			if to.length() <= BACK_SPEED * dt:
				state = IDLE
				target = null
				cooldown = COOLDOWN
			else:
				head += to.normalized() * BACK_SPEED * dt
	_update_visual()


func can_throw() -> bool:
	return cooldown <= 0 and main.complete_t < 0 and player.state in [&"normal", &"spin"] and player.hurt_timer <= 0 \
		and not player.frozen


## Throws the hook along `angle`, or at the aim assist's pick.
func throw(angle: float) -> void:
	head = hand()
	travelled = 0.0
	target = candidate
	dir = (target.point() - head).normalized() if target else Vector2.from_angle(angle)
	state = OUT
	Sound.play("hookThrow")


func _fly(dt: float) -> void:
	var step := SPEED * dt
	# A target that died on the way leaves it flying straight on.
	if target:
		var to: Vector2 = target.point() - head
		if not target.active:
			state = BACK
		elif to.length() <= step:
			head = target.point()
			target.catch()
			player.start_zip(target.point() + Vector2(0, ZIP_BELOW))
			state = HELD
			Sound.play("hookCatch")
			main.particles.emit(head, {count = 8, speed = 70, life = 0.3, color = [Color.WHITE, Anchor.CYAN]})
		else:
			head += to.normalized() * step
		return
	# Straight out, in 2 px steps: a block or an enemy stops it.
	var moved := 0.0
	while moved < step:
		head += dir * 2.0
		moved += 2.0
		travelled += 2.0
		if main.level.tile(head) in [Level.SOLID, Level.CORRUPT]:
			Brittle.strike(main.level, head)
			state = BACK
			Sound.play("hookMiss")
			main.particles.emit(head, {count = 5, speed = 50, life = 0.2, color = [Color.WHITE, CABLE]})
			return
		for e: Enemy in get_tree().get_nodes_in_group("enemies"):
			if e.dead or e == main.boss or not e.rect().has_point(head):
				continue
			if e.projectile:
				# Reflect (a System Prompt): the hook catches the shot and throws it back as Clawd's own.
				if not Prompts.on("reflect"):
					continue
				e.remove()
				Bullet.fire(main.level, head, (-dir).angle(), 380.0, Weapons.get_def("blaster"), REFLECT_DAMAGE * Weapons.damage_mult())
				Sound.play("deflect")
				main.particles.emit(head, {count = 8, speed = 70, life = 0.3, color = [Color.WHITE, Anchor.ORANGE_LIGHT]})
				state = BACK
				return
			_hook_enemy(e)
			state = BACK
			return
		if travelled >= REACH * reach_mult:
			state = BACK
			return


## The hook strikes `e`: what it has to lose (a shield bot's shield) or HOOK_DAMAGE.
func _hook_enemy(e: Enemy) -> void:
	var stripped: bool = e.has_method("hook_hit") and e.hook_hit(dir)
	if not stripped:
		e.hit(&"shot", HOOK_DAMAGE)
	Sound.play("hookCatch" if stripped else "hit")
	main.particles.emit(head, {count = 10 if stripped else 4, speed = 80, life = 0.3, color = [Color.WHITE, Anchor.CYAN]})


## The claw at the head, turned along the cable, and the cable's dots from the hand to it.
func _update_visual() -> void:
	var out := state != IDLE
	_claw.visible = out
	_cable.visible = out
	if not out:
		return
	var from := hand()
	var d := head - from
	_claw.position = Px.to3(head.round())
	_claw.rotation.z = -d.angle()
	var n := mini(DOTS, maxi(1, floori(d.length() / 3.0)))
	for i in DOTS:
		if i < n:
			var p := from.lerp(head, float(i) / n).round()
			_cable.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, Px.to3(p) + Vector3(0, 0.5 * Px.M, 0)))
			_cable.multimesh.set_instance_color(i, CABLE * (1.4 if i % 2 == 0 else 1.0))
		else:
			_cable.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3.ZERO))
