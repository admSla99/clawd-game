class_name TreeScreen
extends Node2D

## The prompt tree's window (docs/prompt-tree-plan.md), like Path of Exile's passive tree, over the drifting
## backdrop like the shop: the nodes of Prompts joined by their links in a pannable field (small nodes, notables,
## keystones, the start in the middle), lit orange once allocated, outlined where a point could go. A card at the
## bottom tells the selected (or hovered) node's name and what it does; the start's card adds up everything
## allocated. Top right the points (free / all) and the wallet, and a button that buys a point. Keys: arrows / WASD
## move to the nearest node that way, Space / Enter (or a click) allocates or refunds, U buys a point, R twice
## refunds everything, Escape or T goes back to the map; dragging with the mouse pans, and the view follows the
## selection.

## The field's margin around the view's edges and how much room the card takes at the bottom.
const CARD_H := 46
const FIELD_TOP := 27
## A node's half-size by kind.
const HALF := {"start": 7, "small": 3, "notable": 5, "keystone": 7}
## The branches' names, dim, by where they grow (tree px).
const LABELS := [["OFFENSE", Vector2(115, -36)], ["TOOL CALL", Vector2(62, -72)], ["SUB-AGENTS", Vector2(-115, -36)],
	["SURVIVAL", Vector2(-62, 72)], ["TOKENS", Vector2(112, 56)]]
const LINK_OFF := Color("#34343A")
const NODE_OFF := Color("#4A4A50")
const FILL_OFF := Color(0.06, 0.06, 0.07, 1.0)
## What the stats are called on the start's card, in order.
const STAT_NAMES := [["damage", "% damage"], ["rate", "% fire rate"], ["tokens", "% tokens"], ["reach", "% hook reach"],
	["zip", "% zip speed"], ["hover", "% hover"], ["run", "% run speed"], ["hearts", " heart(s)"], ["slots", " sub-agent(s)"],
	["stand", " s standing"], ["magnet", " px magnet"], ["minion_damage", "% sub-agent damage"], ["minion_rate", "% sub-agent fire rate"]]

var main: Main
var sel := Prompts.START
var t := 0.0
## The field's centre in tree px (pans and follows the selection).
var cam := Vector2.ZERO
var _mouse := Vector2(-1000, -1000)
var _press := Vector2.ZERO
var _pressing := false
var _dragging := false
## A word for a moment under the points (bought, refused, reset).
var note := ""
var note_t := 0.0
## R pressed once: a second press within this time resets the tree.
var reset_armed := 0.0
## A node just allocated or refunded flashes.
var flash_id := ""
var flash_t := 0.0
var _field: Node2D


func _ready() -> void:
	# The tree is drawn on a child, above the field's panel; what lies past the field's edges is left out.
	_field = Node2D.new()
	add_child(_field)
	_field.draw.connect(_draw_field)


func open() -> void:
	visible = true
	t = 0.0
	sel = Prompts.START
	cam = centre()
	note = ""
	reset_armed = 0.0
	_dragging = false
	_pressing = false


func close() -> void:
	visible = false


# --- Input ---------------------------------------------------------------------

func handle(event: InputEvent) -> bool:
	if event is InputEventMouseMotion:
		_mouse = event.position
		if _pressing and (_dragging or _mouse.distance_to(_press) > 3):
			_dragging = true
			cam -= event.relative
		return false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_mouse = event.position
		if event.pressed:
			_pressing = true
			_dragging = false
			_press = _mouse
			return true
		_pressing = false
		if _dragging:
			_dragging = false
			return true
		if _buy_rect().has_point(_mouse):
			buy()
			return true
		var id := node_at(_mouse)
		if id != "":
			sel = id
			activate()
		return true
	if not (event is InputEventKey and event.pressed and not event.echo):
		return false
	if event.is_action_pressed("back") or event.is_action_pressed("tree"):
		Sound.play("select")
		main.show_map(main.front.sel)
	elif event.physical_keycode == KEY_U:
		buy()
	elif event.physical_keycode == KEY_R:
		if reset_armed > 0:
			Prompts.reset()
			reset_armed = 0.0
			Sound.play("agentGone")
			say("EVERY POINT REFUNDED")
		elif not Progress.tree.is_empty():
			reset_armed = 1.5
			Sound.play("select")
			say("PRESS R AGAIN TO REFUND ALL")
	elif _dir(event) != Vector2.ZERO:
		var next := step(sel, _dir(event))
		if next != "":
			sel = next
			Sound.play("select")
	elif event.is_action_pressed("confirm") or event.is_action_pressed("jump"):
		activate()
	else:
		return false
	return true


