import { BASE_VIEW_H, COLORS } from '../config';

export const FONT = '"JetBrains Mono", ui-monospace, Consolas, monospace';

/**
 * Owns the canvas. Everything is drawn in "world units": the view is ~270 units
 * tall and each unit maps to an integer number of device pixels, which keeps the
 * pixel art crisp while text still renders at full resolution.
 */
export class Renderer {
  readonly ctx: CanvasRenderingContext2D;
  scale = 1;
  viewW = 480;
  viewH = BASE_VIEW_H;
  crt = true;
  private scanlines: CanvasPattern | null = null;

  constructor(readonly canvas: HTMLCanvasElement) {
    const ctx = canvas.getContext('2d', { alpha: false });
    if (!ctx) throw new Error('Canvas 2D not supported');
    this.ctx = ctx;
    this.resize();
    window.addEventListener('resize', () => this.resize());
  }

  resize(): void {
    const dpr = window.devicePixelRatio || 1;
    const w = Math.round(window.innerWidth * dpr);
    const h = Math.round(window.innerHeight * dpr);
    this.canvas.width = w;
    this.canvas.height = h;
    this.canvas.style.width = `${window.innerWidth}px`;
    this.canvas.style.height = `${window.innerHeight}px`;
    this.scale = Math.max(1, Math.round(h / BASE_VIEW_H));
    this.viewW = w / this.scale;
    this.viewH = h / this.scale;
    this.ctx.imageSmoothingEnabled = false;
    this.scanlines = null;
  }

  begin(bg: string = COLORS.bg): void {
    const ctx = this.ctx;
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.globalAlpha = 1;
    ctx.fillStyle = bg;
    ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);
    ctx.setTransform(this.scale, 0, 0, this.scale, 0, 0);
    ctx.imageSmoothingEnabled = false;
  }

  /** Snap a world coordinate to the device pixel grid. */
  snap(v: number): number {
    return Math.round(v * this.scale) / this.scale;
  }

  /** Map a CSS-pixel position (mouse) to view units. */
  toView(clientX: number, clientY: number): { x: number; y: number } {
    const dpr = window.devicePixelRatio || 1;
    return { x: (clientX * dpr) / this.scale, y: (clientY * dpr) / this.scale };
  }

  /** Scanlines + vignette, drawn in device pixels on top of everything. */
  postFx(): void {
    if (!this.crt) return;
    const ctx = this.ctx;
    ctx.save();
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    if (!this.scanlines) {
      const c = document.createElement('canvas');
      const step = Math.max(2, this.scale);
      c.width = 1;
      c.height = step;
      const g = c.getContext('2d')!;
      g.fillStyle = 'rgba(0,0,0,0.13)';
      g.fillRect(0, step - Math.max(1, Math.floor(step / 3)), 1, Math.max(1, Math.floor(step / 3)));
      this.scanlines = ctx.createPattern(c, 'repeat');
    }
    if (this.scanlines) {
      ctx.fillStyle = this.scanlines;
      ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);
    }
    const w = this.canvas.width;
    const h = this.canvas.height;
    const grad = ctx.createRadialGradient(w / 2, h / 2, Math.min(w, h) * 0.35, w / 2, h / 2, Math.max(w, h) * 0.75);
    grad.addColorStop(0, 'rgba(0,0,0,0)');
    grad.addColorStop(1, 'rgba(0,0,0,0.45)');
    ctx.fillStyle = grad;
    ctx.fillRect(0, 0, w, h);
    ctx.restore();
  }

  text(
    str: string,
    x: number,
    y: number,
    opts: { size?: number; color?: string; align?: CanvasTextAlign; bold?: boolean; alpha?: number; baseline?: CanvasTextBaseline } = {},
  ): number {
    const ctx = this.ctx;
    ctx.font = `${opts.bold ? '700 ' : ''}${opts.size ?? 6}px ${FONT}`;
    ctx.fillStyle = opts.color ?? COLORS.text;
    ctx.textAlign = opts.align ?? 'left';
    ctx.textBaseline = opts.baseline ?? 'middle';
    const prev = ctx.globalAlpha;
    if (opts.alpha !== undefined) ctx.globalAlpha = prev * opts.alpha;
    ctx.fillText(str, x, y);
    ctx.globalAlpha = prev;
    return ctx.measureText(str).width;
  }

  measure(str: string, size = 6, bold = false): number {
    this.ctx.font = `${bold ? '700 ' : ''}${size}px ${FONT}`;
    return this.ctx.measureText(str).width;
  }
}
