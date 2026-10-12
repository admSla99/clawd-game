# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

CLAWD is a 2D platformer/shooter starring Clawd. There are two codebases:

- **`src/`**: the original browser game (TypeScript + Vite, Canvas 2D, no runtime deps besides a bundled font,
  all audio synthesized with WebAudio). It is deployed to GitHub Pages from `main` and stays the **source of truth**
  for gameplay, constants and level maps.
- **`godot/`**: a Godot 4.7.2 (GDScript) 2.5D port on the `godot-2.5d` branch (the 2D port is on the remote
  `godot-2d-port` branch). It reimplements `src/` code; scripts usually name the TS file/function they port.
  **`godot/README.md` is the detailed design doc for the port** (rendering pipeline, oblique projection, shaders,
  level pipeline, layout). Read the relevant section before changing the port, and update it in the same commit
  when behaviour changes, as every recent feature commit does.

## Commands

TypeScript game (repo root):

```bash
npm run dev                                  # http://localhost:5173
npm test                                     # vitest: unit tests + reachability of every level
npx vitest run tests/player.test.ts          # one test file
npx vitest run -t "coyote time"              # tests whose name matches
npm run typecheck                            # tsc --noEmit (strict, noUnusedLocals/Parameters)
npm run build                                # typecheck + vite build into dist/
```

CI (`.github/workflows/pages.yml`) runs `npm ci && npm test && npm run build` on every push to `main`.

Dev-only URL params (see `src/main.ts`): `?level=4` (index 0–8), `&tx=120&ty=16` (warp to tile), `?map`, `?shop`,
`?rich`, `?ff=300&hold=KeyD,KeyX` (simulate N ticks with keys held, for headless screenshots), `?touch`.
`window.clawd` exposes the `App` in dev.

Godot port (run from `godot/`; `godot` is not on PATH on this Windows machine, so call the editor executable
directly; `tools/install_godot.sh` is Linux-only):

```bash
godot --headless --script tools/check.gd                       # headless checks, exits non-zero on failure
node tools/export_levels.mjs                                   # run from REPO ROOT: src levels -> godot/levels/*.txt + index.json
godot --headless --script tools/convert_level.gd -- 1-1        # levels/*.txt -> levels/*.tscn (no ids = all)
godot --headless --script tools/build_meshlib.gd               # regenerate tiles/terrain_meshlib.tres
godot --headless --export-release "Web" build/web/index.html   # web build (no threads, any static host)
godot --headless --path . --import                             # after adding a class_name, before running scripts
```

On this machine the editor executable is
`C:/Program Files (x86)/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe`; wrap `--script` runs
in `timeout` (a script that fails to parse never quits). The port targets desktop; the web build is not a focus.

## TypeScript architecture

- `App` (`src/app.ts`) owns the renderer, input, audio and save, and swaps `Scene`s (title, level select, game,
  shop, results). The loop is a fixed timestep (`STEP = 1/60` in `src/config.ts`) with `render(alpha)` interpolation.
- `src/config.ts` holds all movement/feel constants; `src/weapons.ts` holds weapon and upgrade stats/prices.
- `GameScene` (`src/scenes/game.ts`, the largest file) is the `GameContext` that entities call back into
  (`spawn`, `hurtPlayer`, `hitstop`, `shake`, `explode`, `collectToken`, ...). Entities live in `src/entities/`;
  bosses in `src/entities/boss/`.
- Levels are ASCII maps in `src/world/levels/*.ts` (each file starts with a legend); `LEVELS` in
  `src/world/levels/index.ts` is the play order and each level unlocks the next. `parseLevel()` in
  `src/world/level.ts` turns the map into tiles (`TILE_CHARS` in `src/world/tiles.ts`) and spawns (`SPAWN_CHARS`).
  Tiles are 16 px; positions are pixels with y down.
- `tests/reachability.test.ts` plays every level with the real `Player` physics (via `Sim`/`FakeInput` in
  `tests/helpers.ts`) and checks the exit, every spark and every sub-agent are reachable. Run `npm test` after
  editing any map. `tests/player.test.ts` holds the level-design rules (jump height, gap/step limits).

## Godot port: things that span files

- **Units**: game logic keeps the TS units (pixels, y down, 16 px per tile) so constants match `src/config.ts`.
  `Px` (`scripts/px.gd`) converts to metres (1 tile = 1 m, y up, level top-left at origin, gameplay plane z = 0);
  convert `vel` → `velocity` only around `move_and_slide()`.
- **Levels are generated, not hand-edited**: edit the map in `src/world/levels/*.ts`, then run
  `export_levels.mjs` and `convert_level.gd`. Don't edit `godot/levels/*.txt` / `*.tscn` by hand.
  MeshLibrary item id = TS tile id − 1.
- **Projection**: an orthographic camera looking down −z, with depth faked by the oblique projection in
  `shaders/oblique.gdshaderinc`, which **every 3D material must call from `vertex()`**. Nothing in front of z = 0
  shifts, so sprites stay pixel-exact; geometry crossing z = 0 needs vertices there. Fog (`fog.gdshaderinc`) and the
  foreground see-through dither (`reveal.gdshaderinc`) are shared shader includes too, and so is the darkness of
  dark levels (`darkness.gdshaderinc`, global shader parameters `dark_amount` / `dark_lamp` set by `Main`). New `.gdshaderinc` files need
  their `.uid` committed.
- **Time**: `Game` autoload (`scripts/game.gd`) owns game time and hitstop; level objects skip updates while
  `Game.frozen()`, and shader animation runs on `Game.time` so hitstop/pause freeze it.
