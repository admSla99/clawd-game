class_name LootView
extends Node2D

## Labels over the items lying in the level and the tooltip of the one Clawd stands by (docs/endgame-plan.md E2),
## Path of Exile's way: every ItemDrop gets a small dark label with its name in its rarity's colour (labels that
## would overlap stack upwards); the target (Main.loot_target) gets a panel with its name, base, item level and
## kind, its implicit stats, its affixes, and the key that picks it up. Stats that only count in the endgame are
## dimmed and marked. Drawn in view pixels under Ui, like the Overlay; made by Main.

const LABEL_BG := Color(0.03, 0.03, 0.04, 0.82)
const IMPLICIT := Color("#B8B8C8")
const AFFIX := Color("#8C9BFF")
const DIM := Color("#5C5C66")

var main: Node


func _process(_dt: float) -> void:
	queue_redraw()


func _draw() -> void:
	if main == null or main.mode != Main.Mode.PLAY or main.complete_t >= 1.6:
		return
	var placed: Array[Rect2] = []
	var target: ItemDrop = main.loot_target
	var target_label := Rect2()
	for d: ItemDrop in get_tree().get_nodes_in_group("loot"):
		if not d.landed or d.is_queued_for_deletion():
			continue
		var name := Items.name_of(d.item)
		var w := PixelFont.width(name) + 6
		var at: Vector2 = main.overlay.to_view(d.fpos + Vector2(0, -12))
		var r := Rect2(roundf(at.x - w / 2.0), roundf(at.y - 9), w, 9)
		# Up above every label it would overlap, until it overlaps none.
		var moved := true
		while moved:
			moved = false
			for p in placed:
				if p.intersects(r):
					r.position.y = p.position.y - 10
					moved = true
		placed.append(r)
		var col := Items.color(d.item)
		draw_rect(r, LABEL_BG)
		var edge := col if d == target else col.darkened(0.55)
		draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), edge)
		draw_rect(Rect2(r.position + Vector2(0, r.size.y - 1), Vector2(r.size.x, 1)), edge)
		PixelFont.draw(self, name, r.position + Vector2(3, 1), col)
		if d == target:
			target_label = r
	# The tooltip over every label.
	if target and is_instance_valid(target) and target_label.has_area():
		_tooltip(target, target_label)


## The tooltip of `d`, above its label `label`, kept on screen.
func _tooltip(d: ItemDrop, label: Rect2) -> void:
	var it := d.item
	var rows := []  # [text, colour] or [] for a divider
	rows.append([Items.name_of(it), Items.color(it)])
	if it.rarity != "normal":
		rows.append([Items.BASES[it.base].name, Hud.TEXT_DIM])
	rows.append(["%s · ITEM LEVEL %d" % [Items.KIND_NAME[Items.kind(it)], it.ilvl], Hud.TEXT_DIM])
	var stat_lines: Array = Items.lines(it)
	var endgame := false
	if not stat_lines.is_empty():
		rows.append([])
		for l in stat_lines:
			var only_endgame: bool = l[1] and not main.endgame
			endgame = endgame or only_endgame
			rows.append([l[0] + (" *" if only_endgame else ""), DIM if only_endgame else IMPLICIT if l[2] else AFFIX])
	rows.append([])
	if endgame:
		rows.append(["* only in the endgame (hit points)", DIM])
	var key := Settings.keys_text([&"pickup"]).split(" ")[0]
	if Gear.fits(it):
		rows.append(["%s · PICK UP" % key, Hud.ORANGE_LIGHT])
	else:
		rows.append(["INVENTORY FULL", Hud.RED])
	var w := 0
	var h := 6
	for row in rows:
		if row.is_empty():
			h += 5
		else:
			w = maxi(w, PixelFont.width(row[0]))
			h += PixelFont.LINE
	w += 12
	var v: Rect2 = Rect2(Vector2.ONE * Main.PAD, get_viewport_rect().size - Vector2.ONE * Main.PAD * 2)
	var x := clampf(label.get_center().x - w / 2.0, v.position.x + 4, v.end.x - 4 - w)
	var y := maxf(label.position.y - 3 - h, v.position.y + 26)
	var box := Rect2(roundf(x), roundf(y), w, h)
	Hud.panel(self, box, Items.color(it).darkened(0.35), Color(0.05, 0.05, 0.06, 0.94))
	var ty := box.position.y + 4
	for row in rows:
		if row.is_empty():
			for dx in range(4, w - 4, 2):
				draw_rect(Rect2(box.position.x + dx, ty + 2, 1, 1), Hud.BORDER.lightened(0.2))
			ty += 5
			continue
		PixelFont.draw_centred(self, row[0], box.get_center().x, ty, row[1])
		ty += PixelFont.LINE
