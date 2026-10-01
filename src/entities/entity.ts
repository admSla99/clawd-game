import type { AudioEngine, Sfx } from '../core/audio';
import type { Camera } from '../core/camera';
import { lerp, type Rect } from '../core/math';
import type { Particles } from '../render/particles';
import type { Renderer } from '../render/renderer';
import type { Level } from '../world/level';
import type { Platform, Player } from './player';

/** What entities may ask of the running level. Implemented by GameScene. */
export interface GameContext {
  level: Level;
  player: Player;
  particles: Particles;
  audio: AudioEngine;
  camera: Camera;
  time: number;
  platforms: Platform[];
  spawn(e: Entity): void;
  sfx(s: Sfx): void;
  hitstop(seconds: number): void;
  shake(amount: number): void;
  hurtPlayer(fromX: number): void;
  collectSpark(index: number, x: number, y: number): void;
  collectToken(x: number, y: number): void;
  rescueAgent(index: number): void;
  activateCheckpoint(x: number, bottom: number, id: number): void;
  reachGoal(x: number, y: number): void;
  onBossDefeated(x: number, y: number): void;
  onWeaponFound(x: number, y: number): void;
  /** Area damage to enemies; also breaks corrupted blocks. */
  explode(x: number, y: number, radius: number, damage: number): void;
  /** Hit-scan beam from (x, y) along `angle`. */
  fireBeam(x: number, y: number, angle: number, damage: number): void;
  /** Radius in which loose tokens fly to Clawd (0 = no magnet). */
  magnet: number;
}

export abstract class Entity {
  x = 0;
  y = 0;
  w = 0;
  h = 0;
  prevX = 0;
  prevY = 0;
  alive = true;
  /** Higher draws later (on top). */
  layer = 0;

  savePrev(): void {
    this.prevX = this.x;
    this.prevY = this.y;
  }

  get rect(): Rect {
    return { x: this.x, y: this.y, w: this.w, h: this.h };
  }

  ix(alpha: number): number {
    return lerp(this.prevX, this.x, alpha);
  }

  iy(alpha: number): number {
    return lerp(this.prevY, this.y, alpha);
  }

  abstract update(dt: number, g: GameContext): void;
  abstract draw(r: Renderer, g: GameContext, alpha: number): void;
}

export type HitKind = 'stomp' | 'spin' | 'beam' | 'pound' | 'shot';

/** Base for things that hurt Clawd and can (usually) be defeated. */
export abstract class Enemy extends Entity {
  hp = 1;
  stompable = true;
  /** Cannot be damaged at all (crushers). */
  invincible = false;
  /** Projectiles: destroyed by spin, do not bounce Clawd. */
  projectile = false;
  /** Projectiles that Clawd's bullets can shoot down. */
  cancellable = true;
  /** Projectiles that vanish when they hit Clawd. */
  consumeOnHit = true;
  /** Tokens that pop out when defeated. */
  tokens = 2;
  flash = 0;
  /** Seconds of immunity after taking a hit. */
  immune = 0;

  /** Area that damages Clawd on contact (null = harmless right now). */
  get hurtbox(): Rect | null {
    return this.rect;
  }

  /** Returns true if the hit was accepted. */
  hit(kind: HitKind, g: GameContext, damage = 1): boolean {
    if (this.invincible || this.immune > 0) return false;
    this.hp -= damage;
    this.flash = 0.12;
    if (this.hp <= 0) {
      this.die(kind, g);
    } else if (kind !== 'shot') {
      // Melee hits give a short grace period so one spin is one hit.
      this.immune = 0.3;
    }
    return true;
  }

  protected die(_kind: HitKind, g: GameContext): void {
    this.alive = false;
    const cx = this.x + this.w / 2;
    const cy = this.y + this.h / 2;
    g.particles.emit(cx, cy, { count: 22, speed: 140, life: 0.6, color: ['#FFFFFF', '#BDBDBD', '#E0605A'], gravity: 300, size: 1.5 });
    g.particles.emit(cx, cy, { count: 6, speed: 40, life: 0.4, color: '#D97757', size: 2 });
    g.sfx('enemyDie');
    g.hitstop(0.05);
    g.shake(0.18);
  }

  tickTimers(dt: number): void {
    this.flash = Math.max(0, this.flash - dt);
    this.immune = Math.max(0, this.immune - dt);
  }
}
