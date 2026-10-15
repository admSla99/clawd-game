class_name Prompts
extends RefCounted

## World 3's System Prompts as a passive tree, like Path of Exile's (docs/prompt-tree-plan.md): nodes joined by
## links around the start, SYSTEM PROMPT; a point allocates a node next to one Clawd has. Small nodes add a few
## per cent to one stat; notables (the eight prompts of world 3's first version, same ids) and keystones (big
## trade-offs) do more. Points: every spark found in world 3 gives one (Progress.tree_sparks()), and more are bought
## with tokens at a rising price (BUY_MAX at most). Refunds are free: a node can go when the rest stays joined to
## the start, and reset() gives them all back. What the allocated nodes add up to is read where it matters:
## Weapons (damage, fire rate), Gun (spread, critical hits), Enemy.die() (tokens), Token (magnet), ToolCall
## (reflecting shots), Main._apply_loadout() (hearts, hover, run speed, the hook's reach and zip speed, sub-agent
## slots and how long they stand). The window is TreeScreen; Progress.tree holds the allocated ids.

const START := "root"
## id -> kind ("start", "small", "notable", "keystone"), name, short label (pause menu) for the big ones, what it
## does, where it sits in the tree (px from the start, y down) and its stats (`mods`, summed by stat(); a flag is
## read with on()).
const NODES := {
	"root": {"kind": "start", "name": "SYSTEM PROMPT", "at": Vector2(0, 0), "mods": {},
		"desc": "Where every prompt begins. A point allocates a node next to one you have."},
	# Offense, east.
	"dmg1": {"kind": "small", "name": "Sharper Tokens", "at": Vector2(30, 0), "mods": {"damage": 8}, "desc": "+8% damage."},
	"dmg2": {"kind": "small", "name": "Sharper Tokens", "at": Vector2(58, 0), "mods": {"damage": 8}, "desc": "+8% damage."},
	"concise": {"kind": "notable", "name": "Be concise.", "short": "CONCISE", "at": Vector2(86, -20), "mods": {"rate": 20, "damage": -15},
		"desc": "+20% fire rate, but every shot deals 15% less damage."},
	"dmg3": {"kind": "small", "name": "Sharper Tokens", "at": Vector2(114, -20), "mods": {"damage": 8}, "desc": "+8% damage."},
	"expert": {"kind": "keystone", "name": "You are an expert.", "short": "EXPERT", "at": Vector2(144, -20), "mods": {"damage": 35, "hearts": -1},
		"desc": "+35% damage, but one heart less."},
	"rate1": {"kind": "small", "name": "Fast Inference", "at": Vector2(86, 20), "mods": {"rate": 8}, "desc": "+8% fire rate."},
	"rate2": {"kind": "small", "name": "Fast Inference", "at": Vector2(114, 20), "mods": {"rate": 8}, "desc": "+8% fire rate."},
	"temperature": {"kind": "notable", "name": "Temperature 1.5", "short": "TEMP 1.5", "at": Vector2(142, 20), "mods": {"temperature": 1},
		"desc": "Wilder aim, but one hit in seven deals double damage."},
	# The Tool Call, north.
	"reach1": {"kind": "small", "name": "Long Context", "at": Vector2(0, -22), "mods": {"reach": 12}, "desc": "The hook reaches 12% farther."},
	"zip1": {"kind": "small", "name": "Low Latency", "at": Vector2(0, -42), "mods": {"zip": 10}, "desc": "Zips 10% faster."},
	"ontask": {"kind": "notable", "name": "Stay on task.", "short": "ON TASK", "at": Vector2(-20, -62), "mods": {"reach": 50, "zip": 25},
		"desc": "The Tool Call reaches 50% farther and zips 25% faster."},
	"reach2": {"kind": "small", "name": "Long Context", "at": Vector2(20, -62), "mods": {"reach": 12}, "desc": "The hook reaches 12% farther."},
	"reflect": {"kind": "notable", "name": "Reflect.", "short": "REFLECT", "at": Vector2(20, -80), "mods": {"reflect": 1},
		"desc": "The hook catches enemy shots and throws them back."},
	# Sub-agents, west.
	"stand1": {"kind": "small", "name": "Patience", "at": Vector2(-30, 0), "mods": {"stand": 2}, "desc": "Sub-agents stand 2 s longer."},
	"stand2": {"kind": "small", "name": "Patience", "at": Vector2(-58, 0), "mods": {"stand": 2}, "desc": "Sub-agents stand 2 s longer."},
	"delegate": {"kind": "notable", "name": "Delegate.", "short": "DELEGATE", "at": Vector2(-86, -20), "mods": {"slots": 1},
		"desc": "One more sub-agent out at once."},
	"stand3": {"kind": "small", "name": "Patience", "at": Vector2(-114, -20), "mods": {"stand": 2}, "desc": "Sub-agents stand 2 s longer."},
	"orchestrator": {"kind": "keystone", "name": "Orchestrator.", "short": "ORCHESTRATOR", "at": Vector2(-144, -20), "mods": {"slots": 1, "damage": -20},
		"desc": "One more sub-agent out at once, but Clawd's own shots deal 20% less damage."},
	"tooluse": {"kind": "notable", "name": "Tool use.", "short": "TOOL USE", "at": Vector2(-86, 20), "mods": {"minions": 1},
		"desc": "Standing sub-agents shoot the nearest enemy in sight."},
	"mdmg1": {"kind": "small", "name": "Shared Weights", "at": Vector2(-114, 20), "mods": {"minion_damage": 30}, "desc": "Sub-agents' shots deal 30% more damage."},
	"mrate1": {"kind": "small", "name": "Async Calls", "at": Vector2(-142, 20), "mods": {"minion_rate": 30}, "desc": "Sub-agents shoot 30% faster."},
	"parallel": {"kind": "notable", "name": "Parallel tool calls.", "short": "PARALLEL", "at": Vector2(-170, 20), "mods": {"parallel": 1},
		"desc": "Sub-agents fire two shots at once."},
	# Survival, south.
	"hover1": {"kind": "small", "name": "Jet Fuel", "at": Vector2(0, 22), "mods": {"hover": 15}, "desc": "+15% hover time."},
	"hover2": {"kind": "small", "name": "Jet Fuel", "at": Vector2(0, 42), "mods": {"hover": 15}, "desc": "+15% hover time."},
	"steps": {"kind": "notable", "name": "Think step by step.", "short": "STEPS", "at": Vector2(-20, 62), "mods": {"hover": 60, "run": -10},
		"desc": "+60% hover time, but Clawd runs 10% slower."},
	"run1": {"kind": "small", "name": "Quick Feet", "at": Vector2(20, 62), "mods": {"run": 5}, "desc": "Clawd runs 5% faster."},
	"guardrails": {"kind": "notable", "name": "Guardrails.", "short": "GUARDRAILS", "at": Vector2(20, 80), "mods": {"hearts": 1},
		"desc": "One more heart."},
	# Tokens, south-east.
	"tok1": {"kind": "small", "name": "Billing", "at": Vector2(36, 30), "mods": {"tokens": 6}, "desc": "Enemies drop 6% more tokens."},
	"tok2": {"kind": "small", "name": "Billing", "at": Vector2(60, 50), "mods": {"tokens": 6}, "desc": "Enemies drop 6% more tokens."},
	"cite": {"kind": "notable", "name": "Cite your sources.", "short": "CITE", "at": Vector2(84, 70), "mods": {"tokens": 30},
		"desc": "Enemies drop 30% more tokens."},
	"magnet1": {"kind": "small", "name": "Embeddings", "at": Vector2(112, 70), "mods": {"magnet": 36},
		"desc": "Tokens within 36 px more fly to Clawd (without the Token Magnet too)."},
	"retrieval": {"kind": "notable", "name": "Retrieval.", "short": "RETRIEVAL", "at": Vector2(140, 70), "mods": {"magnet": 72},
		"desc": "Tokens fly to Clawd from 72 px farther."},
}
const LINKS := [
	["root", "dmg1"], ["dmg1", "dmg2"], ["dmg2", "concise"], ["concise", "dmg3"], ["dmg3", "expert"], ["dmg2", "rate1"],
	["rate1", "rate2"], ["rate2", "temperature"],
	["root", "reach1"], ["reach1", "zip1"], ["zip1", "ontask"], ["zip1", "reach2"], ["reach2", "reflect"],
	["root", "stand1"], ["stand1", "stand2"], ["stand2", "delegate"], ["delegate", "stand3"], ["stand3", "orchestrator"],
	["stand2", "tooluse"], ["tooluse", "mdmg1"], ["mdmg1", "mrate1"], ["mrate1", "parallel"],
	["root", "hover1"], ["hover1", "hover2"], ["hover2", "steps"], ["hover2", "run1"], ["run1", "guardrails"],
	["root", "tok1"], ["tok1", "tok2"], ["tok2", "cite"], ["cite", "magnet1"], ["magnet1", "retrieval"],
]
## Bought points: the first costs BUY_PRICE tokens, every next one BUY_STEP more, at most BUY_MAX of them.
const BUY_PRICE := 60
const BUY_STEP := 30
const BUY_MAX := 10
## Temperature 1.5: extra random spread (radians) and the chance of a double hit.
const TEMP_SPREAD := 0.06
const TEMP_CRIT := 1.0 / 7.0


