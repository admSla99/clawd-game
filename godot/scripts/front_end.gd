class_name FrontEnd
extends Node2D

## The title screen (src/scenes/title.ts) and the world map (src/scenes/levelSelect.ts), drawn in the Ui layer
## over the game's own world: Main keeps a level (Main.BACKDROP) loaded behind them and drifts the camera
## through it, so the fog, lights, parallax, bugs and platforms are all alive back there.
## - Title: the CLAWD logo assembles itself out of glowing dots (2 px voxel cubes in front of the level, a
##   MultiMesh, so the bloom picks them up), "L A T E N T   S P A C E" and a subtitle fade in, Clawd stands on a
##   hovering platform with a token spinning beside him (voxels at twice the size), "PRESS SPACE TO START"
##   blinks. Space / Enter / jump or a click opens the map; H and M work as in the game (GameMenu).
## - Map: one dotted path of level nodes per world (three rows, the world's number and name in a column on their
##   left) with a light running along the open stretches; the selected node has an orange border and Clawd
##   hopping on it; locked ones show a padlock, finished ones an orange corner; a locked world says over its row
##   how to open it. An info card names the level with its rescued sub-agents and best time (Progress), and is a PLAY
##   button too. Left / right pick a level, up / down a world, Space plays, Escape goes back to the title; the
##   mouse picks and plays nodes.
## Everything uses the HUD's panel look and the pixel font, on whole view pixels.

enum { CLOSED, TITLE, MAP }

