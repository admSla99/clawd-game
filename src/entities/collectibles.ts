import { COLORS, gray } from '../config';
import { overlaps } from '../core/math';
import type { Renderer } from '../render/renderer';
import { drawSpark, drawToken, panel } from '../render/shapes';
import { CLAWD, CLAWD_PALETTE, drawSprite } from '../render/sprites';
import { Entity, type GameContext } from './entity';

export class Spark extends Entity {
  private t = Math.random() * 10;

  constructor(
    x: number,
    bottom: number,
    readonly index: number,
    /** Already collected in an earlier run: drawn hollow but still collectible. */
    readonly ghost: boolean,
  ) {
    super();
    this.w = 14;
    this.h = 14;
    this.x = x - 7;
    this.y = bottom - 15;
    this.layer = 2;
    this.savePrev();
  }

  update(dt: number, g: GameContext): void {
    this.t += dt;
    if (overlaps(this.rect, g.player.hitbox)) {
      this.alive = false;
      g.collectSpark(this.index, this.x + 7, this.y + 7);
    }
  }

  draw(r: Renderer, g: GameContext): void {
    const ctx = r.ctx;
    const cx = this.x + 7;
    const cy = this.y + 7 + Math.sin(this.t * 2.5) * 2;
    // Soft glow.
    ctx.globalAlpha = 0.12 + Math.sin(g.time * 3) * 0.04;
    ctx.fillStyle = COLORS.orange;
    ctx.beginPath();
    ctx.arc(cx, cy, 11, 0, Math.PI * 2);
    ctx.fill();
    ctx.globalAlpha = this.ghost ? 0.55 : 1;
    drawSpark(ctx, cx, cy, this.t, { ghost: this.ghost });
    ctx.globalAlpha = 1;
  }
}

export class Token extends Entity {
  private t = Math.random() * 10;
  private vy = 0;
  private free: boolean;

  constructor(x: number, y: number, popped = false) {
    super();
    this.w = 8;
    this.h = 8;
    this.x = x - 4;
    this.y = y - 4;
    this.free = popped;
    if (popped) this.vy = -120 - Math.random() * 60;
    this.savePrev();
  }

  update(dt: number, g: GameContext): void {
    this.t += dt;
    const p = g.player;
    if (!this.free && g.magnet > 0 && Math.hypot(p.cx - this.x - 4, p.y + 9 - this.y - 4) < g.magnet) this.free = true;
    if (this.free) {
      // Popped tokens home in on Clawd.
      const dx = p.cx - (this.x + 4);
      const dy = p.y + 8 - (this.y + 4);
      const d = Math.hypot(dx, dy) || 1;
      this.vy += 400 * dt;
      const k = Math.min(1, this.t * 1.5);
      this.x += (dx / d) * 260 * k * dt;
      this.y += (this.vy * (1 - k) + (dy / d) * 260 * k) * dt;
    }
    if (overlaps(this.rect, p.hitbox)) {
      this.alive = false;
      g.collectToken(this.x + 4, this.y + 4);
    }
  }

  draw(r: Renderer): void {
    drawToken(r.ctx, this.x + 4, this.y + 4 + (this.free ? 0 : Math.sin(this.t * 3 + this.x) * 1.5), this.t);
  }
}

export class SubAgent extends Entity {
  private t = Math.random() * 10;
  private rescued = false;
  private rescueT = 0;

  constructor(
    x: number,
    bottom: number,
    readonly index: number,
    readonly ghost: boolean,
  ) {
    super();
    this.w = 14;
    this.h = 12;
    this.x = x - 7;
    this.y = bottom - 12;
    this.layer = 1;
    this.savePrev();
  }

  update(dt: number, g: GameContext): void {
    this.t += dt;
    if (!this.rescued && overlaps(this.rect, g.player.hitbox)) {
      this.rescued = true;
      g.rescueAgent(this.index);
    }
    if (this.rescued) {
      this.rescueT += dt;
      if (this.rescueT > 0.7 && this.rescueT < 1.1) {
        g.particles.emit(this.x + 7, this.y + 6, { count: 3, speed: 30, angle: -Math.PI / 2, spread: 0.4, vy: -140, life: 0.6, color: COLORS.orange });
      }
      if (this.rescueT > 1.1) this.alive = false;
    }
  }

  draw(r: Renderer, g: GameContext): void {
    const ctx = r.ctx;
    const cx = this.x + 7;
    let by = this.y + 12;
    if (this.rescued) {
      const hop = Math.abs(Math.sin(this.rescueT * 10)) * 5;
      by -= this.rescueT > 0.7 ? (this.rescueT - 0.7) * 260 : hop;
      if (this.rescueT > 0.7) {
        ctx.fillStyle = 'rgba(217,119,87,0.35)';
        ctx.fillRect(cx - 4, by - 300, 8, 300);
      }
      drawSprite(ctx, CLAWD.cheer, CLAWD_PALETTE, cx, by, { px: 1 });
      return;
    }
    const wave = Math.sin(this.t * 6) > 0;
    drawSprite(ctx, wave ? CLAWD.cheer : CLAWD.idle, CLAWD_PALETTE, cx, by, {
      px: 1,
      flip: g.player.cx < cx,
      tint: this.ghost ? '#6E5A52' : undefined,
      alpha: this.ghost ? 0.7 : 1,
    });
    // "help" bubble
    if (Math.sin(this.t * 2) > -0.3) {
      panel(ctx, cx - 11, this.y - 13, 22, 9, '#5A5A5A', 'rgba(20,20,20,0.9)');
      r.text('HELP', cx, this.y - 8.5, { size: 4.5, align: 'center', color: COLORS.orangeLight });
    }
  }
}

