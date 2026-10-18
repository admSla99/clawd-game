class_name TreeScreen
extends Node2D

## The prompt tree's window (docs/prompt-tree-plan.md), like Path of Exile's passive tree, over the drifting
## backdrop like the shop: the nodes of Prompts joined by their links in a pannable field (small nodes, notables,
## keystones, the start in the middle), lit orange once allocated, outlined where a point could go. A card at the
## bottom tells the selected (or hovered) node's name and what it does; the start's card adds up everything
## allocated. Top right the points (free / all) and the wallet, and a button that buys a point. Keys: arrows / WASD
## move to the nearest node that way, Space / Enter (or a click) allocates or refunds, U buys a point, R twice
## refunds everything, Escape or T goes back to the map; dragging with the mouse pans, and the view follows the
## selection made with the keys. A tree bigger than the field (the prompt tree, docs/endgame-plan.md E9) has a
## small map of itself in the field's corner (the view's frame on it; a click or drag there moves the view), and
## the start's selected card lists what every allocated node adds up to in a panel over the field.
## The same window draws the Atlas's tree (scripts/atlas.gd, docs/endgame-plan.md E8) while `atlas` is set: its nodes,
## a strip of the sixteen map tiers over the field (completed, open, locked; coloured by world) and no point to buy.
## Tab switches between the two once the hideout is open.

## The field's margin around the view's edges and how much room the card takes at the bottom.
const CARD_H := 46
const FIELD_TOP := 27
## A node's half-size by kind.
const HALF := {"start": 7, "small": 3, "notable": 5, "keystone": 7}
## The small map of a big tree: its scale.
const MINI_SCALE := 0.14
## The Atlas's tier strip: its height over the field, a cell's size, and each world's colour.
const STRIP_H := 18
const TIER_CELL := Vector2(21, 11)
const WORLD_COLOR := {1: Color("#968CD2"), 2: Color("#EA7C3E"), 3: Color("#5FD8C8")}
const LINK_OFF := Color("#34343A")
const NODE_OFF := Color("#4A4A50")
const FILL_OFF := Color(0.06, 0.06, 0.07, 1.0)
## What the stats are called in the start's list, in order, and the keystones' and notables' flags.
const STAT_NAMES := [["damage", "% damage"], ["rate", "% fire rate"], ["crit_inc", "% critical chance"],
	["crit_multi", "% critical damage"], ["heat", "% context window"], ["ele_damage", "% elemental damage"],
	["extra_fire", "% added as overheat"], ["extra_cold", "% added as latency"], ["extra_lightning", "% added as voltage"],
	["ignite", "% ignite chance"], ["shock", "% shock chance"], ["freeze", "% easier freezing"], ["burn", "% burning damage"],
	["ailment_time", "% ailment duration"], ["hearts", " heart(s)"], ["life_pct", "% maximum life"], ["armour", " armour"],
	["armour_pct", "% armour"], ["evasion", " evasion"], ["evasion_pct", "% evasion"], ["res_ele", "% elemental res."],
	["res_chaos", "% corruption res."], ["regen_pct", "% life regen a second"], ["leech", "% leech"],
	["avoid", "% ailment avoidance"], ["reach", "% hook reach"], ["zip", "% zip speed"], ["hover", "% hover"],
	["run", "% run speed"], ["tokens", "% tokens"], ["magnet", " px magnet"], ["slots", " sub-agent(s)"],
	["stand", " s standing"], ["minion_damage", "% sub-agent damage"], ["minion_rate", "% sub-agent fire rate"]]
const FLAG_NAMES := [["temperature", "temperature 1.5"], ["precise", "temperature 0"], ["reflect", "reflect"],
	["zipguard", "agentic loop"], ["minions", "tool use"], ["parallel", "parallel tool calls"], ["robust", "robustness"],
	["airgap", "air-gapped"], ["gradleech", "gradient leech"]]