const WORLD_NAMES := {1: "LATENT SPACE", 2: "BENCHMARK WARS", 3: "AGENT MODE"}
## What opens a locked world, said over its row.
const WORLD_HINTS := {2: "— defeat the Hallucination to find a weapon —", 3: "— defeat Codex to find the Tool Call —"}
## The rows' heights (fractions of the view) and the label column left of them (view px).
const ROW_Y := [0.27, 0.47, 0.67]
const LABEL_W := 100
const LOGO_FONT := {
	"C": [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
	"L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
	"A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"W": ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "##.##", "#...#"],
	"D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
}
## Logo: 3 view px per dot, 2 x 2 dots per glyph pixel (title.ts).
const CELL := 3
const GPX := 2
const BORDER := Color("#4A4A4A")
const DIM := Color("#5C5C5C")
## The logo and Clawd on the title sit this far in front of the gameplay plane, in front of the scenery's
## foreground layer (z = 6 m), so nothing covers them. The oblique projection draws a point at depth z shifted
## down by z / 3 (whole pixels for a multiple of 3/16 m); FRONT lifts them back by that much.
const FRONT_Z := 9.0
const FRONT := Vector3(0, FRONT_Z / 3.0, FRONT_Z)
## Clawd, his platform and the token on the title are drawn at twice the size.
const HERO_SCALE := 2.0

var state := CLOSED
var main: Main
## Seconds since the screen opened.
var t := 0.0
## Selected level index on the map, and where the map's Clawd is (view px).
var sel := 0
var clawd_pos := Vector2.ZERO
## Gun textures for the map's Clawd, per weapon id.
var _gun_textures := {}
## Sub-agents and sparks per level (`A` and `S` in its map).
var agents_total := {}
var sparks_total := {}

var _dots := []
var _logo_w := 0
var _props: Node3D
var _logo: MultiMeshInstance3D
var _hero: Node3D
var _hero_body: MeshInstance3D
var _hero_jets: MeshInstance3D
var _hero_token: MeshInstance3D
var _mouse := Vector2(-1000, -1000)
var _last_drift := 0.0
var _fade_in := 0.0


func _ready() -> void:
	_build_logo_dots()


# --- Opening and closing -------------------------------------------------------

func open_title() -> void:
	state = TITLE
	t = 0.0
	_fade_in = 0.0
	_ensure_props()
	_props.visible = true
	visible = true


func open_map(focus := -1) -> void:
	state = MAP
	t = 0.0
	_fade_in = 0.0
	_ensure_props()
	_props.visible = false
	visible = true
	_count_agents()
	# Default to the first unfinished unlocked level (LevelSelectScene's constructor).
	var first := 0
	for i in main.level_ids.size():
		if Progress.is_unlocked(main.level_ids, i):
			first = i
			if not Progress.progress_for(main.level_ids[i]).completed:
				break
	sel = focus if focus >= 0 and Progress.is_unlocked(main.level_ids, focus) else first
	clawd_pos = node_pos(sel)


func close() -> void:
	state = CLOSED
	visible = false
	if _props:
		_props.visible = false


func _count_agents() -> void:
	if not agents_total.is_empty():
		return
	for id in main.level_ids:
		var map := FileAccess.get_file_as_string("res://levels/%s.txt" % id)
		agents_total[id] = map.count("A")
		sparks_total[id] = map.count("S")


# --- Input ---------------------------------------------------------------------

## An event from Main (mouse in SubViewport pixels). Returns true when it was used.
func handle(event: InputEvent) -> bool:
	if event is InputEventMouseMotion:
		_mouse = event.position
		return false
	var click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if click:
		_mouse = event.position
	elif not (event is InputEventKey and event.pressed and not event.echo):
		return false
	match state:
		TITLE:
			if t > 0.4 and (click or event.is_action_pressed("confirm") or event.is_action_pressed("jump")):
				Sound.play("confirm")
				main.show_map()
				return true
		MAP:
			return _map_click(_mouse) if click else _map_key(event)
	return false


func _map_key(event: InputEvent) -> bool:
	var ids: Array = main.level_ids
	var world := _world_of(sel)
	var row := _indices_of(world)
	var k := row.find(sel)
	if _pressed(event, "right"):
		if k < row.size() - 1 and Progress.is_unlocked(ids, row[k + 1]):
			sel = row[k + 1]
			Sound.play("select")
		else:
			Sound.play("denied")
	elif _pressed(event, "left"):
		if k > 0:
			sel = row[k - 1]
			Sound.play("select")
	elif _pressed(event, "down") or _pressed(event, "up"):
		var w := world + (1 if _pressed(event, "down") else -1)
		var open := _indices_of(w).filter(func(i: int) -> bool: return Progress.is_unlocked(ids, i))
		if open.is_empty():
			Sound.play("denied")
		else:
			sel = open[mini(k, open.size() - 1)]
			Sound.play("select")
	elif event.is_action_pressed("shop"):
		_open_shop()
	elif event.is_action_pressed("tree"):
		_open_tree()
	elif event.is_action_pressed("inventory"):
		Sound.play("confirm")
		main.show_items()
	elif event.is_action_pressed("back"):
		Sound.play("select")
		main.show_title()
	elif event.is_action_pressed("confirm") or event.is_action_pressed("jump"):
		_play(sel)
	else:
		return false
	return true


## An action, or its arrow key (like the menus).
func _pressed(event: InputEvent, action: String) -> bool:
	return event.is_action_pressed(action) or event.is_action_pressed("ui_" + action)


## The shop opens once 1-1 is cleared (in TS once a weapon is found; the port's shop sells world-1 things).
func shop_open() -> bool:
	return Progress.progress_for(main.level_ids[0]).completed


func _open_shop() -> void:
	if not shop_open():
		Sound.play("denied")
		return
	Sound.play("confirm")
	main.show_shop()


## The prompt tree opens once the hook is Clawd's (world 3).
func tree_open() -> bool:
	return Progress.has_tool("hook")


func _open_tree() -> void:
	if not tree_open():
		Sound.play("denied")
		return
	Sound.play("confirm")
	main.show_tree()


## Left of the shop's button, once it opens; its free points in brackets.
func _tree_rect() -> Rect2:
	var sr := _shop_rect()
	var w := PixelFont.width(_tree_label()) + 14
	return Rect2(sr.position.x - 6 - w, sr.position.y, w, 14)


func _tree_label() -> String:
	var free := Prompts.points_free()
	return "T · PROMPTS" + (" (%d)" % free if free > 0 else "")


## Left of the prompt tree's button (or the shop's).
func _items_rect() -> Rect2:
	var r := _tree_rect() if tree_open() else _shop_rect()
	var w := PixelFont.width("I · ITEMS") + 14
	return Rect2(r.position.x - 6 - w, r.position.y, w, 14)


func _shop_rect() -> Rect2:
	var v := view()
	var label := "B · SHOP" if shop_open() else "SHOP (LOCKED)"
	var w := PixelFont.width(label) + 14
	return Rect2(v.end.x - 14 - w, v.position.y + 8, w, 14)


func _map_click(p: Vector2) -> bool:
	if _items_rect().has_point(p):
		Sound.play("confirm")
		main.show_items()
		return true
	if _shop_rect().has_point(p):
		_open_shop()
		return true
	if tree_open() and _tree_rect().has_point(p):
		_open_tree()
		return true
	for i in main.level_ids.size():
		if Rect2(node_pos(i) - Vector2(16, 16), Vector2(32, 32)).has_point(p) and Progress.is_unlocked(main.level_ids, i):
			if sel == i:
				_play(i)
			else:
				sel = i
				Sound.play("select")
			return true
	# The info card doubles as a big PLAY button.
	if _card_rect().has_point(p):
		_play(sel)
		return true
	return false


func _play(i: int) -> void:
	Sound.play("confirm")
	main.play(main.level_ids[i])


# --- Layout --------------------------------------------------------------------

## The part of the SubViewport on screen (Main.PAD is cut off on every side).
func view() -> Rect2:
	return Rect2(Vector2.ONE * Main.PAD, get_viewport_rect().size - Vector2.ONE * Main.PAD * 2)


## The gun the map's Clawd holds: the equipped weapon while a world-2 or world-3 level is selected, "" when unarmed.
func map_gun() -> String:
	if _world_of(sel) < 2 or Progress.weapons.is_empty():
		return ""
	return Progress.equipped if Progress.weapons.has(Progress.equipped) else String(Progress.weapons[0])


## The gun in his hands as in a level (Gun._update_visual(), aiming right): 2 px cells, the grip 5 px right of
## his middle and 9 px over his feet (`feet`, view px).
func _draw_map_gun(id: String, feet: Vector2) -> void:
	var tex: ImageTexture = _gun_textures.get(id)
	if tex == null:
		tex = Spark._texture(GunSprite.SPRITES[id], GunSprite.PALETTE)
		_gun_textures[id] = tex
	var size := tex.get_size() * Gun.CELL
	draw_texture_rect(tex, Rect2((feet + Vector2(5, -9 + Gun.CELL) - Vector2(0, size.y)).round(), size), false)


func _world_of(i: int) -> int:
	return int(main.levels[i].world)


func _indices_of(world: int) -> Array:
	var out := []
	for i in main.levels.size():
		if int(main.levels[i].world) == world:
			out.append(i)
	return out


## nodePos(): nodes spread over up to 380 px right of the label column, gently waving (6 px). The worlds' rows sit
## at ROW_Y of the height, far enough apart that Clawd hopping on a node (he reaches 32 px up) stays clear of the
## row above.
func node_pos(i: int) -> Vector2:
	var v := view()
	var world := _world_of(i)
	var row := _indices_of(world)
	var k := row.find(i)
	var left := v.position.x + 12 + LABEL_W
	var span := minf(v.end.x - 26 - left, 380)
	var x := left + span * k / maxf(1, row.size() - 1)
	return Vector2(x, row_y(world) + sin(k * 1.7 + world) * 6).round()


## The middle of world `world`'s row (view px).
func row_y(world: int) -> float:
	var v := view()
	return v.position.y + v.size.y * ROW_Y[clampi(world - 1, 0, ROW_Y.size() - 1)]


func _card_rect() -> Rect2:
	var v := view()
	var w := 264.0
	var y := minf(row_y(3) + 30, v.end.y - 60)
	return Rect2(roundf(v.get_center().x - w / 2), roundf(y), w, 46)


# --- Update --------------------------------------------------------------------

func _process(dt: float) -> void:
	if state == CLOSED:
		return
	t += dt
	_fade_in += dt
	# A new pass of the drift fades in from black, like the start.
	if main.drift_x < _last_drift:
		_fade_in = 0.0
	_last_drift = main.drift_x
	if state == TITLE:
		_update_logo()
		_update_hero()
	elif state == MAP:
		clawd_pos += (node_pos(sel) - clawd_pos) * minf(1.0, dt * 8)
	queue_redraw()


## How dark the fade over the backdrop is: in at the start of each pass, out before the drift starts over.
func _fade() -> float:
	var end := main.camera.bounds.x - main.camera.view_size().x / 2 + 40
	var speed := Main.TITLE_DRIFT if state == TITLE else Main.MAP_DRIFT
	var out := clampf((main.drift_x - (end - speed * 0.6)) / (speed * 0.6), 0.0, 1.0)
	return maxf(1.0 - clampf(_fade_in / 0.8, 0.0, 1.0), out)


## Where SubViewport pixel `sv` is, relative to the camera, at FRONT_Z (lifted by FRONT): the camera sits over the
## middle of the rendered area, DISTANCE in front of the gameplay plane.
func _on_camera(sv: Vector2) -> Vector3:
	var half := get_viewport_rect().size / 2
	return Vector3((sv.x - half.x) * Px.M, -(sv.y - half.y) * Px.M, -GameCamera.DISTANCE) + FRONT


# --- Title: logo and hero ------------------------------------------------------

func _build_logo_dots() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var word := "CLAWD"
	var glyph_w := 5 * GPX * CELL
	var gap := 3 * CELL
	_logo_w = word.length() * glyph_w + (word.length() - 1) * gap
	for li in word.length():
		var glyph: Array = LOGO_FONT[word[li]]
		for gy in glyph.size():
			for gx in 5:
				if glyph[gy][gx] != "#":
					continue
				for dy in GPX:
					for dx in GPX:
						_dots.append({
							"tx": li * (glyph_w + gap) + (gx * GPX + dx) * CELL,
							"ty": (gy * GPX + dy) * CELL,
							"sx": (rng.randf() - 0.5) * 600,
							"sy": (rng.randf() - 0.5) * 400,
							"delay": rng.randf() * 0.6 + li * 0.08,
						})


func _logo_top_left() -> Vector2:
	var v := view()
	return Vector2(roundf(v.get_center().x - _logo_w / 2.0), roundf(v.position.y + v.size.y * 0.13))


func _ensure_props() -> void:
	if _props:
		return
	# They hang on the camera, so they move exactly with the view: placing them in the level from the camera's
	# position each frame left them a fraction of a pixel off the view's rounding, and they jittered.
	_props = Node3D.new()
	_props.name = "TitleProps"
	main.camera.add_child(_props)
	# Logo: one 2 px glowing cube per dot.
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/particles.gdshader")
	var box := BoxMesh.new()
	box.size = Vector3(2, 2, 2) * Px.M
	box.material = mat
	_logo = MultiMeshInstance3D.new()
	_logo.multimesh = MultiMesh.new()
	_logo.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_logo.multimesh.use_colors = true
	_logo.multimesh.mesh = box
	_logo.multimesh.instance_count = _dots.size()
	_props.add_child(_logo)
	# Clawd on a hovering platform (MovingPlatform's meshes) with a token beside him.
	_hero = Node3D.new()
	_hero.scale = Vector3.ONE * HERO_SCALE
	_props.add_child(_hero)
	for m in [MovingPlatform.SLAB_MESH, MovingPlatform.GLOW_MESH]:
		var slab := MeshInstance3D.new()
		slab.mesh = m
		slab.position.y = -MovingPlatform.H * Px.M
		_hero.add_child(slab)
	_hero_jets = MeshInstance3D.new()
	_hero_jets.position.y = -(MovingPlatform.H + 3) * Px.M
	_hero.add_child(_hero_jets)
	_hero_body = MeshInstance3D.new()
	_hero_body.position.x = -7 * Px.M
	_hero.add_child(_hero_body)
	_hero_token = MeshInstance3D.new()
	_hero.add_child(_hero_token)


## Where dot `i` is now (view px of its top-left), and how far it has come (0..1): it flies in from its
## random start with an ease-out over 0.9 s after its delay.
func dot(i: int) -> Array:
	var d: Dictionary = _dots[i]
	var k := _ease_out_cubic(clampf((t - d.delay) / 0.9, 0.0, 1.0))
	return [(_logo_top_left() + Vector2(d.sx * (1 - k) + d.tx, d.sy * (1 - k) + d.ty)).round(), k]


func _update_logo() -> void:
	for i in _dots.size():
		var d: Dictionary = _dots[i]
		var at: Array = dot(i)
		var p: Vector2 = at[0]
		var k: float = at[1]
		var wave := sin(t * 3 - d.tx * 0.05) > 0.92
		# Orange with a little glow, the passing wave light orange and brighter.
		var c := Color("#F0A585") * 1.6 if wave else Color("#D97757") * 1.1
		c.a = 0.3 + 0.7 * k
		_logo.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, _on_camera(p + Vector2.ONE)))
		_logo.multimesh.set_instance_color(i, c)


