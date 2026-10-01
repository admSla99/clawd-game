import { PLAYER } from '../config';
import type { InputView } from '../core/input';
import { approach, sign, type Rect } from '../core/math';
import { moveX, moveY, rectHitsSolid, type Body } from '../world/collision';
import type { Level } from '../world/level';

/** Anything Clawd can stand on that is not a tile (moving or fake platforms). */
export interface Platform {
  x: number;
  /** Top surface. */
  y: number;
  w: number;
  /** Movement during the current tick. */
  dx: number;
  dy: number;
  active: boolean;
  onStand?(): void;
}

export interface PlayerWorld {
  level: Level;
  platforms: Platform[];
}

export type PlayerState = 'normal' | 'spin' | 'poundWindup' | 'pound' | 'poundLand' | 'hurt' | 'dead';

export type PlayerEvent =
  | 'jump'
  | 'land'
  | 'hardLand'
  | 'hoverStart'
  | 'hoverStop'
  | 'spin'
  | 'poundStart'
  | 'poundLand'
  | 'dropThrough';

export class Player implements Body {
  x = 0;
  y = 0;
  w = PLAYER.width;
  h = PLAYER.height;
  vx = 0;
  vy = 0;
  prevX = 0;
  prevY = 0;
  facing: 1 | -1 = 1;

  state: PlayerState = 'normal';
  stateTimer = 0;
  grounded = false;
  onOneWay = false;
  coyote = 0;
  jumpBuffer = 0;
  jumping = false;
  hoverLeft = PLAYER.hoverDuration;
  hovering = false;
  spinCooldown = 0;
  airSpinUsed = false;
  invuln = 0;
  dropTimer = 0;
  riding: Platform | null = null;
  noclip = false;
  /** Holding a weapon (world 2): the attack button shoots instead of spinning. */
  armed = false;
  /** Aim angle in radians (0 = right), set by the game each tick when armed. */
  aim = 0;
  hoverMax: number = PLAYER.hoverDuration;

  // Visual-only state.
  squashX = 1;
  squashY = 1;
  anim = 0;
  blinkTimer = 2.5;
  lastFallSpeed = 0;

  readonly events: PlayerEvent[] = [];

  constructor(x: number, bottom: number) {
    this.spawn(x, bottom);
  }

  /** Place Clawd with feet at (x, bottom). */
  spawn(x: number, bottom: number): void {
    this.x = x - this.w / 2;
    this.y = bottom - this.h;
    this.prevX = this.x;
    this.prevY = this.y;
    this.vx = 0;
    this.vy = 0;
    this.state = 'normal';
    this.stateTimer = 0;
    this.grounded = false;
    this.hovering = false;
    this.jumping = false;
    this.riding = null;
    this.hoverLeft = this.hoverMax;
    this.invuln = 0;
    this.squashX = 1;
    this.squashY = 1;
  }

  get cx(): number {
    return this.x + this.w / 2;
  }

  get bottom(): number {
    return this.y + this.h;
  }

  get hitbox(): Rect {
    return { x: this.x + 2, y: this.y + 3, w: this.w - 4, h: this.h - 3 };
  }

  /** Spin attack area, or null when not spinning. */
  get attackBox(): Rect | null {
    if (this.state !== 'spin') return null;
    const r = PLAYER.spinReach;
    return { x: this.x - r, y: this.y - 2, w: this.w + r * 2, h: this.h + 4 };
  }

  /** The hover jet that damages what is below Clawd. */
  get hoverBeam(): Rect | null {
    if (!this.hovering) return null;
    return { x: this.cx - 6, y: this.bottom, w: 12, h: 30 };
  }

