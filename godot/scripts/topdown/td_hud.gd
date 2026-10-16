class_name TdHud
extends Node2D

## The top-down prototype's HUD, in the view's pixels like the main game's: life bar and XP top left, the wave and
## kills, the weapon, the controls; damage numbers and popups follow their 3D point (TdMain.to_view()); a panel when
## Clawd falls.

var main: Node
## [text, world position (Vector3), colour, age, life]
var popups := []


func popup(text: String, at: Vector3, color: Color, life := 1.0) -> void:
	popups.append([text, at, color, 0.0, life])


func _process(dt: float) -> void:
	for p in popups:
		p[3] += dt
	popups = popups.filter(func(p): return p[3] < p[4])
	queue_redraw()


func _draw() -> void:
	if main == null or main.player == null:
		return
	var v := get_viewport_rect().size
	var pl: TdPlayer = main.player
	# Life.
	var r := Rect2(8, 8, 96, 14)
	Hud.panel(self, r, Hud.BORDER, Hud.FILL, true)
	var bar := Rect2(r.position + Vector2(4, 4), Vector2(88, 6))
	draw_rect(bar, Color(0.03, 0.03, 0.04))
	draw_rect(Rect2(bar.position, Vector2(roundf(bar.size.x * clampf(pl.life / pl.max_life, 0, 1)), bar.size.y)), Hud.RED)
	var lt := "%d / %d" % [maxi(0, ceili(pl.life)), roundi(pl.max_life)]
	PixelFont.draw_centred(self, lt, r.get_center().x, r.position.y + 4, Hud.TEXT)
	Hud.draw_xp(self, Vector2(9, 26), Progress.char_level, Experience.fraction())
	var info := "WAVE %d · KILLS %d · AREA LEVEL %d" % [main.wave, main.kills, main.area]
	PixelFont.draw(self, info, Vector2(v.x - 8 - PixelFont.width(info), 10), Hud.TEXT_DIM)
	PixelFont.draw(self, String(pl.weapon.name).to_upper(), Vector2(10, v.y - 18), Hud.TEXT)
	var help := "WASD MOVE · MOUSE AIM · LMB SHOOT · SPACE DODGE · ESC BACK"
	PixelFont.draw_centred(self, help, v.x / 2, v.y - 10, Color("#5C5C5C"))
	for p in popups:
		var at: Vector2 = main.to_view(p[1]) + Vector2(0, -p[3] * 18)
		var c: Color = p[2]
		c.a = clampf(2.0 * (1.0 - p[3] / p[4]), 0, 1)
		PixelFont.draw_centred(self, p[0], at.x, at.y + 1, Color(0, 0, 0, c.a * 0.7))
		PixelFont.draw_centred(self, p[0], at.x, at.y, c)
	# Enemy bars, once hurt.
	for e: TdEnemy in main.enemies:
		if e.hp < e.max_hp:
			var at: Vector2 = main.to_view(Vector3(e.pos.x, e.height + 1.0, e.pos.y))
			draw_rect(Rect2(at.x - 8, at.y, 16, 2), Color("#333333"))
			draw_rect(Rect2(at.x - 8, at.y, roundf(16 * e.hp / e.max_hp), 2), Hud.RED)
	if main.dead_t >= 0:
		var pr := Rect2(v.x / 2 - 90, v.y / 2 - 22, 180, 44)
		Hud.panel(self, pr, Hud.RED, Color(0.05, 0.03, 0.03, 0.92), true)
		PixelFont.draw_centred(self, "CLAWD WENT OFFLINE", pr.get_center().x, pr.position.y + 9, Hud.RED)
		PixelFont.draw_centred(self, "SPACE AGAIN · ESC BACK", pr.get_center().x, pr.position.y + 25, Hud.TEXT_DIM)
