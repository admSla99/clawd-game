class_name LootView
extends Node2D

## Labels over the items lying in the level and the tooltip of the one Clawd stands by (docs/endgame-plan.md E2),
## Path of Exile's way: every ItemDrop gets a small dark label with its name in its rarity's colour (labels that
## would overlap stack upwards); the target (Main.loot_target) gets ItemTooltip's panel, what equipping it would
## change, and the key that picks it up; the hideout's stations get their names and the key that uses them. Drawn
## in view pixels under Ui, like the Overlay; made by Main.

const LABEL_BG := Color(0.03, 0.03, 0.04, 0.82)

var main: Node


func _process(_dt: float) -> void:
	queue_redraw()


func _draw() -> void:
	if main == null or main.mode != Main.Mode.PLAY or main.complete_t >= 1.6 or Game.paused:
		return
	var placed: Array[Rect2] = []
	var target: ItemDrop = main.loot_target
	var target_label := Rect2()
	for d: ItemDrop in get_tree().get_nodes_in_group("loot"):
		if not d.landed or d.is_queued_for_deletion():
			continue
		var orb := Currency.is_currency(d.item)
		var name := Currency.name_of(d.item.currency) if orb else Items.name_of(d.item)
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
		var col := Currency.LABEL if orb else Items.color(d.item)
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
	_draw_stations()


## The hideout's stations: each one's name over it, dim; the one Clawd stands at as "E · NAME" in orange.
func _draw_stations() -> void:
	var key := Settings.keys_text([&"pickup"]).split(" ")[0]
	for st: Station in get_tree().get_nodes_in_group("stations"):
		var at: Vector2 = main.overlay.to_view(st.feet() + Vector2(0, -st.height() - 5), Station.Z)
		if st == main.station_target:
			var text := "%s · %s" % [key, st.title()]
			var w := PixelFont.width(text) + 10
			var r := Rect2(roundf(at.x - w / 2.0), roundf(at.y - 11), w, 11)
			Hud.panel(self, r, Hud.ORANGE, Color(0.05, 0.05, 0.06, 0.9))
			PixelFont.draw_centred(self, text, r.get_center().x, r.position.y + 2, Hud.ORANGE_LIGHT)
		else:
			PixelFont.draw_centred(self, st.title(), at.x, at.y - 9, Color(Hud.TEXT_DIM, 0.8))


## The tooltip of `d`, above its label `label`, kept on screen: ItemTooltip's rows, what equipping it would change,
## and the key that picks it up (or INVENTORY FULL).
func _tooltip(d: ItemDrop, label: Rect2) -> void:
	var it := d.item
	var rows := ItemTooltip.rows(it, main.endgame)
	if Items.equippable(it):
		rows += ItemTooltip.compare_rows(it, Progress.gear.get(Gear.slot_for(it), {}))
	rows.append([])
	var key := Settings.keys_text([&"pickup"]).split(" ")[0]
	rows.append(["%s · PICK UP" % key, Hud.ORANGE_LIGHT] if Gear.fits(it) else ["INVENTORY FULL", Hud.RED])
	var v := Rect2(Vector2.ONE * Main.PAD, get_viewport_rect().size - Vector2.ONE * Main.PAD * 2)
	v.position.y += 24
	v.size.y -= 24
	var at := ItemTooltip.place(ItemTooltip.size(rows), label, v, "above")
	ItemTooltip.draw(self, rows, at, Items.color(it).darkened(0.35))
