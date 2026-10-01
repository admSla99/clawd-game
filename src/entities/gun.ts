import type { Sfx } from '../core/audio';
import { WEAPONS, type Loadout, type WeaponDef, type WeaponId } from '../weapons';
import { Bullet } from './bullets';
import type { GameContext } from './entity';

const SHOT_SFX: Record<WeaponDef['kind'], Sfx> = {
  token: 'gunToken',
  pellet: 'gunPellet',
  glyph: 'gunGlyph',
  beam: 'gunBeam',
  orb: 'gunOrb',
};

/**
 * Clawd's weapon. Every shot adds "context" heat; fill the context window and
 * the gun overflows and has to cool down before it fires again.
 */
export class Gun {
  weapon: WeaponDef;
  heat = 0;
  overheated = 0;
  cooldown = 0;
  /** Visual: muzzle flash and recoil timers. */
  flash = 0;
  recoil = 0;
  private shotCount = 0;

  constructor(
    id: WeaponId,
    private loadout: Loadout,
  ) {
    this.weapon = WEAPONS[id];
  }

  get heatCap(): number {
    return this.loadout.heatCap;
  }

  setWeapon(id: WeaponId): void {
    this.weapon = WEAPONS[id];
    this.cooldown = Math.max(this.cooldown, 0.12);
  }

  /** Returns true when it fired this tick. */
  update(dt: number, trigger: boolean, g: GameContext, pivotX: number, pivotY: number, angle: number): boolean {
    this.cooldown -= dt;
    this.flash = Math.max(0, this.flash - dt);
    this.recoil = Math.max(0, this.recoil - dt * 6);
    if (this.overheated > 0) {
      this.overheated -= dt;
      this.heat = Math.max(0, this.heat - this.heatCap * 0.75 * dt);
      if (this.overheated <= 0) this.heat = 0;
      return false;
    }
    this.heat = Math.max(0, this.heat - 32 * dt);
    if (!trigger || this.cooldown > 0) return false;

    const w = this.weapon;
    this.cooldown = 1 / (w.fireRate * this.loadout.rateMult);
    this.heat += w.heat;
    const mx = pivotX + Math.cos(angle) * 16;
    const my = pivotY + Math.sin(angle) * 16;
    const damage = w.damage * this.loadout.damageMult;
    if (w.kind === 'beam') {
      g.fireBeam(mx, my, angle, damage);
    } else {
      for (let i = 0; i < w.pellets; i++) {
        const fanOffset = w.pellets > 1 ? -w.fan / 2 + (w.fan * i) / (w.pellets - 1) : 0;
        const a = angle + fanOffset + (Math.random() - 0.5) * 2 * w.spread;
        const speed = w.speed * (w.pellets > 1 ? 0.85 + Math.random() * 0.3 : 1);
        g.spawn(new Bullet(mx, my, a, speed, w, damage));
      }
    }
    this.shotCount++;
    if (w.kind !== 'beam' || this.shotCount % 4 === 0) g.sfx(SHOT_SFX[w.kind]);
    this.flash = 0.06;
    this.recoil = w.kind === 'orb' ? 1 : w.kind === 'pellet' ? 0.8 : 0.35;
    if (w.kind === 'orb') g.shake(0.15);
    if (w.kind === 'pellet') g.shake(0.08);
    g.particles.emit(mx, my, { count: w.kind === 'pellet' ? 6 : 2, speed: 60, angle, spread: 0.8, life: 0.12, color: ['#FFFFFF', w.color] });

    if (this.heat >= this.heatCap) {
      this.overheated = 1.3;
      g.sfx('overheat');
    }
    return true;
  }
}
