# Scenery themes — ideas for future levels

The background is the inside of a model. Every theme shares the **neural forest** (`scripts/scenery.gd`):
trunks of neuron layers with glowing nodes, weight cables between them that carry light pulses, floating
neurons, dark cables and trunk bases in the foreground. The motifs below are meant to be added per theme on
top of it, to tell the levels apart. They use the same machinery as the forest: `Scenery` layers (depth,
parallax, haze, perspective), the theme palette in `scripts/themes.gd`, animation in
`shaders/scenery.gdshader` on `Game.time`.

| Theme (level) | Motif | Notes |
|---|---|---|
| `plains` (1-1 Token Plains) | **Loss landscape** | Far wireframe hills with contour lines; a small glowing ball slowly rolls down into a valley ("gradient descent") and restarts. Fits 1-1 as the calm opening. |
| `plains`, sky of any theme | **Embedding galaxies** | Clusters of glowing points and token fragments high in the sky, turning slowly as the camera moves; literally the latent space of the game's name. |
| `caves` (1-2 Gradient Caves) | **Loss landscape, inverted** — done (`shaders/motif_caves.gdshader`) | The landscape seen from inside a valley: contour-line walls, the ball as a light source rolling past. Pairs with the bioluminescent nodes of the forest. |
| `window` (1-3 Context Window) | **Floating windows** | Text panels with lines of prompt / code drifting into depth; old ones crumble into pixels as the context overflows (ties in with the level's rising void). |
| `boss` (1-B The Hallucination) | **Glitching forest** | Everything above, distorted: trunks that split and rejoin, cables looping into nothing, colours shifting, rows tearing sideways like the bug glitch. |
| `mesa` (2-1 Merge Conflict Mesa) | **Diff strata** | Mesas built from layered green / red diff bands, conflict markers (`<<<<<<<`, `=======`) as glowing seams. |
| `forge` (2-2 GPU Forge) | **Server racks and GPU monoliths** | Racks with blinking LEDs, heat sinks, glowing hot dies, fans, thick power cables between them; embers already rise in this theme. |
| `swamp` (2-3 Prompt Injection Swamp) | **Corrupted data pools** | Tangled cables sinking into murky pools that reflect the haze; injected strings floating up as bubbles of text. |
| `towers` (2-4 The Diff Towers) | **Transformer stacks** | Tall columns of stacked translucent plates (layers) with light running up the residual stream; green / red diff stripes on the plates. |
| `codex` (2-B Codex) | **Code monoliths** | Monoliths covered in scrolling code (the theme already draws code lines), cursor blinks, syntax colours in the theme's cyan. |
