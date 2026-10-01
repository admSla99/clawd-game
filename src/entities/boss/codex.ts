import { COLORS, TILE, gray } from '../../config';
import type { Rect } from '../../core/math';
import { hash2 } from '../../core/noise';
import type { Renderer } from '../../render/renderer';
import { drawSprite, type Palette } from '../../render/sprites';
import { Bug, Shot } from '../enemies';
import { Enemy, type GameContext, type HitKind } from '../entity';

type Attack = 'burst' | 'slam' | 'wall' | 'tests' | 'rmrf';
type Mode = 'intro' | 'idle' | Attack | 'refactor' | 'dead';

const MAX_HP = 90;
const INTRO_TEXT = '> codex --ship-it';
const WALL_TEXT = 'const answer = autocomplete(everything); // trust me ';
const BURST_GLYPHS = '{}();=<>[]';

const PATTERNS: Attack[][] = [
  ['burst', 'slam', 'wall', 'burst', 'slam'],
  ['burst', 'tests', 'slam', 'wall', 'burst', 'slam'],
  ['rmrf', 'burst', 'slam', 'wall', 'tests', 'rmrf', 'slam'],
];

/**
 * World 2 boss: a rival coding model. A floating monitor whose screen is its
 * face, flanked by two giant mouse-cursor hands. Only the monitor takes damage.
 */
export class Codex extends Enemy {
  readonly maxHp = MAX_HP;
  private mode: Mode = 'intro';
  private timer = 3.2;
  private t = 0;
  private phase = 0;
  private step = 0;
  private volley = 0;
  private cx: number;
  private cy: number;
  private hands: CodexHand[] = [];
  private typed = 0;
  private typeT = 0;
  private sayText = '';
  private sayT = 0;

  constructor(
    x: number,
    private floorY: number,
    private arenaW: number,
  ) {
    super();
    this.w = 72;
    this.h = 50;
    this.cx = x;
    this.cy = floorY - 150;
    this.hp = MAX_HP;
    this.tokens = 0;
    this.stompable = true;
    this.layer = 1;
    this.sync();
    this.savePrev();
  }

  get dead(): boolean {
    return this.mode === 'dead';
  }

  private sync(): void {
    this.x = this.cx - this.w / 2;
    this.y = this.cy - this.h / 2;
  }

  get hurtbox(): Rect | null {
    if (this.mode === 'dead' || this.mode === 'intro') return null;
    return { x: this.x + 4, y: this.y + 4, w: this.w - 8, h: this.h - 8 };
  }

  hit(_kind: HitKind, g: GameContext, damage = 1): boolean {
    if (this.mode === 'intro' || this.mode === 'refactor' || this.mode === 'dead') return false;
    this.hp -= damage;
    this.flash = 0.08;
    if (Math.random() < 0.3) g.sfx('hit');
    if (this.hp <= 0) {
      this.hp = 0;
      this.mode = 'dead';
      this.timer = 2.8;
      this.say('SEGFAULT', 3);
      g.sfx('bossHit');
      g.hitstop(0.2);
      for (const h of this.hands) h.retire(g);
      return true;
    }
    const nextPhase = this.hp <= MAX_HP / 3 ? 2 : this.hp <= (MAX_HP * 2) / 3 ? 1 : 0;
    if (nextPhase > this.phase) {
      this.phase = nextPhase;
      this.mode = 'refactor';
      this.timer = 1.8;
      this.step = 0;
      this.say(this.phase === 1 ? 'REFACTORING...' : 'ENABLING --YOLO MODE', 1.8);
      g.sfx('bossHit');
      g.shake(0.6);
      g.hitstop(0.15);
      g.particles.emit(this.cx, this.cy, { count: 60, speed: 180, life: 0.8, color: ['#FFFFFF', COLORS.cyan, COLORS.red], size: 1.5 });
    }
    return true;
  }

  private say(text: string, seconds: number): void {
    this.sayText = text;
    this.sayT = seconds;
  }

