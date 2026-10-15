class_name Gear
extends RefCounted

## What Clawd wears and carries (docs/endgame-plan.md E2, E3): the equipped items by slot (Items.SLOTS), the
## inventory and the stash, all in Progress (`gear`, `inventory`, `stash`, saved to their own file by
## Progress.save_items()). stat() adds up the equipped items' stats, cached until invalidate() (tokens read the
## magnet every frame). The inventory and the stash are grids: every item there has its top-left cell in "at"
## ([x, y]) and covers Items.size() cells; find_spot() fills a grid column by column, like Path of Exile.

const INV_SIZE := Vector2i(12, 5)
const STASH_SIZE := Vector2i(12, 12)

static var _cache := {}


## The equipped items' `key` summed.
static func stat(key: String) -> float:
	if not _cache.has(key):
		var n := 0.0
		for slot in Progress.gear:
			n += Items.stat(Progress.gear[slot], key)
		_cache[key] = n
	return _cache[key]


## Call after Progress.gear changes.
static func invalidate() -> void:
	_cache.clear()


## The equipped weapon item, or {} (Clawd then fires the weapon picked with 1-5 / Q / R).
static func weapon() -> Dictionary:
	return Progress.gear.get("weapon", {})


## The slot `item` would go in: its kind's, the first free ring slot for a plugin (else the first).
static func slot_for(item: Dictionary) -> String:
	var kind := Items.kind(item)
	if kind == "ring":
		return "ring2" if Progress.gear.has("ring1") and not Progress.gear.has("ring2") else "ring1"
	return kind


## Puts `item` on in `slot` (or its own slot); returns what was there ({} if nothing). Saved.
static func equip(item: Dictionary, slot := "") -> Dictionary:
	if slot == "":
		slot = slot_for(item)
	assert(Items.SLOT_KIND[slot] == Items.kind(item))
	var old: Dictionary = Progress.gear.get(slot, {})
	Progress.gear[slot] = item
	invalidate()
	Progress.save_items()
	return old


## Takes off what is in `slot`; returns it ({} if nothing). Saved.
static func unequip(slot: String) -> Dictionary:
	var old: Dictionary = Progress.gear.get(slot, {})
	Progress.gear.erase(slot)
	invalidate()
	Progress.save_items()
	return old


static func at_of(item: Dictionary) -> Vector2i:
	var a: Array = item.get("at", [-1, -1])
	return Vector2i(int(a[0]), int(a[1]))


static func rect_of(item: Dictionary) -> Rect2i:
	return Rect2i(at_of(item), Items.size(item))


## The items of `items` that `r` overlaps, but `ignore`.
static func overlapping(items: Array, r: Rect2i, ignore: Dictionary = {}) -> Array:
	return items.filter(func(it): return not is_same(it, ignore) and rect_of(it).intersects(r))


## The item covering `cell`, or {}.
static func item_at(items: Array, cell: Vector2i) -> Dictionary:
	for it in items:
		if rect_of(it).has_point(cell):
			return it
	return {}


static func free_at(items: Array, grid: Vector2i, r: Rect2i, ignore: Dictionary = {}) -> bool:
	return Rect2i(Vector2i.ZERO, grid).encloses(r) and overlapping(items, r, ignore).is_empty()


## The first free top-left for `size` cells, column by column from the top left; (-1, -1) when none is.
static func find_spot(items: Array, grid: Vector2i, size: Vector2i) -> Vector2i:
	for x in grid.x - size.x + 1:
		for y in grid.y - size.y + 1:
			if free_at(items, grid, Rect2i(Vector2i(x, y), size)):
				return Vector2i(x, y)
	return Vector2i(-1, -1)


## Puts `item` into `items` at `at`, or at the first free spot when `at` is (-1, -1) or taken. False if none.
static func place(items: Array, grid: Vector2i, item: Dictionary, at := Vector2i(-1, -1)) -> bool:
	if at.x < 0 or not free_at(items, grid, Rect2i(at, Items.size(item))):
		at = find_spot(items, grid, Items.size(item))
	if at.x < 0:
		return false
	item.at = [at.x, at.y]
	items.append(item)
	return true


## Gives every item of `items` a spot of its own (old saves, a spot taken twice); returns the ones that do not fit.
static func normalize(items: Array, grid: Vector2i) -> Array:
	var kept := []
	var left := []
	for it in items:
		var r := rect_of(it)
		if r.position.x >= 0 and free_at(kept, grid, r):
			kept.append(it)
		else:
			left.append(it)
	var over := []
	for it in left:
		if not place(kept, grid, it):
			over.append(it)
	items.assign(kept)
	return over


static func fits(item: Dictionary) -> bool:
	return find_spot(Progress.inventory, INV_SIZE, Items.size(item)).x >= 0


## Into the inventory's first free spot (saved); false when there is none.
static func take(item: Dictionary) -> bool:
	if not place(Progress.inventory, INV_SIZE, item):
		return false
	Progress.save_items()
	return true
