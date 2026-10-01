import { COLORS, TILE, gray } from '../../config';
import type { Rect } from '../../core/math';
import type { Renderer } from '../../render/renderer';
import { Enemy, type GameContext, type HitKind } from '../entity';
import { Shot } from '../enemies';
import { FakePlatform } from '../platforms';

type Mode = 'intro' | 'appear' | 'attack' | 'descend' | 'vulnerable' | 'hurt' | 'vanish' | 'dead';

const MAX_HP = 3;

/**
 * Mini-boss of world 1: a glitching cloud of dots. It teleports, fires dot
 * bursts, rains shots and conjures fake platforms. After each attack it sinks
 * to the floor, dazed — that is the moment to stomp or spin it.
 */
export class Hallucination extends Enemy {
  readonly maxHp = MAX_HP;
  private mode: Mode = 'intro';
  private timer = 2.2;
  private t = 0;
  private attackIndex = 0;
  private volley = 0;
  private cx: number;
  private cy: number;
  private tx: number;
  private ty: number;
  private warnings: { x: number; t: number }[] = [];
  private visible = 0;

  constructor(
    x: number,
    y: number,
    private floorY: number,
    private arenaW: number,
  ) {
    super();
    this.w = 34;
    this.h = 34;
    this.cx = x;
    this.cy = y;
    this.tx = x;
    this.ty = y;
    this.hp = MAX_HP;
    this.invincible = true;
    this.stompable = false;
    this.layer = 2;
    this.sync();
    this.savePrev();
  }

  get vulnerable(): boolean {
    return this.mode === 'vulnerable';
  }

  get dead(): boolean {
    return this.mode === 'dead';
  }

  private get phase(): number {
    return MAX_HP - this.hp; // 0, 1, 2 — gets faster as it is hurt
  }

  private sync(): void {
    this.x = this.cx - this.w / 2;
    this.y = this.cy - this.h / 2;
  }

  get hurtbox(): Rect | null {
    if (this.mode === 'vulnerable' || this.mode === 'dead' || this.mode === 'hurt' || this.visible < 0.6) return null;
    return { x: this.x + 4, y: this.y + 4, w: this.w - 8, h: this.h - 8 };
  }

  hit(_kind: HitKind, g: GameContext): boolean {
    if (this.mode !== 'vulnerable') return false;
    this.hp--;
    this.flash = 0.4;
    this.stompable = false;
    this.invincible = true;
    g.sfx('bossHit');
    g.shake(0.5);
    g.hitstop(0.12);
    g.particles.emit(this.cx, this.cy, { count: 40, speed: 160, life: 0.7, color: ['#FFFFFF', COLORS.red, COLORS.cyan], gravity: 200, size: 1.5 });
    if (this.hp <= 0) {
      this.mode = 'dead';
      this.timer = 2.2;
    } else {
      this.mode = 'hurt';
      this.timer = 0.8;
    }
    return true;
  }

  private pickAnchor(g: GameContext): void {
    const choices = [0.22, 0.5, 0.78].map((f) => f * this.arenaW);
    const far = choices.filter((x) => Math.abs(x - g.player.cx) > 60);
    const pool = far.length ? far : choices;
    this.tx = pool[Math.floor(Math.random() * pool.length)];
    this.ty = this.floorY - TILE * (5.5 + Math.random() * 2);
  }

