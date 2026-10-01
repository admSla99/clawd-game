import { COLORS } from '../config';

/** The orange dotted star from the reference image: a plus with diagonal accents. */
export function drawSpark(ctx: CanvasRenderingContext2D, x: number, y: number, t: number, opts: { scale?: number; color?: string; ghost?: boolean } = {}): void {
  const s = opts.scale ?? 1;
  const color = opts.color ?? COLORS.orange;
  const arm = 3 + (Math.sin(t * 6) > 0.3 ? 1 : 0);
  const step = 2 * s;
  const d = s;
  ctx.fillStyle = color;
  const dot = (ix: number, iy: number, size = d) => {
    if (opts.ghost && (ix + iy) % 2 !== 0) return;
    ctx.fillRect(x + ix * step - size / 2, y + iy * step - size / 2, size, size);
  };
  dot(0, 0, d * 2);
  for (let i = 1; i <= arm; i++) {
    dot(i, 0);
    dot(-i, 0);
    dot(0, i);
    dot(0, -i);
  }
  dot(1, 1);
  dot(-1, 1);
  dot(1, -1);
  dot(-1, -1);
  if (arm > 3) {
    ctx.globalAlpha *= 0.5;
    dot(2, 2);
    dot(-2, 2);
    dot(2, -2);
    dot(-2, -2);
    ctx.globalAlpha /= 0.5;
  }
}

export function drawToken(ctx: CanvasRenderingContext2D, x: number, y: number, t: number): void {
  const w = Math.abs(Math.cos(t * 4)); // spinning coin
  ctx.fillStyle = COLORS.orangeLight;
  const hw = Math.max(0.5, 2 * w);
  ctx.fillRect(x - hw, y - 1, hw * 2, 2);
  ctx.fillRect(x - Math.max(0.5, w), y - 2, Math.max(1, 2 * w), 4);
}

export function drawSpeaker(ctx: CanvasRenderingContext2D, x: number, y: number, muted: boolean, color: string): void {
  ctx.fillStyle = color;
  ctx.fillRect(x, y - 1, 2, 3);
  ctx.fillRect(x + 2, y - 2, 1, 5);
  ctx.fillRect(x + 3, y - 3, 1, 7);
  if (muted) {
    for (let i = 0; i < 4; i++) {
      ctx.fillRect(x + 5 + i, y - 2 + i, 1, 1);
      ctx.fillRect(x + 8 - i, y - 2 + i, 1, 1);
    }
  } else {
    ctx.fillRect(x + 5, y - 1, 1, 3);
    ctx.fillRect(x + 7, y - 3, 1, 7);
  }
}

/** Dotted rounded box used throughout the UI. */
export function panel(ctx: CanvasRenderingContext2D, x: number, y: number, w: number, h: number, border: string = COLORS.hudBorder, fill: string = COLORS.hudFill): void {
  ctx.fillStyle = fill;
  ctx.fillRect(x, y, w, h);
  ctx.fillStyle = border;
  ctx.fillRect(x + 1, y, w - 2, 0.5);
  ctx.fillRect(x + 1, y + h - 0.5, w - 2, 0.5);
  ctx.fillRect(x, y + 1, 0.5, h - 2);
  ctx.fillRect(x + w - 0.5, y + 1, 0.5, h - 2);
}
