import { COLORS, gray } from '../config';
import { clamp, type Rect } from '../core/math';
import { hash2 } from '../core/noise';
import type { Renderer } from '../render/renderer';
import { hasFloorAt, moveX, moveY } from '../world/collision';
import { Bug, Shot } from './enemies';
import { Enemy, type GameContext, type HitKind } from './entity';

const MAGENTA = '#C25BD6';

/** "Lint" turret: tracks Clawd and fires three-shot bursts. Floor or ceiling mounted. */
export class Turret extends Enemy {
  private angle: number;
  private timer = 1.2 + Math.random();
  private burst = 0;
  private burstT = 0;

  constructor(
    x: number,
    edgeY: number,
    private ceiling: boolean,
  ) {
    super();
    this.w = 16;
    this.h = 12;
    this.x = x - 8;
    this.y = ceiling ? edgeY : edgeY - 12;
    this.hp = 6;
    this.tokens = 4;
    this.stompable = !ceiling;
    this.angle = ceiling ? Math.PI / 2 : -Math.PI / 2;
    this.savePrev();
  }

  private get pivot(): { x: number; y: number } {
    return { x: this.x + 8, y: this.ceiling ? this.y + 5 : this.y + 7 };
  }

  update(dt: number, g: GameContext): void {
    this.tickTimers(dt);
    const p = g.player;
    const pv = this.pivot;
    const dx = p.cx - pv.x;
    const dy = p.y + 9 - pv.y;
    const dist = Math.hypot(dx, dy);
    let target = Math.atan2(dy, dx);
    // Floor turrets aim at the upper half-plane, ceiling ones at the lower.
    if (this.ceiling) target = clamp(target, 0.1, Math.PI - 0.1);
    else target = target > Math.PI / 2 ? -Math.PI + 0.1 : target > 0 ? -0.1 : clamp(target, -Math.PI + 0.1, -0.1);
    let diff = target - this.angle;
    while (diff > Math.PI) diff -= Math.PI * 2;
    while (diff < -Math.PI) diff += Math.PI * 2;
    this.angle += clamp(diff, -3 * dt, 3 * dt);

    this.timer -= dt;
    if (this.timer <= 0 && dist < 250) {
      this.burst = 3;
      this.burstT = 0;
      this.timer = 2.4;
    }
    if (this.burst > 0) {
      this.burstT -= dt;
      if (this.burstT <= 0) {
        const s = 135;
        g.spawn(new Shot(pv.x + Math.cos(this.angle) * 10, pv.y + Math.sin(this.angle) * 10, Math.cos(this.angle) * s, Math.sin(this.angle) * s));
        g.sfx('shoot');
        this.burst--;
        this.burstT = 0.14;
      }
    }
  }

  draw(r: Renderer, g: GameContext): void {
    const ctx = r.ctx;
    const pv = this.pivot;
    const warn = this.timer < 0.45 && Math.floor(g.time * 20) % 2 === 0;
    // Barrel.
    ctx.fillStyle = warn ? COLORS.red : gray(200);
    for (let i = 2; i < 11; i += 1.5) ctx.fillRect(pv.x + Math.cos(this.angle) * i - 1, pv.y + Math.sin(this.angle) * i - 1, 2, 2);
    // Dome.
    const tint = this.flash > 0 ? '#FFFFFF' : undefined;
    for (let j = 0; j < 3; j++) {
      for (let i = 0; i < 4 - (j === 0 ? 1 : 0); i++) {
        const row = this.ceiling ? j : 2 - j;
        const ox = j === 0 ? 2 : 0;
        ctx.fillStyle = tint ?? (row === 0 ? gray(210) : gray(130));
        ctx.fillRect(this.x + ox + i * 4 + 1, this.y + (this.ceiling ? row : 2 - row) * 4 + 1, 2.5, 2.5);
      }
    }
    ctx.fillStyle = COLORS.red;
    ctx.fillRect(pv.x - 1, pv.y - 1, 2, 2);
  }
}

/** Overclocked drone: circles Clawd, telegraphs, then dives at him. */
export class Drone extends Enemy {
  vx = 0;
  vy = 0;
  private mode: 'idle' | 'orbit' | 'aim' | 'dive' | 'recover' = 'idle';
  private timer = 0;
  private side = Math.random() < 0.5 ? -1 : 1;
  private t = Math.random() * 5;
  private homeY: number;

  constructor(x: number, bottom: number) {
    super();
    this.w = 14;
    this.h = 10;
    this.x = x - 7;
    this.y = bottom - 12;
    this.homeY = this.y;
    this.hp = 3;
    this.tokens = 3;
    this.savePrev();
  }

