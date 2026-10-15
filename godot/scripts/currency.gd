class_name Currency
extends RefCounted

## Currency orbs (docs/endgame-plan.md E6), Path of Exile's crafting in AI words: each changes an item's (or a map's)
## rarity or affixes. They drop from enemies (CHANCE, raised by a map's quantity; bosses drop BOSS_DROPS), are
## picked up on touch, and live in a pouch of their own (Progress.currency, id -> count), not in the inventory's
## grid; the inventory window shows them in a row and uses them (click an orb, then an item). On the ground a drop
## is {"currency": id} in an ItemDrop.

## id -> name, PoE's orb, what it does, its colour, its drop weight.
const ORBS := {
	"seed": {"name": "Prompt Seed", "poe": "Transmutation", "desc": "Makes a normal item magic.", "color": Color("#7FD67F"), "weight": 30.0},
	"fewshot": {"name": "Few-shot Example", "poe": "Augmentation", "desc": "Adds an affix to a magic item.", "color": Color("#8CE0FF"), "weight": 24.0},
	"resample": {"name": "Resample", "poe": "Alteration", "desc": "Rerolls a magic item's affixes.", "color": Color("#6E95FF"), "weight": 20.0},
	"distill": {"name": "Distillation", "poe": "Alchemy", "desc": "Makes a normal item rare.", "color": Color("#F2D27A"), "weight": 10.0},
	"reset": {"name": "Context Reset", "poe": "Scouring", "desc": "Makes a magic or rare item normal.", "color": Color("#A8A8B4"), "weight": 8.0},
	"temperature": {"name": "Temperature Spike", "poe": "Chaos", "desc": "Rerolls a rare item's affixes.", "color": Color("#FF7A4A"), "weight": 5.0},
	"rlhf": {"name": "RLHF", "poe": "Divine", "desc": "Rerolls the values of an item's affixes.", "color": Color("#FF9FD0"), "weight": 1.5},
	"finetune": {"name": "Fine-tune", "poe": "Exalted", "desc": "Adds an affix to a rare item.", "color": Color("#E6D2FF"), "weight": 0.5},
}
const ORDER := ["seed", "fewshot", "resample", "distill", "reset", "temperature", "rlhf", "finetune"]
## A defeated enemy drops an orb with this chance (times a map's quantity); a boss drops BOSS_DROPS.
const CHANCE := 0.05
const BOSS_DROPS := 2
## The colour of currency's labels and popups.
const LABEL := Color("#C8B78A")
## The orb's sprite (o rim, c body, W glint, d shade).
const ROWS := ["..oooo..", ".occcco.", "occWccco", "occcccco", "occcccdo", "occccddo", ".oddddo.", "..oooo.."]


static func is_currency(it: Dictionary) -> bool:
	return it.has("currency")


static func name_of(id: String) -> String:
	return ORBS[id].name


static func count(id: String) -> int:
	return int(Progress.currency.get(id, 0))


static func add(id: String, n := 1) -> void:
	Progress.currency[id] = count(id) + n
	Progress.save_items()


## A random orb by the drop weights.
static func roll(rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for id in ORDER:
		total += ORBS[id].weight
	var r := rng.randf() * total
	for id in ORDER:
		r -= ORBS[id].weight
		if r < 0:
			return id
	return ORDER[0]


## The orb's sprite rows and palette.
static func palette(id: String) -> Dictionary:
	var c: Color = ORBS[id].color
	return {"o": c.darkened(0.55), "c": c, "W": Color.WHITE, "d": c.darkened(0.3)}


## Uses orb `id` on `it` (an item or a map): "" when it worked (the orb is spent), else why not.
static func apply(id: String, it: Dictionary, rng: RandomNumberGenerator) -> String:
	if count(id) <= 0:
		return "NO %s LEFT" % name_of(id).to_upper()
	if it.is_empty() or is_currency(it):
		return "USE IT ON AN ITEM"
	var r: String = it.rarity
	match id:
		"seed":
			if r != "normal":
				return "NEEDS A NORMAL ITEM"
			it.rarity = "magic"
			_reroll(it, 1 + rng.randi() % 2, rng)
		"fewshot":
			if r != "magic":
				return "NEEDS A MAGIC ITEM"
			if not Items.add_affix(it, rng):
				return "NO ROOM FOR ANOTHER AFFIX"
		"resample":
			if r != "magic":
				return "NEEDS A MAGIC ITEM"
			_reroll(it, 1 + rng.randi() % 2, rng)
		"distill":
			if r != "normal":
				return "NEEDS A NORMAL ITEM"
			it.rarity = "rare"
			_reroll(it, Items._weighted(Items.RARE_COUNT, rng), rng)
		"temperature":
			if r != "rare":
				return "NEEDS A RARE ITEM"
			_reroll(it, Items._weighted(Items.RARE_COUNT, rng), rng)
		"finetune":
			if r != "rare":
				return "NEEDS A RARE ITEM"
			if not Items.add_affix(it, rng):
				return "NO ROOM FOR ANOTHER AFFIX"
		"reset":
			if r == "normal":
				return "IT IS NORMAL ALREADY"
			it.rarity = "normal"
			it.affixes = []
			it.erase("name")
		"rlhf":
			if it.affixes.is_empty():
				return "IT HAS NO AFFIXES"
			for a in it.affixes:
				var t: Array = Items.AFFIXES[a.id].tiers[a.tier]
				a.value = rng.randi_range(t[1], t[2])
	Progress.currency[id] = count(id) - 1
	Gear.invalidate()
	Progress.save_items()
	return ""


## New affixes (`n` of them) for a magic or rare item, and a rare's new name.
static func _reroll(it: Dictionary, n: int, rng: RandomNumberGenerator) -> void:
	it.affixes = []
	for i in n:
		Items.add_affix(it, rng)
	if it.rarity == "rare":
		Items.name_rare(it, rng)
	else:
		it.erase("name")