  update(dt: number, g: GameContext): void {
    this.tickTimers(dt);
    this.t += dt;
    this.timer -= dt;
    for (const w of this.warnings) w.t -= dt;
    this.warnings = this.warnings.filter((w) => w.t > -0.2);

    // Glide towards the target position.
    const k = Math.min(1, dt * (this.mode === 'descend' ? 5 : 8));
    this.cx += (this.tx - this.cx) * k;
    this.cy += (this.ty - this.cy) * k;

    const speedUp = 1 + this.phase * 0.25;
    switch (this.mode) {
      case 'intro':
        this.visible = Math.min(1, this.visible + dt * 0.8);
        if (this.timer <= 0) this.next('attack', 0.6);
        break;
      case 'appear':
        this.visible = Math.min(1, this.visible + dt * 3);
        if (this.timer <= 0) this.next('attack', 0.5);
        break;
      case 'attack':
        if (this.timer <= 0) this.doAttack(g, speedUp);
        break;
      case 'descend':
        if (Math.abs(this.cy - this.ty) < 3) {
          this.mode = 'vulnerable';
          this.timer = Math.max(1.6, 2.8 - this.phase * 0.4);
          this.stompable = true;
          this.invincible = false;
        }
        break;
      case 'vulnerable':
        this.cy = this.ty + Math.sin(this.t * 3) * 1.5;
        if (Math.random() < dt * 8) g.particles.emit(this.cx + (Math.random() - 0.5) * 20, this.y, { count: 1, speed: 10, vy: -20, life: 0.6, color: gray(180) });
        if (this.timer <= 0) this.vanish(g);
        break;
      case 'hurt':
        this.cx += Math.sin(this.t * 80) * 0.8;
        if (this.timer <= 0) this.vanish(g);
        break;
      case 'vanish':
        this.visible = Math.max(0, this.visible - dt * 4);
        if (this.timer <= 0) {
          this.pickAnchor(g);
          this.cx = this.tx;
          this.cy = this.ty;
          this.mode = 'appear';
          this.timer = 0.6;
          g.sfx('bossTeleport');
        }
        break;
      case 'dead':
        if (Math.random() < dt * 30) {
          g.particles.emit(this.cx + (Math.random() - 0.5) * 30, this.cy + (Math.random() - 0.5) * 30, {
            count: 6,
            speed: 120,
            life: 0.6,
            color: ['#FFFFFF', COLORS.red, COLORS.cyan, COLORS.orange],
            size: 1.5,
          });
          g.shake(0.06);
        }
        this.visible = Math.max(0, this.timer / 2.2);
        if (this.timer <= 0 && this.alive) {
          this.alive = false;
          g.particles.emit(this.cx, this.cy, { count: 120, speed: 220, life: 1.2, color: ['#FFFFFF', COLORS.orange, COLORS.orangeLight], size: 2, drag: 1.5 });
          g.shake(0.8);
          g.onBossDefeated(this.cx, this.floorY);
        }
        break;
    }
    this.sync();
  }

  private next(mode: Mode, time: number): void {
    this.mode = mode;
    this.timer = time;
  }

  private vanish(g: GameContext): void {
    this.mode = 'vanish';
    this.timer = 0.35;
    this.stompable = false;
    this.invincible = true;
    g.particles.emit(this.cx, this.cy, { count: 30, speed: 90, life: 0.5, color: [gray(220), COLORS.cyan, COLORS.red] });
  }

  private doAttack(g: GameContext, speedUp: number): void {
    const pattern = this.attackIndex % 3;
    if (pattern === 0) {
      // Radial bursts.
      const n = 8 + this.phase * 2;
      const off = this.volley * 0.35;
      for (let i = 0; i < n; i++) {
        const a = (i / n) * Math.PI * 2 + off;
        g.spawn(new Shot(this.cx, this.cy, Math.cos(a) * 80 * speedUp, Math.sin(a) * 80 * speedUp, '#E6E6E6'));
      }
      g.sfx('shoot');
      this.volley++;
      if (this.volley < 2 + (this.phase > 0 ? 1 : 0)) {
        this.timer = 0.7 / speedUp;
        return;
      }
    } else if (pattern === 1) {
      // Rain from above with warnings on the floor.
      if (this.volley === 0) {
        const n = 6 + this.phase * 2;
        for (let i = 0; i < n; i++) this.warnings.push({ x: TILE * 2 + Math.random() * (this.arenaW - TILE * 4), t: 0.9 });
        this.warnings.push({ x: g.player.cx, t: 0.9 });
        this.volley = 1;
        this.timer = 0.9;
        return;
      }
      for (const w of this.warnings) g.spawn(new Shot(w.x, g.camera.y - 4, 0, 190 * speedUp, COLORS.red));
      g.sfx('shoot');
    } else {
      // Fake platforms + one burst.
      const spots = [
        [TILE * 5, this.floorY - TILE * 3.5],
        [this.arenaW / 2 - TILE * 2, this.floorY - TILE * 6.5],
        [this.arenaW - TILE * 9, this.floorY - TILE * 3.5],
      ];
      for (const [x, y] of spots) g.spawn(new FakePlatform(x, y, TILE * 4));
      const n = 10;
      for (let i = 0; i < n; i++) {
        const a = (i / n) * Math.PI * 2;
        g.spawn(new Shot(this.cx, this.cy, Math.cos(a) * 70 * speedUp, Math.sin(a) * 70 * speedUp, COLORS.cyan));
      }
      g.sfx('bossTeleport');
    }
    // Done attacking: sink down, dazed.
    this.attackIndex++;
    this.volley = 0;
    this.mode = 'descend';
    this.tx = Math.max(TILE * 3, Math.min(this.arenaW - TILE * 3, this.cx));
    this.ty = this.floorY - this.h / 2 - 1;
  }