func _update_hero() -> void:
	var v := view()
	# The platform's top, centred, 4 px of hover bob; Clawd blinks now and then like on the 2D title.
	var bob := roundf(sin(t * 2.0) * 2.0)
	var top := Vector2(v.get_center().x, v.position.y + v.size.y * 0.62 + bob)
	_hero.position = _on_camera(top)
	var blink := sin(t * 0.7) > 0.95
	var breathe := sin(t * 3) > 0.6
	_hero_body.mesh = ClawdSprite.mesh({"arms": "mid", "legs": "stand", "eyes": "blink" if blink else "open", "look": Vector2i(1 if sin(t * 0.4) > 0.7 else 0, 0)})
	_hero_body.position.y = (1.0 if breathe else 0.0) * Px.M / HERO_SCALE
	_hero_jets.mesh = MovingPlatform.JET_MESHES[randi() % MovingPlatform.JET_MESHES.size()]
	# The token floats to his right, bobbing and spinning.
	_hero_token.mesh = TokenSprite.mesh(t * 4)
	_hero_token.rotation.y = PI if fmod(t * 4, TAU) > PI else 0.0
	_hero_token.position = Vector3(15, roundf(16 + sin(t * 2.5) * 2), 0) * Px.M


static func _ease_out_cubic(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3)


