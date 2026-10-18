class_name Prompts
extends RefCounted

## World 3's System Prompts as a passive tree, like Path of Exile's (docs/prompt-tree-plan.md; redrawn for the
## endgame, docs/endgame-plan.md E9): nodes joined by links around the start, SYSTEM PROMPT; a point allocates a
## node next to one Clawd has. Eight sectors grow from the start (the Tool Call, elements, offense, precision,
## movement and tokens, sustain, defence, sub-agents), each a hub notable, two branches to notables, a middle path,
## and its keystone or big notable at the end; an outer ring joins every sector's notables to its neighbours'.
## Small nodes add a little to one stat; notables do more; keystones are big trade-offs. Points: one per character
## level gained, every spark found in world 3, and more bought with tokens at a rising price (BUY_MAX at most);
## there are more nodes than points. Refunds are free: a node can go when the rest stays joined to the start, and
## reset() gives them all back. What the allocated nodes add up to is read through Stats (with the gear's) where
## it matters: Weapons (damage, fire rate), Gun (spread, critical hits, Temperature 0.), Enemy (tokens, ailments),
## Token (magnet), ToolCall (reflecting shots), Player (leech, avoiding ailments, zipping unhurt) and
## Main._apply_loadout() (hearts, life, defences, hover, run speed, the hook, sub-agents). The window is
## TreeScreen; Progress.tree holds the allocated ids.

