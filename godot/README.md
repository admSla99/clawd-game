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
`@` → `Start` marker, `E` → `scenes/bug.tscn`, `o` → `scenes/token.tscn`, `C` → `Checkpoint`, `G` → `Goal`,
`?` → `Sign` (numbered in map order like `Spawn.index`), `M` / `V` → `MovingPlatform`. Other spawn characters
are skipped. Only 1-1 has been
re-converted since checkpoints, the exit, signs and moving platforms were added.

`export_levels.mjs` merges `levels/overrides.json` (fields per level id) into `index.json`, for metadata where
the port differs from the TS game: 1-1's sign texts, since the port has no variable jump height.
The result is saved as `levels/<id>.tscn`.

One tile is 1 m; tile `(x, y)` of the map fills `x..x+1` × `-(y+1)..-y`, so the level's top-left corner is the
origin and y points up. Blocks are 3 m deep, centred on the gameplay plane z = 0. One-way platforms (`=`) sit in
their own `OneWay` GridMap on physics layer `oneway`; the player collides with that layer only while falling with
its body clear of the platform.

## Running

The game starts in `scenes/level_select.tscn`: one button per entry in `levels/index.json`. A button sets
`Main.start_level` and switches to `scenes/main.tscn`, which loads that level and puts the player on its
`Start` marker. **N** loads the next level (wrapping after 2-B).

Gameplay ported so far: run, jump, coyote time, jump buffer, hover, corner correction, spin,
ground pound and drop-through from `src/entities/player.ts`. Unlike the TS player every jump is a full jump
(about 4.4 tiles): letting go of jump early does not cut it (`JUMP_CUT_MULT` is gone); spikes knock Clawd back and cost a heart; bugs
patrol, turn at walls and ledges, hurt on contact and die when stomped, spun, pounded or hit by the hover jet;
tokens are collected on touch. A defeated bug drops `Bug.TOKENS` = 10 tokens (2 in TS): `Token.pop()` makes
popped tokens that burst out of its middle with a random sideways speed, fall under gravity, and over 0.6 s turn
into a 260 px/s flight to Clawd (`Token._home()`, after `Token.update()` for a free token); they can be picked
up only after 0.3 s, so the burst is seen even when Clawd stomps from right above. The level's token total
(results panel) counts the map's tokens plus 10 per bug. Like `Level.tile()` in TS, the columns left and right of
the map are solid: `Level` adds two invisible walls (`SideWalls`, physics layer 1) at its edges, so Clawd and
the bugs stop there instead of walking off the start, and `Level.tile()` returns solid outside the map.

Checkpoints (`scripts/checkpoint.gd`, `C` in the map): a voxel terminal on a ribbed post, standing 0.6 m
behind the gameplay plane so Clawd walks in front of it. Its 18 x 12 px screen has dark glass 1 px back in the
bezel; off it shows a blinking grey cursor. Touching it (16 x 28 px box against Clawd's hitbox, like the TS
`Checkpoint`) calls `Main.activate_checkpoint()`: Clawd respawns there from now on (falling out, losing the
last heart), the hearts refill, an orange burst and a rising "STATE SAVED" popup play, the bezel turns
orange, the screen shows a glowing "OK" for 1.2 s and then ">_", and a GlowLight warms the ground around it.

The exit (`scripts/goal.gd`, `G`): the 2D gate's ring of 40 light dots on a 12 x 18 px ellipse, turning,
with waves of light orange running round, built every frame as 2 x 2 px voxels 6 px deep; inside a dithered
swirl on whole pixels (`shaders/portal.gdshader`, a quad on the gameplay plane), under it a dark pad with
orange LEDs, a pulsing GlowLight, sparks drifting up and "EXIT" above (Overlay world text). Clawd walks into
it, since it stands on the gameplay plane. Touching its inner 16 x 40 px calls `Main.reach_goal()`: a burst,
Clawd stops (`Player.frozen`) and cheers, drifts to the middle, after 0.6 s stretches into a thin beam and
vanishes; after 2 s the results panel (tokens collected / in the level, time) fades in over the level, and jump
goes to the next level.