  update(dt: number, g: GameContext): void {
    this.tickTimers(dt);
    this.t += dt;
    this.timer -= dt;
    this.sayT -= dt;

    if (this.hands.length === 0) {
      this.hands = [new CodexHand(this, -1, this.floorY), new CodexHand(this, 1, this.floorY)];
      for (const h of this.hands) g.spawn(h);
    }

    // Drift above the arena.
    if (this.mode !== 'dead') {
      const span = this.arenaW / 2 - 110;
      const tx = this.arenaW / 2 + Math.sin(this.t * (0.45 + this.phase * 0.12)) * span;
      const ty = this.floorY - 150 + Math.sin(this.t * 1.3) * 6;
      this.cx += (tx - this.cx) * Math.min(1, dt * 2);
      this.cy += (ty - this.cy) * Math.min(1, dt * 2);
    }

    const speed = 1 + this.phase * 0.2;
    switch (this.mode) {
      case 'intro':
        this.typeT += dt;
        if (this.typeT > 0.09 && this.typed < INTRO_TEXT.length) {
          this.typeT = 0;
          this.typed++;
          g.sfx('typing');
        }
        if (this.timer <= 0) this.nextAttack(g);
        break;
      case 'idle':
      case 'refactor':
        if (this.timer <= 0) this.nextAttack(g);
        break;
      case 'burst':
        if (this.timer <= 0) {
          this.fireBurst(g, speed);
          this.volley++;
          this.timer = 0.5;
          if (this.volley >= 3 + this.phase) this.rest();
        }
        break;
      case 'slam':
        if (this.timer <= 0 || this.hands.every((h) => !h.busy)) this.rest();
        break;
      case 'wall':
        if (this.timer <= 0) this.rest();
        break;
      case 'tests':
        if (this.timer <= 0) this.rest();
        break;
      case 'rmrf':
        if (this.timer <= 0) {
          if (this.volley < 3) {
            g.spawn(new ColumnBeam(g.player.cx, this.floorY));
            this.volley++;
            this.timer = 0.75;
          } else {
            this.rest();
          }
        }
        break;
      case 'dead':
        if (Math.random() < dt * 30) {
          g.particles.emit(this.cx + (Math.random() - 0.5) * 70, this.cy + (Math.random() - 0.5) * 50, {
            count: 6,
            speed: 130,
            life: 0.7,
            color: ['#FFFFFF', COLORS.cyan, COLORS.orange, COLORS.red],
            size: 1.5,
          });
          g.shake(0.08);
          if (Math.random() < 0.3) g.sfx('explode');
        }
        this.cy += 12 * dt;
        if (this.timer <= 0 && this.alive) {
          this.alive = false;
          g.particles.emit(this.cx, this.cy, { count: 160, speed: 260, life: 1.4, color: ['#FFFFFF', COLORS.cyan, COLORS.orange], size: 2, drag: 1.4 });
          g.shake(1);
          g.sfx('explode');
          g.onBossDefeated(this.cx, this.floorY);
        }
        break;
    }
    this.sync();
  }

  private rest(): void {
    this.mode = 'idle';
    this.timer = Math.max(0.45, 1.2 - this.phase * 0.3);
  }

  private nextAttack(g: GameContext): void {
    const pattern = PATTERNS[this.phase];
    const attack = pattern[this.step % pattern.length];
    this.step++;
    this.mode = attack;
    this.volley = 0;
    switch (attack) {
      case 'burst':
        this.timer = 0.4;
        break;
      case 'slam': {
        const p = g.player;
        const hand = this.hands.reduce((a, b) => (Math.abs(a.cx - p.cx) < Math.abs(b.cx - p.cx) ? a : b));
        hand.slam();
        if (this.phase === 2) this.hands.find((h) => h !== hand)?.slam(0.7);
        this.timer = 4;
        break;
      }
      case 'wall':
        this.spawnWall(g);
        this.say('autocompleting...', 1.5);
        this.timer = 2.2;
        break;
      case 'tests': {
        const n = 2 + this.phase;
        for (let i = 0; i < n; i++) g.spawn(new Bug(TILE * 4 + Math.random() * (this.arenaW - TILE * 8), TILE * 2, 2));
        this.say(`npm test → ${n} failing`, 1.6);
        this.timer = 1.4;
        break;
      }
      case 'rmrf':
        this.say('rm -rf ./clawd', 1.6);
        this.timer = 0.5;
        break;
    }
  }