export class Checkpoint extends Entity {
  active = false;
  private t = 0;

  constructor(
    x: number,
    bottom: number,
    readonly id: number,
  ) {
    super();
    this.w = 16;
    this.h = 28;
    this.x = x - 8;
    this.y = bottom - 28;
    this.savePrev();
  }

  update(dt: number, g: GameContext): void {
    this.t += dt;
    if (!this.active && overlaps(this.rect, g.player.hitbox)) {
      this.active = true;
      this.t = 0;
      g.activateCheckpoint(this.x + 8, this.y + this.h, this.id);
      g.particles.emit(this.x + 8, this.y + 6, { count: 24, speed: 90, life: 0.7, color: [COLORS.orange, COLORS.orangeLight], gravity: 120 });
    }
  }

  draw(r: Renderer): void {
    const ctx = r.ctx;
    const x = this.x;
    const y = this.y;
    const on = this.active;
    // Post.
    for (let py = y + 12; py < y + 28; py += 2) {
      ctx.fillStyle = gray(on ? 150 : 95);
      ctx.fillRect(x + 7, py, 2, 1);
    }
    ctx.fillStyle = gray(80);
    ctx.fillRect(x + 3, y + 27, 10, 1);
    // Screen.
    panel(ctx, x - 1, y, 18, 12, on ? COLORS.orange : '#6A6A6A', '#121212');
    if (on) {
      r.text(this.t < 1.2 ? 'OK' : '>_', x + 8, y + 6.5, { size: 5, align: 'center', color: COLORS.orange, bold: true });
    } else if (Math.floor(this.t * 2) % 2 === 0) {
      ctx.fillStyle = gray(130);
      ctx.fillRect(x + 4, y + 7, 4, 1);
    }
    if (on && this.t < 1.5) {
      r.text('STATE SAVED', x + 8, y - 8 - this.t * 6, { size: 4.5, align: 'center', color: COLORS.orangeLight, alpha: 1 - this.t / 1.5 });
    }
  }
}

export class Goal extends Entity {
  private t = 0;
  private reached = false;

  constructor(x: number, bottom: number) {
    super();
    this.w = 28;
    this.h = 40;
    this.x = x - 14;
    this.y = bottom - 40;
    this.savePrev();
  }

  update(dt: number, g: GameContext): void {
    this.t += dt;
    if (Math.random() < dt * 20) {
      const a = Math.random() * Math.PI * 2;
      g.particles.emit(this.x + 14 + Math.cos(a) * 12, this.y + 18 + Math.sin(a) * 16, {
        count: 1,
        speed: 12,
        life: 0.8,
        color: COLORS.orange,
        vy: -12,
      });
    }
    if (!this.reached && overlaps({ x: this.x + 6, y: this.y, w: 16, h: this.h }, g.player.hitbox)) {
      this.reached = true;
      g.reachGoal(this.x + 14, this.y + 20);
    }
  }

  draw(r: Renderer): void {
    const ctx = r.ctx;
    const cx = this.x + 14;
    const cy = this.y + 19;
    // Dotted elliptical gate.
    for (let i = 0; i < 40; i++) {
      const a = (i / 40) * Math.PI * 2 + this.t * 1.5;
      const px = cx + Math.cos(a) * 12;
      const py = cy + Math.sin(a) * 18;
      const b = (Math.sin(a * 3 - this.t * 5) + 1) / 2;
      ctx.fillStyle = b > 0.6 ? COLORS.orangeLight : COLORS.orange;
      ctx.fillRect(px - 0.75, py - 0.75, 1.5, 1.5);
    }
    ctx.globalAlpha = 0.18 + Math.sin(this.t * 4) * 0.06;
    ctx.fillStyle = COLORS.orange;
    ctx.beginPath();
    ctx.ellipse(cx, cy, 9, 15, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.globalAlpha = 1;
    r.text('EXIT', cx, this.y - 6, { size: 5, align: 'center', color: COLORS.orangeLight, bold: true });
  }
}

export class Sign extends Entity {
  private show = 0;

  constructor(
    x: number,
    bottom: number,
    readonly text: string,
  ) {
    super();
    this.w = 12;
    this.h = 16;
    this.x = x - 6;
    this.y = bottom - 16;
    this.savePrev();
  }

  update(dt: number, g: GameContext): void {
    const near = Math.abs(g.player.cx - (this.x + 6)) < 52 && Math.abs(g.player.bottom - (this.y + 16)) < 48;
    this.show += ((near ? 1 : 0) - this.show) * Math.min(1, dt * 10);
  }

  draw(r: Renderer): void {
    const ctx = r.ctx;
    const x = this.x;
    const y = this.y;
    ctx.fillStyle = gray(90);
    for (let py = y + 9; py < y + 16; py += 2) ctx.fillRect(x + 5, py, 2, 1);
    panel(ctx, x - 1, y, 14, 10, '#8A8A8A', '#181818');
    r.text('?', x + 6, y + 5.5, { size: 6, align: 'center', color: COLORS.orange, bold: true });
    if (this.show > 0.02) {
      const lines = this.text.split('\n');
      const w = Math.max(...lines.map((l) => r.measure(l, 5.5))) + 12;
      const h = lines.length * 8 + 6;
      const bx = x + 6 - w / 2;
      const by = y - h - 8 - (1 - this.show) * 6;
      ctx.globalAlpha = this.show;
      panel(ctx, bx, by, w, h, '#6A6A6A', 'rgba(18,18,18,0.94)');
      lines.forEach((l, i) => r.text(l, x + 6, by + 7 + i * 8, { size: 5.5, align: 'center', color: COLORS.textBright }));
      ctx.globalAlpha = 1;
    }
  }
}