func _dir(event: InputEvent) -> Vector2:
	if event.is_action_pressed("left") or event.is_action_pressed("ui_left"):
		return Vector2.LEFT
	if event.is_action_pressed("right") or event.is_action_pressed("ui_right"):
		return Vector2.RIGHT
	if event.is_action_pressed("up") or event.is_action_pressed("ui_up"):
		return Vector2.UP
	if event.is_action_pressed("down") or event.is_action_pressed("ui_down"):
		return Vector2.DOWN
	return Vector2.ZERO


## The nearest node from `from` towards `dir` (within 60° of it, nearer and straighter first), or "".
static func step(from: String, dir: Vector2) -> String:
	var at: Vector2 = Prompts.NODES[from].at
	var best := ""
	var best_score := INF
	for id in Prompts.NODES:
		if id == from:
			continue
		var d: Vector2 = Prompts.NODES[id].at - at
		var off := absf(dir.angle_to(d))
		if off > deg_to_rad(60):
			continue
		var score := d.length() * (1.0 + off * 2.0)
		if score < best_score:
			best_score = score
			best = id
	return best


## Allocates or refunds the selected node.
func activate() -> void:
	var r := Prompts.toggle(sel)
	match r:
		"allocated", "refunded":
			Sound.play("confirm" if r == "allocated" else "agentGone")
			flash_id = sel
			flash_t = 0.35
		"no points":
			Sound.play("denied")
			say("NO FREE POINTS · U BUYS ONE")
		"far":
			Sound.play("denied")
			say("NOT NEXT TO YOUR TREE")
		"holds":
			Sound.play("denied")
			say("OTHER NODES HANG ON IT")
		_:
			Sound.play("denied")


func buy() -> void:
	match Prompts.buy_point():
		"bought":
			Sound.play("buy")
			say("A NEW POINT")
		"poor":
			Sound.play("denied")
			say("NOT ENOUGH TOKENS")
		_:
			Sound.play("denied")
			say("NO MORE POINTS FOR SALE")


func say(s: String) -> void:
	note = s
	note_t = 2.5


# --- Layout --------------------------------------------------------------------

func _view() -> Rect2:
	return Rect2(Vector2.ONE * Main.PAD, get_viewport_rect().size - Vector2.ONE * Main.PAD * 2)


## The box round the tree's nodes, with room for the biggest.
static func bounds() -> Rect2:
	var box := Rect2(Vector2.ZERO, Vector2.ZERO)
	for id in Prompts.NODES:
		box = box.expand(Prompts.NODES[id].at)
	return box.grow(8)


## The middle of the tree (where the view starts).
static func centre() -> Vector2:
	return bounds().get_center().round()


## Keeps the view on the tree: along an axis where the whole tree fits it stays in the middle.
static func clamp_cam(c: Vector2, size: Vector2) -> Vector2:
	var b := bounds()
	for i in 2:
		var lo := b.position[i] + size[i] / 2
		var hi := b.end[i] - size[i] / 2
		c[i] = b.get_center()[i] if lo > hi else clampf(c[i], lo, hi)
	return c


## Where the tree is drawn.
func field() -> Rect2:
	var v := _view()
	return Rect2(v.position.x + 6, v.position.y + FIELD_TOP, maxf(0, v.size.x - 12), maxf(0, v.size.y - FIELD_TOP - CARD_H - 18))


## A node's place on the screen.
func screen_of(id: String) -> Vector2:
	var at: Vector2 = Prompts.NODES[id].at
	return (field().get_center() + at - cam).round()