  update(dt: number, g: GameContext): void {
    this.tickTimers(dt);
    this.t += dt;
    const p = g.player;
    const cx = this.x + 7;
    const cy = this.y + 5;
    const dist = Math.hypot(p.cx - cx, p.y - cy);
    this.timer -= dt;
    switch (this.mode) {
      case 'idle':
        this.vx *= 0.9;
        this.vy = (this.homeY + Math.sin(this.t * 2) * 4 - this.y) * 3;
        if (dist < 230) {
          this.mode = 'orbit';
          this.timer = 1.6 + Math.random();
        }
        break;
      case 'orbit': {
        const tx = p.cx + this.side * 70;
        const ty = p.y - 46 + Math.sin(this.t * 3) * 8;
        this.vx += ((tx - cx) * 5 - this.vx * 2.2) * dt;
        this.vy += ((ty - cy) * 5 - this.vy * 2.2) * dt;
        if (this.timer <= 0) {
          this.mode = 'aim';
          this.timer = 0.45;
        }
        break;
      }
      case 'aim':
        this.vx *= 0.85;
        this.vy *= 0.85;
        if (this.timer <= 0) {
          const dx = p.cx - cx;
          const dy = p.y + 9 - cy;
          const d = Math.hypot(dx, dy) || 1;
          this.vx = (dx / d) * 270;
          this.vy = (dy / d) * 270;
          this.mode = 'dive';
          this.timer = 0.55;
        }
        break;
      case 'dive':
        if (this.timer <= 0) {
          this.mode = 'recover';
          this.timer = 0.6;
        }
        break;
      case 'recover':
        this.vx *= 0.92;
        this.vy = this.vy * 0.92 - 30 * dt;
        if (this.timer <= 0) {
          this.mode = 'orbit';
          this.side = -this.side;
          this.timer = 1.8 + Math.random() * 1.2;
        }
        break;
    }
    const hitX = moveX(this, this.vx * dt, g.level);
    const res = moveY(this, this.vy * dt, g.level);
    if ((hitX || res.floor || res.ceiling) && this.mode === 'dive') {
      this.mode = 'recover';
      this.timer = 0.6;
      this.vx = -this.vx * 0.3;
      this.vy = -Math.abs(this.vy) * 0.3;
    }
  }

  draw(r: Renderer, g: GameContext, alpha: number): void {
    const ctx = r.ctx;
    const x = this.ix(alpha);
    const y = this.iy(alpha);
    const white = this.flash > 0;
    // Rotors.
    const spin = Math.floor(g.time * 30) % 2;
    ctx.fillStyle = gray(160);
    ctx.fillRect(x - 2 + spin * 2, y - 2, 6, 1);
    ctx.fillRect(x + 10 - spin * 2, y - 2, 6, 1);
    // Body.
    for (let j = 0; j < 3; j++) {
      for (let i = 0; i < 4; i++) {
        if (j === 2 && (i === 0 || i === 3)) continue;
        ctx.fillStyle = white ? '#FFFFFF' : j === 0 ? gray(210) : gray(120);
        ctx.fillRect(x + i * 3.5 + 1, y + j * 3 + 1, 2.5, 2.5);
      }
    }
    const angry = this.mode === 'aim' || this.mode === 'dive';
    ctx.fillStyle = angry ? (Math.floor(g.time * 24) % 2 ? '#FFFFFF' : COLORS.red) : COLORS.redDark;
    ctx.fillRect(x + 5.5, y + 4, 3, 2);
    if (this.mode === 'dive' && Math.random() < 0.6) g.particles.emit(x + 7, y + 5, { count: 1, speed: 10, life: 0.25, color: COLORS.red });
  }
}

/** "403" shield bot: blocks shots from the front. Jump over it, hit it from behind or above. */
export class ShieldBot extends Enemy {
  vx = 0;
  vy = 0;
  facing = -1;
  private fireTimer = 2 + Math.random();
  private turnTimer = 0;
  private t = 0;
  private shieldFlash = 0;

  constructor(x: number, bottom: number) {
    super();
    this.w = 16;
    this.h = 20;
    this.x = x - 8;
    this.y = bottom - 20;
    this.hp = 9;
    this.tokens = 6;
    this.savePrev();
  }

  /** Does the shield stop a shot travelling along (vx, vy)? */
  blocksDirection(vx: number, vy: number): boolean {
    const front = vx * this.facing < 0;
    const flat = Math.abs(vy) < Math.abs(vx) * 1.4;
    if (front && flat) {
      this.shieldFlash = 0.15;
      return true;
    }
    return false;
  }

  update(dt: number, g: GameContext): void {
    this.tickTimers(dt);
    this.t += dt;
    this.shieldFlash = Math.max(0, this.shieldFlash - dt);
    const p = g.player;
    const dx = p.cx - (this.x + 8);
    const near = Math.abs(dx) < 260 && Math.abs(p.y - this.y) < 120;
    const want = dx > 0 ? 1 : -1;
    if (near && want !== this.facing) {
      // Slow to turn around: that is the window to shoot its back.
      this.turnTimer += dt;
      if (this.turnTimer > 0.7) {
        this.facing = want;
        this.turnTimer = 0;
      }
    } else {
      this.turnTimer = 0;
    }
    this.vx = near && Math.abs(dx) > 36 && this.turnTimer === 0 ? this.facing * 30 : 0;
    const aheadX = this.facing > 0 ? this.x + this.w + 2 : this.x - 2;
    if (!hasFloorAt(aheadX, this.y + this.h + 2, g.level)) this.vx = 0;
    this.vy = Math.min(this.vy + 1400 * dt, 400);
    moveX(this, this.vx * dt, g.level);
    if (moveY(this, this.vy * dt, g.level).floor) this.vy = 0;

    this.fireTimer -= dt;
    if (near && this.fireTimer <= 0 && Math.abs(p.y + 9 - (this.y + 9)) < 40 && want === this.facing) {
      this.fireTimer = 2.6;
      g.spawn(new Shot(this.x + 8 + this.facing * 10, this.y + 9, this.facing * 125, 0));
      g.sfx('shoot');
    }
    if (this.y > g.level.pixelH + 50) this.alive = false;
  }

