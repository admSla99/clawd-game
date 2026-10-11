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
```

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
  foreground see-through dither (`reveal.gdshaderinc`) are shared shader includes too. New `.gdshaderinc` files need
  their `.uid` committed.
- **Time**: `Game` autoload (`scripts/game.gd`) owns game time and hitstop; level objects skip updates while
  `Game.frozen()`, and shader animation runs on `Game.time` so hitstop/pause freeze it.
- **View**: `ViewScale` autoload picks an integer scale; `scenes/main.tscn` renders into a ~480×270 `SubViewport`
  scaled up with nearest filtering. Everything is unshaded; "lighting" is `GlowLight` nodes (group `lights`) that
  `Main` passes to the terrain shader.
- Visuals (Clawd, bugs, tokens, decor) are voxel meshes built from text-grid sprites by `Voxel.mesh()`, ported from
  `src/render/sprites.ts` / `shapes.ts`.
- `tools/check.gd` compares the noise ports, converted levels and player physics against values from the TS
  sources; when porting more TS logic, add a check there.

## godot-ai MCP

`.mcp.json` registers the `godot-ai` MCP server (needs `uvx`). Its editor plugin lives in `godot/addons/godot_ai/`
(third-party, don't modify). It only works with the GUI editor open, not `--headless`. Use the `mcp__godot-ai__*`
tools to inspect scenes, run the game and take screenshots.
