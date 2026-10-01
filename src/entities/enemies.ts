import { COLORS, TILE, gray } from '../config';
import { hash2 } from '../core/noise';
import type { Rect } from '../core/math';
import type { Renderer } from '../render/renderer';
import { BUG, ENEMY_PALETTE, SPAMBOT, drawSprite } from '../render/sprites';
import { hasFloorAt, moveX, moveY, rectHitsSolid } from '../world/collision';
import { Enemy, type GameContext } from './entity';
import type { Platform } from './player';

/** Glitch beetle: patrols, turns at walls and ledges. */
export class Bug extends Enemy {
  vx = -30;
  vy = 0;
  private t = Math.random() * 3;

  constructor(x: number, bottom: number, hp = 1) {
    super();
    this.hp = hp;
    this.w = 16;
    this.h = 11;
    this.x = x - 8;
    this.y = bottom - 11;
    this.savePrev();
  }

  update(dt: number, g: GameContext): void {
    this.tickTimers(dt);
    this.t += dt;
    this.vy = Math.min(this.vy + 1400 * dt, 400);
    if (moveX(this, this.vx * dt, g.level)) this.vx = -this.vx;
    const res = moveY(this, this.vy * dt, g.level);
    if (res.floor) {
      this.vy = 0;
      const aheadX = this.vx > 0 ? this.x + this.w + 1 : this.x - 1;
      if (!hasFloorAt(aheadX, this.y + this.h + 2, g.level)) this.vx = -this.vx;
    }
    if (this.y > g.level.pixelH + 50) this.alive = false;
  }

  get hurtbox(): Rect {
    return { x: this.x + 2, y: this.y + 3, w: this.w - 4, h: this.h - 3 };
  }

  draw(r: Renderer, g: GameContext, alpha: number): void {
    const frame = Math.floor(this.t * 6) % 2 === 0 ? BUG.a : BUG.b;
    const glitchSeed = Math.floor(g.time * 10);
    drawSprite(r.ctx, frame, ENEMY_PALETTE, this.ix(alpha) + this.w / 2, this.iy(alpha) + this.h + 1, {
      px: 2,
      fill: 0.8,
      flip: this.vx > 0,
      tint: this.flash > 0 ? '#FFFFFF' : undefined,
      glitch: (row) => (hash2(row, glitchSeed, this.x | 0) > 0.93 ? 1 : 0),
    });
  }
}

/** Projectile fired by spam bots and the boss. */
export class Shot extends Enemy {
  private life = 4;

  constructor(
    x: number,
    y: number,
    public vx: number,
    public vy: number,
    private color = COLORS.red,
    /** Draw as a code character instead of a dot (Codex). */
    private glyph = '',
    cancellable = true,
    life = 4,
  ) {
    super();
    const size = glyph ? 7 : 5;
    this.w = size;
    this.h = size;
    this.x = x - size / 2;
    this.y = y - size / 2;
    this.life = life;
    this.cancellable = cancellable;
    this.projectile = true;
    this.stompable = false;
    this.layer = 3;
    this.savePrev();
  }

  update(dt: number, g: GameContext): void {
    this.life -= dt;
    this.x += this.vx * dt;
    this.y += this.vy * dt;
    if (Math.random() < 0.5) g.particles.emit(this.x + 2.5, this.y + 2.5, { count: 1, speed: 5, life: 0.25, color: this.color });
    if (this.life <= 0 || (!this.glyph && rectHitsSolid(this.x + 1, this.y + 1, 3, 3, g.level))) this.alive = false;
  }

  protected die(_kind: string, g: GameContext): void {
    this.alive = false;
    g.particles.emit(this.x + 2.5, this.y + 2.5, { count: 8, speed: 60, life: 0.3, color: [this.color, '#FFFFFF'] });
  }

  draw(r: Renderer, _g: GameContext, alpha: number): void {
    const ctx = r.ctx;
    const x = this.ix(alpha);
    const y = this.iy(alpha);
    if (this.glyph) {
      r.text(this.glyph, x + this.w / 2, y + this.h / 2, { size: 8, align: 'center', bold: true, color: this.color });
      return;
    }
    ctx.fillStyle = this.color;
    ctx.fillRect(x + 1, y, 3, 5);
    ctx.fillRect(x, y + 1, 5, 3);
    ctx.fillStyle = '#FFFFFF';
    ctx.fillRect(x + 2, y + 2, 1, 1);
  }
}

/** Flying spam drone that hovers around its post and fires at Clawd. */
export class SpamBot extends Enemy {
  private t = Math.random() * 5;
  private fireTimer = 1.5 + Math.random();
  private ax: number;
  private ay: number;

  constructor(x: number, bottom: number, hp = 1) {
    super();
    this.hp = hp;
    this.w = 18;
    this.h = 15;
    this.ax = x - 9;
    this.ay = bottom - 15;
    this.x = this.ax;
    this.y = this.ay;
    this.savePrev();
  }