  private fireBurst(g: GameContext, speed: number): void {
    const p = g.player;
    const ox = this.cx;
    const oy = this.cy + 14;
    const base = Math.atan2(p.y + 9 - oy, p.cx - ox);
    const n = 5;
    for (let i = 0; i < n; i++) {
      const a = base + (i - (n - 1) / 2) * 0.17 + (this.volley % 2 ? 0.08 : 0);
      const ch = BURST_GLYPHS[Math.floor(Math.random() * BURST_GLYPHS.length)];
      g.spawn(new Shot(ox, oy, Math.cos(a) * 120 * speed, Math.sin(a) * 120 * speed, COLORS.cyan, ch));
    }
    g.sfx('shoot');
  }

  /** A column of ghost text sweeping across the arena, with one gap to slip through. */
  private spawnWall(g: GameContext): void {
    const fromRight = g.player.cx < this.arenaW / 2;
    const startX = fromRight ? this.arenaW - TILE * 2 : TILE * 2;
    const vx = (fromRight ? -1 : 1) * (95 + this.phase * 15);
    const gapCenter = this.floorY - 26 - Math.random() * 70;
    const gapHalf = 22;
    let i = 0;
    for (let y = TILE; y < this.floorY - 4; y += 9) {
      if (Math.abs(y - gapCenter) < gapHalf) continue;
      const ch = WALL_TEXT[i++ % WALL_TEXT.length];
      const life = (this.arenaW - TILE * 3) / Math.abs(vx);
      g.spawn(new Shot(startX, y, vx, 0, '#7FE3EA', ch === ' ' ? '·' : ch, false, life));
    }
    g.sfx('typing');
  }

  draw(r: Renderer, g: GameContext): void {
    const ctx = r.ctx;
    const glitch = this.mode === 'refactor' || this.mode === 'dead' || this.phase === 2 ? (hash2(Math.floor(g.time * 20), 1, 3) > 0.7 ? 2 : 0) : 0;
    const x = this.x + glitch;
    const y = this.y;
    const white = this.flash > 0;

    // Antenna.
    ctx.fillStyle = gray(150);
    for (let i = 0; i < 4; i++) ctx.fillRect(this.cx - 1, y - 4 - i * 3, 2, 2);
    ctx.fillStyle = Math.floor(g.time * 3) % 2 ? COLORS.cyan : gray(90);
    ctx.fillRect(this.cx - 2, y - 17, 4, 4);

    // Bezel of dots.
    for (let i = 0; i <= this.w; i += 3) {
      for (const yy of [y, y + this.h]) {
        ctx.fillStyle = white ? '#FFFFFF' : gray(215);
        ctx.fillRect(x + i - 1, yy - 1, 2, 2);
      }
    }
    for (let j = 0; j <= this.h; j += 3) {
      for (const xx of [x, x + this.w]) {
        ctx.fillStyle = white ? '#FFFFFF' : gray(215);
        ctx.fillRect(xx - 1, y + j - 1, 2, 2);
      }
    }
    // Screen.
    ctx.fillStyle = '#0C1213';
    ctx.fillRect(x + 3, y + 3, this.w - 6, this.h - 6);
    // Scrolling code behind the face.
    const lines = 6;
    for (let l = 0; l < lines; l++) {
      const ly = y + 7 + l * 7;
      const len = 10 + Math.floor(hash2(l + Math.floor(this.t * 2), 7, 1) * 40);
      for (let k = 0; k < len; k += 3) {
        ctx.fillStyle = 'rgba(95,208,216,0.18)';
        ctx.fillRect(x + 6 + k + (l % 3) * 4, ly, 2, 1);
      }
    }

    if (this.mode === 'intro') {
      r.text(INTRO_TEXT.slice(0, this.typed) + (Math.floor(g.time * 3) % 2 ? '_' : ''), x + 6, y + this.h / 2, { size: 5, color: COLORS.cyan });
    } else {
      // Eyes.
      const blink = Math.sin(this.t * 1.7) > 0.97;
      const eyeH = blink ? 1 : 10;
      const look = Math.max(-3, Math.min(3, (g.player.cx - this.cx) / 60));
      const eyeColor = this.mode === 'dead' ? COLORS.red : white ? '#FFFFFF' : COLORS.cyan;
      ctx.fillStyle = eyeColor;
      ctx.fillRect(x + 24 + look, y + 14 + (10 - eyeH) / 2, 6, eyeH);
      ctx.fillRect(x + 42 + look, y + 14 + (10 - eyeH) / 2, 6, eyeH);
      // Mouth.
      const attacking = this.mode === 'burst' || this.mode === 'rmrf' || this.mode === 'wall';
      if (this.mode === 'dead') r.text('x_x', x + this.w / 2, y + 36, { size: 6, align: 'center', bold: true, color: COLORS.red });
      else if (attacking) ctx.fillRect(x + 33 + look, y + 31, 6, 5);
      else ctx.fillRect(x + 28 + look, y + 34, 16, 1.5);
      // Cracks in later phases.
      if (this.phase >= 1) {
        ctx.fillStyle = COLORS.red;
        for (let i = 0; i < 6 * this.phase; i++) ctx.fillRect(x + 8 + hash2(i, 2, 9) * 56, y + 6 + hash2(i, 3, 9) * 36, 1.5, 1.5);
      }
    }
    // Name plate.
    r.text('CODEX', x + this.w / 2, y + this.h - 4, { size: 4, align: 'center', bold: true, color: gray(120) });

    if (this.sayT > 0 && this.sayText) {
      r.text(this.sayText, this.cx, y + this.h + 12, { size: 6, align: 'center', bold: true, color: this.mode === 'dead' ? COLORS.red : '#7FE3EA', alpha: Math.min(1, this.sayT * 3) });
    }
    if (this.mode === 'intro' && this.typed >= INTRO_TEXT.length) {
      r.text('CODEX', this.cx, y + this.h + 16, { size: 11, align: 'center', bold: true, color: COLORS.textBright });
      r.text('a rival model has entered the chat', this.cx, y + this.h + 28, { size: 5, align: 'center', color: COLORS.text });
    }
  }
}