## The node under screen point `p`, or "".
func node_at(p: Vector2) -> String:
	if not field().has_point(p):
		return ""
	for id in Prompts.NODES:
		var h: int = HALF[Prompts.NODES[id].kind] + 2
		if Rect2(screen_of(id) - Vector2(h, h), Vector2(h, h) * 2 + Vector2.ONE).has_point(p):
			return id
	return ""


func _card_rect() -> Rect2:
	var v := _view()
	return Rect2(v.position.x + 14, v.end.y - CARD_H - 14, v.size.x - 28, CARD_H)


func _buy_rect() -> Rect2:
	var v := _view()
	var p := Prompts.point_price()
	var label := "U · BUY POINT" if p >= 0 else "ALL POINTS BOUGHT"
	var w := PixelFont.width(label) + (PixelFont.width(str(p)) + 32 if p >= 0 else 14)
	return Rect2(v.end.x - 14 - w, v.position.y + 8, w, 14)


# --- Update --------------------------------------------------------------------

func _process(dt: float) -> void:
	if not visible:
		return
	t += dt
	note_t = maxf(0.0, note_t - dt)
	reset_armed = maxf(0.0, reset_armed - dt)
	flash_t = maxf(0.0, flash_t - dt)
	# The view follows the selection once it nears the field's edge (not while the mouse drags it).
	if not _dragging:
		var f := field().grow(-26)
		var s: Vector2 = field().get_center() + Prompts.NODES[sel].at - cam
		var want := cam
		if s.x < f.position.x:
			want.x -= f.position.x - s.x
		elif s.x > f.end.x:
			want.x += s.x - f.end.x
		if s.y < f.position.y:
			want.y -= f.position.y - s.y
		elif s.y > f.end.y:
			want.y += s.y - f.end.y
		cam = cam.lerp(want, minf(1.0, dt * 10))
	cam = clamp_cam(cam, field().size)
	var hover := node_at(_mouse)
	if hover != "" and not _dragging:
		sel = hover
	queue_redraw()
	_field.queue_redraw()


# --- Drawing -------------------------------------------------------------------

func _draw() -> void:
	var v := _view()
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color(0.02, 0.02, 0.04, 0.72))
	_big("PROMPT TREE", v.position + Vector2(14, 8), Hud.ORANGE)
	var free := Prompts.points_free()
	var pts := "%d FREE · %d / %d POINTS" % [free, Progress.tree.size(), Prompts.points_total()]
	var x := v.position.x + 14 + PixelFont.width("PROMPT TREE") * 2 + 12
	_text(pts, Vector2(x, v.position.y + 12), Hud.ORANGE_LIGHT if free > 0 else Hud.TEXT_DIM)
	_draw_buy(v)
	var fr := field()
	Hud.panel(self, fr.grow(1), Color("#26262A"), Color(0.03, 0.03, 0.04, 0.55))
	_draw_card()
	var help := "ARROWS MOVE   SPACE ALLOCATE / REFUND   U BUY POINT   R R RESET   DRAG PAN   ESC BACK"
	_text(help, Vector2(v.get_center().x - PixelFont.width(help) / 2.0, v.end.y - 10), Color("#5C5C5C"))


func _draw_buy(v: Rect2) -> void:
	var r := _buy_rect()
	var p := Prompts.point_price()
	var can := p >= 0 and Progress.wallet >= p
	var hover := r.has_point(_mouse)
	Hud.panel(self, r, Hud.ORANGE if can else Color("#3A3A3A"), Color(0.07, 0.07, 0.08, 0.9))
	if p < 0:
		PixelFont.draw_centred(self, "ALL POINTS BOUGHT", r.get_center().x, r.position.y + 4, Hud.TEXT_DIM)
	else:
		PixelFont.draw(self, "U · BUY POINT", r.position + Vector2(6, 4), Hud.ORANGE_LIGHT if hover and can else Hud.TEXT if can else Hud.TEXT_DIM)
		var s := str(p)
		PixelFont.draw(self, s, Vector2(r.end.x - 6 - PixelFont.width(s), r.position.y + 4), Hud.TEXT if can else Hud.RED)
		draw_texture(Hud._coin_tex[8], Vector2(r.end.x - 17 - PixelFont.width(s), r.position.y + 3))
	# The wallet left of it.
	var tokens := str(Progress.wallet)
	var wx := r.position.x - 8 - PixelFont.width(tokens)
	_text(tokens, Vector2(wx, v.position.y + 12), Hud.TEXT)
	draw_texture(Hud._coin_tex[8], Vector2(wx - 12, v.position.y + 11))