const ATLAS_STAT_NAMES := [["quantity", "% item quantity"], ["rarity", "% item rarity"], ["pack", "% more enemies"],
	["mod_loot", "% loot from mods"], ["monster_damage", "% enemy damage"], ["map_drop", "% maps dropped"],
	["map_up", "% maps a tier higher"], ["boss_maps", " map(s) from bosses"], ["currency", "% orbs"],
	["orb_distill", "% distillations"], ["orb_temperature", "% temperature spikes"], ["orb_finetune", "% fine-tunes"],
	["xp", "% experience"], ["death_xp", "% less experience lost"], ["portals", " portal(s)"],
	["res_penalty", "% less resistance penalty a tier"]]

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
## The view keeps the selection in sight (after the keys moved it; not after the mouse panned).
var follow := true
## Dragging on the small map.
var _mini_drag := false
## A node just allocated or refunded flashes.
var flash_id := ""
var flash_t := 0.0
var _field: Node2D
## Opened over a level (the hideout's terminal): back closes it there instead of going to the map.
var overlay := false
## Showing the Atlas's tree instead of the prompt tree.
var atlas := false


func _ready() -> void:
	# The tree is drawn on a child, above the field's panel; what lies past the field's edges is left out.
	_field = Node2D.new()
	add_child(_field)
	_field.draw.connect(_draw_field)


## The tree shown: Prompts or Atlas (both have the same static functions).
func src():
	return Atlas if atlas else Prompts


func open(show_atlas := false) -> void:
	atlas = show_atlas
	visible = true
	t = 0.0
	sel = src().START
	cam = centre()
	note = ""
	reset_armed = 0.0
	_dragging = false
	_pressing = false
	_mini_drag = false
	follow = true
	if Progress.tree_redrawn and not atlas:
		Progress.tree_redrawn = false
		say("THE TREE WAS REDRAWN · EVERY POINT IS BACK")


func close() -> void:
	visible = false


# --- Input ---------------------------------------------------------------------

func handle(event: InputEvent) -> bool:
	if event is InputEventMouseMotion:
		_mouse = event.position
		if _mini_drag:
			cam = mini_to_tree(_mouse)
		elif _pressing and (_dragging or _mouse.distance_to(_press) > 3):
			_dragging = true
			follow = false
			cam -= event.relative
		return false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_mouse = event.position
		if event.pressed:
			if mini_rect().has_point(_mouse):
				_mini_drag = true
				follow = false
				cam = mini_to_tree(_mouse)
				return true
			_pressing = true
			_dragging = false
			_press = _mouse
			return true
		if _mini_drag:
			_mini_drag = false
			return true
		_pressing = false
		if _dragging:
			_dragging = false
			return true
		if not atlas and _buy_rect().has_point(_mouse):
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
		if overlay:
			main.close_tree_in_level()
		else:
			main.show_map(main.front.sel)
	elif event.physical_keycode == KEY_TAB and Main.hideout_open():
		Sound.play("select")
		open(not atlas)
	elif event.physical_keycode == KEY_U and not atlas:
		buy()
	elif event.physical_keycode == KEY_R:
		if reset_armed > 0:
			src().reset()
			reset_armed = 0.0
			Sound.play("agentGone")
			say("EVERY POINT REFUNDED")
		elif not src().allocated().is_empty():
			reset_armed = 1.5
			Sound.play("select")
			say("PRESS R AGAIN TO REFUND ALL")
	elif _dir(event) != Vector2.ZERO:
		var next := step(src().NODES, sel, _dir(event))
		if next != "":
			sel = next
			follow = true
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


## The nearest node of `nodes` from `from` towards `dir` (within 60° of it, nearer and straighter first), or "".
static func step(nodes: Dictionary, from: String, dir: Vector2) -> String:
	var at: Vector2 = nodes[from].at
	var best := ""
	var best_score := INF
	for id in nodes:
		if id == from:
			continue
		var d: Vector2 = nodes[id].at - at
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
	var r: String = src().toggle(sel)
	match r:
		"allocated", "refunded":
			Sound.play("confirm" if r == "allocated" else "agentGone")
			flash_id = sel
			flash_t = 0.35
		"no points":
			Sound.play("denied")
			say("NO FREE POINTS · COMPLETE A NEW TIER" if atlas else "NO FREE POINTS · U BUYS ONE")
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