- **View**: `ViewScale` autoload picks an integer scale; `scenes/main.tscn` renders into a ~480×270 `SubViewport`
  scaled up with nearest filtering. Everything is unshaded; "lighting" is `GlowLight` nodes (group `lights`) that
  `Main` passes to the terrain shader.
- Visuals (Clawd, bugs, tokens, decor) are voxel meshes built from text-grid sprites by `Voxel.mesh()`, ported from
  `src/render/sprites.ts` / `shapes.ts`.
- `tools/check.gd` compares the noise ports, converted levels and player physics against values from the TS
  sources, and plays through every ported feature in 1-1 (sections per feature); when porting more TS logic, add
  a check there. It starts `Main` in `PLAY` mode and points `Settings.path` / `Progress.path` at their own files,
  so it never touches the player's saves.
- **Main scene and modes**: `scenes/main.tscn` (`scripts/main.gd`, class `Main`) is the main scene. `Main.mode`
  is `TITLE`, `MAP`, `SHOP` (screens drawn over `BACKDROP` = 1-1, which the camera drifts through with the player
  parked) or `PLAY`. Ported TS scenes map to: `title.ts`/`levelSelect.ts` → `scripts/front_end.gd`, `shop.ts` →
  `scripts/shop_screen.gd` + `scripts/shop.gd`, results → `Overlay`, pause/controls/keybinds → `scripts/game_menu.gd`.
- **Autoloads**: `Game` (time, hitstop, pause), `ViewScale`, `Settings` (key bindings, CRT, mute →
  `user://settings.cfg`), `Sound` (synthesizes `src/core/audio.ts` effects/music offline into AudioStreamWAVs; every
  `Sound.play("x")` needs `x` in `Sound.PRELOAD`, checked), `Progress` (the level part of `src/save.ts` plus shop
  state → `user://progress.json`).
- **UI** is pixel art drawn in the SubViewport's `Ui` CanvasLayer with `PixelFont` (`Hud`, `Overlay`, `FrontEnd`,
  `Shop`, `Menu`). The SubViewport is `Main.PAD` px larger than the screen on every side, so screen-space UI is
  offset by PAD. Screen-fixed 3D props hang on the camera; anything in front of z = 0 is drawn shifted down by z/3.
- **Spawns**: `Level.SPAWNS` in `scripts/level.gd` maps map characters to nodes (`@ E o C G ? M V A S F R T Y D H I B`, every TS spawn; `B` is a marker where `Main` spawns the level's `boss`);
  numbered spawns (signs, sub-agents, sparks) get `index` in map order like `Spawn.index` in TS.

## Godot port status (branch `godot-2.5d`)

**`godot/docs/port-plan.md` is the task list for the remaining levels, shooting and weapons**, with the user's
decisions from the planning interview. Work through it in order and tick tasks off in the commits that finish them.

All levels are converted with every spawn ported so far; world 1 (1-1, 1-2 darkness, 1-3 rising void, 1-B the
Hallucination, which drops the Token Blaster) and 2-1 (mesa motif) are playable; **1-1** is fully playable (title → map → level →
results → map, shop). Enemies extend `Enemy` (`scripts/enemy.gd`, from `src/entities/entity.ts`): bug, spam bot,
shot, rate limiter, Hallucination, and world 2's turret (`T` / `Y`), drone, shield bot and injector (M6; world 2's
bugs and spam bots are tougher). Shooting is ported (M5): world 2 is armed (`scripts/gun.gd`, `bullet.gd`,
`weapons.gd`, `beam_fx.gd`), aiming with the mouse (polled from the window: the SubViewport's container ignores
the mouse, so no mouse event reaches nodes inside it) or the keys, weapon switching, the HUD weapon panel and
crosshair, and the shop's ARMORY and GUN MODS once a weapon is found. No gamepad support (the user's call).
Port-only design decisions the user asked for (keep them): every jump is a full jump (no jump cut, sign texts in
`godot/levels/overrides.json`); every enemy drops 5× its TS tokens (a bug 10) and has 3× its TS hp (`Enemy.HP_FACTOR`, not bosses); sparks are a solid glowing star; spikes are a bed across
the block depth; hit enemies show damage numbers and, once hurt, a health bar (`Overlay`); the shop opens after
clearing 1-1 and adds Spark Radar, Fortune Haiku, Firewall and Double
Tokens; world-2 weapons/mods are a locked ARMORY row until Clawd finds a weapon.

Not ported yet (the next goal is world 2):
- The boss Codex (`src/entities/boss/codex.ts`, 2-B); the motifs and checks of 2-2 … 2-B (M8–M11).

To port a level: `node godot/tools/export_levels.mjs` (repo root; `git checkout` the `.txt` files whose only
change is line endings), `godot --headless --script tools/convert_level.gd -- <id>`, then check it plays
(`tools/check.gd` section) and looks right (capture screenshots of the real window).

To port an entity: a script in `godot/scripts/` that names the TS class it ports, a `Level.SPAWNS` entry, re-convert
the levels using it, sounds through `Sound`, a `tools/check.gd` section, and a `godot/README.md` paragraph plus a
Layout row.

## godot-ai MCP

`.mcp.json` registers the `godot-ai` MCP server (needs `uvx`). Its editor plugin lives in `godot/addons/godot_ai/`
(third-party, don't modify). It only works with the GUI editor open, not `--headless`. Use the `mcp__godot-ai__*`
tools to inspect scenes, run the game and take screenshots. Add autoloads / change project settings through it
(`autoload_manage`, `project_manage`) rather than by editing `project.godot` while the editor is open; it refuses
while the game is running in the editor.
