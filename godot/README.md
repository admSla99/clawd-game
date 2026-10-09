# CLAWD — Godot 2.5D vertical slice

Godot 4.7.2 port of the game in `../src`, rebuilt in 3D with a side camera (2.5D). The 2D port is on the
`godot-2d-port` branch. GDScript; Forward+ renderer on desktop, Compatibility (WebGL 2) on the web export.

## Setup on a new machine (Linux x86_64)

```bash
cd godot
./tools/install_godot.sh                                # editor + web export templates (resumes if cut off)
godot --headless --script tools/build_meshlib.gd        # regenerates tiles/terrain_meshlib.tres
node tools/export_levels.mjs                            # run from repo root: src levels -> levels/*.txt
godot --headless --script tools/convert_level.gd        # levels/*.txt -> levels/*.tscn
godot --headless --import                               # first import, creates .godot/
godot --editor --path .
```

`install_godot.sh` downloads from the official GitHub release and checks the files against its
`SHA512-SUMS.txt`. It installs:

| What | Where |
|---|---|
| Editor binary | `~/.local/opt/godot/4.7.2-stable/godot`, linked as `~/.local/bin/godot` |
| Web export templates | `~/.local/share/godot/export_templates/4.7.2.stable/` |

The templates archive is ~1.3 GB (all platforms); the script keeps only the `web_*` templates.
Re-running the script skips anything already installed. To change version, edit `VERSION` in the script
and `config/features` in `project.godot`.

On macOS or Windows, download the editor and `export_templates.tpz` for 4.7.2 from
<https://godotengine.org/download/archive/4.7.2-stable/> and install the templates via
*Editor → Manage Export Templates → Install from File*.