const CURSOR = [
  'O.........',
  'OO........',
  'OwO.......',
  'OwwO......',
  'OwwwO.....',
  'OwwwwO....',
  'OwwwwwO...',
  'OwwwwwwO..',
  'OwwwwwwwO.',
  'OwwwwwwwwO',
  'OwwwwwOOOO',
  'OwwOwwO...',
  'OwO.OwwO..',
  'OO..OwwO..',
  'O....OwwO.',
  '.....OOOO.',
];
const CURSOR_PAL: Palette = { O: '#E6E6E6', w: '#6A6A6A' };

/** One of Codex's giant cursor hands. Invulnerable; slams the floor and sends shockwaves. */
export class CodexHand extends Enemy {
  busy = false;
  private mode: 'hover' | 'track' | 'drop' | 'stuck' | 'return' | 'gone' = 'hover';
  private timer = 0;
  private delay = 0;
  private t = Math.random() * 5;
  private targetX = 0;

  constructor(
    private head: Codex,
    private side: -1 | 1,
    private floorY: number,
  ) {
    super();
    this.w = 20;
    this.h = 32;
    this.invincible = true;
    this.stompable = false;
    this.tokens = 0;
    this.layer = 2;
    this.x = head.x + head.w / 2 + side * 60 - 10;
    this.y = head.y + 10;
    this.savePrev();
  }

  get cx(): number {
    return this.x + this.w / 2;
  }

  slam(delay = 0): void {
    if (this.mode === 'gone') return;
    this.busy = true;
    this.delay = delay;
    this.mode = 'track';
    this.timer = 0.85 + delay;
  }

  retire(g: GameContext): void {
    this.mode = 'gone';
    this.alive = false;
    g.particles.emit(this.cx, this.y + 16, { count: 30, speed: 120, life: 0.6, color: ['#FFFFFF', gray(150)] });
  }

  get hurtbox(): Rect | null {
    if (this.mode === 'gone') return null;
    return { x: this.x + 3, y: this.y + 3, w: this.w - 6, h: this.h - 6 };
  }

