# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

CLAWD is a 2.5D platformer/shooter starring Clawd, made in **Godot 4.7.2 (GDScript)** in `godot/`. It began as a
port of a TypeScript browser game; that game is retired and kept only on the `ts-legacy` branch (the 2D Godot port
is on `godot-2d-port`). `main` is the Godot game and new work happens there.

**`godot/README.md` is the detailed design doc** (rendering pipeline, oblique projection, shaders, levels, every
system, checks, layout). Read the relevant section before changing something, and update it in the same commit
when behaviour changes, as every feature commit does. Scripts that were ported still name the TS file/function they
came from (`src/...` paths refer to the `ts-legacy` branch); that is history, not a dependency.

## Commands

Run from `godot/`. `godot` is not on PATH on this Windows machine; the editor executable is
`C:/Program Files (x86)/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe`. Wrap `--script` runs
in `timeout` (a script that fails to parse never quits). `tools/install_godot.sh` is Linux-only.

```bash
godot --headless --script tools/check.gd                       # headless checks, exits non-zero on failure
godot --headless --script tools/reach.gd [-- 2-1]              # levels' exit/sparks/sub-agents reachable (5-12 s each)
godot --headless --script tools/convert_level.gd -- 1-1        # levels/*.txt -> levels/*.tscn (no ids = all)
godot --headless --script tools/build_meshlib.gd               # regenerate tiles/terrain_meshlib.tres
godot --headless --export-release "Web" build/web/index.html   # web build (no threads, any static host)
godot --headless --path . --import                             # after adding a class_name, before running scripts
```

The game targets desktop (keyboard and mouse; no gamepad or touch, the user's call); the web build is not a focus.

## Things that span files

- **Units**: game logic works in pixels, y down, 16 px per tile (the TS units). `Px` (`scripts/px.gd`) converts
  to metres (1 tile = 1 m, y up, level top-left at origin, gameplay plane z = 0); convert `vel` → `velocity` only
  around `move_and_slide()`.
- **Levels**: an ASCII map `godot/levels/<id>.txt` (legend in *Levels* of `godot/README.md`) plus its entry in
  `godot/levels/index.json` (play order; each level unlocks the next), both edited by hand. After editing a map run
  `convert_level.gd -- <id>` (never edit the `.tscn`) and `reach.gd -- <id>`. MeshLibrary item id = tile id − 1.
- **Projection**: an orthographic camera looking down −z, with depth faked by the oblique projection in
  `shaders/oblique.gdshaderinc`, which **every 3D material must call from `vertex()`**. Nothing in front of z = 0
  shifts, so sprites stay pixel-exact; geometry crossing z = 0 needs vertices there. Fog (`fog.gdshaderinc`), the
  foreground see-through dither (`reveal.gdshaderinc`) and the darkness of dark levels (`darkness.gdshaderinc`,
  global shader parameters `dark_amount` / `dark_lamp` set by `Main`) are shared includes too. New
  `.gdshaderinc` files need their `.uid` committed.
- **Time**: `Game` autoload (`scripts/game.gd`) owns game time and hitstop; level objects skip updates while
  `Game.frozen()`, and shader animation runs on `Game.time` so hitstop/pause freeze it.
- **View**: `ViewScale` autoload picks an integer scale; `scenes/main.tscn` renders into a ~480×270 `SubViewport`
  scaled up with nearest filtering. Everything is unshaded; "lighting" is `GlowLight` nodes (group `lights`) that
  `Main` passes to the terrain shader.
- Visuals (Clawd, enemies, tokens, decor) are voxel meshes built from text-grid sprites by `Voxel.mesh()`.
- **Checks**: `tools/check.gd` plays through every feature (sections per feature) and compares the noise ports,
  converted levels and player physics against reference values; every new feature gets a check there. Per-level
  sections are separate files, `tools/checks/<id>.gd` (template `2-1.gd`); theme motifs are found by file name
  (`Main.motif_shader_for()` / `motif_script_for()`). It starts `Main` in `PLAY` mode and points `Settings.path` /
  `Progress.path` at their own files, so it never touches the player's saves.
- **Main scene and modes**: `scenes/main.tscn` (`scripts/main.gd`, class `Main`) is the main scene. `Main.mode`
  is `TITLE`, `MAP`, `SHOP`, `TREE`, `ITEMS` (screens drawn over `BACKDROP` = 1-1, which the camera drifts through with the
  player parked) or `PLAY`. Title and world map → `scripts/front_end.gd`, shop → `scripts/shop_screen.gd` +
  `scripts/shop.gd`, prompt tree → `scripts/tree_screen.gd` + `scripts/prompts.gd`, results → `Overlay`,
  pause/controls/keybinds → `scripts/game_menu.gd`, inventory and stash → `scripts/inventory_screen.gd` (items:
  `items.gd`, `gear.gd`, `stats.gd`, `item_drop.gd`, `loot_view.gd`, `item_tooltip.gd`; character level: `experience.gd`).
- **Autoloads**: `Game` (time, hitstop, pause), `ViewScale`, `Settings` (key bindings, CRT, mute, crosshair colour →
  `user://settings.cfg`), `Sound` (synthesizes effects/music offline into AudioStreamWAVs; every
  `Sound.play("x")` needs `x` in `Sound.PRELOAD`, checked), `Progress` (cleared levels, sparks, sub-agents, wallet,
  shop state, weapons → `user://progress.json`).
- **UI** is pixel art drawn in the SubViewport's `Ui` CanvasLayer with `PixelFont` (`Hud`, `Overlay`, `FrontEnd`,
  `Shop`, `Menu`). The SubViewport is `Main.PAD` px larger than the screen on every side, so screen-space UI is
  offset by PAD. Screen-fixed 3D props hang on the camera; anything in front of z = 0 is drawn shifted down by z/3.
