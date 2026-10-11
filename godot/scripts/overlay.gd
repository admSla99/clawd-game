class_name Overlay
extends Node2D

## Text over the 3D view, drawn in the SubViewport at view resolution with PixelFont, so it is pixel art
## like the rest: floating popups ("STATE SAVED"), the text of nodes in the group "world_text" (sign
## bubbles, the exit label; they implement `overlay_draw(overlay)`) and the level-complete panel.
## Lives in a CanvasLayer above the colour grade. World positions are level pixels; to_view() maps them
## through the camera, including the oblique shift of points off the gameplay plane.

const TEXT := Color("#E6E6E6")
const TEXT_DIM := Color("#9A9A9A")
const ORANGE := Color("#D97757")
const ORANGE_LIGHT := Color("#F0A585")

var camera: Camera3D
## {text, at (level px), z (m), t, life, color, rise (px/s)}
var popups: Array[Dictionary] = []
## Level-complete panel, or empty: {title, subtitle, rows: [[label, value]], t}.
var results := {}


## Shows `text` centred above `at` (level pixels, `z` metres off the gameplay plane), rising and fading
## over `life` seconds.
func popup(text: String, at: Vector2, color: Color, life := 1.2, z := 0.0, rise := 16.0) -> void:
	popups.append({"text": text, "at": at, "z": z, "t": 0.0, "life": life, "color": color, "rise": rise})


func clear() -> void:
	popups.clear()
	results = {}


## Level pixels (and depth in metres) to SubViewport pixels, rounded.
func to_view(at: Vector2, z := 0.0) -> Vector2:
	var w := Px.to3(at) + Vector3(0, 0, z)
	# The oblique projection (shaders/oblique.gdshaderinc): perspective for points behind the plane, then
	# the shift up by a third of the depth.
	if w.z < 0:
		var c := camera.global_position
		w.x -= -w.z * 0.03 * (w.x - c.x)
		w.y -= -w.z * 0.03 * (w.y - c.y)
	w.y -= w.z / 3.0
	return camera.unproject_position(Vector3(w.x, w.y, 0)).round()


func _physics_process(dt: float) -> void:
	if not Game.paused:
		for p in popups:
			p.t += dt
		popups = popups.filter(func(p: Dictionary) -> bool: return p.t < p.life)
	if not results.is_empty():
		results.t += dt
	queue_redraw()


func _draw() -> void:
	if not camera:
		return
	# The level's own text (signs, HELP, EXIT) only while playing, not behind the title and the map.
	var main := get_tree().get_first_node_in_group("main")
	if main == null or main.mode == Main.Mode.PLAY:
		for n in get_tree().get_nodes_in_group("world_text"):
			n.overlay_draw(self)
	for p in popups:
		var v := to_view(p.at, p.z)
		var c: Color = p.color
		c.a = 1.0 - p.t / p.life
		PixelFont.draw_centred(self, p.text, v.x, v.y - p.t * p.rise, c)
	if not results.is_empty():
		_draw_results()


## A panel like panel() in src/render/shapes.ts: a fill with a 1 px border that leaves the corners open.
func panel(r: Rect2, border: Color, fill: Color) -> void:
	r = Rect2(r.position.round(), r.size.round())
	draw_rect(r, fill)
	draw_rect(Rect2(r.position.x + 1, r.position.y, r.size.x - 2, 1), border)
	draw_rect(Rect2(r.position.x + 1, r.end.y - 1, r.size.x - 2, 1), border)
	draw_rect(Rect2(r.position.x, r.position.y + 1, 1, r.size.y - 2), border)
	draw_rect(Rect2(r.end.x - 1, r.position.y + 1, 1, r.size.y - 2), border)


## Text `lines` in a panel centred above `anchor` (view pixels, the panel's bottom `gap` px above it),
## faded by `show` (0..1) and slid down a little while it fades in, like the 2D sign bubble.
func bubble(lines: PackedStringArray, anchor: Vector2, show: float, gap := 8.0) -> void:
	var w := 0
	for l in lines:
		w = maxi(w, PixelFont.width(l))
	w += 12
	var h := lines.size() * PixelFont.LINE + 6
	var top := roundf(anchor.y - h - gap - (1.0 - show) * 6)
	var left := roundf(anchor.x - w / 2.0)
	panel(Rect2(left, top, w, h), Color(0.42, 0.42, 0.42, show), Color(0.07, 0.07, 0.07, 0.94 * show))
	# A small tail pointing at the anchor.
	for i in 3:
		draw_rect(Rect2(roundf(anchor.x) - 2 + i, top + h + i, 5 - i * 2, 1), Color(0.42, 0.42, 0.42, show) if i == 2 else Color(0.07, 0.07, 0.07, 0.94 * show))
	for i in lines.size():
		var c := TEXT
		c.a = show
		PixelFont.draw_centred(self, lines[i], anchor.x, top + 4 + i * PixelFont.LINE, c)


func _draw_results() -> void:
	var t: float = results.t
	var view := get_viewport_rect().size
	var cx := view.x / 2
	# Dim the view, then the panel slides in.
	var k := clampf(t / 0.4, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, view), Color(0.04, 0.04, 0.06, 0.55 * k))
	var y := roundf(view.y * 0.3 - (1.0 - k) * 12)
	var big := Color(ORANGE, k)
	draw_set_transform(Vector2(roundf(cx - PixelFont.width(results.title)), y), 0, Vector2(2, 2))
	PixelFont.draw(self, results.title, Vector2.ZERO, big)
	draw_set_transform(Vector2.ZERO)
	PixelFont.draw_centred(self, results.subtitle, cx, y + 18, Color(TEXT_DIM, k))
	var rows: Array = results.rows
	var agents: Array = results.get("agents", [])
	var w := 150.0
	var agents_h := 18 if not agents.is_empty() else 0
	var h := rows.size() * 12 + 12 + agents_h
	var top := y + 32
	panel(Rect2(cx - w / 2, top, w, h), Color(0.29, 0.29, 0.29, k), Color(0.08, 0.08, 0.08, 0.95 * k))
	# Sub-agents: a small Clawd each, cheering when rescued, dark when not (ResultsScene).
	if not agents.is_empty():
		PixelFont.draw(self, "SUB-AGENTS", Vector2(cx - w / 2 + 12, top + 10), Color(TEXT_DIM, k))
		for i in agents.size():
			var tex := ClawdSprite.texture(ClawdSprite.frame("high" if agents[i] else "mid"), Color(0, 0, 0, 0) if agents[i] else Color("#3A3A3A"))
			# They pop in one after another, the rescued ones with a hop.
			if t > 0.5 + i * 0.25:
				var hop := roundf(absf(sin((t - i * 0.3) * 6)) * 2) if agents[i] else 0.0
				draw_texture(tex, Vector2(cx - w / 2 + 70 + i * 20, top + 6 - hop), Color(1, 1, 1, k))
	for i in rows.size():
		var ry := top + 8 + agents_h + i * 12
		PixelFont.draw(self, rows[i][0], Vector2(cx - w / 2 + 12, ry), Color(TEXT_DIM, k))
		PixelFont.draw(self, rows[i][1], Vector2(cx - w / 2 + 70, ry), Color(TEXT, k))
	var note: String = results.get("note", "")
	if note != "":
		PixelFont.draw_centred(self, note, cx, top + h + 8, Color(ORANGE_LIGHT, k))
	if t > 1.0 and floori(t * 1.6) % 2 == 0:
		PixelFont.draw_centred(self, "PRESS SPACE", cx, top + h + (22 if note != "" else 14), Color(TEXT, k))