  update(dt: number, g: GameContext): void {
    this.t += dt;
    this.timer -= dt;
    const homeX = this.head.x + this.head.w / 2 + this.side * 62 - this.w / 2;
    const homeY = this.head.y + 12 + Math.sin(this.t * 2) * 4;
    switch (this.mode) {
      case 'hover':
        this.x += (homeX - this.x) * Math.min(1, dt * 5);
        this.y += (homeY - this.y) * Math.min(1, dt * 5);
        break;
      case 'track':
        if (this.delay > 0) {
          this.delay -= dt;
          this.x += (homeX - this.x) * Math.min(1, dt * 5);
          break;
        }
        this.targetX = g.player.cx - this.w / 2;
        this.x += (this.targetX - this.x) * Math.min(1, dt * 6);
        this.y += (this.floorY - 120 - this.y) * Math.min(1, dt * 6);
        if (this.timer <= 0) {
          this.mode = 'drop';
        }
        break;
      case 'drop':
        this.y += 650 * dt;
        if (this.y + this.h >= this.floorY) {
          this.y = this.floorY - this.h;
          this.mode = 'stuck';
          this.timer = 0.8;
          g.sfx('slam');
          g.shake(0.5);
          g.particles.emit(this.cx, this.floorY, { count: 30, speed: 140, angle: -Math.PI / 2, spread: Math.PI, life: 0.5, color: [gray(220), COLORS.cyan], gravity: 300 });
          for (const s of [-1, 1]) g.spawn(new Shot(this.cx + s * 12, this.floorY - 5, s * 165, 0, '#7FE3EA', '≈', false, 2.6));
        }
        break;
      case 'stuck':
        if (this.timer <= 0) this.mode = 'return';
        break;
      case 'return':
        this.x += (homeX - this.x) * Math.min(1, dt * 4);
        this.y += (homeY - this.y) * Math.min(1, dt * 4);
        if (Math.abs(this.y - homeY) < 4) {
          this.mode = 'hover';
          this.busy = false;
        }
        break;
      case 'gone':
        break;
    }
  }

  draw(r: Renderer, g: GameContext): void {
    const ctx = r.ctx;
    const pointingDown = this.mode === 'track' || this.mode === 'drop' || this.mode === 'stuck';
    if (this.mode === 'track' && this.delay <= 0) {
      // Telegraph: shadow on the floor.
      const on = Math.floor(g.time * 16) % 2 === 0;
      ctx.fillStyle = on ? COLORS.red : COLORS.redDark;
      for (let i = 0; i < this.w; i += 3) ctx.fillRect(this.x + i, this.floorY - 2, 2, 1);
    }
    const rows = pointingDown ? [...CURSOR].reverse() : CURSOR;
    drawSprite(ctx, rows, CURSOR_PAL, this.cx, this.y + this.h, { px: 2, fill: 0.85, flip: this.side > 0 });
  }
}

/** "rm -rf" column: a warning line, then a deadly vertical beam. */
export class ColumnBeam extends Enemy {
  private timer = 0.85;
  private active = 0;

  constructor(
    x: number,
    private floorY: number,
  ) {
    super();
    this.w = 18;
    this.h = floorY;
    this.x = x - 9;
    this.y = 0;
    this.projectile = true;
    this.cancellable = false;
    this.consumeOnHit = false;
    this.invincible = true;
    this.stompable = false;
    this.tokens = 0;
    this.layer = 3;
    this.savePrev();
  }

  get hurtbox(): Rect | null {
    return this.active > 0 ? { x: this.x + 3, y: 0, w: this.w - 6, h: this.floorY } : null;
  }

  update(dt: number, g: GameContext): void {
    if (this.timer > 0) {
      this.timer -= dt;
      if (this.timer <= 0) {
        this.active = 0.35;
        g.sfx('laser');
        g.shake(0.3);
      }
      return;
    }
    this.active -= dt;
    g.particles.emit(this.x + 9, this.floorY, { count: 3, speed: 90, angle: -Math.PI / 2, spread: 1.2, life: 0.3, color: [COLORS.red, '#FFFFFF'] });
    if (this.active <= 0) this.alive = false;
  }

  draw(r: Renderer, g: GameContext): void {
    const ctx = r.ctx;
    if (this.timer > 0) {
      const on = Math.floor(g.time * 14) % 2 === 0;
      ctx.fillStyle = on ? COLORS.red : COLORS.redDark;
      for (let y = 0; y < this.floorY; y += 6) ctx.fillRect(this.x + 8, y, 2, 3);
      return;
    }
    ctx.fillStyle = 'rgba(224,96,90,0.5)';
    ctx.fillRect(this.x, 0, this.w, this.floorY);
    ctx.fillStyle = '#FFFFFF';
    ctx.fillRect(this.x + 6, 0, this.w - 12, this.floorY);
  }
}