  update(dt: number, input: InputView, world: PlayerWorld): void {
    const P = PLAYER;
    const level = world.level;
    this.prevX = this.x;
    this.prevY = this.y;
    this.events.length = 0;
    this.anim += dt;

    this.blinkTimer -= dt;
    if (this.blinkTimer < -0.12) this.blinkTimer = 2 + Math.random() * 3;
    this.squashX += (1 - this.squashX) * Math.min(1, dt * 12);
    this.squashY += (1 - this.squashY) * Math.min(1, dt * 12);

    if (this.noclip) {
      const s = 320;
      const dx = (input.held('right') ? 1 : 0) - (input.held('left') ? 1 : 0);
      const dy = (input.held('down') ? 1 : 0) - (input.held('up') ? 1 : 0);
      this.x += dx * s * dt;
      this.y += dy * s * dt;
      this.vx = this.vy = 0;
      this.grounded = false;
      return;
    }
    if (this.state === 'dead') return;

    this.invuln = Math.max(0, this.invuln - dt);
    this.spinCooldown -= dt;
    this.dropTimer -= dt;
    this.jumpBuffer = Math.max(0, this.jumpBuffer - dt);
    if (input.pressed('jump')) this.jumpBuffer = P.jumpBuffer;

    // Ride moving platforms.
    if (this.riding) {
      const p = this.riding;
      if (!p.active || this.x + this.w <= p.x || this.x >= p.x + p.w) {
        this.riding = null;
      } else {
        moveX(this, p.dx, level);
        moveY(this, p.y - this.h - this.y, level);
      }
    }

    if (this.grounded) {
      this.coyote = P.coyoteTime;
      this.hoverLeft = this.hoverMax;
      this.airSpinUsed = false;
    } else {
      this.coyote = Math.max(0, this.coyote - dt);
    }

    const dir = (input.held('right') ? 1 : 0) - (input.held('left') ? 1 : 0);

    // Horizontal movement.
    if (this.state === 'poundWindup' || this.state === 'pound' || this.state === 'poundLand') {
      this.vx = 0;
    } else if (this.state === 'hurt') {
      this.vx = approach(this.vx, 0, P.airDecel * dt);
    } else {
      const target = dir * P.runSpeed;
      let accel: number;
      if (this.grounded) {
        if (dir === 0) accel = P.groundDecel;
        else if (this.vx !== 0 && sign(this.vx) !== dir) accel = P.turnAccel;
        else accel = P.groundAccel;
      } else {
        accel = dir === 0 ? P.airDecel : P.airAccel;
      }
      this.vx = approach(this.vx, target, accel * dt);
      if (dir !== 0) this.facing = dir > 0 ? 1 : -1;
    }

    // Actions.
    if (this.state === 'normal' || this.state === 'spin') {
      const spinPressed = input.pressed('spin') || (!this.armed && input.pressed('attack'));
      if (!this.grounded && input.held('down') && spinPressed) {
        this.startPound();
      } else if (spinPressed && this.spinCooldown <= 0 && this.state !== 'spin') {
        this.startSpin();
      }
    }
    if (this.state === 'normal' || this.state === 'spin') {
      if (this.grounded && this.onOneWay && input.held('down') && this.jumpBuffer > 0) {
        this.dropTimer = P.dropThroughTime;
        this.jumpBuffer = 0;
        this.grounded = false;
        this.riding = null;
        this.coyote = 0;
        this.y += 1;
        this.events.push('dropThrough');
      } else if (this.jumpBuffer > 0 && (this.grounded || this.coyote > 0)) {
        this.vy = -P.jumpVelocity;
        this.jumping = true;
        this.grounded = false;
        this.coyote = 0;
        this.jumpBuffer = 0;
        this.riding = null;
        this.squashX = 0.72;
        this.squashY = 1.3;
        this.events.push('jump');
      }
    }

    // Variable jump height.
    if (this.jumping && this.vy < 0 && !input.held('jump')) {
      this.vy *= P.jumpCutMult;
      this.jumping = false;
    }
    if (this.vy >= 0) this.jumping = false;

    // Hover: hold jump in the air once rising has (almost) stopped.
    const wantHover =
      this.state === 'normal' &&
      !this.grounded &&
      this.coyote <= 0 &&
      this.hoverLeft > 0 &&
      input.held('jump') &&
      this.vy > -40;
    if (wantHover) {
      if (!this.hovering) {
        this.hovering = true;
        this.events.push('hoverStart');
      }
      this.hoverLeft -= dt;
      this.vy = approach(this.vy, P.hoverFallSpeed, P.hoverAccel * dt);
    } else if (this.hovering) {
      this.hovering = false;
      this.events.push('hoverStop');
    }

    // Gravity.
    if (this.state === 'poundWindup' || this.state === 'poundLand') {
      this.vy = 0;
    } else if (this.state === 'pound') {
      this.vy = P.poundSpeed;
    } else if (!this.hovering) {
      let g = P.gravity;
      if (Math.abs(this.vy) < P.apexThreshold && input.held('jump')) g *= P.apexGravityMult;
      else if (this.vy > 0) g *= P.fallGravityMult;
      this.vy = Math.min(this.vy + g * dt, P.maxFall);
    }

    // State timers.
    this.stateTimer -= dt;
    if (this.stateTimer <= 0) {
      if (this.state === 'spin') {
        this.state = 'normal';
        this.spinCooldown = P.spinCooldown;
      } else if (this.state === 'poundWindup') {
        this.state = 'pound';
        this.vy = P.poundSpeed;
      } else if (this.state === 'hurt' || this.state === 'poundLand') {
        this.state = 'normal';
      }
    }

    // Integrate.
    const wasGrounded = this.grounded;
    const fallSpeed = this.vy;
    if (moveX(this, this.vx * dt, level)) this.vx = 0;

    const dy = this.vy * dt;
    if (dy < 0) this.cornerCorrect(dy, level);
    const res = moveY(this, dy, level, this.dropTimer > 0);
    if (res.ceiling) {
      this.vy = 0;
      this.jumping = false;
    }

    let landed = res.floor;
    let onOneWay = res.oneWay;
    let ride: Platform | null = null;
    if (!landed && this.vy >= 0 && this.dropTimer <= 0) {
      for (const p of world.platforms) {
        if (!p.active) continue;
        if (this.x + this.w <= p.x || this.x >= p.x + p.w) continue;
        const prevBottom = this.prevY + this.h;
        const prevTop = p.y - p.dy;
        if (prevBottom <= prevTop + 1.5 && this.bottom >= p.y) {
          this.y = p.y - this.h;
          landed = true;
          onOneWay = true;
          ride = p;
          break;
        }
      }
    }
    this.riding = ride;
    if (ride) ride.onStand?.();

    if (landed) {
      if (!wasGrounded) {
        this.lastFallSpeed = fallSpeed;
        if (this.state === 'pound') {
          this.state = 'poundLand';
          this.stateTimer = 0.16;
          this.squashX = 1.45;
          this.squashY = 0.6;
          this.events.push('poundLand');
        } else if (fallSpeed > 120) {
          const k = Math.min(1, fallSpeed / P.maxFall);
          this.squashX = 1 + 0.35 * k;
          this.squashY = 1 - 0.3 * k;
          this.events.push(fallSpeed > 300 ? 'hardLand' : 'land');
        }
        if (this.hovering) {
          this.hovering = false;
          this.events.push('hoverStop');
        }
      }
      this.vy = 0;
      this.grounded = true;
      this.onOneWay = onOneWay;
    } else {
      this.grounded = false;
    }
  }