func _draw_field() -> void:
	var fr := field()
	# A window too small for the tree (headless runs) draws none of it.
	if fr.size.x < 40 or fr.size.y < 40:
		return
	for l in LABELS:
		var at: Vector2 = (fr.get_center() + l[1] - cam).round()
		if fr.grow(-4).has_point(at):
			PixelFont.draw_centred(_field, l[0], at.x, at.y - 3, Color("#4E4E56"))
	for l in Prompts.LINKS:
		var a: String = l[0]
		var b: String = l[1]
		var both := Prompts.on(a) and Prompts.on(b)
		var one := Prompts.on(a) or Prompts.on(b)
		var c := Hud.ORANGE if both else Color(Hud.ORANGE_LIGHT, 0.45) if one else LINK_OFF
		_line(screen_of(a), screen_of(b), c, 2 if both else 1)
	for id in Prompts.NODES:
		_draw_node(id)
	if note_t > 0:
		var w := PixelFont.width(note) + 12
		var r := Rect2(fr.get_center().x - w / 2.0, fr.position.y + 4, w, 13)
		Hud.panel(_field, r, Color("#3A3A3A"), Color(0.05, 0.05, 0.06, 0.95))
		PixelFont.draw_centred(_field, note, r.get_center().x, r.position.y + 3, Hud.RED if note.begins_with("NO") else Hud.ORANGE_LIGHT)


## A pixel line from `a` to `b`, `w` px thick, inside the field.
func _line(a: Vector2, b: Vector2, c: Color, w: int) -> void:
	var f := field()
	var n := maxi(1, ceili(maxf(absf(b.x - a.x), absf(b.y - a.y))))
	for i in n + 1:
		var p := a.lerp(b, float(i) / n).round()
		if not f.has_point(p):
			continue
		_field.draw_rect(Rect2(p - Vector2(floori(w / 2.0), floori(w / 2.0)), Vector2(w, w)), c)


func _draw_node(id: String) -> void:
	var node: Dictionary = Prompts.NODES[id]
	var p := screen_of(id)
	var h: int = HALF[node.kind]
	var on := Prompts.on(id)
	var open := not on and Prompts.reachable(id)
	var pulse := 0.5 + 0.5 * sin(t * 5)
	var border := Hud.ORANGE_LIGHT if on else Hud.ORANGE.lerp(Hud.ORANGE_LIGHT, pulse) if open else NODE_OFF
	var fill := Hud.ORANGE if on else FILL_OFF
	if id == flash_id and flash_t > 0:
		fill = Color.WHITE
	var r := Rect2(p - Vector2(h, h), Vector2(h, h) * 2 + Vector2.ONE)
	if not field().encloses(r.grow(1)):
		return
	match node.kind:
		"small":
			_field.draw_rect(r, border)
			_field.draw_rect(r.grow(-1), fill)
		"notable":
			# A rounded square with a ring inside.
			_field.draw_rect(r.grow_individual(-1, 0, -1, 0), border)
			_field.draw_rect(r.grow_individual(0, -1, 0, -1), border)
			_field.draw_rect(r.grow(-1), fill)
			_field.draw_rect(r.grow(-3), border if on else NODE_OFF)
			_field.draw_rect(r.grow(-4), fill)
		"keystone", "start":
			# An octagon: two crossing bars, with a dark ring and a core.
			var k := 3
			_field.draw_rect(r.grow_individual(-k, 0, -k, 0), border)
			_field.draw_rect(r.grow_individual(0, -k, 0, -k), border)
			_field.draw_rect(r.grow(-1), border)
			_field.draw_rect(r.grow(-2), fill if id != Prompts.START else Color("#2A1A16"))
			_field.draw_rect(r.grow(-4), border)
			_field.draw_rect(r.grow(-5), fill)
	if id == sel:
		var s := h + 3 + roundi(absf(sin(t * 6)))
		for sx in [-1, 1]:
			for sy in [-1, 1]:
				var k := p + Vector2(sx * s, sy * s)
				_field.draw_rect(Rect2(k.x - (2 if sx > 0 else 0), k.y, 3, 1), Hud.TEXT)
				_field.draw_rect(Rect2(k.x, k.y - (2 if sy > 0 else 0), 1, 3), Hud.TEXT)


