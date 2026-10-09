class_name Px

## Game logic keeps the units of the TS game: pixels, y down, 16 px per tile. The 3D world uses
## metres, y up, 1 m per tile, with the level's top-left corner at the origin and gameplay on z = 0.

const M := 1.0 / 16


static func of(v: Vector3) -> Vector2:
	return Vector2(v.x, -v.y) / M


static func to3(v: Vector2) -> Vector3:
	return Vector3(v.x, -v.y, 0) * M


## GridMap cell of the tile under a point.
static func cell(p: Vector2) -> Vector3i:
	return Vector3i(floori(p.x / 16), -floori(p.y / 16) - 1, 0)