The game uses only built-in Godot features (GridMap, GDScript). The `addons/godot_ai` editor plugin
([godot-ai](https://github.com/hi-godot/godot-ai) 4.3.0) lets Claude Code drive the editor and the running game
over MCP; `../.mcp.json` registers its server for this project. It needs `uv` (`uvx`) and a GUI editor, as it does
not start in `--headless` mode. Its `_mcp_game_helper` autoload also runs in exported builds.

## Levels

Levels stay authored in `../src/world/levels/*.ts`. After changing one, regenerate:

```bash
node godot/tools/export_levels.mjs                      # from the repo root
cd godot && godot --headless --script tools/convert_level.gd -- 1-1   # ids optional; none = all
```

`export_levels.mjs` writes each level's `map` rows to `levels/<id>.txt` and the id/name list to
`levels/index.json`. `convert_level.gd` runs `Level.build()` (`scripts/level.gd`): it places the tile characters
(`#` `=` `^` `X`, same as `TILE_CHARS` in `src/world/tiles.ts`) as GridMap cells and adds a child per spawn:
`@` → `Start` marker, `E` → `scenes/bug.tscn`, `o` → `scenes/token.tscn`. Other spawn characters are skipped.
The result is saved as `levels/<id>.tscn`.

One tile is 1 m; tile `(x, y)` of the map fills `x..x+1` × `-(y+1)..-y`, so the level's top-left corner is the
origin and y points up. Blocks are 3 m deep, centred on the gameplay plane z = 0. One-way platforms (`=`) sit in
their own `OneWay` GridMap on physics layer `oneway`; the player collides with that layer only while falling with
its body clear of the platform.

## Running

The game starts in `scenes/level_select.tscn`: one button per entry in `levels/index.json`. A button sets
`Main.start_level` and switches to `scenes/main.tscn`, which loads that level and puts the player on its
`Start` marker. **N** loads the next level (wrapping after 2-B).

Gameplay ported so far: run, variable jump, coyote time, jump buffer and hover from
`src/entities/player.ts`; spikes knock Clawd back and cost a heart; bugs patrol, turn at walls and ledges,
hurt on contact and die when stomped; tokens are collected on touch. Falling out of the level or losing
the last heart respawns on `@` with full hearts.

Game logic keeps the TS units: positions and speeds in pixels with y down (`pos`, `vel` on the player and bugs,
16 px per tile), so the constants are the ones from `src/config.ts`. `scripts/px.gd` (`Px`) converts between
level pixels and metres; the player and bugs convert `vel` to `velocity` only around `move_and_slide()`.

## Checks

```bash
godot --headless --script tools/check.gd     # exits non-zero on failure
```

Compares the noise functions with values computed from `src/core/noise.ts`, every converted level's GridMap
cells and spawns with its `.txt` map, the player's jump height and gap/step limits with the level-design rules in
`tests/player.test.ts`, the level select and level switching, and spikes, bugs, stomps and tokens in 1-1.

## Game clock and camera

- `Game` (autoload, `scripts/game.gd`): game time and hitstop. Level objects skip their update while
  `Game.frozen()`, so hitstop and pause stop the world like in `src/scenes/game.ts`.
- `scripts/game_camera.gd`: port of `src/core/camera.ts` (look-ahead, vertical deadzone, small levels
  centred, trauma shake) on a `Camera3D`. It works in level pixels on the gameplay plane, shows 270 px of it in
  height (`BASE_VIEW_H`) and looks at the view centre pitched down 14°.
- `scripts/noise.gd` (`DotNoise`): bit-exact ports of `hash2`, `valueNoise2`, `periodicNoise1`, `mulberry32`.
- `scripts/particles.gd`: port of `src/render/particles.ts` drawn as cubes in a MultiMesh; emit with the same
  options as `particles.emit`.

## Voxel models

`scripts/voxel.gd` (`Voxel.mesh()`) turns the text-grid sprites into voxel meshes: every palette character is a
cube 2 px wide, extruded to a per-character depth around z = 0, with vertex colors and no faces between two cubes.
The sprites stay where the 2D port had them: Clawd's frames from `Player.FRAMES` (`clawd_frame()` in
`scripts/player.gd`, depth `DEPTH`), the bug's from `FRAMES` in `scripts/bug.gd`, and the token from `ROWS` in
`scripts/token.gd`. Meshes are built once per frame; animating swaps `MeshInstance3D.mesh`. Squash & stretch
scales the player's `Visual` node, not the collision shape, with the factors from `src/entities/player.ts`.

## Look and feedback

`scenes/main.tscn` has a `DirectionalLight3D` with shadows and a `WorldEnvironment` with SSAO, glow (HDR
threshold 0.9; spikes, tokens and the hover jet are emissive), light fog and far depth-of-field blur. Clawd has a
blob shadow (`Decal`). Block faces carry a faint 1 m grid so single tiles stay readable.

The player emits `event(kind, at)` for `jump`, `land`, `hard_land`, `hurt` and `stomp`; `main.gd` answers
with particles (same counts and colors as `particles.emit` in `src/scenes/game.ts`), camera shake and
hitstop.

V-Sync is set to Mailbox (`display/window/vsync/vsync_mode=3`): plain V-Sync dropped to 1 fps on Wayland with
Intel graphics.

## Web build

```bash
godot --headless --export-release "Web" build/web/index.html
python3 -m http.server -d build/web 8080                # http://localhost:8080
```

The "Web" preset in `export_presets.cfg` builds without threads, so the output runs on any static host
without COOP/COEP headers.

## Layout

| Path | Contents |
|---|---|
| `project.godot` | 1440×810 window, 60 Hz physics, input actions named as in `src/core/input.ts`, 3D physics layers `world`, `player`, `enemies`, `oneway` |
| `scenes/level_select.tscn`, `scripts/level_select.gd` | Start scene, level buttons |
| `scenes/main.tscn`, `scripts/main.gd` | Game scene: `Level` (current level), `Camera3D`, light, environment, particles, player. `load_level(id)`, `next_level()` |
| `scenes/player.tscn`, `scripts/player.gd` | Clawd: movement, spikes, enemy contact and stomps, voxel frames, hover jets, blob shadow |
| `scenes/bug.tscn`, `scripts/bug.gd` | Patrolling bug (group `enemies`) |
| `scenes/token.tscn`, `scripts/token.gd` | Collectible token |
| `scripts/level.gd` | `Level`: builds a level from map rows, tile lookup by pixel, level size |
| `scripts/px.gd`, `scripts/voxel.gd` | Pixel ↔ metre conversion; voxel meshes from text-grid sprites |
| `scripts/fx.gd` | `Fx.burst()` emits into the level's particles |
| `tools/check.gd` | Headless checks, see *Checks* |
| `levels/<id>.txt`, `levels/index.json`, `levels/<id>.tscn` | Level maps exported from `src`, and the 3D level scenes converted from them |
| `tiles/terrain_meshlib.tres` | MeshLibrary of the level GridMaps. Item id = tile id from `src/world/tiles.ts` minus one: `#` solid (0), `=` one-way (1), `^` spike (2), `X` corrupted (3). Spikes have no collision shape; the player detects them by item like the TS version |
| `tools/build_meshlib.gd` | Generates `tiles/terrain_meshlib.tres` |
| `tools/export_levels.mjs`, `tools/convert_level.gd` | Level pipeline, see *Levels* |
| `addons/godot_ai/` | godot-ai editor plugin (MCP) |
