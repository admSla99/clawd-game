# World 3 plan: AGENT MODE

World 3 adds a verb that joins movement and aiming, gives the rescued sub-agents a use, and starts the build
customization that the endgame (endless maps with modifiers, later) will grow from. Chosen by the user on
2026-10-13 from three concepts (A Toolchain, B Latent Sea, C Orchestrator): **A's Tool Call as the main mechanic
with A's levels, C's sub-agents as the second mechanic, and System Prompts (Hollow Knight's charms) for builds.**
Tick the boxes in the commit that finishes a task; record extras the user asks for under *Added beyond the plan*.

## The world

**WORLD 3 — AGENT MODE.** Codex, beaten, drops the **Tool Call**; world 3 opens on the map as a third row.
Five levels, each with its own theme, motif and music:

| Level | Name | Subtitle | What it teaches |
|---|---|---|---|
| 3-1 | Endpoint Canopy | *every branch is an API* | Tool Call: zipping to anchors over chasms and spikes, yanking enemies; the Parser |
| 3-2 | Webhook Cliffs | *it calls you back. eventually.* | A vertical climb: Webhooks (moving anchors), sub-agents, plates and gates |
| 3-3 | The Sandbox | *nothing here is permanent* | A flat arena run: brittle blocks, Retry Loops that lock the arena until destroyed; a good farming level |
| 3-4 | Timeout Ravine | *respond within 1.2 seconds* | Timeout anchors, deadlock gates (two plates at once) and races against a plate's timer |
| 3-B | The Router | *all requests go through me* | The boss |

## Mechanics

### Tool Call (the hook)
*Ori and the Will of the Wisps' Grapple, Bionic Commando.*

- Action `tool`: **Shift / F / right mouse button** (the right button moves from spin to the hook; spin keeps
  C / L, and unarmed the attack button spins anyway). Owned once Codex is beaten (`Progress`), from then on in
  every level, worlds 1 and 2 too.
- Aimed like the gun: the mouse, or the keys (facing, ↑ / ↓ tilt). An aim assist picks the anchor nearest to the
  aim line within the hook's reach (8 tiles) and a 35° cone; with none, the hook flies straight and comes back.
- **Anchor** (`+`, an API endpoint: a glowing node): the hook catches it and **zips** Clawd to it (fast, no
  gravity, stopped by walls). Arriving gives a small hop and refills hover and the air spin; jump during the zip
  lets go with a jump; letting go of `tool` keeps the speed (a fling).
- **Timeout anchor** (`*`): dissolves 1.2 s after it is caught, comes back after 3 s.
- **Enemies**: small ones (bugs, injector bugs, drones) are yanked to Clawd and stunned; a shield bot loses its
  shield; a Parser loses its armour; a Webhook zips Clawd to it like an anchor.
- Look: a voxel claw on a dotted cable, a small sound set (throw, catch, zip, miss).

### Sub-agents (echoes)
*Prince of Persia: The Lost Crown, The Swapper, Braid.*

- Action `agent`: **G / middle mouse button**. Clawd's last 3 s are always recorded; `agent` sends out a
  sub-agent that **replays those 3 s** from where Clawd was and then stays where Clawd stood when it was sent, for
  8 s: it holds plates, can be stood on, draws enemy fire (3 hits) and then fades. Press again to recall the oldest.
- How many at once depends on the sub-agents rescued (in every world): 1, 2 from 10 rescued, 3 from 18 rescued
  (22 in the game once world 3 is in). The HUD's sub-agent counter shows the free ones.
- **Plates and gates**: plates are digits `1`–`9` on the floor, gates are the letters `a`–`i` (`a` ↔ `1`, …): a
  gate (solid, a column of its letter) is open while every plate of its digit is held by Clawd, a sub-agent or a
  crate. Some plates time out: a gate stays open for a while after its plate is let go (per level metadata).

### System Prompts (builds)
*Hollow Knight's charms.*

- Bought in the shop (a SYSTEM PROMPTS section from world 3 on, priced in tokens and sparks) and equipped within a
  **context budget** of 4 (upgrade *Longer System Prompt*: 6, 8). Equipped prompts show in the pause menu.
- First set (cost in budget):

| Prompt | Cost | Effect |
|---|---|---|
| Be concise. | 1 | +20 % fire rate, −15 % damage |
| Cite your sources. | 1 | enemies drop +30 % tokens |
| Temperature 1.5 | 1 | wider spread, 15 % of hits deal double damage |
| Think step by step. | 2 | +60 % hover time, −10 % run speed |
| Stay on task. | 2 | Tool Call reach +50 %, faster zips |
| Delegate. | 2 | +1 sub-agent at once |
| You are an expert. | 3 | +35 % damage, one heart less |
| Reflect. | 3 | the hook catches enemy shots and throws them back |

- Later the endgame's maps can use the same system as map modifiers.

### New enemies

| Char | Enemy | Behaviour |
|---|---|---|
| `P` | **Parser** | An armoured crawler: bullets bounce off its plating until the Tool Call rips it off, then it is fragile |
| `W` | **Webhook** | Flies a fixed loop and dives at Clawd; it is a moving anchor (hook it to ride it up) |
| `L` | **Retry Loop** | A `while(true)` ring that spawns a bug every 4 s (3 alive at most) until destroyed; gates with no plate (`z`) open once every Retry Loop of the level is gone |

### New tiles and spawns

| Char | What |
|---|---|
| `+` `*` | Anchor, timeout anchor |
| `%` | Brittle block (sandbox data): solid, breaks from 3 bullets, a pound, an explosion or a zip into it |
| `1`–`9`, `a`–`i`, `z` | Plates and gates; `z` gates open when the level's Retry Loops are destroyed |

`tools/reach.gd` learns anchors (a zip to every anchor in reach and sight, then the usual drifts), treats gates as
open and brittle blocks as broken; puzzles get their own check sections.

### The Router (3-B)

A switchboard hub over the arena with cables to four ports in the walls, anchors under the ceiling, 3 phases,
120 hp (boss bar):
1. **Routing**: packets run along the cables and fire from the ports; its core hides behind a firewall plate
   that the Tool Call rips off (three catches), then the core can be shot until the plate grows back.
2. **Loopback**: hostile echoes of Clawd replay his last 3 s (touching one hurts); anchors move.
3. **Timeout storm**: anchors become timeout anchors, packets come in bursts, the floor's edges turn to spikes.

Beaten: WORLD 3 CLEAR, the ending, and a teaser for what comes next.

## Decisions (2026-10-13)

- The TS game is retired (branch `ts-legacy`); world 3 is made directly in Godot. Maps are hand-written
  `levels/<id>.txt`, `tools/reach.gd` replaces the TS reachability tests.
- Same rules as before: full jumps only, enemies 3× hp and 5× tokens, prices tuned to that income, spark prices
  add up to all the levels' sparks (55 with world 3).
- Each level: 5 sparks, 2 sub-agents, a checkpoint or two, a motif and music of its own.
- Rhythm: milestone by milestone; after each one `tools/check.gd`, `tools/reach.gd` for changed maps, README,
  commit + push to `main`.

## Tasks

### W0 The line
- [x] TS game kept on `ts-legacy`; `src/`, `tests/`, the npm/vite files, the Pages workflow and
      `export_levels.mjs` removed; `overrides.json` folded into `index.json`.
- [x] `tools/reach.gd`: reachability of every level in GDScript (all seven playable levels pass).
- [x] README.md, `godot/README.md`, CLAUDE.md, `port-plan.md` brought up to date; this plan.
- [x] `godot-2.5d` merged into `main`; work continues on `main`.

### W1 Skeleton
- [ ] `index.json` entries for 3-1 … 3-B with placeholder maps; WORLD 3 on the world map (third row, name, lock
      hint); the five themes' palettes and parallax.
- [ ] Codex drops the Tool Call (pickup), WORLD 2 CLEAR opens world 3 instead of the end screen.

### W2 Tool Call
- [ ] `tool` action and binding (right mouse button moves from spin), owned flag in `Progress`.
- [ ] The hook (`scripts/tool_call.gd`): aim, assist, flight, catch, zip, fling, miss; anchors `+`; sounds; look.
- [ ] Yanking enemies (small ones, shields); the HUD shows the hook.
- [ ] `reach.gd` zips to anchors; checks.

### W3 3-1 Endpoint Canopy
- [ ] Parser (`P`).
- [ ] The map, signs, sparks, sub-agents; canopy motif and music; `tools/checks/3-1.gd`.

### W4 Sub-agents
- [ ] `agent` action, the 3 s recording, the echo (replay, stand, plate, decoy, fade, recall), slots from rescued
      sub-agents, HUD.
- [ ] Plates `1`–`9` and gates `a`–`i`; checks.

### W5 3-2 Webhook Cliffs
- [ ] Webhook (`W`).
- [ ] The map (vertical), cliffs motif and music, check section.

### W6 3-3 The Sandbox
- [ ] Brittle blocks `%` (MeshLibrary item, breaking by bullets, pound, orb, zip).
- [ ] Retry Loop (`L`) and `z` gates.
- [ ] The map (arena run), sandbox motif and music, check section.

### W7 3-4 Timeout Ravine
- [ ] Timeout anchors `*`, timed plates.
- [ ] The map, ravine motif and music, check section.

### W8 3-B The Router
- [ ] The boss, its arena, router motif and music; WORLD 3 CLEAR and the ending.

### W9 System Prompts
- [ ] Progress (owned, equipped), the shop's SYSTEM PROMPTS section and equipping, Longer System Prompt.
- [ ] The eight prompts' effects; the pause menu lists them; checks.

### W10 Finish
- [ ] Prices and spark sum (55), token income per level in *Shop*, README / CLAUDE.md, a playthrough list for the
      user.

## Added beyond the plan

(none yet)
