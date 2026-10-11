class_name TokenSprite

## The token at 1 px resolution: a 6 x 6 px coin in the light orange of drawToken() in
## src/render/shapes.ts, with a darker rim, a lit top-left and a white glint. Spinning is drawn as
## whole-pixel widths (6, 4, 2 px edge-on) like the narrowing rectangles of the 2D coin, not as a rotated
## mesh. SPARK holds the frames of the sparkle left when it is collected. Everything uses a glowing
## material, so the WorldEnvironment glow picks it up.

const PALETTE := {
	"c": Color("#C2603E"), # rim
	"T": Color("#F0A585"), # face
	"S": Color("#DB8462"), # shaded lower right
	"L": Color("#FFD2BC"), # lit top left
	"W": Color("#FFFFFF"), # glint
}
const FRAMES := {
	6: [".cccc.", "cLLTTc", "cLWTTc", "cTTTTc", "cTTTSc", ".cccc."],
	4: [".cc.", "cLTc", "cWTc", "cTTc", "cTSc", ".cc."],
	2: ["LL", "cc", "cc", "cc", "cc", "cc"],
}
const SPARK := [
	["...W...", "...L...", "..LWL..", "WLWWWLW", "..LWL..", "...L...", "...W..."],
	["L.......L", ".W.....W.", "....W....", "...WLW...", "..WL.LW..", "...WLW...", "....W....", ".W.....W.", "L.......L"],
	["W.........W", "...........", "...........", "...........", ".....L.....", "....L.L....", ".....L.....", "...........", "...........", "...........", "W.........W"],
]

static var MATERIAL := Voxel.material(1.6)
static var MESHES := {}
static var SPARK_MESHES: Array = SPARK.map(func(rows: Array) -> ArrayMesh:
	return Voxel.mesh(_pad(rows, 11), PALETTE, {"W": 2, "L": 2}, Px.M, Voxel.material(2.2)))


## Centres a square frame in a size x size grid, so every spark frame shares its centre.
static func _pad(rows: Array, size: int) -> Array:
	var m := (size - rows.size()) / 2
	var out := []
	for y in size:
		var r: String = rows[y - m] if y >= m and y - m < rows.size() else ""
		out.append(".".repeat(m) + r + ".".repeat(size - m - r.length()))
	return out


## Coin frame for a spin phase: the width follows |cos| of the spin like drawToken().
static func mesh(spin: float) -> ArrayMesh:
	var c := absf(cos(spin))
	var w := 6 if c > 0.7 else 4 if c > 0.3 else 2
	if not MESHES.has(w):
		MESHES[w] = Voxel.mesh(FRAMES[w], PALETTE, {"c": 2, "T": 2, "S": 2, "L": 2, "W": 2}, Px.M, MATERIAL)
	return MESHES[w]