# --- Drawing -------------------------------------------------------------------

func _draw() -> void:
	match state:
		TITLE:
			_draw_title()
		MAP:
			_draw_map()
	var f := _fade()
	if f > 0:
		draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color(0.02, 0.02, 0.03, f))


## Text with a 1 px dark shadow, so it reads over the level.
func _text(s: String, at: Vector2, color: Color, centred := false) -> void:
	var x := at.x - (PixelFont.width(s) / 2.0 if centred else 0.0)
	PixelFont.draw(self, s, Vector2(x, at.y + 1), Color(0, 0, 0, 0.65 * color.a))
	PixelFont.draw(self, s, Vector2(x, at.y), color)


## Text at twice the size, with a shadow.
func _big(s: String, at: Vector2, color: Color, centred := false) -> void:
	var x := roundf(at.x - (PixelFont.width(s) if centred else 0.0))
	draw_set_transform(Vector2(x, at.y), 0, Vector2(2, 2))
	PixelFont.draw(self, s, Vector2(0, 1), Color(0, 0, 0, 0.65 * color.a))
	PixelFont.draw(self, s, Vector2.ZERO, color)
	draw_set_transform(Vector2.ZERO)


func _draw_title() -> void:
	var v := view()
	var cx := v.get_center().x
	var lt := _logo_top_left()
	var a := clampf((t - 1.2) * 2, 0.0, 1.0)
	_text("L A T E N T     S P A C E", Vector2(cx, lt.y + 50), Color(Hud.TEXT, a), true)
	_text("a tiny platformer starring Clawd", Vector2(cx, lt.y + 61), Color(Hud.TEXT_DIM, a), true)
	if t > 1.6 and floori(t * 1.6) % 2 == 0:
		_big("PRESS SPACE TO START", Vector2(cx, v.position.y + v.size.y * 0.8), Hud.TEXT, true)
	var by := v.end.y - 10
	_text("H — CONTROLS & KEYS     M — MUTE", Vector2(cx, by), Color(Hud.TEXT_DIM, a), true)
	var ver := "v0.2 · a Clawd fan game"
	_text(ver, Vector2(v.end.x - 8 - PixelFont.width(ver), by), Color(DIM, a))