  update(dt: number, g: GameContext): void {
    this.tickTimers(dt);
    this.t += dt;
    this.x = this.ax + Math.sin(this.t * 0.8) * 26;
    this.y = this.ay + Math.sin(this.t * 2.1) * 6;
    const p = g.player;
    const dx = p.cx - (this.x + 9);
    const dy = p.y + 9 - (this.y + 8);
    const d = Math.hypot(dx, dy);
    this.fireTimer -= dt;
    if (this.fireTimer <= 0 && d < 210) {
      this.fireTimer = 2.4;
      const s = 85;
      g.spawn(new Shot(this.x + 9, this.y + 10, (dx / d) * s, (dy / d) * s));
      g.sfx('shoot');
    }
  }

  draw(r: Renderer, g: GameContext, alpha: number): void {
    const frame = Math.floor(this.t * 10) % 2 === 0 ? SPAMBOT.a : SPAMBOT.b;
    const charging = this.fireTimer < 0.4;
    drawSprite(r.ctx, frame, ENEMY_PALETTE, this.ix(alpha) + 9, this.iy(alpha) + 16, {
      px: 2,
      fill: 0.8,
      flip: g.player.cx > this.x + 9,
      tint: this.flash > 0 ? '#FFFFFF' : charging && Math.floor(g.time * 20) % 2 === 0 ? COLORS.red : undefined,
    });
  }
}

/** "429" crusher block: drops when Clawd walks beneath, then slowly rises. Top is walkable. */
export class RateLimiter extends Enemy implements Platform {
  dx = 0;
  dy = 0;
  active = true;
  private homeY: number;
  private mode: 'idle' | 'shake' | 'fall' | 'rest' | 'rise' = 'idle';
  private timer = 0;
  private vy = 0;

  constructor(x: number, top: number) {
    super();
    this.w = 32;
    this.h = 32;
    this.x = x;
    this.y = top;
    this.homeY = top;
    this.invincible = true;
    this.stompable = false;
    this.savePrev();
  }

  get hurtbox(): Rect | null {
    // Only the bottom and sides hurt; the top is a platform.
    return { x: this.x + 1, y: this.y + 6, w: this.w - 2, h: this.h - 6 };
  }

  update(dt: number, g: GameContext): void {
    const oldY = this.y;
    const p = g.player;
    switch (this.mode) {
      case 'idle':
        if (p.cx > this.x - 10 && p.cx < this.x + this.w + 10 && p.y > this.y + this.h && p.y - this.y < TILE * 9) {
          this.mode = 'shake';
          this.timer = 0.3;
        }
        break;
      case 'shake':
        this.timer -= dt;
        if (this.timer <= 0) {
          this.mode = 'fall';
          this.vy = 0;
        }
        break;
      case 'fall': {
        this.vy = Math.min(this.vy + 1800 * dt, 520);
        const res = moveY(this, this.vy * dt, g.level);
        if (res.floor || this.y > g.level.pixelH) {
          this.mode = 'rest';
          this.timer = 0.9;
          g.sfx('crush');
          const near = Math.abs(p.cx - (this.x + 16)) < 140 && Math.abs(p.y - this.y) < 120;
          if (near) g.shake(0.35);
          g.particles.emit(this.x + 16, this.y + this.h, { count: 24, speed: 110, angle: -Math.PI / 2, spread: Math.PI, life: 0.5, color: ['#BDBDBD', '#777'], gravity: 300 });
        }
        break;
      }
      case 'rest':
        this.timer -= dt;
        if (this.timer <= 0) this.mode = 'rise';
        break;
      case 'rise':
        this.y = Math.max(this.homeY, this.y - 55 * dt);
        if (this.y <= this.homeY) this.mode = 'idle';
        break;
    }
    this.dx = 0;
    this.dy = this.y - oldY;
  }

  draw(r: Renderer, g: GameContext, alpha: number): void {
    const ctx = r.ctx;
    const shake = this.mode === 'shake' ? (Math.random() - 0.5) * 2 : 0;
    const x = this.ix(alpha) + shake;
    const y = this.iy(alpha);
    // Chain back up to where it hangs.
    ctx.fillStyle = gray(70);
    for (let cy = y - 3; cy > this.homeY - 2; cy -= 4) ctx.fillRect(x + 15, cy, 2, 2);
    for (let j = 0; j < 8; j++) {
      for (let i = 0; i < 8; i++) {
        const edge = i === 0 || j === 0 || i === 7 || j === 7;
        ctx.fillStyle = edge ? gray(205) : gray(70 + hash2(i, j, 4) * 30);
        ctx.fillRect(x + i * 4 + 1, y + j * 4 + 1, edge ? 2 : 1.5, edge ? 2 : 1.5);
      }
    }
    // Angry eyes.
    const angry = this.mode !== 'idle' && this.mode !== 'rise';
    ctx.fillStyle = angry ? COLORS.red : gray(150);
    ctx.fillRect(x + 7, y + 10 + (angry ? 1 : 0), 6, 2);
    ctx.fillRect(x + 19, y + 10 + (angry ? 1 : 0), 6, 2);
    if (angry) {
      ctx.fillRect(x + 7, y + 9, 2, 1);
      ctx.fillRect(x + 23, y + 9, 2, 1);
    }
    r.text('429', x + 16, y + 22, { size: 5, align: 'center', color: angry ? COLORS.red : gray(140), bold: true });
    void g;
  }
}