Moving platforms (`scripts/moving_platform.gd`, `M` horizontal, `V` vertical): `MovingPlatform` from
`src/entities/platforms.ts`, 48 x 6 px, swinging 3.5 tiles either way with a 4 s period; each platform in map
order starts 1.3 s further in its swing. They update before the player (`process_physics_priority = -10`). The
player handles them like the TS player: after moving, a falling Clawd whose feet were above a platform's
previous top lands on it (`riding`); at the start of the next frame he is carried by its `dx` and kept on its top;
jumping, getting hurt, bouncing or down + jump (drop-through) leave it. `Player.on_ground` (tile floor or a
platform) replaces `is_on_floor()` for the camera and the poses. They are drawn like the level's one-way ledges:
a white crust with orange LEDs at the ends and along the grey edge, a dark body tapering underneath, two small
flickering orange jets and a GlowLight, snapped to whole pixels.

Signs (`scripts/sign.gd`, `?`): a 14 x 10 px board with a grey rim, a dark face 1 px back and a glowing orange
"?" (from `PixelFont`) on a ribbed post, 0.6 m behind the gameplay plane, with a small GlowLight. `Main` gives
each its text, `signs[index]` of the level in `levels/index.json`. While Clawd is within 52 px sideways and
48 px up or down (like the 2D sign), `show` eases to 1 and the Overlay draws the text in a bubble above the
board that fades in and slides up 6 px, with a small tail pointing at it.