## The box round a tree's (Prompts' or Atlas') nodes and its labels, with room for the biggest.
static func bounds(tree) -> Rect2:
	var box := Rect2(Vector2.ZERO, Vector2.ZERO)
	for id in tree.NODES:
		box = box.expand(tree.NODES[id].at)
	for l in tree.LABELS:
		var w := PixelFont.width(l[0]) / 2.0
		box = box.expand(l[1] - Vector2(w, 4)).expand(l[1] + Vector2(w, 4))
	return box.grow(8)


## The middle of the tree shown (where the view starts).
func centre() -> Vector2:
	return bounds(src()).get_center().round()


## Keeps the view on `tree`: along an axis where the whole tree fits it stays in the middle.
static func clamp_cam(tree, c: Vector2, size: Vector2) -> Vector2:
	var b := bounds(tree)
	for i in 2:
		var lo := b.position[i] + size[i] / 2
		var hi := b.end[i] - size[i] / 2
		c[i] = b.get_center()[i] if lo > hi else clampf(c[i], lo, hi)
	return c


## Where the tree is drawn (lower in the Atlas, under its tier strip).
func field() -> Rect2:
	var v := _view()
	var top := FIELD_TOP + (STRIP_H if atlas else 0)
	return Rect2(v.position.x + 6, v.position.y + top, maxf(0, v.size.x - 12), maxf(0, v.size.y - top - CARD_H - 18))


## A node's place on the screen.
func screen_of(id: String) -> Vector2:
	var at: Vector2 = src().NODES[id].at
	return (field().get_center() + at - cam).round()


## The node under screen point `p`, or "".
func node_at(p: Vector2) -> String:
	if not field().has_point(p) or mini_rect().has_point(p):
		return ""
	var nodes: Dictionary = src().NODES
	for id in nodes:
		var h: int = HALF[nodes[id].kind] + 2
		if Rect2(screen_of(id) - Vector2(h, h), Vector2(h, h) * 2 + Vector2.ONE).has_point(p):
			return id
	return ""


## The small map in the field's top right corner, or an empty Rect2 when the whole tree fits the field.
func mini_rect() -> Rect2:
	var b := bounds(src())
	var fr := field()
	if b.size.x <= fr.size.x and b.size.y <= fr.size.y:
		return Rect2()
	var size := (b.size * MINI_SCALE).ceil()
	return Rect2(Vector2(fr.end.x - size.x - 5, fr.position.y + 5), size)


## The tree point under screen point `p` on the small map.
func mini_to_tree(p: Vector2) -> Vector2:
	var r := mini_rect()
	var b := bounds(src())
	return b.position + (p.clamp(r.position, r.end) - r.position) / MINI_SCALE


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
	# The view follows the selection once it nears the field's edge (after the keys moved it).
	if follow and not _dragging and not _mini_drag:
		var f := field().grow(-26)
		var s: Vector2 = field().get_center() + src().NODES[sel].at - cam
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
	cam = clamp_cam(src(), cam, field().size)
	var hover := node_at(_mouse)
	if hover != "" and not _dragging and not _mini_drag:
		sel = hover
	queue_redraw()
	_field.queue_redraw()


# --- Drawing -------------------------------------------------------------------

