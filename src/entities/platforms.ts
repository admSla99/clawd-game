import { TILE, gray } from '../config';
import type { Renderer } from '../render/renderer';
import { Entity, type GameContext } from './entity';
import type { Platform } from './player';

/** A dotted platform that oscillates horizontally or vertically. */
export class MovingPlatform extends Entity implements Platform {
  dx = 0;
  dy = 0;
  active = true;
  private t: number;
  private baseX: number;
  private baseY: number;

  constructor(
    cx: number,
    top: number,
    private axis: 'h' | 'v',
    private amp = TILE * 3.5,
    private period = 4,
    phase = 0,
  ) {
    super();
    this.w = TILE * 3;
    this.h = 6;
    this.baseX = cx - this.w / 2;
    this.baseY = top;
    this.x = this.baseX;
    this.y = this.baseY;
    this.t = phase;
    this.savePrev();
  }

  update(dt: number): void {
    this.t += dt;
    const o = Math.sin((this.t / this.period) * Math.PI * 2) * this.amp;
    const nx = this.axis === 'h' ? this.baseX + o : this.baseX;
    const ny = this.axis === 'v' ? this.baseY + o : this.baseY;
    this.dx = nx - this.x;
    this.dy = ny - this.y;
    this.x = nx;
    this.y = ny;
  }

  draw(r: Renderer, _g: GameContext, alpha: number): void {
    drawPlatformDots(r.ctx, this.ix(alpha), this.iy(alpha), this.w, 1);
  }
}

export function drawPlatformDots(ctx: CanvasRenderingContext2D, x: number, y: number, w: number, a: number): void {
  ctx.globalAlpha = a;
  for (let i = 0; i < w; i += 4) {
    ctx.fillStyle = gray(225);
    ctx.fillRect(x + i, y, 3, 1);
    ctx.fillStyle = gray(150);
    ctx.fillRect(x + i + 1, y + 2, 2, 1);
    if ((i / 4) % 2 === 0) {
      ctx.fillStyle = gray(85);
      ctx.fillRect(x + i + 1, y + 4, 1, 1);
    }
  }
  ctx.fillStyle = '#D97757';
  ctx.fillRect(x, y, 1, 1);
  ctx.fillRect(x + w - 1, y, 1, 1);
  ctx.globalAlpha = 1;
}

/** A hallucinated platform: looks real, dissolves shortly after you stand on it. */
export class FakePlatform extends Entity implements Platform {
  dx = 0;
  dy = 0;
  active = true;
  private stood = -1;
  private age = 0;

  constructor(
    x: number,
    top: number,
    w: number,
    private lifetime = 7,
  ) {
    super();
    this.x = x;
    this.y = top;
    this.w = w;
    this.h = 6;
    this.savePrev();
  }

  onStand(): void {
    if (this.stood < 0) this.stood = 0;
  }

  update(dt: number, g: GameContext): void {
    this.age += dt;
    if (this.stood >= 0) this.stood += dt;
    if ((this.stood > 0.45 || this.age > this.lifetime) && this.active) {
      this.active = false;
      this.alive = false;
      g.particles.emit(this.x + this.w / 2, this.y, { count: 20, speed: 50, life: 0.5, color: ['#C25BD6', '#FFFFFF', '#5FD0D8'], gravity: 100 });
    }
  }

  draw(r: Renderer, g: GameContext): void {
    const fadeIn = Math.min(1, this.age * 3);
    const shaky = this.stood >= 0 ? (Math.random() - 0.5) * 2 : 0;
    const flicker = this.stood >= 0 && Math.floor(g.time * 30) % 2 === 0 ? 0.4 : 1;
    drawPlatformDots(r.ctx, this.x + shaky, this.y, this.w, fadeIn * flicker);
  }
}