Moves (keys as in `src/core/input.ts`): **X / J** (attack) or **C / L** (spin) spins: 0.32 s attack around
Clawd, with a hop once per jump in the air. **S / ↓** in the air starts a ground pound (a short windup, then a
fall at 620 px/s); landing shakes the camera, defeats bugs within 30 px, and breaks the whole 4-connected
cluster of corrupted blocks (`X`) under Clawd, who then keeps falling (`Main._on_pound_land()`,
`Level.break_corrupt()`). Breaking re-bakes only the cell texels within `MAX_DIST` of the broken tiles (a few ms;
the full bake of 1-1 takes ~200 ms). **S + jump** on a one-way platform drops through it (the `oneway` mask is
off for 0.18 s). Holding jump while hovering, the jet below Clawd hurts bugs. Spin and the pound windup turn
the voxel body about its vertical axis (the 2D sprite's `turn` flip), and the spin ring is 10 glowing cubes on
a real horizontal circle of 17 px around Clawd, which the oblique projection draws as the 2D game's 17 x 6 px
ellipse, front half over Clawd. Falling out of the level or losing
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
`tests/player.test.ts`, the level select and level switching, spikes, bugs, stomps and tokens in 1-1 (the 10
tokens a bug drops fly to Clawd; the map's left edge stops him), spin,
air spin hop, ground pound through 1-1's corrupted blocks and drop-through, 1-1's checkpoints (activation,
respawn), signs (texts, bubble near Clawd, glyphs for every sign text) and exit (completion, results, next
level), and that a running jump clears
crossing the 26-tile gap of 1-1 on its two moving platforms (a
small controller jumps when the next platform comes close), that a tapped jump is a full jump, and the HUD
(tokens fly to the counter and are counted when they land, hearts break and refill, +1 heart per 100 tokens up
to 5), and the menus (pause freezes the world, every pause item, the HUD buttons, rebinding with conflicts,
clearing, reset, saving to a separate settings file, glyphs for every key name), and the sound (every effect
renders, is audible and does not clip, the pitches of token / jump / checkpoint, track loop lengths, and that
the game's events play their sounds, the jet hisses while hovering, M mutes, the exit and results switch the
music).

## Game clock and camera

- `Game` (autoload, `scripts/game.gd`): game time and hitstop. Level objects skip their update while
  `Game.frozen()`, so hitstop and pause stop the world like in `src/scenes/game.ts`.
- `Settings` (autoload, `scripts/settings.gd`): key bindings, the CRT filter and mute, saved in `user://`
  (see Menus and key bindings).
- `Sound` (autoload, `scripts/sound.gd`): synthesized effects and music (see Sound and music).
- `ViewScale` (autoload, `scripts/view_scale.gd`): view size from the window like `Renderer.resize()` in
  `src/render/renderer.ts` (integer scale, view about 270 tall and at least ~420 wide), same as the 2D port.
- `scripts/game_camera.gd`: port of `src/core/camera.ts` (look-ahead, vertical deadzone, small levels
  centred, trauma shake) on an orthographic `Camera3D` that looks straight down -z. It works in level pixels on
  the gameplay plane; one level pixel is exactly one view pixel on both axes. Depth comes from the oblique
  projection in `shaders/oblique.gdshaderinc`, which every 3D material calls from `vertex()`: a point moves up
  by a third of its distance behind the gameplay plane, as if the camera were pitched down atan(1/3) (~18.4°).
  One view row covers 3 px of depth (`ROW_Z`), so the 3 m deep blocks show a 16 px top band. On top of that
  the projection adds a little perspective: points behind the gameplay plane move towards the view centre by
  3% of their distance from it per metre of depth, so blocks and background towers off the centre show their
  sides (up to ~11 px at the view's edges) and top bands are thicker near the bottom of the view. Nothing in
  front of the gameplay plane moves, so Clawd, the enemies and the block fronts stay pixel-exact; faces that
  cross z = 0 get vertices there (`BoxMesh.subdivide_depth`, `Voxel.mesh()`). Scenery boxes converge from their
  own front faces. The terrain shader draws the exposed side faces (crust over the top edge, a lit front rim,
  strata darkening towards the back, a share of the theme's light colour, `ambient`). A pitched
  orthographic camera would shorten one axis by cos(pitch) and make sprites shimmer by a pixel while moving.
  The SubViewport renders `Main.PAD` extra pixels on every side, so nothing the oblique shift moves into view
  is frustum-culled at the edges.
- `scripts/noise.gd` (`DotNoise`): bit-exact ports of `hash2`, `valueNoise2`, `periodicNoise1`, `mulberry32`.
- `scripts/particles.gd`: port of `src/render/particles.ts` drawn as 1 px cubes in a MultiMesh; emit with the same
  options as `particles.emit`. Particles start half a tile in front of the gameplay plane, so they show over
  Clawd and the bugs like the 2D overlay, and drift in depth.
- `scripts/parallax.gd` (`Parallax`): the theme backgrounds of `src/render/parallax.ts`, unchanged from the 2D port
  (dot ridges, factory columns, twinkling stars, data rain, code lines, rings, embers, fog bands). It lives in a
  CanvasLayer behind the 3D level, over the haze; the Environment's background mode is *canvas*.

## Text

Text is pixel art too: `scripts/pixel_font.gd` (`PixelFont`) is a bitmap font with 5 px capitals and digits,
lowercase with a 4 px x-height and 2 px descenders, arrows and the punctuation the signs use, drawn from one
atlas with nearest filtering on whole view pixels, 8 px per line like the 2D game's 5.5 px text.
`PixelFont.rows()` returns the same glyphs as text-grid rows for `Voxel.mesh()` (the checkpoint screen).
`scripts/overlay.gd` (`Overlay`, `View/SubViewport/World/Ui`, a CanvasLayer above the colour grade) draws text
over the 3D view in SubViewport pixels: rising popups (`Overlay.popup()`), the text of nodes in the group
`world_text` (they implement `overlay_draw(overlay)`) and panels like `panel()` in `src/render/shapes.ts`.
`Overlay.to_view()` maps a level position (and depth) through the camera and the oblique projection.

## HUD

`scripts/hud.gd` (`Hud`, in the same `Ui` CanvasLayer, under the Overlay) is `drawHud()` from
`src/render/hud.ts` for hearts and tokens, drawn as sprites from text grids at view resolution. Top left is one
dark panel with the 2D panel's open corners, a 1 px shadow under it, a faint highlight inside its top edge and a
short orange tab on top; in it 9 x 8 px hearts lit from the top left (lost ones are dark sockets), a dotted
divider, an 8 px token in `TokenSprite`'s palette that turns once every 3 s, and the count in 4 x 7 px digits
with a 1 px shadow and dim leading zeros (`007`). Top right are a CONTROLS button, a pause button (two bars), a
mute button (`drawSpeaker()`) and the level's label (`1-1 · token plains`, the id in light orange); the buttons light up under the mouse and
stay orange while their menu is open, and the speaker shows a red cross while muted. Everything sits 6 px
inside the part of the SubViewport on screen (it is `Main.PAD` bigger on every side). It animates on real time,
so through hitstop:

- a lost heart flashes white and breaks into falling shards, while the panel shakes and its border turns red;
  on the last heart (Player emits `die`) it breaks first and the hearts come back one by one 0.55 s later;
- refilled hearts pop up 1 px with a fading white outline; the last heart left beats;
- a collected token (`Main.collect_token()`) flies from where it was along an arc to the counter coin, tokens
  picked up together 0.04 s apart, and the count shown (`Hud.shown`) ticks up when each lands: the coin
  glints and the digits jump 1 px in light orange;
- it fades out under the level-complete panel.

Like `collectToken()` in TS, every 100th token gives a heart, up to 5 (the HUD grows a slot, "+1 HEART"
pops up), and a checkpoint refills to 3 without taking those away.

## Sound and music

`scripts/sound.gd` (autoload `Sound`) is `src/core/audio.ts`. Like the TS game it ships no audio files: it
synthesizes the same sounds, but offline into `AudioStreamWAV`s (16-bit mono, 44.1 kHz) instead of live
WebAudio nodes:

- `tone()`: an oscillator (sine, triangle, and square / sawtooth band-limited with PolyBLEP, like WebAudio's
  wavetables) with the exponential frequency ramp and the TS envelope (0.0001 -> vol in 8 ms -> 0.0001).
- `noise()`: white noise through WebAudio's bandpass biquad (RBJ, constant 0 dB peak gain) with an exponential
  centre sweep and fade.
- Effects: `play()`'s recipes; the ones the port uses (`PRELOAD`) render in a thread at start-up (~80 ms).
- Music: `scheduleStep()` (bass, arpeggio, lead on every other 4 bars, kick / snare / hats) rendered as one
  seamless loop of the whole pattern (128 sixteenths with a lead, 64 without; notes that ring past the end wrap
  to the start), in a thread the first time a track plays (~0.35 s for plains). Each level plays its `music`
  from `levels/index.json`; the level select and the results panel play `map`; the exit stops the music.
- The hover jet: the looping bandpassed noise with `hoverUpdate()`'s 40 rad/s wobble baked into 6 periods,
  faded in and out while `Player.hovering` (stopped while paused).

The TS bus gains are baked into the samples (effects 0.55, music 0.22); the Master bus is at 0.8 and is muted by
the `mute` key (M) or the HUD's speaker button (saved in `Settings`). Sounds follow the TS call sites: player
events (jump, land, spin, pound, pound landing, break, hurt, die / fell, stomp + enemyDie, defeat), tokens,
+1 heart, checkpoints, the exit (complete), and the menus (select, confirm, denied).

## Menus and key bindings

`scripts/game_menu.gd` (`GameMenu`, `Ui/Menu`, drawn over everything) holds the in-level menus of
`src/scenes/game.ts` and `src/scenes/keybinds.ts`, in the HUD's panel look (orange tab, titles at twice the
size, the selected row as a faint orange bar with a bright left edge and a `>` prompt):

- **Controls help** (`controls` key, H; or the HUD's CONTROLS button): what every key does, built from the
  current bindings like `controlLines()`; Enter (or its button) opens the keybindings.
- **Pause** (`pause` key, P, or Escape; or the HUD's pause button): RESUME, RESTART FROM CHECKPOINT, RESTART
  LEVEL, CRT FILTER: ON/OFF, KEYBINDINGS, QUIT TO MAP (`scenes/level_select.tscn`).
- **Keybindings**: every bindable action with 3 key slots drawn as keycaps. Enter (or a click) on a slot
  listens for the next key: Escape cancels, Backspace clears the slot (the last key of an action stays), a
  key that belongs to another action is refused with "X ALREADY BOUND TO ..." (W may be both jump and up, as
  in the default layout). RESET DEFAULTS, BACK.

`Main._input()` hands every event to `GameMenu.handle()` first, with mouse positions moved into SubViewport
pixels; the mouse hovers and clicks rows, slots and the HUD buttons. Menus navigate with the bound up/down/
left/right keys and always with the arrows. While a menu is open `Game.paused` stops the world; closing it
resumes two physics frames later, so the Space that picked RESUME is not also a jump.

`scripts/settings.gd` (autoload `Settings`) keeps the bindings (physical keycodes, so they follow key
positions, not the keyboard layout) and the CRT filter in `user://settings.cfg`, and writes the bindings into
the InputMap actions of the same names (`left right up down jump attack spin pause mute controls`; the TS
menu also has weapon and shop keys, which the port does not have yet). Fixed keys like `FIXED_KEYS` in TS:
Escape pauses and goes back, Enter / Space confirm, Backspace goes back. `Settings.key_label()` is `keyLabel()`
(arrows, letters and symbols as themselves, short names like SHIFT or BKSP).

## Voxel models

`scripts/voxel.gd` (`Voxel.mesh()`) turns text-grid sprites into voxel meshes: every palette character is a
column `size` wide (2 px by default), extruded to a per-character depth around z = 0; side faces cover only the
depth a neighbouring column does not. The material (`shaders/voxel.gdshader`) is unshaded and the vertex colours
are stored linear: the front face keeps the palette colour exactly and the other faces are darker or lighter by
a fixed factor (`SHADE`), or take a given `top` colour. The lanterns and tufts are in `scripts/decor.gd`.

The bug and the token are drawn at 1 px like Clawd. `scripts/bug_sprite.gd` (`BugSprite`) is the glitch beetle
of `BUG` in `src/render/sprites.ts`: a round shell with a thinner rim, a lit spot, the dark spot that hops between
the two walk frames and red eyes with a glint; one 2 px row shifts sideways when the 2D draw() would glitch it
(re-rolled 10 times a second). `scripts/token_sprite.gd` (`TokenSprite`) is the light orange coin of `drawToken()`
in `src/render/shapes.ts` with a rim, a lit side and a glint; it spins as whole-pixel widths (6, 4, 2 px) and
bobs in whole pixels. Both snap to the pixel grid. When a bug is stomped or a token collected, the node is freed
at once and `scripts/sprite_fx.gd` (`SpriteFx`) plays what is left: the flattened shell (a white flash, then
grey; hitstop holds it) or a sparkle with a fading light.

Clawd is drawn by `scripts/clawd_sprite.gd` (`ClawdSprite`) at 1 px resolution, from the 13 x 10 cell layout of
`clawdFrame()` in `src/render/sprites.ts`: an 18 x 16 px body with a shaded left column and bottom, a lit top rim
and right edge, eyes with a glint, arms and four legs per pose. `Player._update_visual()` picks the pose like
`drawClawd()` in `src/render/clawdView.ts` and adds: pupils that look ahead while running, up while rising and
down while falling (and back over the shoulder now and then when idle), arms that swing while running, and
squash & stretch (from `src/entities/player.ts`, plus a pinch when turning) drawn as a wider/flatter or
narrower/taller body instead of a scaled mesh. `ClawdSprite.mesh()` caches every combination it builds.
The visual snaps to whole pixels (the camera is pixel-aligned), so the sprite never lands between pixels. A
small `GlowLight` on Clawd warms the ground around him. Clawd and the bugs take a warm rim light from the GlowLight that reaches
them most (`GlowLight.rim_for()`, a lantern, token or firefly): `Voxel.mesh()` stores each pixel's silhouette
edges in UV.x, and `shaders/voxel.gdshader` lights the 1 px edge of the front face on the light's side and the
side faces turned towards it, in three steps.

## Look and feedback

The look is modern pixel art on 3D blocks, without scene lights: everything is unshaded and drawn per view
pixel. `scenes/main.tscn` renders the game into a `SubViewport` at the view size (~480×270, see `ViewScale`),
which the `SubViewportContainer` scales up by a whole factor with nearest filtering. The `WorldEnvironment`
only adds glow (HDR threshold 0.9; colours above 1.0 glow), and `shaders/crt.gdshader` draws the scanlines and
vignette of `Renderer.postFx()` over the window.

Each theme has a palette in `scripts/themes.gd` (`Themes.PALETTES`): haze gradient, ray colour and a light
colour for the background. The level blocks keep their black / white / orange look in every theme.

Back to front:

- `shaders/haze.gdshader` (`Background/Haze`): the palette's dark top to its haze at the horizon in dithered
  steps, with slanted light rays that pulse slowly and drift with the camera.
- `Parallax` (see above), its baked grey layers tinted between the palette's haze and light colours and its
  stars, data rain and rings towards the light colour.
- `scripts/scenery.gd` (`Scenery`): the neural forest, three layers deep, drawn by `shaders/scenery.gdshader`:
  trunks (columns of a neuron layer with pulsing node sockets and signals climbing their fibres), sagging
  weight cables between neighbouring trunks that carry light pulses, and floating neurons, all in the
  palette's light colour. The camera is orthographic, so
  `Scenery.update()` moves each layer with the camera by its parallax factor; layers are generated from the
  level's `terrainSeed`. Per-theme motifs to add on top are collected in `docs/scenery-themes.md`.
- The level: all blocks use `shaders/terrain_pixels.gdshader`. On level load `Level.bake_cells()` writes one
  texel per 4 px cell (distance to open air, random, open cell above, solid). Front faces: a black body that
  steps darker away from air, faint panel seams, orange circuit traces with blinking nodes, rims where blocks
  meet air and a white/grey crust with orange sparkles on exposed tops. One-way platforms are crust strips
  with orange LEDs, spikes orange triangles, corrupted blocks an animated orange glitch. Top faces are bands of
  view rows from the white front lip to dark speckled grey. Lower block corners that meet air below and to
  the side are rounded (4 px). One-way platforms are a thin strip (4 px tall,
  0.75 m deep), so they read as ledges rather than blocks. Blob shadows of Clawd and the enemies nearest the view
  (up to 16) are drawn on the top faces under them (`Level.shadow_at()`, `Level.set_shadows()`). The animation runs on `Game.time`, so hitstop and pause freeze it.
- Midground (a `Scenery` layer at z = -3 m between the level and the forest): big dark trunks with muted
  ledges sticking out, thick synapse bridges and a few neurons. It is anchored to the level and uses the
  level's perspective (`world_perspective` in the scenery shader), so it shifts against the level as the
  camera moves like a real object behind it. Less hazed than the forest so it reads nearer, enough that the
  ledges don't pass for platforms.
- `scripts/decor.gd` (`Decor.populate()`): props from the `terrainSeed`. On exposed tops: voxel lanterns at the
  back of the top band (behind Clawd), small tufts in the light colour at the front lip and the back that sway
  and bend away from Clawd as he walks through (`Decor.interact()`), and neuron flowers, a stalk with a glowing
  bulb and its own GlowLight (more in dark levels). Under ceilings and one-way platforms: data vines that hang
  and sway, some ending in a glowing node, and short dark drips. Sway is done in `shaders/voxel.gdshader`
  (instance `sway` / `bend`), rounded to whole pixels per row.
- Warm lights: `GlowLight` nodes (`scripts/glow_light.gd`, group `lights`) on lanterns, tokens and Clawd's hover
  jets. `Main` passes the visible ones nearest the view (at most 32) to `Level.set_lights()`; the terrain lights
  the pixels around them in four steps with an ordered dither between them. On block fronts only the crust
  within three cells of open air takes light.
- Air light: `scripts/motes.gd` (`Motes`) fills the level with fireflies / data motes at depths around the
  gameplay plane, 1 px glints with a dimmer cross that drift on slow loops and blink (more in dark levels);
  every tenth carries a small `GlowLight`. `shaders/light_fx.gdshader` (`Foreground/LightFx`, a CanvasLayer
  over the 3D view) adds light shafts in front of everything, scrolling faster than the level, and mist
  rising from the level's bottom edge so pits and the bottom fade into the haze; both are dithered and
  additive.
- Foreground: a `Scenery` layer in front of the level (parallax 1.35): clusters of big near-black data ferns
  (2 px voxels with a faint rim in the theme's light colour, swaying), dark broken trunk bases with a jagged
  top, rising from the level's bottom (in dark levels also hanging from its top), and thick dark cables
  hanging into the view.
- See-through windows: everything in front of the gameplay plane (ferns, stumps, hanging cables, front tufts,
  vines and flowers) is thinned out with an ordered dither in a circle around Clawd and the five enemies or
  tokens nearest him (`Main._update_reveal()`, `shaders/reveal.gdshaderinc`), down to a quarter of its pixels
  at the centre, so nothing the player needs to see hides behind the foreground.
- Depth fog: `shaders/fog.gdshaderinc`, used by the scenery and the terrain, fades every pixel by its depth
  behind the gameplay plane (`1 - e^(-depth * 0.06)`, thicker in the lower part of the view) into the sky
  colour of its view row (the haze gradient of the theme), so distant trunks dissolve into the sky behind
  them; motes dim with depth the same way.
- Colour grade: `shaders/grade.gdshader` (`Grade`, the top canvas layer in the SubViewport) lifts the darks a
  little towards the theme's haze colour, warms the lights towards the lanterns' orange and adds a touch of
  saturation, pixel for pixel.

The player emits `event(kind, at)` for `jump`, `land`, `hard_land`, `hurt`, `stomp`, `defeat`, `spin`,
`pound_start`, `pound_land` and `drop_through`; `main.gd` answers
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
| `project.godot` | 480×270 base view (integer-scaled by `ViewScale`), 60 Hz physics, input actions named as in `src/core/input.ts`, 3D physics layers `world`, `player`, `enemies`, `oneway` |
| `scenes/level_select.tscn`, `scripts/level_select.gd` | Start scene, level buttons |
| `scenes/main.tscn`, `scripts/main.gd` | Game scene: `View/SubViewport/World` holds the environment (glow), `Background/Haze` and `Background/Parallax`, `Scenery`, `Level` (current level), `Camera3D`, particles and the player; `ScreenFx/Crt` on top. `load_level(id)`, `next_level()` |
| `scenes/player.tscn`, `scripts/player.gd` | Clawd: movement, spin, ground pound, drop-through, spikes, enemy contact and stomps, voxel frames, spin ring, hover jets |
| `scenes/bug.tscn`, `scripts/bug.gd` | Patrolling bug (group `enemies`) |
| `scenes/token.tscn`, `scripts/token.gd` | Collectible token |
| `scripts/checkpoint.gd` | Checkpoint terminal (`C`) |
| `scripts/goal.gd`, `shaders/portal.gdshader` | Exit gate (`G`) and its swirl |
| `scripts/sign.gd` | Tutorial sign (`?`) and its text bubble |
| `scripts/moving_platform.gd` | Moving platform (`M`, `V`) |
| `scripts/pixel_font.gd`, `scripts/overlay.gd` | Bitmap font; text over the 3D view (popups, world text, panels) |
| `scripts/hud.gd` | HUD: hearts, token counter, CONTROLS and pause buttons, level label |
| `scripts/game_menu.gd`, `scripts/settings.gd` | Pause, controls help and keybinding menus; saved bindings |
| `scripts/sound.gd` | Synthesized sound effects, music loops and the hover jet (`src/core/audio.ts`) |
| `scripts/level.gd` | `Level`: builds a level from map rows, tile lookup by pixel, level size |
| `scripts/px.gd`, `scripts/voxel.gd` | Pixel ↔ metre conversion; voxel meshes from text-grid sprites |
| `scripts/parallax.gd`, `scripts/view_scale.gd` | Theme backgrounds behind the level; view size from the window |
| `scripts/scenery.gd`, `scripts/glow_light.gd` | Towers and floating blocks behind the level, foreground silhouettes; warm lights for the terrain shader |
| `scripts/themes.gd`, `scripts/decor.gd` | Background palette per theme; lanterns and tufts on the level |
| `shaders/terrain_pixels.gdshader` | Level blocks (crust, circuits, one-way, spikes, corrupted glitch, lights, Clawd's shadow) |
| `shaders/scenery.gdshader`, `shaders/haze.gdshader`, `shaders/crt.gdshader` | Background towers; haze gradient and light rays; CRT scanlines and vignette |
| `scripts/fx.gd` | `Fx.burst()` emits into the level's particles |
| `tools/check.gd` | Headless checks, see *Checks* |
| `levels/<id>.txt`, `levels/index.json`, `levels/<id>.tscn` | Level maps exported from `src`, and the 3D level scenes converted from them |
| `levels/overrides.json` | Port-specific level metadata merged into `index.json` (1-1's sign texts) |
| `tiles/terrain_meshlib.tres` | MeshLibrary of the level GridMaps. Item id = tile id from `src/world/tiles.ts` minus one: `#` solid (0), `=` one-way (1), `^` spike (2), `X` corrupted (3). Spikes have no collision shape; the player detects them by item like the TS version |
| `tools/build_meshlib.gd` | Generates `tiles/terrain_meshlib.tres` |
| `tools/export_levels.mjs`, `tools/convert_level.gd` | Level pipeline, see *Levels* |
| `addons/godot_ai/` | godot-ai editor plugin (MCP) |