func _draw() -> void:
	var v := _view()
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color(0.02, 0.02, 0.04, 0.72))
	var title := "ATLAS" if atlas else "PROMPT TREE"
	_big(title, v.position + Vector2(14, 8), Hud.ORANGE)
	var free: int = src().points_free()
	var pts := "%d FREE · %d / %d POINTS" % [free, src().allocated().size(), src().points_total()]
	var x := v.position.x + 14 + PixelFont.width(title) * 2 + 12
	_text(pts, Vector2(x, v.position.y + 12), Hud.ORANGE_LIGHT if free > 0 else Hud.TEXT_DIM)
	if atlas:
		_draw_tiers(v)
	else:
		# Clawd's level: a point per level gained.
		Hud.draw_xp(self, Vector2(x + PixelFont.width(pts) + 14, v.position.y + 12), Progress.char_level, Experience.fraction())
		_draw_buy(v)
	var fr := field()
	Hud.panel(self, fr.grow(1), Color("#26262A"), Color(0.03, 0.03, 0.04, 0.55))
	_draw_card()
	var tab := "   TAB %s" % ("PROMPT TREE" if atlas else "ATLAS") if Main.hideout_open() else ""
	var help := "ARROWS MOVE   SPACE ALLOCATE / REFUND%s   R R RESET   DRAG PAN   ESC BACK%s" % ["" if atlas else "   U BUY POINT", tab]
	_text(help, Vector2(v.get_center().x - PixelFont.width(help) / 2.0, v.end.y - 10), Color("#5C5C5C"))


## The Atlas's sixteen tiers in a row under the title, grouped by world: completed ones filled in the world's colour
## (with how many times), the open one outlined and pulsing, locked ones dim.
func _draw_tiers(v: Rect2) -> void:
	var gap := 2.0
	var group := 6.0
	var w := Maps.MAX_TIER * (TIER_CELL.x + gap) - gap + group * 2
	var x := v.get_center().x - w / 2.0
	var y := v.position.y + FIELD_TOP - 2
	var open := Atlas.unlocked_tier()
	var pulse := 0.5 + 0.5 * sin(t * 5)
	for tier in range(1, Maps.MAX_TIER + 1):
		if tier > 1 and Maps.world_of(tier) != Maps.world_of(tier - 1):
			x += group
		var r := Rect2(Vector2(x, y).round(), TIER_CELL)
		var c: Color = WORLD_COLOR[Maps.world_of(tier)]
		var label := "T%d" % tier
		if Atlas.done(tier):
			draw_rect(r, c)
			draw_rect(r.grow(-1), c.darkened(0.25))
			PixelFont.draw_centred(self, label, r.get_center().x, r.position.y + 3, Color(0.05, 0.05, 0.06))
		elif tier == open:
			draw_rect(r, c.lerp(Color.WHITE, pulse * 0.4))
			draw_rect(r.grow(-1), Color(0.05, 0.05, 0.06, 0.95))
			PixelFont.draw_centred(self, label, r.get_center().x, r.position.y + 3, c)
		else:
			draw_rect(r, Color("#2E2E34"))
			draw_rect(r.grow(-1), Color(0.04, 0.04, 0.05, 0.95))
			PixelFont.draw_centred(self, label, r.get_center().x, r.position.y + 3, Color("#4E4E56"))
		x += TIER_CELL.x + gap


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
	for l in src().LABELS:
		var at: Vector2 = (fr.get_center() + l[1] - cam).round()
		if fr.grow(-4).has_point(at):
			PixelFont.draw_centred(_field, l[0], at.x, at.y - 3, Color("#4E4E56"))
	var tree = src()
	for l in tree.LINKS:
		var a: String = l[0]
		var b: String = l[1]
		var both: bool = tree.on(a) and tree.on(b)
		var one: bool = tree.on(a) or tree.on(b)
		var c := Hud.ORANGE if both else Color(Hud.ORANGE_LIGHT, 0.45) if one else LINK_OFF
		_line(screen_of(a), screen_of(b), c, 2 if both else 1)
	for id in tree.NODES:
		_draw_node(id)
	if sel == tree.START and not atlas:
		_draw_totals()
	_draw_mini()
	if note_t > 0:
		var w := PixelFont.width(note) + 12
		var r := Rect2(fr.get_center().x - w / 2.0, fr.position.y + 4, w, 13)
		Hud.panel(_field, r, Color("#3A3A3A"), Color(0.05, 0.05, 0.06, 0.95))
		PixelFont.draw_centred(_field, note, r.get_center().x, r.position.y + 3, Hud.RED if note.begins_with("NO") else Hud.ORANGE_LIGHT)