const START := "root"
## id -> kind ("start", "small", "notable", "keystone"), name, short label (pause menu) for the big ones, what it
## does, where it sits in the tree (px from the start, y down) and its stats (`mods`, summed by stat(); a flag is
## read with on()). Written by a generator from the sectors' layout; the sectors' names are LABELS.
const NODES := {
	"root": {"kind": "start", "name": "SYSTEM PROMPT", "at": Vector2(0, 0), "mods": {},
		"desc": "Where every prompt begins. A point allocates a node next to one you have."},
	# Tool call, north.
	"tc_a1": {"kind": "small", "name": "Long Context", "at": Vector2(0, -26), "mods": {"reach": 12},
		"desc": "The hook reaches 12% farther."},
	"tc_a2": {"kind": "small", "name": "Low Latency", "at": Vector2(0, -46), "mods": {"zip": 10},
		"desc": "Zips 10% faster."},
	"ontask": {"kind": "notable", "name": "Stay on task.", "short": "ON TASK", "at": Vector2(0, -69),
		"mods": {"reach": 50, "zip": 25}, "desc": "The Tool Call reaches 50% farther and zips 25% faster."},
	"tc_l1": {"kind": "small", "name": "Long Context", "at": Vector2(-30, -88), "mods": {"reach": 12},
		"desc": "The hook reaches 12% farther."},
	"tc_l2": {"kind": "small", "name": "Long Context", "at": Vector2(-42, -106), "mods": {"reach": 12},
		"desc": "The hook reaches 12% farther."},
	"reflect": {"kind": "notable", "name": "Reflect.", "short": "REFLECT", "at": Vector2(-45, -125),
		"mods": {"reflect": 1}, "desc": "The hook catches enemy shots and throws them back."},
	"tc_r1": {"kind": "small", "name": "Low Latency", "at": Vector2(30, -88), "mods": {"zip": 10},
		"desc": "Zips 10% faster."},
	"tc_r2": {"kind": "small", "name": "Low Latency", "at": Vector2(42, -106), "mods": {"zip": 10},
		"desc": "Zips 10% faster."},
	"fastpath": {"kind": "notable", "name": "Fast path.", "short": "FAST PATH", "at": Vector2(45, -125),
		"mods": {"zip": 30, "run": 5}, "desc": "Zips 30% faster, and Clawd runs 5% faster."},
	"tc_m1": {"kind": "small", "name": "Long Context", "at": Vector2(0, -91), "mods": {"reach": 12},
		"desc": "The hook reaches 12% farther."},
	"tc_m2": {"kind": "small", "name": "Low Latency", "at": Vector2(0, -112), "mods": {"zip": 10},
		"desc": "Zips 10% faster."},
	"tc_m3": {"kind": "small", "name": "Long Context", "at": Vector2(0, -133), "mods": {"reach": 12},
		"desc": "The hook reaches 12% farther."},
	"tc_o1": {"kind": "small", "name": "Long Context", "at": Vector2(-30, -144), "mods": {"reach": 12},
		"desc": "The hook reaches 12% farther."},
	"tc_o2": {"kind": "small", "name": "Low Latency", "at": Vector2(30, -144), "mods": {"zip": 10},
		"desc": "Zips 10% faster."},
	"agentloop": {"kind": "notable", "name": "Agentic loop.", "short": "AGENTIC LOOP", "at": Vector2(0, -160),
		"mods": {"zipguard": 1}, "desc": "Nothing can hurt Clawd while he zips."},
	# Elements, north-east.
	"el_a1": {"kind": "small", "name": "Multimodal Input", "at": Vector2(34, -18), "mods": {"ele_damage": 10},
		"desc": "The damage added as elements is 10% more."},
	"el_a2": {"kind": "small", "name": "Multimodal Input", "at": Vector2(62, -33), "mods": {"ele_damage": 10},
		"desc": "The damage added as elements is 10% more."},
	"multimodal": {"kind": "notable", "name": "Multimodal.", "short": "MULTIMODAL", "at": Vector2(91, -49),
		"mods": {"extra_fire": 4, "extra_cold": 4, "extra_lightning": 4},
		"desc": "4% of damage is added as each of Overheat, Latency and Voltage."},
	"el_l1": {"kind": "small", "name": "Overclock", "at": Vector2(95, -74), "mods": {"extra_fire": 3},
		"desc": "3% of damage is added as Overheat."},
	"el_l2": {"kind": "small", "name": "Hot Path", "at": Vector2(110, -91), "mods": {"ignite": 25},
		"desc": "Ignites 25% more often."},
	"runaway": {"kind": "notable", "name": "Thermal runaway.", "short": "RUNAWAY", "at": Vector2(134, -105),
		"mods": {"extra_fire": 6, "burn": 40},
		"desc": "6% of damage is added as Overheat, and burning deals 40% more damage."},
	"el_r1": {"kind": "small", "name": "Power Draw", "at": Vector2(138, -51), "mods": {"extra_lightning": 3},
		"desc": "3% of damage is added as Voltage."},
	"el_r2": {"kind": "small", "name": "Surge Line", "at": Vector2(170, -59), "mods": {"shock": 25},
		"desc": "Shocks 25% more often."},
	"surge": {"kind": "notable", "name": "Power surge.", "short": "SURGE", "at": Vector2(197, -71),
		"mods": {"extra_lightning": 6, "shock": 40},
		"desc": "6% of damage is added as Voltage, and shocks come 40% more often."},
	"el_m1": {"kind": "small", "name": "Cold Storage", "at": Vector2(121, -64), "mods": {"extra_cold": 3},
		"desc": "3% of damage is added as Latency."},
	"el_m2": {"kind": "small", "name": "Frozen Weights", "at": Vector2(148, -79), "mods": {"freeze": 30},
		"desc": "Freezes enemies 30% more easily."},
	"el_m3": {"kind": "small", "name": "Cold Storage", "at": Vector2(176, -94), "mods": {"extra_cold": 3},
		"desc": "3% of damage is added as Latency."},
	"el_o1": {"kind": "small", "name": "Thermal Load", "at": Vector2(170, -113), "mods": {"burn": 20},
		"desc": "Burning deals 20% more damage."},
	"el_o2": {"kind": "small", "name": "Long Tail", "at": Vector2(212, -91), "mods": {"ailment_time": 15},
		"desc": "Ailments on enemies last 15% longer."},
	"coldstart": {"kind": "notable", "name": "Cold start.", "short": "COLD START", "at": Vector2(212, -113),
		"mods": {"extra_cold": 8, "freeze": 60, "ailment_time": 20},
		"desc": "8% of damage is added as Latency, enemies freeze 60% more easily and ailments last 20% longer."},
	# Offense, east.
	"of_a1": {"kind": "small", "name": "Sharper Tokens", "at": Vector2(48, 0), "mods": {"damage": 8},
		"desc": "+8% damage."},
	"of_a2": {"kind": "small", "name": "Sharper Tokens", "at": Vector2(87, 0), "mods": {"damage": 8},
		"desc": "+8% damage."},
	"bigger": {"kind": "notable", "name": "Bigger model.", "short": "BIGGER MODEL", "at": Vector2(129, 0),
		"mods": {"damage": 25}, "desc": "+25% damage."},
	"of_l1": {"kind": "small", "name": "Fast Inference", "at": Vector2(165, -16), "mods": {"rate": 6},
		"desc": "+6% fire rate."},
	"of_l2": {"kind": "small", "name": "Fast Inference", "at": Vector2(198, -22), "mods": {"rate": 6},
		"desc": "+6% fire rate."},
	"concise": {"kind": "notable", "name": "Be concise.", "short": "CONCISE", "at": Vector2(234, -24),
		"mods": {"rate": 20, "damage": -15}, "desc": "+20% fire rate, but every shot deals 15% less damage."},
	"of_r1": {"kind": "small", "name": "Sharper Tokens", "at": Vector2(165, 16), "mods": {"damage": 8},
		"desc": "+8% damage."},
	"of_r2": {"kind": "small", "name": "Sharper Tokens", "at": Vector2(198, 22), "mods": {"damage": 8},
		"desc": "+8% damage."},
	"batching": {"kind": "notable", "name": "Batching.", "short": "BATCHING", "at": Vector2(234, 24),
		"mods": {"rate": 12, "damage": 12}, "desc": "+12% fire rate and +12% damage."},
	"of_m1": {"kind": "small", "name": "Fast Inference", "at": Vector2(171, 0), "mods": {"rate": 6},
		"desc": "+6% fire rate."},
	"of_m2": {"kind": "small", "name": "Sharper Tokens", "at": Vector2(210, 0), "mods": {"damage": 8},
		"desc": "+8% damage."},
	"of_m3": {"kind": "small", "name": "Fast Inference", "at": Vector2(249, 0), "mods": {"rate": 6},
		"desc": "+6% fire rate."},
	"of_o1": {"kind": "small", "name": "Fast Inference", "at": Vector2(270, -16), "mods": {"rate": 6},
		"desc": "+6% fire rate."},
	"of_o2": {"kind": "small", "name": "Sharper Tokens", "at": Vector2(270, 16), "mods": {"damage": 8},
		"desc": "+8% damage."},
	"expert": {"kind": "keystone", "name": "You are an expert.", "short": "EXPERT", "at": Vector2(300, 0),
		"mods": {"damage": 35, "hearts": -1}, "desc": "+35% damage, but one heart less (25 life less in the endgame)."},
	# Precision, south-east.
	"pr_a1": {"kind": "small", "name": "Top-p Sampling", "at": Vector2(34, 18), "mods": {"crit_inc": 15},
		"desc": "Critical strikes come 15% more often."},
	"pr_a2": {"kind": "small", "name": "Top-p Sampling", "at": Vector2(62, 33), "mods": {"crit_inc": 15},
		"desc": "Critical strikes come 15% more often."},
	"temp15": {"kind": "notable", "name": "Temperature 1.5", "short": "TEMP 1.5", "at": Vector2(91, 49),
		"mods": {"temperature": 1}, "desc": "Wilder aim, but one hit in seven deals double damage."},
	"pr_l1": {"kind": "small", "name": "Logit Bias", "at": Vector2(138, 51), "mods": {"crit_multi": 12},
		"desc": "+12% critical strike damage."},
	"pr_l2": {"kind": "small", "name": "Logit Bias", "at": Vector2(170, 59), "mods": {"crit_multi": 12},
		"desc": "+12% critical strike damage."},
	"cot": {"kind": "notable", "name": "Chain of thought.", "short": "CHAIN OF THOUGHT", "at": Vector2(197, 71),
		"mods": {"crit_multi": 40}, "desc": "+40% critical strike damage."},
	"pr_r1": {"kind": "small", "name": "Context Window", "at": Vector2(95, 74), "mods": {"heat": 10},
		"desc": "The context window holds 10% more heat."},
	"pr_r2": {"kind": "small", "name": "Context Window", "at": Vector2(110, 91), "mods": {"heat": 10},
		"desc": "The context window holds 10% more heat."},
	"caching": {"kind": "notable", "name": "Context caching.", "short": "CACHING", "at": Vector2(134, 105),
		"mods": {"heat": 30, "rate": 6}, "desc": "The context window holds 30% more heat, and +6% fire rate."},
	"pr_m1": {"kind": "small", "name": "Top-p Sampling", "at": Vector2(121, 64), "mods": {"crit_inc": 15},
		"desc": "Critical strikes come 15% more often."},
	"pr_m2": {"kind": "small", "name": "Top-p Sampling", "at": Vector2(148, 79), "mods": {"crit_inc": 15},
		"desc": "Critical strikes come 15% more often."},
	"pr_m3": {"kind": "small", "name": "Logit Bias", "at": Vector2(176, 94), "mods": {"crit_multi": 12},
		"desc": "+12% critical strike damage."},
	"pr_o1": {"kind": "small", "name": "Logit Bias", "at": Vector2(212, 91), "mods": {"crit_multi": 12},
		"desc": "+12% critical strike damage."},
	"pr_o2": {"kind": "small", "name": "Context Window", "at": Vector2(170, 113), "mods": {"heat": 10},
		"desc": "The context window holds 10% more heat."},
	"temp0": {"kind": "keystone", "name": "Temperature 0.", "short": "TEMP 0", "at": Vector2(212, 113),
		"mods": {"precise": 1},
		"desc": "Shots fly dead straight and deal 30% more damage, but never critically strike or hit double."},
	# Movement & tokens, south.
	"mv_a1": {"kind": "small", "name": "Jet Fuel", "at": Vector2(0, 26), "mods": {"hover": 15},
		"desc": "+15% hover time."},
	"mv_a2": {"kind": "small", "name": "Quick Feet", "at": Vector2(0, 46), "mods": {"run": 4},
		"desc": "Clawd runs 4% faster."},
	"steps": {"kind": "notable", "name": "Think step by step.", "short": "STEPS", "at": Vector2(0, 69),
		"mods": {"hover": 60, "run": -10}, "desc": "+60% hover time, but Clawd runs 10% slower."},
	"mv_l1": {"kind": "small", "name": "Billing", "at": Vector2(30, 88), "mods": {"tokens": 6},
		"desc": "Enemies drop 6% more tokens."},
	"mv_l2": {"kind": "small", "name": "Billing", "at": Vector2(42, 106), "mods": {"tokens": 6},
		"desc": "Enemies drop 6% more tokens."},
	"cite": {"kind": "notable", "name": "Cite your sources.", "short": "CITE", "at": Vector2(45, 125),
		"mods": {"tokens": 30}, "desc": "Enemies drop 30% more tokens."},
	"mv_r1": {"kind": "small", "name": "Quick Feet", "at": Vector2(-30, 88), "mods": {"run": 4},
		"desc": "Clawd runs 4% faster."},
	"mv_r2": {"kind": "small", "name": "Jet Fuel", "at": Vector2(-42, 106), "mods": {"hover": 15},
		"desc": "+15% hover time."},
	"streaming": {"kind": "notable", "name": "Streaming.", "short": "STREAMING", "at": Vector2(-45, 125),
		"mods": {"run": 10, "hover": 20}, "desc": "Clawd runs 10% faster, and +20% hover time."},
	"mv_m1": {"kind": "small", "name": "Embeddings", "at": Vector2(0, 91), "mods": {"magnet": 24},
		"desc": "Tokens within 24 px more fly to Clawd (without the Token Magnet too)."},
	"mv_m2": {"kind": "small", "name": "Embeddings", "at": Vector2(0, 112), "mods": {"magnet": 24},
		"desc": "Tokens within 24 px more fly to Clawd (without the Token Magnet too)."},
	"mv_m3": {"kind": "small", "name": "Billing", "at": Vector2(0, 133), "mods": {"tokens": 6},
		"desc": "Enemies drop 6% more tokens."},
	"mv_o1": {"kind": "small", "name": "Billing", "at": Vector2(30, 144), "mods": {"tokens": 6},
		"desc": "Enemies drop 6% more tokens."},
	"mv_o2": {"kind": "small", "name": "Embeddings", "at": Vector2(-30, 144), "mods": {"magnet": 24},
		"desc": "Tokens within 24 px more fly to Clawd (without the Token Magnet too)."},
	"retrieval": {"kind": "notable", "name": "Retrieval.", "short": "RETRIEVAL", "at": Vector2(0, 160),
		"mods": {"magnet": 72}, "desc": "Tokens fly to Clawd from 72 px farther."},
	# Sustain, south-west.
	"su_a1": {"kind": "small", "name": "Self-repair", "at": Vector2(-34, 18), "mods": {"regen_pct": 0.4},
		"desc": "Regenerates 0.4% of maximum life a second (endgame)."},
	"su_a2": {"kind": "small", "name": "Self-repair", "at": Vector2(-62, 33), "mods": {"regen_pct": 0.4},
		"desc": "Regenerates 0.4% of maximum life a second (endgame)."},
	"selfheal": {"kind": "notable", "name": "Self-healing.", "short": "SELF-HEALING", "at": Vector2(-91, 49),
		"mods": {"regen_pct": 1.2, "life_pct": 4},
		"desc": "Regenerates 1.2% of maximum life a second, and +4% maximum life (endgame)."},
	"su_l1": {"kind": "small", "name": "Backprop", "at": Vector2(-95, 74), "mods": {"leech": 0.4},
		"desc": "0.4% of the damage Clawd deals is leeched as life (endgame)."},
	"su_l2": {"kind": "small", "name": "Backprop", "at": Vector2(-110, 91), "mods": {"leech": 0.4},
		"desc": "0.4% of the damage Clawd deals is leeched as life (endgame)."},
	"gradflow": {"kind": "notable", "name": "Gradient flow.", "short": "GRADIENT FLOW", "at": Vector2(-134, 105),
		"mods": {"leech": 1.2}, "desc": "1.2% of the damage Clawd deals is leeched as life (endgame)."},
	"su_r1": {"kind": "small", "name": "Fault Tolerance", "at": Vector2(-138, 51), "mods": {"avoid": 10},
		"desc": "10% chance to avoid being ignited, chilled or shocked (endgame)."},
	"su_r2": {"kind": "small", "name": "Fault Tolerance", "at": Vector2(-170, 59), "mods": {"avoid": 10},
		"desc": "10% chance to avoid being ignited, chilled or shocked (endgame)."},
	"graceful": {"kind": "notable", "name": "Graceful degradation.", "short": "GRACEFUL", "at": Vector2(-197, 71),
		"mods": {"avoid": 30, "life_pct": 4},
		"desc": "30% chance to avoid being ignited, chilled or shocked, and +4% maximum life (endgame)."},
	"su_m1": {"kind": "small", "name": "Self-repair", "at": Vector2(-121, 64), "mods": {"regen_pct": 0.4},
		"desc": "Regenerates 0.4% of maximum life a second (endgame)."},
	"su_m2": {"kind": "small", "name": "Backprop", "at": Vector2(-148, 79), "mods": {"leech": 0.4},
		"desc": "0.4% of the damage Clawd deals is leeched as life (endgame)."},
	"su_m3": {"kind": "small", "name": "Self-repair", "at": Vector2(-176, 94), "mods": {"regen_pct": 0.4},
		"desc": "Regenerates 0.4% of maximum life a second (endgame)."},
	"su_o1": {"kind": "small", "name": "Backprop", "at": Vector2(-170, 113), "mods": {"leech": 0.4},
		"desc": "0.4% of the damage Clawd deals is leeched as life (endgame)."},
	"su_o2": {"kind": "small", "name": "Fault Tolerance", "at": Vector2(-212, 91), "mods": {"avoid": 10},
		"desc": "10% chance to avoid being ignited, chilled or shocked (endgame)."},
	"gradleech": {"kind": "keystone", "name": "Gradient Leech.", "short": "GRADIENT LEECH", "at": Vector2(-212, 113),
		"mods": {"gradleech": 1}, "desc": "Leech heals twice as fast, but Clawd never regenerates life."},
	# Defence, west.
	"de_a1": {"kind": "small", "name": "More Parameters", "at": Vector2(-48, 0), "mods": {"life_pct": 5},
		"desc": "+5% maximum life (endgame)."},
	"de_a2": {"kind": "small", "name": "More Parameters", "at": Vector2(-87, 0), "mods": {"life_pct": 5},
		"desc": "+5% maximum life (endgame)."},
	"guardrails": {"kind": "notable", "name": "Guardrails.", "short": "GUARDRAILS", "at": Vector2(-129, 0),
		"mods": {"hearts": 1, "res_ele": 5},
		"desc": "One more heart (25 life in the endgame), and +5% to elemental resistances."},
	"de_l1": {"kind": "small", "name": "Hardening", "at": Vector2(-165, 16), "mods": {"armour_pct": 12},
		"desc": "+12% armour (endgame)."},
	"de_l2": {"kind": "small", "name": "Hardening", "at": Vector2(-198, 22), "mods": {"armour_pct": 12},
		"desc": "+12% armour (endgame)."},
	"hardened": {"kind": "notable", "name": "Hardened weights.", "short": "HARDENED", "at": Vector2(-234, 24),
		"mods": {"armour_pct": 30, "armour": 40}, "desc": "+40 armour and +30% armour (endgame)."},
	"de_r1": {"kind": "small", "name": "Dropout", "at": Vector2(-165, -16), "mods": {"evasion_pct": 12},
		"desc": "+12% evasion (endgame)."},
	"de_r2": {"kind": "small", "name": "Dropout", "at": Vector2(-198, -22), "mods": {"evasion_pct": 12},
		"desc": "+12% evasion (endgame)."},
	"stochastic": {"kind": "notable", "name": "Stochastic depth.", "short": "STOCHASTIC", "at": Vector2(-234, -24),
		"mods": {"evasion_pct": 30, "evasion": 40}, "desc": "+40 evasion and +30% evasion (endgame)."},
	"de_m1": {"kind": "small", "name": "Red Teaming", "at": Vector2(-171, 0), "mods": {"res_ele": 6},
		"desc": "+6% to Overheat, Latency and Voltage resistances (endgame)."},
	"de_m2": {"kind": "small", "name": "Sandboxing", "at": Vector2(-210, 0), "mods": {"res_chaos": 10},
		"desc": "+10% to Corruption resistance (endgame)."},
	"de_o1": {"kind": "small", "name": "Hardening", "at": Vector2(-282, 19), "mods": {"armour_pct": 12},
		"desc": "+12% armour (endgame)."},
	"de_o2": {"kind": "small", "name": "Dropout", "at": Vector2(-282, -19), "mods": {"evasion_pct": 12},
		"desc": "+12% evasion (endgame)."},
	"robust": {"kind": "keystone", "name": "Robustness.", "short": "ROBUSTNESS", "at": Vector2(-330, 0),
		"mods": {"robust": 1}, "desc": "Evasion counts as armour, but Clawd never evades (endgame)."},
	"airgap": {"kind": "keystone", "name": "Air-gapped.", "short": "AIR-GAPPED", "at": Vector2(-252, 0),
		"mods": {"airgap": 1}, "desc": "Corruption cannot hurt Clawd, but he has 40% less maximum life (endgame)."},
	# Sub-agents, north-west.
	"sa_a1": {"kind": "small", "name": "Patience", "at": Vector2(-34, -18), "mods": {"stand": 2},
		"desc": "Sub-agents stand 2 s longer."},
	"sa_a2": {"kind": "small", "name": "Patience", "at": Vector2(-62, -33), "mods": {"stand": 2},
		"desc": "Sub-agents stand 2 s longer."},
	"tooluse": {"kind": "notable", "name": "Tool use.", "short": "TOOL USE", "at": Vector2(-91, -49),
		"mods": {"minions": 1}, "desc": "Standing sub-agents shoot the nearest enemy in sight."},
	"sa_l1": {"kind": "small", "name": "Shared Weights", "at": Vector2(-138, -51), "mods": {"minion_damage": 20},
		"desc": "Sub-agents' shots deal 20% more damage."},
	"sa_l2": {"kind": "small", "name": "Shared Weights", "at": Vector2(-170, -59), "mods": {"minion_damage": 20},
		"desc": "Sub-agents' shots deal 20% more damage."},
	"parallel": {"kind": "notable", "name": "Parallel tool calls.", "short": "PARALLEL", "at": Vector2(-197, -71),
		"mods": {"parallel": 1}, "desc": "Sub-agents fire two shots at once."},
	"sa_r1": {"kind": "small", "name": "Patience", "at": Vector2(-95, -74), "mods": {"stand": 2},
		"desc": "Sub-agents stand 2 s longer."},
	"sa_r2": {"kind": "small", "name": "Async Calls", "at": Vector2(-110, -91), "mods": {"minion_rate": 20},
		"desc": "Sub-agents shoot 20% faster."},
	"delegate": {"kind": "notable", "name": "Delegate.", "short": "DELEGATE", "at": Vector2(-134, -105),
		"mods": {"slots": 1}, "desc": "One more sub-agent out at once."},
	"sa_m1": {"kind": "small", "name": "Shared Weights", "at": Vector2(-121, -64), "mods": {"minion_damage": 20},
		"desc": "Sub-agents' shots deal 20% more damage."},
	"sa_m2": {"kind": "small", "name": "Async Calls", "at": Vector2(-148, -79), "mods": {"minion_rate": 20},
		"desc": "Sub-agents shoot 20% faster."},
	"sa_m3": {"kind": "small", "name": "Shared Weights", "at": Vector2(-176, -94), "mods": {"minion_damage": 20},
		"desc": "Sub-agents' shots deal 20% more damage."},
	"sa_o1": {"kind": "small", "name": "Async Calls", "at": Vector2(-212, -91), "mods": {"minion_rate": 20},
		"desc": "Sub-agents shoot 20% faster."},
	"sa_o2": {"kind": "small", "name": "Patience", "at": Vector2(-170, -113), "mods": {"stand": 2},
		"desc": "Sub-agents stand 2 s longer."},
	"orchestrator": {"kind": "keystone", "name": "Orchestrator.", "short": "ORCHESTRATOR", "at": Vector2(-212, -113),
		"mods": {"slots": 1, "damage": -20},
		"desc": "One more sub-agent out at once, but Clawd's own shots deal 20% less damage."},
	# The outer ring, between the sectors.
	"tc_el1": {"kind": "small", "name": "Long Context", "at": Vector2(75, -118), "mods": {"reach": 12},
		"desc": "The hook reaches 12% farther."},
	"tc_el2": {"kind": "small", "name": "Multimodal Input", "at": Vector2(104, -112), "mods": {"ele_damage": 10},
		"desc": "The damage added as elements is 10% more."},
	"el_of1": {"kind": "small", "name": "Multimodal Input", "at": Vector2(209, -55), "mods": {"ele_damage": 10},
		"desc": "The damage added as elements is 10% more."},
	"el_of2": {"kind": "small", "name": "Sharper Tokens", "at": Vector2(222, -40), "mods": {"damage": 8},
		"desc": "+8% damage."},
	"of_pr1": {"kind": "small", "name": "Fast Inference", "at": Vector2(222, 40), "mods": {"rate": 6},
		"desc": "+6% fire rate."},
	"of_pr2": {"kind": "small", "name": "Top-p Sampling", "at": Vector2(209, 55), "mods": {"crit_inc": 15},
		"desc": "Critical strikes come 15% more often."},
	"pr_mv1": {"kind": "small", "name": "Context Window", "at": Vector2(104, 112), "mods": {"heat": 10},
		"desc": "The context window holds 10% more heat."},
	"pr_mv2": {"kind": "small", "name": "Jet Fuel", "at": Vector2(75, 118), "mods": {"hover": 15},
		"desc": "+15% hover time."},
	"mv_su1": {"kind": "small", "name": "Quick Feet", "at": Vector2(-75, 118), "mods": {"run": 4},
		"desc": "Clawd runs 4% faster."},
	"mv_su2": {"kind": "small", "name": "Self-repair", "at": Vector2(-104, 112), "mods": {"regen_pct": 0.4},
		"desc": "Regenerates 0.4% of maximum life a second (endgame)."},
	"su_de1": {"kind": "small", "name": "Backprop", "at": Vector2(-209, 55), "mods": {"leech": 0.4},
		"desc": "0.4% of the damage Clawd deals is leeched as life (endgame)."},
	"su_de2": {"kind": "small", "name": "More Parameters", "at": Vector2(-222, 40), "mods": {"life_pct": 5},
		"desc": "+5% maximum life (endgame)."},
	"de_sa1": {"kind": "small", "name": "Dropout", "at": Vector2(-222, -40), "mods": {"evasion_pct": 12},
		"desc": "+12% evasion (endgame)."},
	"de_sa2": {"kind": "small", "name": "Patience", "at": Vector2(-209, -55), "mods": {"stand": 2},
		"desc": "Sub-agents stand 2 s longer."},
	"sa_tc1": {"kind": "small", "name": "Async Calls", "at": Vector2(-104, -112), "mods": {"minion_rate": 20},
		"desc": "Sub-agents shoot 20% faster."},
	"sa_tc2": {"kind": "small", "name": "Low Latency", "at": Vector2(-75, -118), "mods": {"zip": 10},
		"desc": "Zips 10% faster."},
}
const LINKS := [
	["root", "tc_a1"], ["tc_a1", "tc_a2"], ["tc_a2", "ontask"], ["ontask", "tc_l1"], ["tc_l1", "tc_l2"],
	["tc_l2", "reflect"], ["ontask", "tc_r1"], ["tc_r1", "tc_r2"], ["tc_r2", "fastpath"], ["ontask", "tc_m1"],
	["tc_m1", "tc_m2"], ["reflect", "tc_o1"], ["tc_o1", "agentloop"], ["fastpath", "tc_o2"], ["tc_o2", "agentloop"],
	["tc_m2", "tc_m3"], ["tc_m3", "agentloop"], ["root", "el_a1"], ["el_a1", "el_a2"], ["el_a2", "multimodal"],
	["multimodal", "el_l1"], ["el_l1", "el_l2"], ["el_l2", "runaway"], ["multimodal", "el_r1"], ["el_r1", "el_r2"],
	["el_r2", "surge"], ["multimodal", "el_m1"], ["el_m1", "el_m2"], ["runaway", "el_o1"], ["el_o1", "coldstart"],
	["surge", "el_o2"], ["el_o2", "coldstart"], ["el_m2", "el_m3"], ["el_m3", "coldstart"], ["root", "of_a1"],
	["of_a1", "of_a2"], ["of_a2", "bigger"], ["bigger", "of_l1"], ["of_l1", "of_l2"], ["of_l2", "concise"],
	["bigger", "of_r1"], ["of_r1", "of_r2"], ["of_r2", "batching"], ["bigger", "of_m1"], ["of_m1", "of_m2"],
	["concise", "of_o1"], ["of_o1", "expert"], ["batching", "of_o2"], ["of_o2", "expert"], ["of_m2", "of_m3"],
	["of_m3", "expert"], ["root", "pr_a1"], ["pr_a1", "pr_a2"], ["pr_a2", "temp15"], ["temp15", "pr_l1"],
	["pr_l1", "pr_l2"], ["pr_l2", "cot"], ["temp15", "pr_r1"], ["pr_r1", "pr_r2"], ["pr_r2", "caching"],
	["temp15", "pr_m1"], ["pr_m1", "pr_m2"], ["cot", "pr_o1"], ["pr_o1", "temp0"], ["caching", "pr_o2"],
	["pr_o2", "temp0"], ["pr_m2", "pr_m3"], ["pr_m3", "temp0"], ["root", "mv_a1"], ["mv_a1", "mv_a2"],
	["mv_a2", "steps"], ["steps", "mv_l1"], ["mv_l1", "mv_l2"], ["mv_l2", "cite"], ["steps", "mv_r1"],
	["mv_r1", "mv_r2"], ["mv_r2", "streaming"], ["steps", "mv_m1"], ["mv_m1", "mv_m2"], ["cite", "mv_o1"],
	["mv_o1", "retrieval"], ["streaming", "mv_o2"], ["mv_o2", "retrieval"], ["mv_m2", "mv_m3"],
	["mv_m3", "retrieval"], ["root", "su_a1"], ["su_a1", "su_a2"], ["su_a2", "selfheal"], ["selfheal", "su_l1"],
	["su_l1", "su_l2"], ["su_l2", "gradflow"], ["selfheal", "su_r1"], ["su_r1", "su_r2"], ["su_r2", "graceful"],
	["selfheal", "su_m1"], ["su_m1", "su_m2"], ["gradflow", "su_o1"], ["su_o1", "gradleech"], ["graceful", "su_o2"],
	["su_o2", "gradleech"], ["su_m2", "su_m3"], ["su_m3", "gradleech"], ["root", "de_a1"], ["de_a1", "de_a2"],
	["de_a2", "guardrails"], ["guardrails", "de_l1"], ["de_l1", "de_l2"], ["de_l2", "hardened"],
	["guardrails", "de_r1"], ["de_r1", "de_r2"], ["de_r2", "stochastic"], ["guardrails", "de_m1"],
	["de_m1", "de_m2"], ["hardened", "de_o1"], ["de_o1", "robust"], ["stochastic", "de_o2"], ["de_o2", "robust"],
	["de_m2", "airgap"], ["root", "sa_a1"], ["sa_a1", "sa_a2"], ["sa_a2", "tooluse"], ["tooluse", "sa_l1"],
	["sa_l1", "sa_l2"], ["sa_l2", "parallel"], ["tooluse", "sa_r1"], ["sa_r1", "sa_r2"], ["sa_r2", "delegate"],
	["tooluse", "sa_m1"], ["sa_m1", "sa_m2"], ["parallel", "sa_o1"], ["sa_o1", "orchestrator"],
	["delegate", "sa_o2"], ["sa_o2", "orchestrator"], ["sa_m2", "sa_m3"], ["sa_m3", "orchestrator"],
	["fastpath", "tc_el1"], ["tc_el1", "tc_el2"], ["tc_el2", "runaway"], ["surge", "el_of1"], ["el_of1", "el_of2"],
	["el_of2", "concise"], ["batching", "of_pr1"], ["of_pr1", "of_pr2"], ["of_pr2", "cot"], ["caching", "pr_mv1"],
	["pr_mv1", "pr_mv2"], ["pr_mv2", "cite"], ["streaming", "mv_su1"], ["mv_su1", "mv_su2"], ["mv_su2", "gradflow"],
	["graceful", "su_de1"], ["su_de1", "su_de2"], ["su_de2", "hardened"], ["stochastic", "de_sa1"],
	["de_sa1", "de_sa2"], ["de_sa2", "parallel"], ["delegate", "sa_tc1"], ["sa_tc1", "sa_tc2"],
	["sa_tc2", "reflect"]
]
## The sectors' names, dim, past their ends (tree px).
const LABELS := [
	["TOOL CALL", Vector2(0, -184)], ["ELEMENTS", Vector2(244, -130)], ["OFFENSE", Vector2(345, 0)],
	["PRECISION", Vector2(244, 130)], ["MOVEMENT & TOKENS", Vector2(0, 184)], ["SUSTAIN", Vector2(-244, 130)],
	["DEFENCE", Vector2(-375, 0)], ["SUB-AGENTS", Vector2(-244, -130)]
]
## Bought points: the first costs BUY_PRICE tokens, every next one BUY_STEP more, at most BUY_MAX of them.
const BUY_PRICE := 60
const BUY_STEP := 30
const BUY_MAX := 10
## Temperature 1.5: extra random spread (radians) and the chance of a double hit.
const TEMP_SPREAD := 0.06
const TEMP_CRIT := 1.0 / 7.0
## Temperature 0.: more damage (no spread, no critical strikes).
const PRECISE_MORE := 0.3
## Air-gapped.: less maximum life (Corruption cannot hurt).
const AIRGAP_LESS_LIFE := 0.4
## The tree's layout: a save from an older one gets its points back once (Progress.load_file()).
const VERSION := 2

## stat()'s sums, kept while Progress.tree stays the same (its hash).
static var _cache := {}
static var _cache_of := 0


## An allocated node (the start always is), or a flag one of them sets.
static func on(id: String) -> bool:
	if NODES.has(id):
		return id == START or Progress.tree.has(id)
	return stat(id) > 0


## A stat summed over the allocated nodes.
static func stat(key: String) -> float:
	var h := Progress.tree.hash()
	if h != _cache_of:
		_cache = {}
		_cache_of = h
	if not _cache.has(key):
		var n := 0.0
		for id in Progress.tree:
			n += float(NODES.get(id, {}).get("mods", {}).get(key, 0))
		_cache[key] = n
	return _cache[key]


## The nodes linked to `id` (in `links`: the Atlas's tree uses these too).
static func neighbours(id: String, links := LINKS) -> Array:
	var out := []
	for l in links:
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


## The nodes of `ids` joined to the start through `ids` (of the tree of `links` and `start`).
static func joined(ids: Array, links := LINKS, start := START) -> Array:
	var seen := {start: true}
	var queue := [start]
	while not queue.is_empty():
		for n in neighbours(queue.pop_front(), links):
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


static func allocated() -> Array:
	return Progress.tree


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
