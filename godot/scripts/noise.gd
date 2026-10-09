class_name DotNoise

## Seeded randomness and value noise, bit-exact ports of src/core/noise.ts. JS does these in
## 32-bit integer math (Math.imul, >>>), so every product and sum is masked back to 32 bits.

const M32 := 0xFFFFFFFF


static func hash2(x: int, y: int, seed := 0) -> float:
	var h := (x * 374761393 + y * 668265263 + seed * 2147483647) & M32
	h = ((h ^ (h >> 13)) * 1274126177) & M32
	h ^= h >> 16
	return h / 4294967296.0


static func smooth(t: float) -> float:
	return t * t * (3 - 2 * t)


static func value_noise2(x: float, y: float, seed := 0) -> float:
	var x0 := floori(x)
	var y0 := floori(y)
	var fx := smooth(x - x0)
	var fy := smooth(y - y0)
	var a := hash2(x0, y0, seed)
	var b := hash2(x0 + 1, y0, seed)
	var c := hash2(x0, y0 + 1, seed)
	var d := hash2(x0 + 1, y0 + 1, seed)
	return a + (b - a) * fx + (c - a) * fy + (a - b - c + d) * fx * fy


## 1D value noise that repeats every `period` units.
static func periodic_noise1(x: float, period: float, seed := 0) -> float:
	var p := maxi(1, roundi(period))
	var xi := floori(x)
	var f := smooth(x - xi)
	var a := hash2(posmod(xi, p), 0, seed)
	var b := hash2(posmod(xi + 1, p), 0, seed)
	return a + (b - a) * f


## Returns a seeded generator of floats in [0, 1), same sequence as mulberry32 in TS.
static func mulberry32(seed: int) -> Callable:
	var state := [seed & M32]
	return func() -> float:
		state[0] = (state[0] + 0x6D2B79F5) & M32
		var t: int = state[0]
		t = ((t ^ (t >> 15)) * (t | 1)) & M32
		t ^= (t + (((t ^ (t >> 7)) * (t | 61)) & M32)) & M32
		return ((t ^ (t >> 14)) & M32) / 4294967296.0