func _draw_card() -> void:
	var d := _card_rect()
	var node: Dictionary = Prompts.NODES[sel]
	Hud.panel(self, d, Color("#4A4A4A"), Color(0.07, 0.07, 0.08, 0.95), true)
	var kind: String = {"small": "", "notable": "NOTABLE", "keystone": "KEYSTONE", "start": ""}[node.kind]
	_text(String(node.name).to_upper(), d.position + Vector2(8, 6), Hud.TEXT)
	if kind != "":
		PixelFont.draw(self, kind, d.position + Vector2(14 + PixelFont.width(String(node.name).to_upper()), 6), Hud.ORANGE if kind == "KEYSTONE" else Hud.ORANGE_LIGHT)
	var desc: String = node.desc
	if sel == Prompts.START:
		desc = totals()
	var lines := wrap_text(desc, d.size.x - 16)
	for i in mini(2, lines.size()):
		PixelFont.draw(self, lines[i], d.position + Vector2(8, 17 + i * 8), Hud.TEXT_DIM)
	var hint := ""
	var col := Hud.ORANGE
	if sel == Prompts.START:
		hint = "%d POINTS FROM WORLD 3'S SPARKS · %d BOUGHT" % [Progress.tree_sparks(), Progress.points_bought]
		col = Hud.TEXT_DIM
	elif Prompts.on(sel):
		hint = "ALLOCATED · SPACE / CLICK: REFUND" if Prompts.can_refund(sel) else "ALLOCATED · OTHER NODES HANG ON IT"
		col = Hud.ORANGE_LIGHT if Prompts.can_refund(sel) else Hud.TEXT_DIM
	elif not Prompts.reachable(sel):
		hint = "NOT NEXT TO YOUR TREE YET"
		col = Hud.TEXT_DIM
	elif Prompts.points_free() <= 0:
		hint = "NO FREE POINTS · U: BUY ONE"
		col = Hud.RED
	else:
		hint = "SPACE / CLICK: ALLOCATE (1 POINT)"
	if reset_armed > 0:
		hint = "PRESS R AGAIN TO REFUND EVERY POINT"
		col = Hud.RED
	PixelFont.draw(self, hint, d.position + Vector2(8, 35), col)


## The words of `s` in lines at most `w` px wide.
static func wrap_text(s: String, w: float) -> Array:
	var out := []
	var line := ""
	for word in s.split(" "):
		var test := word if line == "" else line + " " + word
		if PixelFont.width(test) > w and line != "":
			out.append(line)
			line = word
		else:
			line = test
	if line != "":
		out.append(line)
	return out


## What the allocated nodes add up to, for the start's card.
static func totals() -> String:
	var parts := []
	for s in STAT_NAMES:
		var v := Prompts.stat(s[0])
		if v != 0:
			parts.append("%s%d%s" % ["+" if v > 0 else "", roundi(v), s[1]])
	for id in ["temperature", "reflect", "tooluse", "parallel"]:
		if Prompts.on(id):
			parts.append(String(Prompts.NODES[id].short).to_lower())
	return "Nothing allocated yet." if parts.is_empty() else ", ".join(PackedStringArray(parts))


func _text(s: String, at: Vector2, color: Color) -> void:
	PixelFont.draw(self, s, at + Vector2(0, 1), Color(0, 0, 0, 0.65))
	PixelFont.draw(self, s, at, color)


func _big(s: String, at: Vector2, color: Color) -> void:
	draw_set_transform(at.round(), 0, Vector2(2, 2))
	PixelFont.draw(self, s, Vector2(0, 1), Color(0, 0, 0, 0.65))
	PixelFont.draw(self, s, Vector2.ZERO, color)
	draw_set_transform(Vector2.ZERO)