## An allocated node (the start always is), or a flag one of them sets.
static func on(id: String) -> bool:
	if NODES.has(id):
		return id == START or Progress.tree.has(id)
	return stat(id) > 0


## A stat summed over the allocated nodes.
static func stat(key: String) -> float:
	var n := 0.0
	for id in Progress.tree:
		n += float(NODES.get(id, {}).get("mods", {}).get(key, 0))
	return n


static func neighbours(id: String) -> Array:
	var out := []
	for l in LINKS:
		if l[0] == id:
			out.append(l[1])
		elif l[1] == id:
			out.append(l[0])
	return out


## Points: one per character level gained (scripts/experience.gd), world 3's sparks and the bought ones.
static func points_total() -> int:
	return Progress.char_level - 1 + Progress.tree_sparks() + Progress.points_bought


static func points_free() -> int:
	return points_total() - Progress.tree.size()


## The next point's price in tokens, or -1 when BUY_MAX are bought.
static func point_price() -> int:
	return -1 if Progress.points_bought >= BUY_MAX else BUY_PRICE + BUY_STEP * Progress.points_bought


## Buys a point: "bought", "poor" or "max".
static func buy_point() -> String:
	var p := point_price()
	if p < 0:
		return "max"
	if Progress.wallet < p:
		return "poor"
	Progress.wallet -= p
	Progress.points_bought += 1
	Progress.save()
	return "bought"