  /** Nudge sideways when clipping the corner of a ceiling while jumping. */
  private cornerCorrect(dy: number, level: Level): void {
    if (!rectHitsSolid(this.x, this.y + dy, this.w, this.h, level)) return;
    for (let off = 1; off <= PLAYER.cornerCorrection; off++) {
      for (const s of [1, -1]) {
        const nx = this.x + off * s;
        if (!rectHitsSolid(nx, this.y + dy, this.w, this.h, level) && !rectHitsSolid(nx, this.y, this.w, this.h, level)) {
          this.x = nx;
          return;
        }
      }
    }
  }

  private startSpin(): void {
    this.state = 'spin';
    this.stateTimer = PLAYER.spinDuration;
    if (!this.grounded && !this.airSpinUsed) {
      this.vy = Math.min(this.vy, -PLAYER.spinHop);
      this.airSpinUsed = true;
      this.jumping = false;
    }
    if (this.hovering) {
      this.hovering = false;
      this.events.push('hoverStop');
    }
    this.events.push('spin');
  }

  private startPound(): void {
    this.state = 'poundWindup';
    this.stateTimer = PLAYER.poundWindup;
    this.vx = 0;
    this.vy = 0;
    this.jumping = false;
    if (this.hovering) {
      this.hovering = false;
      this.events.push('hoverStop');
    }
    this.events.push('poundStart');
  }

  /** Called by the game when a ground pound broke through the floor. */
  continuePound(): void {
    this.state = 'pound';
    this.vy = PLAYER.poundSpeed;
    this.grounded = false;
  }

  /** Bounce off an enemy's head. */
  bounce(held: boolean): void {
    this.vy = -(held ? PLAYER.stompBounceHeld : PLAYER.stompBounce);
    this.jumping = held;
    this.grounded = false;
    this.riding = null;
    this.hoverLeft = this.hoverMax;
    this.airSpinUsed = false;
    if (this.state === 'pound' || this.state === 'poundWindup') this.state = 'normal';
    this.squashX = 0.8;
    this.squashY = 1.25;
  }

  /** Returns true when the hit landed (not invulnerable). */
  hurt(fromX: number): boolean {
    if (this.invuln > 0 || this.state === 'dead' || this.noclip) return false;
    this.state = 'hurt';
    this.stateTimer = PLAYER.hurtStun;
    this.invuln = PLAYER.hurtInvuln;
    this.vx = (this.cx < fromX ? -1 : 1) * PLAYER.hurtKnockX;
    this.vy = -PLAYER.hurtKnockY;
    this.grounded = false;
    this.riding = null;
    this.jumping = false;
    if (this.hovering) {
      this.hovering = false;
      this.events.push('hoverStop');
    }
    return true;
  }
}