func _draw_map() -> void:
	var v := view()
	var ids: Array = main.level_ids
	# The level stays alive behind the map, but dimmed so the paths and nodes read; more so from the middle down,
	# where world 3's row lies over the backdrop's lit ground.
	var full := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, full), Color(0.02, 0.02, 0.04, 0.5))
	var y0 := v.position.y + v.size.y * 0.5
	var y1 := v.position.y + v.size.y * 0.6
	var clear := Color(0.02, 0.02, 0.04, 0.0)
	var dark := Color(0.02, 0.02, 0.04, 0.6)
	draw_polygon(PackedVector2Array([Vector2(0, y0), Vector2(full.x, y0), Vector2(full.x, y1), Vector2(0, y1)]),
		PackedColorArray([clear, clear, dark, dark]))
	draw_rect(Rect2(0, y1, full.x, full.y - y1), dark)
	_big("WORLD MAP", v.position + Vector2(14, 8), Hud.TEXT)
	Hud.draw_xp(self, v.position + Vector2(14 + PixelFont.width("WORLD MAP") * 2 + 14, 12), Progress.char_level,
		Experience.fraction())
	# Shop button, then the wallet: banked tokens and sparks not spent (top right, like the TS map).
	var sr := _shop_rect()
	var shop_ok := shop_open()
	var shop_hover := sr.has_point(_mouse) and shop_ok
	Hud.panel(self, sr, Hud.ORANGE if shop_ok else Color("#333333"), Color(0.07, 0.07, 0.08, 0.9))
	PixelFont.draw_centred(self, "B · SHOP" if shop_ok else "SHOP (LOCKED)", sr.get_center().x, sr.position.y + 4,
		Hud.ORANGE_LIGHT if shop_hover else Hud.TEXT if shop_ok else DIM)
	if tree_open():
		var tr := _tree_rect()
		var free := Prompts.points_free() > 0
		Hud.panel(self, tr, Hud.ORANGE if free else Color("#4A4A4A"), Color(0.07, 0.07, 0.08, 0.9))
		PixelFont.draw_centred(self, _tree_label(), tr.get_center().x, tr.position.y + 4,
			Hud.ORANGE_LIGHT if tr.has_point(_mouse) else Hud.TEXT if free else Hud.TEXT_DIM)
		sr = tr
	var ir := _items_rect()
	Hud.panel(self, ir, Color("#4A4A4A"), Color(0.07, 0.07, 0.08, 0.9))
	PixelFont.draw_centred(self, "I · ITEMS", ir.get_center().x, ir.position.y + 4, Hud.ORANGE_LIGHT if ir.has_point(_mouse) else Hud.TEXT)
	sr = ir
	var sparks := str(Progress.sparks_available())
	var wx := sr.position.x - 8 - PixelFont.width(sparks)
	_text(sparks, Vector2(wx, v.position.y + 12), Hud.TEXT)
	draw_texture(Spark.icon(), Vector2(wx - 12, v.position.y + 10))
	var wallet := str(Progress.wallet)
	wx -= 18 + PixelFont.width(wallet)
	_text(wallet, Vector2(wx, v.position.y + 12), Hud.TEXT)
	draw_texture(Hud._coin_tex[8], Vector2(wx - 12, v.position.y + 11))

	for world in WORLD_NAMES:
		var row := _indices_of(world)
		if row.is_empty():
			continue
		var open := Progress.is_unlocked(ids, row[0])
		var first := node_pos(row[0])
		var last := node_pos(row[-1])
		# The world's number and name in the label column, a dotted rule from the name to the first node.
		var lx := v.position.x + 12
		var ly := roundf(row_y(world))
		_text("WORLD %d" % world, Vector2(lx, ly - 9), Hud.ORANGE if open else DIM)
		_text(WORLD_NAMES[world], Vector2(lx, ly + 2), Hud.TEXT_DIM if open else Color("#444444"))
		for x in range(int(lx + PixelFont.width("WORLD %d" % world) + 6), int(first.x - 16), 3):
			draw_rect(Rect2(x, ly - 6, 1, 1), Color(0.35, 0.35, 0.35) if open else Color(0.2, 0.2, 0.2))
		if not open and WORLD_HINTS.has(world):
			# A locked world says how to open it over its row (the TS hint under the row); Clawd is never there.
			_text(WORLD_HINTS[world], Vector2((first.x + last.x) / 2, ly - 25), Color("#6A6A6A"), true)
		# Dotted path, lifted in the middle; a light runs along the open stretches.
		for n in row.size() - 1:
			var p0 := node_pos(row[n])
			var p1 := node_pos(row[n + 1])
			var reach := Progress.is_unlocked(ids, row[n + 1])
			var steps := floori(p0.distance_to(p1) / 5)
			for s in range(1, steps):
				var kk := float(s) / steps
				var p := p0.lerp(p1, kk) + Vector2(0, sin(kk * PI) * -6)
				var on := reach and posmod(floori(t * 6 - s * 0.5), 6) == 0
				draw_rect(Rect2(p.round(), Vector2(2, 2)), Hud.ORANGE if on else Color(0.55, 0.55, 0.55) if reach else Color(0.22, 0.22, 0.22))

	for i in ids.size():
		_draw_node(i)

	# Clawd on the selected node, armed in worlds 2 and 3 once he has a weapon (TS says so but draws him unarmed).
	var hop := roundf(absf(sin(t * 4)) * 2)
	var clawd := ClawdSprite.texture(ClawdSprite.rows({"arms": "mid", "legs": "stand", "eyes": "blink" if fmod(t, 3.0) > 2.85 else "open"}))
	draw_texture(clawd, (clawd_pos + Vector2(-clawd.get_width() / 2.0, -10 - clawd.get_height() - hop)).round())
	var gun_id := map_gun()
	if gun_id != "":
		_draw_map_gun(gun_id, clawd_pos + Vector2(0, -10 - hop))

	_draw_card()
	# All sparks found, bottom left (SPARKS FOUND in TS), and the keys.
	var all := 0
	for id in main.level_ids:
		all += sparks_total.get(id, 0)
	draw_texture(Spark.icon(Progress.total_sparks() == 0), Vector2(v.position.x + 10, v.end.y - 12))
	_text("%d / %d" % [Progress.total_sparks(), all], Vector2(v.position.x + 23, v.end.y - 10), Color(DIM))
	var help := "← → LEVEL   ↑ ↓ WORLD   SPACE PLAY   I ITEMS   B SHOP   " + ("T PROMPTS   " if tree_open() else "") + "ESC TITLE"
	_text(help, Vector2(v.end.x - 10 - PixelFont.width(help), v.end.y - 10), Color(DIM))