  draw(r: Renderer, g: GameContext): void {
    const ctx = r.ctx;
    // Floor warnings for the rain attack.
    for (const w of this.warnings) {
      if (w.t <= 0) continue;
      const on = Math.floor(w.t * 12) % 2 === 0;
      ctx.fillStyle = on ? COLORS.red : COLORS.redDark;
      ctx.fillRect(w.x - 4, this.floorY - 2, 8, 1);
      ctx.fillRect(w.x - 1, this.floorY - 6, 2, 3);
    }
    if (this.visible <= 0.01) return;

    const flick = this.mode === 'appear' || this.mode === 'intro' ? (Math.random() < 0.3 ? 0.3 : 1) : 1;
    const vul = this.mode === 'vulnerable';
    const base = this.flash > 0 ? '#FFFFFF' : vul ? gray(120) : gray(225);
    const telegraph = this.mode === 'attack' && this.timer < 0.35;
    const R = vul ? 13 : 16;
    const drawBlob = (ox: number, color: string, alpha: number) => {
      ctx.globalAlpha = alpha * this.visible * flick;
      ctx.fillStyle = color;
      for (let ring = 3; ring <= R; ring += 3) {
        const n = Math.floor(ring * 1.1);
        for (let i = 0; i < n; i++) {
          const a = (i / n) * Math.PI * 2 + this.t * (ring % 2 ? 0.6 : -0.4);
          const wob = ring === R ? Math.sin(a * 3 + this.t * 2) * 2.5 + Math.sin(a * 5 - this.t * 3) * 1.5 : 0;
          const rr = ring + wob;
          ctx.fillRect(this.cx + Math.cos(a) * rr + ox - 0.75, this.cy + Math.sin(a) * rr - 0.75, 1.5, 1.5);
        }
      }
    };
    drawBlob(-1.5, COLORS.red, 0.45);
    drawBlob(1.5, COLORS.cyan, 0.45);
    drawBlob(0, base, 1);
    ctx.globalAlpha = this.visible * flick;

    // Eyes.
    if (vul) {
      ctx.fillStyle = gray(220);
      for (const ex of [-6, 4]) {
        for (let i = 0; i < 3; i++) {
          ctx.fillRect(this.cx + ex + i, this.cy - 4 + i, 1, 1);
          ctx.fillRect(this.cx + ex + 2 - i, this.cy - 4 + i, 1, 1);
        }
      }
      // Dizzy orbit.
      for (let i = 0; i < 3; i++) {
        const a = this.t * 5 + (i * Math.PI * 2) / 3;
        ctx.fillStyle = COLORS.orangeLight;
        ctx.fillRect(this.cx + Math.cos(a) * 12, this.y - 2 + Math.sin(a) * 3, 2, 2);
      }
    } else {
      ctx.fillStyle = telegraph && Math.floor(g.time * 30) % 2 === 0 ? '#FFFFFF' : COLORS.red;
      ctx.fillRect(this.cx - 7, this.cy - 5, 4, 5);
      ctx.fillRect(this.cx + 3, this.cy - 5, 4, 5);
      ctx.fillStyle = '#FFFFFF';
      ctx.fillRect(this.cx - 6, this.cy - 4, 1, 1);
      ctx.fillRect(this.cx + 4, this.cy - 4, 1, 1);
    }
    ctx.globalAlpha = 1;

    if (this.mode === 'intro') {
      r.text('THE HALLUCINATION', this.cx, this.y - 14, { size: 7, align: 'center', bold: true, color: COLORS.textBright, alpha: this.visible });
      r.text('confidently wrong since forever', this.cx, this.y - 5, { size: 4.5, align: 'center', color: COLORS.text, alpha: this.visible });
    }
  }
}
