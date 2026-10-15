class_name Gear
extends RefCounted

## What Clawd wears and carries (docs/endgame-plan.md E2): the equipped items by slot (Items.SLOTS) and the
## inventory, both in Progress (`gear`, `inventory`, saved to their own file by Progress.save_items()). stat() adds
## up the equipped items' stats, cached until invalidate() (tokens read the magnet every frame).
## The inventory holds INVENTORY_CELLS cells of items for now; the grid comes with the inventory window (E3).

const INVENTORY_CELLS := 60

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


static func cells_used() -> int:
	var n := 0
	for it in Progress.inventory:
		var s := Items.size(it)
		n += s.x * s.y
	return n


static func fits(item: Dictionary) -> bool:
	var s := Items.size(item)
	return cells_used() + s.x * s.y <= INVENTORY_CELLS


## Into the inventory if it fits (saved); false when it is full.
static func take(item: Dictionary) -> bool:
	if not fits(item):
		return false
	Progress.inventory.append(item)
	Progress.save_items()
	return true