func _draw_node(i: int) -> void:
	var def: Dictionary = main.levels[i]
	var p := node_pos(i)
	var open := Progress.is_unlocked(main.level_ids, i)
	var done: bool = Progress.progress_for(def.id).completed
	var selected := i == sel
	var hover := Rect2(p - Vector2(12, 9), Vector2(24, 18)).has_point(_mouse) and open
	var border := Hud.ORANGE if selected else Color(0.63, 0.63, 0.63) if done else Hud.ORANGE_LIGHT.lerp(BORDER, 0.5) if hover else Color(0.35, 0.35, 0.35) if open else Color(0.2, 0.2, 0.2)
	var fill := Color(0.16, 0.07, 0.07, 0.95) if def.has("boss") else Color(0.07, 0.07, 0.08, 0.95)
	Hud.panel(self, Rect2(p - Vector2(12, 9), Vector2(24, 18)), border, fill, selected)
	if open:
		var label: String = "BOSS" if def.has("boss") else def.id
		PixelFont.draw_centred(self, label, p.x, p.y - 3, Hud.ORANGE_LIGHT if selected else Hud.TEXT)
	else:
		# Padlock.
		var c := Color(0.32, 0.32, 0.32)
		draw_rect(Rect2(p + Vector2(-3, -1), Vector2(6, 5)), c)
		draw_rect(Rect2(p + Vector2(-2, -4), Vector2(1, 3)), c)
		draw_rect(Rect2(p + Vector2(1, -4), Vector2(1, 3)), c)
		draw_rect(Rect2(p + Vector2(-2, -4), Vector2(4, 1)), c)
	if done:
		draw_rect(Rect2(p + Vector2(8, -8), Vector2(2, 2)), Hud.ORANGE)