## Whether `id` is next to an allocated node (or the start).
static func reachable(id: String) -> bool:
	return neighbours(id).any(func(n: String) -> bool: return on(n))


static func can_allocate(id: String) -> bool:
	return NODES.has(id) and not on(id) and points_free() > 0 and reachable(id)


## Whether `id` can be refunded: the others stay joined to the start without it.
static func can_refund(id: String) -> bool:
	if id == START or not Progress.tree.has(id):
		return false
	var rest: Array = Progress.tree.filter(func(n: String) -> bool: return n != id)
	return joined(rest).size() == rest.size()


## The nodes of `ids` joined to the start through `ids`.
static func joined(ids: Array) -> Array:
	var seen := {START: true}
	var queue := [START]
	while not queue.is_empty():
		for n in neighbours(queue.pop_front()):
			if ids.has(n) and not seen.has(n):
				seen[n] = true
				queue.append(n)
	return ids.filter(func(n: String) -> bool: return seen.has(n))


## Allocates or refunds `id`: "allocated", "refunded", "no points", "far" (not next to the tree), "holds" (others
## hang on it) or "none".
static func toggle(id: String) -> String:
	if not NODES.has(id) or id == START:
		return "none"
	if Progress.tree.has(id):
		if not can_refund(id):
			return "holds"
		Progress.tree.erase(id)
		Progress.save()
		return "refunded"
	if not reachable(id):
		return "far"
	if points_free() <= 0:
		return "no points"
	Progress.tree.append(id)
	Progress.save()
	return "allocated"


## Refunds every node.
static func reset() -> void:
	Progress.tree = []
	Progress.save()


## The allocated notables and keystones, in NODES order, by their short names (the pause menu's line).
static func big_ones() -> Array:
	var out := []
	for id in NODES:
		if NODES[id].has("short") and on(id):
			out.append(NODES[id].short)
	return out


## Multipliers the weapons and enemies read.
static func damage_mult() -> float:
	return maxf(0.1, 1.0 + stat("damage") / 100.0)


static func rate_mult() -> float:
	return 1.0 + stat("rate") / 100.0


static func token_mult() -> float:
	return 1.0 + stat("tokens") / 100.0
