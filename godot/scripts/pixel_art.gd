class_name PixelArt

## Draws a text-grid sprite anchored at its bottom-centre, like drawSprite() in src/render/sprites.ts.
## Each character maps to a palette color; '.', ' ' and characters missing from the palette are
## transparent. Options (all optional, same meaning as DrawOpts in TS):
##   px     size of one art pixel (default 2)
##   flip   mirror horizontally
##   sx/sy  squash & stretch factors
##   turn   -1..1 horizontal squash for spins; negative also mirrors
##   alpha  opacity
##   tint   replace every colour (hit flash, silhouettes)
##   fill   draw each art pixel as a smaller dot (LED look), 1 = solid
##   glitch Callable(row) -> horizontal offset in art pixels
static func draw(ci: CanvasItem, rows: Array, palette: Dictionary, at := Vector2.ZERO, o := {}) -> void:
	var px: float = o.get("px", 2.0)
	var turn: float = o.get("turn", 1.0)
	var sx: float = o.get("sx", 1.0) * absf(turn) * px
	var sy: float = o.get("sy", 1.0) * px
	var flip := (-1 if o.get("flip", false) else 1) * (-1 if turn < 0 else 1)
	var h := rows.size()
	var w: int = rows[0].length()
	var fill: float = o.get("fill", 1.0)
	var alpha: float = o.get("alpha", 1.0)
	var tint = o.get("tint")
	var glitch = o.get("glitch")
	var left := at.x - w * sx / 2
	var top := at.y - h * sy
	var dw := maxf(0.5, sx * fill)
	var dh := maxf(0.5, sy * fill)
	for r in h:
		var row: String = rows[r]
		var g: float = glitch.call(r) * px if glitch else 0.0
		for c in w:
			var ch := row[c]
			if not palette.has(ch):
				continue
			var color: Color = tint if tint != null else palette[ch]
			color.a *= alpha
			var col := w - 1 - c if flip < 0 else c
			ci.draw_rect(Rect2(left + col * sx + g, top + r * sy, dw, dh), color)