func _draw_card() -> void:
	var def: Dictionary = main.levels[sel]
	var prog := Progress.progress_for(def.id)
	var r := _card_rect()
	var hover := r.has_point(_mouse)
	Hud.panel(self, r, Hud.ORANGE if hover else BORDER, Color(0.07, 0.07, 0.08, 0.94), true)
	var cx := r.get_center().x
	# The name at twice the size when it fits the card, else at the normal size (2-3's is too long).
	var title := "%s · %s" % [def.id, String(def.name).to_upper()]
	if PixelFont.width(title) * 2 <= r.size.x - 16:
		_big(title, Vector2(cx, r.position.y + 6), Hud.TEXT, true)
	else:
		PixelFont.draw_centred(self, title, cx + 1, r.position.y + 11, Color(0, 0, 0, 0.65))
		PixelFont.draw_centred(self, title, cx, r.position.y + 10, Hud.TEXT)
	PixelFont.draw_centred(self, def.subtitle, cx, r.position.y + 22, Hud.TEXT_DIM)
	# The bottom row left to right: sparks, sub-agents, CLEARED, ARMED; the best time (or PLAY) on the right.
	var y := r.position.y + 33
	var x := r.position.x + 10
	var stotal: int = sparks_total.get(def.id, 0)
	if stotal > 0:
		var sgot := Progress.count(prog.sparks)
		var s := "%d / %d" % [sgot, stotal]
		draw_texture(Spark.icon(sgot == 0), Vector2(x, y - 2))
		PixelFont.draw(self, s, Vector2(x + 13, y), Hud.TEXT)
		x += 13 + PixelFont.width(s) + 12
	var total: int = agents_total.get(def.id, 0)
	if total > 0:
		var got := Progress.count(prog.agents)
		var s := "%d / %d" % [got, total]
		draw_texture(ClawdSprite.texture(ClawdSprite.frame(), Color(0, 0, 0, 0) if got > 0 else Color("#6A6A6A")), Vector2(x, y - 2))
		PixelFont.draw(self, s, Vector2(x + 17, y), Hud.TEXT)
		x += 17 + PixelFont.width(s) + 12
	var tags := []
	if prog.completed:
		tags.append(["CLEARED", Hud.ORANGE_LIGHT])
	if def.world >= 2:
		tags.append(["ARMED", Hud.ORANGE])
	for tag in tags:
		PixelFont.draw(self, tag[0], Vector2(x, y), tag[1])
		x += PixelFont.width(tag[0]) + 8
	if prog.best_time != null:
		var bt := Progress.format_time(prog.best_time)
		PixelFont.draw(self, bt, Vector2(r.end.x - 10 - PixelFont.width(bt), y), Hud.TEXT_DIM)
	elif hover or floori(t * 1.6) % 2 == 0:
		var play := "SPACE · PLAY"
		PixelFont.draw(self, play, Vector2(r.end.x - 10 - PixelFont.width(play), y), Hud.ORANGE_LIGHT)