## The start's list: what every allocated node adds up to, in columns over the field's top left.
func _draw_totals() -> void:
	var lines := totals_lines()
	if lines.is_empty():
		return
	var fr := field()
	var rows := maxi(1, floori((fr.size.y - 16) / PixelFont.LINE))
	var cols := ceili(float(lines.size()) / rows)
	var col_w := 0
	for l in lines:
		col_w = maxi(col_w, PixelFont.width(l) + 10)
	var r := Rect2(fr.position + Vector2(5, 5), Vector2(col_w * cols + 4, mini(rows, lines.size()) * PixelFont.LINE + 7))
	Hud.panel(_field, r, Color("#3A3A3A"), Color(0.04, 0.04, 0.05, 0.94))
	for i in lines.size():
		var at := r.position + Vector2(6 + (i / rows) * col_w, 4 + (i % rows) * PixelFont.LINE)
		var line: String = lines[i]
		PixelFont.draw(_field, line, at, Hud.ORANGE_LIGHT if line.begins_with("+") else Hud.RED if line.begins_with("-") else Hud.TEXT)


## The small map of a big tree: every node a dot (allocated ones orange, the selection white), the view's frame.
func _draw_mini() -> void:
	var r := mini_rect()
	if r.size == Vector2.ZERO:
		return
	var tree = src()
	var b := bounds(tree)
	Hud.panel(_field, r.grow(2), Color("#3A3A3A"), Color(0.03, 0.03, 0.04, 0.94))
	for id in tree.NODES:
		var p: Vector2 = (r.position + (tree.NODES[id].at - b.position) * MINI_SCALE).floor()
		var big: bool = tree.NODES[id].kind != "small"
		var c: Color = Hud.TEXT if id == sel else Hud.ORANGE if tree.on(id) else Color("#7A7A82") if big else NODE_OFF
		_field.draw_rect(Rect2(p, Vector2(2, 2) if big or id == sel else Vector2.ONE), c)
	var fr := field()
	var view := Rect2(r.position + (cam - fr.size / 2 - b.position) * MINI_SCALE, fr.size * MINI_SCALE).intersection(r)
	_field.draw_rect(view, Color(Hud.TEXT, 0.6), false, 1.0)


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
	var tree = src()
	var node: Dictionary = tree.NODES[id]
	var p := screen_of(id)
	var h: int = HALF[node.kind]
	var on: bool = tree.on(id)
	var open: bool = not on and tree.reachable(id)
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
			_field.draw_rect(r.grow(-2), fill if id != tree.START else Color("#2A1A16"))
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
	var tree = src()
	var node: Dictionary = tree.NODES[sel]
	Hud.panel(self, d, Color("#4A4A4A"), Color(0.07, 0.07, 0.08, 0.95), true)
	var kind: String = {"small": "", "notable": "NOTABLE", "keystone": "KEYSTONE", "start": ""}[node.kind]
	_text(String(node.name).to_upper(), d.position + Vector2(8, 6), Hud.TEXT)
	if kind != "":
		PixelFont.draw(self, kind, d.position + Vector2(14 + PixelFont.width(String(node.name).to_upper()), 6), Hud.ORANGE if kind == "KEYSTONE" else Hud.ORANGE_LIGHT)
	var desc: String = node.desc
	if sel == tree.START:
		if atlas:
			desc = atlas_totals() if not Progress.atlas.is_empty() else node.desc
		elif not Progress.tree.is_empty():
			desc = "%d nodes allocated. What they add up to is listed above." % Progress.tree.size()
	var lines := wrap_text(desc, d.size.x - 16)
	for i in mini(2, lines.size()):
		PixelFont.draw(self, lines[i], d.position + Vector2(8, 17 + i * 8), Hud.TEXT_DIM)
	# Which branch it is on, dim on the right (the names over the field show only near its edges).
	var branch := branch_of(tree, sel)
	if branch != "":
		PixelFont.draw(self, branch, Vector2(d.end.x - 8 - PixelFont.width(branch), d.position.y + 6), Hud.TEXT_DIM)
	var hint := ""
	var col := Hud.ORANGE
	if sel == tree.START and atlas:
		hint = "%d / %d TIERS COMPLETED · %d / 3 RARE MAP BONUSES · T%d OPEN" % [Atlas.tiers_done(), Maps.MAX_TIER,
			Progress.atlas_bonus.size(), Atlas.unlocked_tier()]
		col = Hud.TEXT_DIM
	elif sel == tree.START:
		hint = "%d FROM LEVELS · %d FROM WORLD 3'S SPARKS · %d BOUGHT" % [Progress.char_level - 1, Progress.tree_sparks(), Progress.points_bought]
		col = Hud.TEXT_DIM
	elif tree.on(sel):
		hint = "ALLOCATED · SPACE / CLICK: REFUND" if tree.can_refund(sel) else "ALLOCATED · OTHER NODES HANG ON IT"
		col = Hud.ORANGE_LIGHT if tree.can_refund(sel) else Hud.TEXT_DIM
	elif not tree.reachable(sel):
		hint = "NOT NEXT TO YOUR TREE YET"
		col = Hud.TEXT_DIM
	elif tree.points_free() <= 0:
		hint = "NO FREE POINTS · COMPLETE A NEW TIER" if atlas else "NO FREE POINTS · U: BUY ONE"
		col = Hud.RED
	else:
		hint = "SPACE / CLICK: ALLOCATE (1 POINT)"
	if reset_armed > 0:
		hint = "PRESS R AGAIN TO REFUND EVERY POINT"
		col = Hud.RED
	PixelFont.draw(self, hint, d.position + Vector2(8, 35), col)