  get hurtbox(): Rect {
    return { x: this.x + 2, y: this.y + 3, w: this.w - 4, h: this.h - 3 };
  }

  draw(r: Renderer, g: GameContext, alpha: number): void {
    const ctx = r.ctx;
    const x = this.ix(alpha);
    const y = this.iy(alpha);
    const white = this.flash > 0;
    const step = Math.floor(this.t * 6) % 2;
    // Body.
    for (let j = 0; j < 5; j++) {
      for (let i = 0; i < 3; i++) {
        ctx.fillStyle = white ? '#FFFFFF' : j === 0 ? gray(210) : gray(120 + hash2(i, j, 3) * 30);
        ctx.fillRect(x + 2 + i * 4 + 0.5, y + j * 3.5 + 0.5, 3, 3);
      }
    }
    // Eye.
    ctx.fillStyle = COLORS.red;
    ctx.fillRect(x + 8 + this.facing * 2 - 1, y + 3, 3, 2);
    // Legs.
    ctx.fillStyle = gray(150);
    ctx.fillRect(x + 3 + step, y + 18, 2, 2);
    ctx.fillRect(x + 11 - step, y + 18, 2, 2);
    // Shield in front.
    const sx = this.facing > 0 ? x + 15 : x - 2;
    const turning = this.turnTimer > 0;
    for (let j = 0; j < 7; j++) {
      ctx.fillStyle = this.shieldFlash > 0 ? '#FFFFFF' : turning && Math.floor(g.time * 16) % 2 ? gray(90) : COLORS.cyan;
      ctx.fillRect(sx, y - 2 + j * 3.2, 3, 2.4);
    }
    r.text('403', x + 8, y - 6, { size: 4, align: 'center', color: COLORS.cyan, alpha: 0.7 });
  }
}

/** Prompt injector: hops at Clawd, and splits into bugs when destroyed. */
export class Injector extends Enemy {
  vx = 0;
  vy = 0;
  private timer = 0.8 + Math.random() * 0.6;
  private grounded = false;
  private t = 0;

  constructor(x: number, bottom: number) {
    super();
    this.w = 16;
    this.h = 14;
    this.x = x - 8;
    this.y = bottom - 14;
    this.hp = 5;
    this.tokens = 3;
    this.savePrev();
  }

  update(dt: number, g: GameContext): void {
    this.tickTimers(dt);
    this.t += dt;
    const p = g.player;
    const dx = p.cx - (this.x + 8);
    this.vy = Math.min(this.vy + 1300 * dt, 420);
    if (moveX(this, this.vx * dt, g.level)) this.vx = -this.vx * 0.5;
    const res = moveY(this, this.vy * dt, g.level);
    this.grounded = res.floor;
    if (res.floor) {
      this.vy = 0;
      this.vx = 0;
      this.timer -= dt;
      if (this.timer <= 0 && Math.abs(dx) < 260) {
        this.vx = Math.sign(dx) * Math.min(110, Math.abs(dx) * 1.3);
        this.vy = -330;
        this.timer = 1 + Math.random() * 0.5;
      }
    }
    if (this.y > g.level.pixelH + 50) this.alive = false;
  }

  protected die(kind: HitKind, g: GameContext): void {
    super.die(kind, g);
    for (const s of [-1, 1]) {
      const b = new Bug(this.x + 8 + s * 6, this.y + this.h, 1);
      b.vx = s * 40;
      g.spawn(b);
    }
  }

  draw(r: Renderer, g: GameContext, alpha: number): void {
    const ctx = r.ctx;
    const x = this.ix(alpha);
    const y = this.iy(alpha);
    const squash = this.grounded ? 1 + Math.max(0, 0.4 - this.timer) * 0.6 : 0.9;
    const w = 16 * squash;
    const h = 14 / squash;
    const left = x + 8 - w / 2;
    const top = y + 14 - h;
    for (let j = 0; j < 4; j++) {
      for (let i = 0; i < 5; i++) {
        if (j === 0 && (i === 0 || i === 4)) continue;
        ctx.fillStyle = this.flash > 0 ? '#FFFFFF' : j === 0 ? '#E3A3EE' : MAGENTA;
        ctx.fillRect(left + (i * w) / 5 + 0.5, top + (j * h) / 4 + 0.5, w / 5 - 1, h / 4 - 1);
      }
    }
    r.text('>_', x + 8, top + h * 0.45, { size: 5, align: 'center', bold: true, color: g.time % 1 < 0.5 ? '#FFFFFF' : '#E3A3EE' });
  }
}
