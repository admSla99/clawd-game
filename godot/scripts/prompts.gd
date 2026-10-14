class_name Prompts
extends RefCounted

## World 3's System Prompts (docs/world3-plan.md, W9), Hollow Knight's charms for Clawd: bought once in the shop's
## SYSTEM PROMPT section (once world 3 is open), then switched on and off there within the context budget (4, +2 per
## level of Longer System Prompt). What the ones that are on do is read where it matters: Weapons (damage, fire
## rate), Gun (spread, critical hits), Enemy.die() (tokens), Main._apply_loadout() (hearts, hover, run speed, the
## hook's reach and zip speed, sub-agent slots) and ToolCall (reflecting shots). Owned and switched-on ids live in
## Progress.prompts / Progress.prompts_on.

## id -> name, short label (pause menu), cost in the budget, price {tokens, sparks}, what it does.
const DEFS := {
	"concise": {"name": "Be concise.", "short": "CONCISE", "cost": 1, "price": 120, "sparks": 1,
		"desc": "+20% fire rate, but every shot deals 15% less damage."},
	"cite": {"name": "Cite your sources.", "short": "CITE", "cost": 1, "price": 150, "sparks": 1,
		"desc": "Enemies drop 30% more tokens."},
	"temperature": {"name": "Temperature 1.5", "short": "TEMP 1.5", "cost": 1, "price": 120, "sparks": 1,
		"desc": "Wilder aim, but one hit in seven deals double damage."},
	"steps": {"name": "Think step by step.", "short": "STEPS", "cost": 2, "price": 160, "sparks": 1,
		"desc": "+60% hover time, but Clawd runs 10% slower."},
	"ontask": {"name": "Stay on task.", "short": "ON TASK", "cost": 2, "price": 200, "sparks": 2,
		"desc": "The Tool Call reaches 50% farther and zips 25% faster."},
	"delegate": {"name": "Delegate.", "short": "DELEGATE", "cost": 2, "price": 220, "sparks": 2,
		"desc": "One more sub-agent out at once."},
	"expert": {"name": "You are an expert.", "short": "EXPERT", "cost": 3, "price": 260, "sparks": 2,
		"desc": "+35% damage, but one heart less."},
	"reflect": {"name": "Reflect.", "short": "REFLECT", "cost": 3, "price": 240, "sparks": 1,
		"desc": "The hook catches enemy shots and throws them back."},
}
const ORDER := ["concise", "cite", "temperature", "steps", "ontask", "delegate", "expert", "reflect"]
## The budget: BUDGET, plus 2 per level of Longer System Prompt (upgrade "sysprompt").
const BUDGET := 4
## Temperature 1.5: extra random spread (radians) and the chance of a double hit.
const TEMP_SPREAD := 0.06
const TEMP_CRIT := 1.0 / 7.0


static func on(id: String) -> bool:
	return Progress.prompts_on.has(id)


static func budget() -> int:
	return BUDGET + 2 * Progress.upgrade("sysprompt")


static func used() -> int:
	var n := 0
	for id in Progress.prompts_on:
		n += int(DEFS.get(id, {}).get("cost", 0))
	return n


## Whether `id` (owned, off) fits in what is left of the budget.
static func fits(id: String) -> bool:
	return used() + int(DEFS[id].cost) <= budget()


## Switches an owned prompt on or off: "on", "off", "full" (it doesn't fit) or "none" (not owned).
static func toggle(id: String) -> String:
	if not Progress.prompts.has(id):
		return "none"
	if on(id):
		Progress.prompts_on.erase(id)
		Progress.save()
		return "off"
	if not fits(id):
		return "full"
	Progress.prompts_on.append(id)
	Progress.save()
	return "on"


## Multipliers the weapons read.
static func damage_mult() -> float:
	return (0.85 if on("concise") else 1.0) * (1.35 if on("expert") else 1.0)


static func rate_mult() -> float:
	return 1.2 if on("concise") else 1.0


static func token_mult() -> float:
	return 1.3 if on("cite") else 1.0