## The name of the branch (LABELS) whose direction from the start is nearest `id`'s, or "" for the start.
static func branch_of(tree, id: String) -> String:
	if id == tree.START:
		return ""
	var at: Vector2 = tree.NODES[id].at
	var best := ""
	var best_off := INF
	for l in tree.LABELS:
		var off := absf(at.angle_to(l[1]))
		if off < best_off:
			best_off = off
			best = l[0]
	return best


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


## What the allocated nodes add up to, a line each (the start's list): the stats, then the flags.
static func totals_lines() -> Array:
	var out := []
	for s in STAT_NAMES:
		var v := Prompts.stat(s[0])
		if v != 0:
			out.append(("%+d" % roundi(v) if is_equal_approx(v, roundf(v)) else "%+.1f" % v) + s[1])
	for f in FLAG_NAMES:
		if Prompts.on(f[0]):
			out.append(f[1])
	return out


## What the Atlas's allocated nodes add up to, for its start's card.
static func atlas_totals() -> String:
	var parts := []
	for s in ATLAS_STAT_NAMES:
		var v := Atlas.stat(s[0])
		if v != 0:
			parts.append("%s%d%s" % ["+" if v > 0 else "", roundi(v), s[1]])
	return "Nothing allocated yet." if parts.is_empty() else ", ".join(PackedStringArray(parts)) + "."


func _text(s: String, at: Vector2, color: Color) -> void:
	PixelFont.draw(self, s, at + Vector2(0, 1), Color(0, 0, 0, 0.65))
	PixelFont.draw(self, s, at, color)


func _big(s: String, at: Vector2, color: Color) -> void:
	draw_set_transform(at.round(), 0, Vector2(2, 2))
	PixelFont.draw(self, s, Vector2(0, 1), Color(0, 0, 0, 0.65))
	PixelFont.draw(self, s, Vector2.ZERO, color)
	draw_set_transform(Vector2.ZERO)
