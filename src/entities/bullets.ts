import { COLORS } from '../config';
import type { Renderer } from '../render/renderer';
import { isSolidTile } from '../world/tiles';
import type { WeaponDef } from '../weapons';
import { Entity, type GameContext } from './entity';
import type { BulletKind } from '../weapons';

const GLYPHS = 'abcdefghijklmnopqrstuvwxyz{}();=<>/+*01';

/** A projectile fired by Clawd. Collisions with enemies are resolved by the game. */
export class Bullet extends Entity {
  readonly kind: BulletKind;
  readonly damage: number;
  readonly color: string;
  readonly splash: WeaponDef['splash'];
  readonly hits = new Set<Entity>();
  pierce: number;
  vx: number;
  vy: number;
  private life: number;
  private t = 0;
  private glyph: string;

  constructor(x: number, y: number, angle: number, speed: number, def: WeaponDef, damage: number) {
    super();
    this.kind = def.kind;
    this.damage = damage;
    this.color = def.color;
    this.splash = def.splash;
    this.pierce = def.pierce;
    this.life = def.life;
    const size = this.kind === 'orb' ? 9 : 4;
    this.w = size;
    this.h = size;
    this.x = x - size / 2;
    this.y = y - size / 2;
    this.vx = Math.cos(angle) * speed;
    this.vy = Math.sin(angle) * speed;
    this.layer = 3;
    this.glyph = GLYPHS[Math.floor(Math.random() * GLYPHS.length)];
    this.savePrev();
  }

  get cx(): number {
    return this.x + this.w / 2;
  }

  get cy(): number {
    return this.y + this.h / 2;
  }

  update(dt: number, g: GameContext): void {
    this.t += dt;
    this.life -= dt;
    this.x += this.vx * dt;
    this.y += this.vy * dt;
    if (this.kind === 'orb' && Math.random() < 0.7) {
      g.particles.emit(this.cx, this.cy, { count: 1, speed: 15, life: 0.35, color: [COLORS.orange, COLORS.orangeLight] });
    }
    const tile = g.level.get(Math.floor(this.cx / 16), Math.floor(this.cy / 16));
    if (isSolidTile(tile)) {
      this.impact(g);
      return;
    }
    if (this.life <= 0) {
      if (this.splash) this.impact(g);
      else this.alive = false;
    }
  }

  /** Stop here: explode (orbs) or puff. */
  impact(g: GameContext): void {
    if (!this.alive) return;
    this.alive = false;
    if (this.splash) {
      g.explode(this.cx, this.cy, this.splash.radius, this.splash.damage);
    } else {
      g.particles.emit(this.cx - this.vx * 0.01, this.cy - this.vy * 0.01, { count: 4, speed: 50, life: 0.2, color: [this.color, '#FFFFFF'] });
    }
  }

  draw(r: Renderer, _g: GameContext, alpha: number): void {
    const ctx = r.ctx;
    const x = this.ix(alpha) + this.w / 2;
    const y = this.iy(alpha) + this.h / 2;
    switch (this.kind) {
      case 'token': {
        // Spinning coin with a short trail.
        const w = Math.max(0.6, Math.abs(Math.cos(this.t * 30)) * 2.5);
        ctx.globalAlpha = 0.35;
        ctx.fillStyle = COLORS.orange;
        ctx.fillRect(x - this.vx * 0.012 - 1, y - this.vy * 0.012 - 1, 2, 2);
        ctx.globalAlpha = 1;
        ctx.fillStyle = COLORS.orangeLight;
        ctx.fillRect(x - w, y - 2, w * 2, 4);
        ctx.fillStyle = COLORS.orange;
        ctx.fillRect(x - w * 0.5, y - 1, w, 2);
        break;
      }
      case 'pellet':
        ctx.fillStyle = this.color;
        ctx.fillRect(x - 1.5, y - 1.5, 3, 3);
        ctx.globalAlpha = 0.4;
        ctx.fillRect(x - this.vx * 0.015 - 1, y - this.vy * 0.015 - 1, 2, 2);
        ctx.globalAlpha = 1;
        break;
      case 'glyph':
        r.text(this.glyph, x, y, { size: 6, align: 'center', color: Math.floor(this.t * 20) % 3 === 0 ? COLORS.orangeLight : this.color, bold: true });
        break;
      case 'orb': {
        for (let i = 0; i < 10; i++) {
          const a = (i / 10) * Math.PI * 2 + this.t * 8;
          ctx.fillStyle = i % 2 ? COLORS.orangeLight : '#FFFFFF';
          ctx.fillRect(x + Math.cos(a) * 5 - 0.75, y + Math.sin(a) * 5 - 0.75, 1.5, 1.5);
        }
        ctx.fillStyle = COLORS.orange;
        ctx.fillRect(x - 2.5, y - 2.5, 5, 5);
        break;
      }
      case 'beam':
        break;
    }
  }
}
