class_name ItemTooltip
extends RefCounted

## An item's tooltip and icon in view pixels, shared by the items on the ground (LootView) and the inventory window
## (InventoryScreen), Path of Exile's way: name in the rarity's colour, base, kind and item level, a dotted
## divider, the implicit stats, the affixes; stats that only count in the endgame dimmed with a *. compare_rows()
## adds what equipping it would change, better in green and worse in red.

const IMPLICIT := Color("#B8B8C8")
const AFFIX := Color("#8C9BFF")
const DIM := Color("#5C5C66")
const BETTER := Color("#7FD67F")
const WORSE := Color("#E0605A")
const FILL := Color(0.05, 0.05, 0.06, 0.95)


## Rows [text, colour], [] for a divider. `header` goes on top (e.g. "EQUIPPED").
static func rows(it: Dictionary, endgame: bool, header := "") -> Array:
	var out := []
	if header != "":
		out.append([header, Hud.TEXT_DIM])
	out.append([Items.name_of(it), Items.color(it)])
	if it.rarity != "normal":
		out.append([Items.BASES[it.base].name, Hud.TEXT_DIM])
	if Maps.is_map(it):
		out.append(["MAP · TIER %d · AREA LEVEL %d" % [it.get("tier", 1), it.ilvl], Hud.TEXT_DIM])
	else:
		out.append(["%s · ITEM LEVEL %d" % [Items.KIND_NAME[Items.kind(it)], it.ilvl], Hud.TEXT_DIM])
	var lines: Array = Items.lines(it)
	if Maps.is_map(it):
		lines += Maps.extra_lines(it)
	var only := false
	if not lines.is_empty():
		out.append([])
		for l in lines:
			var o: bool = l[1] and not endgame
			only = only or o
			out.append([l[0] + (" *" if o else ""), DIM if o else IMPLICIT if l[2] else AFFIX])
	if only:
		out.append([])
		out.append(["* only in the endgame (hit points)", DIM])
	return out


## What putting `new` on instead of `old` ({} for an empty slot) changes, stat by stat.
static func compare_rows(new: Dictionary, old: Dictionary) -> Array:
	var keys := Items.stat_keys(new)
	if not old.is_empty():
		for k in Items.stat_keys(old):
			if k not in keys:
				keys.append(k)
	var out := []
	for k in keys:
		var d := Items.stat(new, k) - (Items.stat(old, k) if not old.is_empty() else 0.0)
		if d != 0:
			out.append([Items.delta_text(k, d), BETTER if d > 0 else WORSE])
	if out.is_empty():
		out.append(["no change", DIM])
	return [[], ["IF EQUIPPED" if old.is_empty() else "IF EQUIPPED INSTEAD", Hud.TEXT_DIM]] + out


static func size(rows: Array) -> Vector2:
	var w := 0
	var h := 6
	for row in rows:
		if row.is_empty():
			h += 5
		else:
			w = maxi(w, PixelFont.width(row[0]))
			h += PixelFont.LINE
	return Vector2(w + 12, h)


## A position for a box of `sz` next to `anchor` on `side` ("above", "left", "right"), kept inside `view`;
## left and right fall back to the other side, then above.
static func place(sz: Vector2, anchor: Rect2, view: Rect2, side := "above") -> Vector2:
	var p := Vector2.ZERO
	if side == "left" and anchor.position.x - 4 - sz.x < view.position.x + 2:
		side = "right" if anchor.end.x + 4 + sz.x <= view.end.x - 2 else "above"
	elif side == "right" and anchor.end.x + 4 + sz.x > view.end.x - 2:
		side = "left" if anchor.position.x - 4 - sz.x >= view.position.x + 2 else "above"
	match side:
		"left":
			p = Vector2(anchor.position.x - 4 - sz.x, anchor.position.y)
		"right":
			p = Vector2(anchor.end.x + 4, anchor.position.y)
		_:
			p = Vector2(anchor.get_center().x - sz.x / 2.0, anchor.position.y - 3 - sz.y)
	p.x = clampf(p.x, view.position.x + 2, view.end.x - 2 - sz.x)
	p.y = clampf(p.y, view.position.y + 2, view.end.y - 2 - sz.y)
	return p.round()


## Draws `rows` in a panel at `at` onto `c` (inside its _draw()); returns the panel's rect.
static func draw(c: CanvasItem, rows: Array, at: Vector2, border: Color) -> Rect2:
	var box := Rect2(at, size(rows))
	Hud.panel(c, box, border, FILL)
	var ty := box.position.y + 4
	for row in rows:
		if row.is_empty():
			for dx in range(4, int(box.size.x) - 4, 2):
				c.draw_rect(Rect2(box.position.x + dx, ty + 2, 1, 1), Hud.BORDER.lightened(0.2))
			ty += 5
			continue
		PixelFont.draw_centred(c, row[0], box.get_center().x, ty, row[1])
		ty += PixelFont.LINE
	return box


## An item's icon centred on `centre`, `scale` px a cell: a weapon as its gun pointing up, the rest as ItemDrop's
## icon in the rarity's colour. `base` alone (with `dim`) draws an empty slot's ghost.
static func draw_icon(c: CanvasItem, it: Dictionary, centre: Vector2, scale := 2, dim := false, base := "") -> void:
	var b: String = it.base if not it.is_empty() else base
	var kind: String = Items.BASES[b].kind
	var rows: Array
	var pal: Dictionary
	if kind == "weapon":
		var gun: Array = GunSprite.SPRITES[Items.BASES[b].weapon]
		# Turned to point up: column x of the sprite becomes row (width - 1 - x).
		rows = []
		var w: int = gun[0].length()
		for y in w:
			var row := ""
			for x in gun.size():
				row += gun[x][w - 1 - y]
			rows.append(row)
		pal = GunSprite.PALETTE
	else:
		rows = ItemDrop.ICONS[kind]
		var col := Items.color(it) if not it.is_empty() else Color.WHITE
		pal = {"o": col.darkened(0.25), "L": col, "d": col.darkened(0.5), "W": Color.WHITE}
	var w2: int = rows[0].length() * scale
	var h2: int = rows.size() * scale
	var tl := (centre - Vector2(w2, h2) / 2.0).round()
	for y in rows.size():
		for x in rows[y].length():
			var ch: String = rows[y][x]
			if pal.has(ch):
				var col: Color = pal[ch]
				if dim:
					col = Color(0.22, 0.22, 0.25, 0.8)
				c.draw_rect(Rect2(tl + Vector2(x, y) * scale, Vector2.ONE * scale), col)