- **Spawns**: `Level.SPAWNS` in `scripts/level.gd` maps map characters to nodes (`B` is a marker where `Main`
  spawns the level's `boss`); numbered spawns (signs, sub-agents, sparks) get `index` in map order.

## Status and plans

Three worlds are done and playable from the title to the end of 3-B: world 1 (1-1, 1-2 darkness, 1-3 rising
void, 1-B the Hallucination, which drops the Token Blaster), world 2 (2-1 … 2-4, each with its motif, and 2-B the
boss Codex, which drops the Tool Call) and world 3, AGENT MODE (3-1 … 3-4 and the boss the Router, 3-B): the Tool
Call (`scripts/tool_call.gd`, anchors `+` / `*` in `anchor.gd`, the player's `zip` state), sub-agents
(`echo_control.gd`, `echo.gd`), plates and gates (`plate.gd`, `gate.gd`), brittle crates (`brittle.gd`), the
enemies parser, webhook and Retry Loop, and the prompt tree (`prompts.gd`, `tree_screen.gd`, `Main.Mode.TREE`; T on
the map; `godot/docs/prompt-tree-plan.md`).
Enemies extend `Enemy` (`scripts/enemy.gd`): bug, spam bot, shot, rate limiter, the three bosses, world 2's turret
(`T` / `Y`), drone, shield bot and injector, and world 3's. Worlds 2 and 3 are armed (`scripts/gun.gd`, `bullet.gd`,
`weapons.gd`, `beam_fx.gd`): aiming with the mouse (polled from the window: the SubViewport's container ignores the
mouse, so no mouse event reaches nodes inside it) or the keys, weapon switching, the HUD weapon panel and
crosshair, and the shop's ARMORY and GUN MODS once a weapon is found.

**`godot/docs/world3-plan.md` is world 3's plan** (design, decisions, milestones W0-W10, all done), and
**`godot/docs/prompt-tree-plan.md`** the changes after its playthrough (the prompt tree, sub-agents that shoot, a
longer 3-4). **`godot/docs/endgame-plan.md` is the next work**: a Path of Exile-like ARPG endgame (character
levels from XP, gear with affixes, a grid inventory and stash, currency orbs, a playable hideout with a Map
Device, procedural maps from chunks, elements and resistances, the Atlas, Delirium, Breaches, pinnacle bosses),
the user's decisions and milestones E0-E13; HP replaces hearts only in the hideout and maps, the campaign keeps
hearts. E1-E4 are done (character level, items and drops, the inventory and stash, the hideout: `levels/hideout.txt`
+ `hideout.json`, outside index.json's play order, opened from the map with O once 3-B is beaten).
`godot/docs/port-plan.md` is the finished plan of the port (history, and its *Added beyond the plan* lists the
extras made on top of the TS game).

Design decisions the user made (keep them): every jump is a full jump (no jump cut); every enemy drops 5× the TS
tokens (a bug 10; a heart per 300 tokens) and has 3× the TS hp (`Enemy.HP_FACTOR`, not bosses); sparks are a solid
glowing star; Clawd's shots stop on platforms too (`Bullet.blocked()`); spikes are a bed across the block depth;
hit enemies show damage numbers and, once hurt, a health bar (`Overlay`); the shop opens after clearing 1-1 and has
Spark Radar, Fortune Haiku, Firewall and Double Tokens besides the TS items; weapons/mods are a locked ARMORY row
until Clawd finds a weapon. Prices are tuned to the 5× income, and the shop's spark prices must add up to the
levels' sparks (checked; *Shop* in `godot/README.md` has the token income per level).

A new level: write `levels/<id>.txt` and its `index.json` entry, `convert_level.gd -- <id>`, `reach.gd -- <id>`, a
`tools/checks/<id>.gd` section, then check it looks right (capture screenshots of the real window).

A new entity: a script in `godot/scripts/`, a `Level.SPAWNS` entry and map character (add it to the legend in
`godot/README.md`), re-convert the levels using it, sounds through `Sound`, a `tools/check.gd` section, and a
`godot/README.md` paragraph plus a Layout row.

## godot-ai MCP

`.mcp.json` registers the `godot-ai` MCP server (needs `uvx`). Its editor plugin lives in `godot/addons/godot_ai/`
(third-party, don't modify). It only works with the GUI editor open, not `--headless`. Use the `mcp__godot-ai__*`
tools to inspect scenes, run the game and take screenshots. Add autoloads / change project settings through it
(`autoload_manage`, `project_manage`) rather than by editing `project.godot` while the editor is open; it refuses
while the game is running in the editor.
