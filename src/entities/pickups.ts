import { COLORS } from '../config';
import { overlaps } from '../core/math';
import { drawGun } from '../render/clawdView';
import type { Renderer } from '../render/renderer';
import { Entity, type GameContext } from './entity';

/** The Token Blaster lying in the arena after the first boss. */
export class WeaponPickup extends Entity {
  private t = 0;
  private taken = false;

  constructor(x: number, bottom: number) {
    super();
    this.w = 20;
    this.h = 16;
    this.x = x - 10;
    this.y = bottom - 26;
    this.layer = 2;
    this.savePrev();
  }

  update(dt: number, g: GameContext): void {
    this.t += dt;
    if (Math.random() < dt * 25) {
      g.particles.emit(this.x + 10 + (Math.random() - 0.5) * 16, this.y + 16, { count: 1, speed: 10, vy: -40, life: 0.8, color: [COLORS.orange, COLORS.orangeLight] });
    }
    if (!this.taken && overlaps(this.rect, g.player.hitbox)) {
      this.taken = true;
      this.alive = false;
      g.onWeaponFound(this.x + 10, this.y + 8);
    }
  }

  draw(r: Renderer): void {
    const ctx = r.ctx;
    const cx = this.x + 10;
    const cy = this.y + 8 + Math.sin(this.t * 2.5) * 2;
    // Beam of light from above.
    ctx.globalAlpha = 0.1 + Math.sin(this.t * 3) * 0.04;
    ctx.fillStyle = COLORS.orange;
    ctx.fillRect(cx - 9, cy - 300, 18, 300 + 18);
    ctx.globalAlpha = 1;
    drawGun(ctx, 'blaster', cx - 6, cy, Math.sin(this.t) * 0.15, 1.6, 0);
    r.text('?!', cx, cy - 16, { size: 6, align: 'center', bold: true, color: COLORS.orangeLight, alpha: 0.6 + Math.sin(this.t * 5) * 0.4 });
  }
}
