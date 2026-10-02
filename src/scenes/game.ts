import type { App, Scene } from '../app';
import { COLORS, PLAYER, TILE, gray } from '../config';
import type { Sfx } from '../core/audio';
import { Camera } from '../core/camera';
import { lerp, overlaps, type Rect } from '../core/math';
import { hash2 } from '../core/noise';
import { Codex } from '../entities/boss/codex';
import { Hallucination } from '../entities/boss/hallucination';
import { Bullet } from '../entities/bullets';
import { Checkpoint, Goal, Sign, Spark, SubAgent, Token } from '../entities/collectibles';
import { Bug, RateLimiter, SpamBot } from '../entities/enemies';
import { Drone, Injector, ShieldBot, Turret } from '../entities/enemies2';
import { Enemy, type Entity, type GameContext } from '../entities/entity';
import { Gun } from '../entities/gun';
import { WeaponPickup } from '../entities/pickups';
import { MovingPlatform } from '../entities/platforms';
import { Player, type Platform } from '../entities/player';
import { drawArmedExtras, drawClawd, gunPivot } from '../render/clawdView';
import { TerrainRenderer } from '../render/dotRenderer';
import { drawControlsOverlay, drawHud, type HudRegions } from '../render/hud';
import { Parallax } from '../render/parallax';
import { Particles } from '../render/particles';
import { panel } from '../render/shapes';
import { drawTouchControls } from '../render/touchView';
import { grantWeapon, progressFor, recordRun } from '../save';
import { WEAPON_ORDER, loadoutFromSave, type Loadout, type WeaponId } from '../weapons';
import { rectTouchesTile } from '../world/collision';
import { parseLevel, type Level } from '../world/level';
import { T, isSolidTile } from '../world/tiles';

type Phase = 'playing' | 'dying' | 'complete';

interface Popup {
  text: string;
  x: number;
  y: number;
  t: number;
  color: string;
}

const PAUSE_ITEMS = ['RESUME', 'RESTART FROM CHECKPOINT', 'RESTART LEVEL', 'CRT FILTER', 'QUIT TO MAP'] as const;

export class GameScene implements Scene, GameContext {
  readonly level: Level;
  readonly player: Player;
  readonly particles = new Particles();
  readonly camera: Camera;
  readonly platforms: Platform[] = [];
  time = 0;

  private entities: Entity[] = [];
  private pending: Entity[] = [];
  private terrain: TerrainRenderer;
  private parallax: Parallax;
  private boss: Hallucination | Codex | null = null;
  private loadout: Loadout;
  private maxHearts: number;
  private gun: Gun | null = null;
  private beams: { x0: number; y0: number; x1: number; y1: number; t: number; color: string }[] = [];
  private weaponLabelT = 0;

  private hearts: number = PLAYER.maxHearts;
  private tokens = 0;
  private sparks: boolean[];
  private agents: boolean[];
  private prevSparks: boolean[];
  private checkpoint: { x: number; bottom: number };
  private phase: Phase = 'playing';
  private phaseTimer = 0;
  private hitstopTimer = 0;
  private flashSparks = 0;
  private flashHearts = 0;
  private popups: Popup[] = [];
  private paused = false;
  private pauseIndex = 0;
  private pauseRows: Rect[] = [];
  private showControls = false;
  private debug = false;
  private hud: HudRegions | null = null;
  private voidY = Number.POSITIVE_INFINITY;
  private voidDelay = 0;
  private fade = 1;
  private introT = 0;
  private wasHovering = false;

  constructor(
    private app: App,
    readonly levelIndex: number,
  ) {
    const def = app.levels[levelIndex];
    this.level = parseLevel(def);
    this.terrain = new TerrainRenderer(this.level, 7 + levelIndex * 13);
    this.parallax = new Parallax(def.theme);
    const r = app.renderer;
    this.camera = new Camera(r.viewW, r.viewH, this.level.pixelW, this.level.pixelH);

    const start = this.level.start;
    this.player = new Player(start.x, start.y);
    this.checkpoint = { x: start.x, bottom: start.y };

    this.loadout = loadoutFromSave(app.save);
    this.maxHearts = this.loadout.maxHearts;
    this.hearts = this.maxHearts;
    this.player.hoverMax = this.loadout.hoverDuration;
    this.player.hoverLeft = this.loadout.hoverDuration;
    if (def.world === 2) {
      // Dev shortcuts can start world 2 without the blaster: hand it over.
      if (app.save.weapons.length === 0) grantWeapon(app.save, 'blaster');
      this.player.armed = true;
      this.gun = new Gun(app.save.equipped ?? 'blaster', this.loadout);
      this.weaponLabelT = 2.5;
    }

    const prog = progressFor(app.save, def.id);
    const sparkCount = this.level.spawnsOf('spark').length;
    const agentCount = this.level.spawnsOf('agent').length;
    this.sparks = new Array<boolean>(sparkCount).fill(false);
    this.agents = new Array<boolean>(agentCount).fill(false);
    this.prevSparks = Array.from({ length: sparkCount }, (_, i) => !!prog.sparks[i]);

    this.spawnEntities(prog.agents);
    if (def.risingVoid) {
      this.voidY = this.level.pixelH + 40;
      this.voidDelay = def.risingVoid.delay;
    }
    this.camera.snapTo(this.player.cx, this.player.y);
    app.audio.playMusic(def.music);
  }

  private spawnEntities(savedAgents: boolean[]): void {
    const signs = this.level.def.signs ?? [];
    const tough = this.level.def.world === 2;
    let platPhase = 0;
    for (const s of this.level.spawns) {
      switch (s.kind) {
        case 'spark':
          this.add(new Spark(s.x, s.y, s.index, this.prevSparks[s.index]));
          break;
        case 'token':
          this.add(new Token(s.x, s.y - 8));
          break;
        case 'bug':
          this.add(new Bug(s.x, s.y, tough ? 2 : 1));
          break;
        case 'spambot':
          this.add(new SpamBot(s.x, s.y, tough ? 3 : 1));
          break;
        case 'turret':
          this.add(new Turret(s.x, s.y, false));
          break;
        case 'ceilturret':
          this.add(new Turret(s.x, s.ty * TILE, true));
          break;
        case 'drone':
          this.add(new Drone(s.x, s.y));
          break;
        case 'shieldbot':
          this.add(new ShieldBot(s.x, s.y));
          break;
        case 'injector':
          this.add(new Injector(s.x, s.y));
          break;
        case 'ratelimiter': {
          const rl = new RateLimiter(s.tx * TILE, s.ty * TILE);
          this.add(rl);
          this.platforms.push(rl);
          break;
        }
        case 'checkpoint':
          this.add(new Checkpoint(s.x, s.y, s.index));
          break;
        case 'agent':
          this.add(new SubAgent(s.x, s.y, s.index, !!savedAgents[s.index]));
          break;
        case 'goal':
          this.add(new Goal(s.x, s.y));
          break;
        case 'platformH':
        case 'platformV': {
          const mp = new MovingPlatform(s.x, s.ty * TILE, s.kind === 'platformH' ? 'h' : 'v', TILE * 3.5, 4, platPhase);
          platPhase += 1.3;
          this.add(mp);
          this.platforms.push(mp);
          break;
        }
        case 'sign':
          this.add(new Sign(s.x, s.y, signs[s.index] ?? '...', this.level.def.touchSigns?.[s.index]));
          break;
        case 'boss': {
          const floorY = this.findFloorBelow(s.tx, s.ty);
          this.boss =
            this.level.def.boss === 'codex'
              ? new Codex(s.x, floorY, this.level.pixelW)
              : new Hallucination(s.x, s.y - TILE / 2, floorY, this.level.pixelW);
          this.add(this.boss);
          break;
        }
        case 'start':
          break;
      }
    }
  }

  private findFloorBelow(tx: number, ty: number): number {
    for (let y = ty; y < this.level.h; y++) {
      if (this.level.get(tx, y) === T.SOLID) return y * TILE;
    }
    return this.level.pixelH;
  }

  private add(e: Entity): void {
    this.entities.push(e);
  }

  // --- GameContext ----------------------------------------------------------

  get audio() {
    return this.app.audio;
  }

  get touchMode(): boolean {
    return this.app.input.touchMode;
  }

  spawn(e: Entity): void {
    this.pending.push(e);
    if ('onStand' in e) this.platforms.push(e as unknown as Platform);
  }

  sfx(s: Sfx): void {
    this.app.audio.play(s);
  }

  hitstop(seconds: number): void {
    this.hitstopTimer = Math.max(this.hitstopTimer, seconds);
  }

  shake(amount: number): void {
    this.camera.shake(amount);
  }

  hurtPlayer(fromX: number): void {
    if (this.phase !== 'playing') return;
    if (!this.player.hurt(fromX)) return;
    this.hearts--;
    this.flashHearts = 0.6;
    this.sfx('hurt');
    this.shake(0.35);
    this.hitstop(0.08);
    this.particles.emit(this.player.cx, this.player.y + 9, { count: 14, speed: 100, life: 0.5, color: [COLORS.orange, '#FFFFFF'], gravity: 300 });
    if (this.hearts <= 0) this.die();
  }

  collectSpark(index: number, x: number, y: number): void {
    this.sparks[index] = true;
    this.flashSparks = 1.4;
    this.sfx('spark');
    this.hitstop(0.05);
    this.particles.emit(x, y, { count: 40, speed: 150, life: 0.8, color: [COLORS.orange, COLORS.orangeLight, '#FFFFFF'], drag: 2, size: 1.5 });
    const n = this.sparks.filter(Boolean).length;
    this.popup(`SPARK ${n}/${this.sparks.length}`, x, y - 10, COLORS.orangeLight);
  }

  collectToken(x: number, y: number): void {
    this.tokens++;
    this.sfx('token');
    this.particles.emit(x, y, { count: 4, speed: 40, life: 0.25, color: COLORS.orangeLight });
    if (this.tokens % PLAYER.tokensPerHeart === 0 && this.hearts < Math.max(PLAYER.heartCap, this.maxHearts)) {
      this.hearts++;
      this.flashHearts = 0.8;
      this.sfx('heart');
      this.popup('+1 HEART', this.player.cx, this.player.y - 10, COLORS.red);
    }
  }

  rescueAgent(index: number): void {
    this.agents[index] = true;
    this.sfx('rescue');
    this.popup('SUB-AGENT RESCUED!', this.player.cx, this.player.y - 14, COLORS.orangeLight);
  }

  activateCheckpoint(x: number, bottom: number): void {
    this.checkpoint = { x, bottom };
    this.sfx('checkpoint');
    if (this.hearts < this.maxHearts) {
      this.hearts = this.maxHearts;
      this.flashHearts = 0.6;
    }
  }

  reachGoal(x: number, y: number): void {
    if (this.phase !== 'playing') return;
    this.phase = 'complete';
    this.phaseTimer = 0;
    this.sfx('complete');
    this.app.audio.hoverStop();
    this.app.audio.playMusic(null);
    this.particles.emit(x, y, { count: 80, speed: 200, life: 1, color: [COLORS.orange, COLORS.orangeLight, '#FFFFFF'], drag: 2, size: 1.5 });
  }

  onBossDefeated(x: number, floorY: number): void {
    if (this.level.def.boss === 'hallucination') {
      this.popup('THE HALLUCINATION HAS BEEN GROUNDED', x, floorY - 70, COLORS.orangeLight, 3);
      // It drops something shiny...
      this.spawn(new WeaponPickup(this.level.pixelW / 2, floorY));
    } else {
      this.popup('CODEX HAS BEEN DEPRECATED', x, floorY - 90, '#7FE3EA', 3);
      this.spawn(new Goal(this.level.pixelW / 2, floorY));
    }
    // Clear leftover projectiles.
    for (const e of this.entities) if (e instanceof Enemy && e.projectile) e.alive = false;
    this.boss = null;
    this.app.audio.playMusic('map');
  }

  onWeaponFound(x: number, y: number): void {
    grantWeapon(this.app.save, 'blaster');
    this.app.persist();
    this.sfx('weaponGet');
    this.hitstop(0.3);
    this.shake(0.4);
    this.particles.emit(x, y, { count: 90, speed: 200, life: 1.1, color: [COLORS.orange, COLORS.orangeLight, '#FFFFFF'], drag: 2, size: 1.5 });
    this.popup('TOKEN BLASTER ACQUIRED!', x, y - 30, COLORS.orangeLight, 3.5);
    this.popup('world 2 unlocked · the shop is open', x, y - 18, COLORS.text, 3.5);
    const gx = Math.floor(this.level.pixelW / 2 / TILE) + 6;
    this.spawn(new Goal(gx * TILE + TILE / 2, this.findFloorBelow(gx, 1)));
  }

  get magnet(): number {
    return this.loadout.magnet;
  }

  explode(x: number, y: number, radius: number, damage: number): void {
    this.sfx('explode');
    this.shake(0.3);
    this.particles.emit(x, y, { count: 40, speed: 160, life: 0.5, color: [COLORS.orange, COLORS.orangeLight, '#FFFFFF', gray(160)], drag: 3, size: 1.5 });
    for (let i = 0; i < 24; i++) {
      const a = (i / 24) * Math.PI * 2;
      this.particles.emit(x + Math.cos(a) * radius * 0.8, y + Math.sin(a) * radius * 0.8, { count: 1, speed: 20, life: 0.3, color: COLORS.orangeLight });
    }
    for (const e of this.entities) {
      if (!(e instanceof Enemy) || !e.alive) continue;
      const nx = Math.max(e.x, Math.min(x, e.x + e.w));
      const ny = Math.max(e.y, Math.min(y, e.y + e.h));
      if (Math.hypot(nx - x, ny - y) > radius) continue;
      if (e.projectile) {
        if (e.cancellable) e.alive = false;
      } else if (e.hit('shot', this, damage)) {
        this.popTokens(e);
      }
    }
    // Explosions break corrupted data too.
    let broke = false;
    for (let ty = Math.floor((y - radius) / TILE); ty <= Math.floor((y + radius) / TILE); ty++) {
      for (let tx = Math.floor((x - radius) / TILE); tx <= Math.floor((x + radius) / TILE); tx++) {
        if (this.level.get(tx, ty) === T.CORRUPT && Math.hypot(tx * TILE + 8 - x, ty * TILE + 8 - y) <= radius + 8) {
          broke = this.breakCluster(tx, ty) || broke;
        }
      }
    }
    if (broke) this.sfx('break');
  }

  fireBeam(x: number, y: number, angle: number, damage: number): void {
    const dx = Math.cos(angle);
    const dy = Math.sin(angle);
    const hit = new Set<Enemy>();
    let ex = x;
    let ey = y;
    for (let d = 0; d < 300; d += 3) {
      ex = x + dx * d;
      ey = y + dy * d;
      if (isSolidTile(this.level.get(Math.floor(ex / TILE), Math.floor(ey / TILE)))) break;
      for (const e of this.entities) {
        if (!(e instanceof Enemy) || !e.alive || hit.has(e)) continue;
        if (ex >= e.x && ex <= e.x + e.w && ey >= e.y && ey <= e.y + e.h) hit.add(e);
      }
    }
    for (const e of hit) {
      if (e.projectile) {
        if (e.cancellable) e.alive = false;
        continue;
      }
      if (e instanceof ShieldBot && e.blocksDirection(dx, dy)) continue;
      if (e.hit('shot', this, damage)) {
        this.popTokens(e);
        if (Math.random() < 0.3) this.particles.emit(e.x + e.w / 2, e.y + e.h / 2, { count: 2, speed: 60, life: 0.2, color: [COLORS.cyan, '#FFFFFF'] });
      }
    }
    this.beams.push({ x0: x, y0: y, x1: ex, y1: ey, t: 0.06, color: COLORS.cyan });
    this.particles.emit(ex, ey, { count: 1, speed: 40, life: 0.2, color: [COLORS.cyan, '#FFFFFF'] });
  }

  /** Bullets against enemies (and the shield bot's shield). */
  private checkBullets(): void {
    for (const b of this.entities) {
      if (!(b instanceof Bullet) || !b.alive) continue;
      const br = b.rect;
      for (const e of this.entities) {
        if (!(e instanceof Enemy) || !e.alive || b.hits.has(e)) continue;
        if (!overlaps(br, e.rect)) continue;
        if (e.projectile) {
          if (e.cancellable) {
            e.alive = false;
            b.impact(this);
            break;
          }
          continue;
        }
        if (e instanceof ShieldBot && e.blocksDirection(b.vx, b.vy)) {
          // Ricochet off the shield.
          b.vx = -b.vx * 0.8;
          b.vy = -Math.abs(b.vy) - 60;
          b.hits.add(e);
          this.sfx('deflect');
          this.particles.emit(b.cx, b.cy, { count: 5, speed: 70, life: 0.2, color: [COLORS.cyan, '#FFFFFF'] });
          continue;
        }
        b.hits.add(e);
        if (e.hit('shot', this, b.damage)) {
          this.sfx('hit');
          this.popTokens(e);
          this.particles.emit(b.cx, b.cy, { count: 3, speed: 60, life: 0.2, color: [b.color, '#FFFFFF'] });
        }
        if (b.splash || b.pierce-- <= 0) {
          b.impact(this);
          break;
        }
      }
    }
  }

  /** Where Clawd aims: right stick, dragged fire button, mouse, touch auto-aim, then keyboard 8-way. */
  private computeAim(): number {
    const input = this.app.input;
    const p = this.player;
    const pv = gunPivot(p, p.cx, p.bottom);
    const stick = input.padAim ?? input.touchAim;
    if (stick) return Math.atan2(stick.y, stick.x);
    if (input.mouseAiming(performance.now())) {
      const wx = input.mouseX + this.camera.x;
      const wy = input.mouseY + this.camera.y;
      return Math.atan2(wy - pv.y, wx - pv.x);
    }
    const up = input.held('up');
    const down = input.held('down') && !p.grounded;
    const side = input.held('left') || input.held('right');
    const f = p.facing;
    if (input.touchMode && !up && !down) {
      const target = this.autoAimTarget(pv.x, pv.y, f);
      if (target) return Math.atan2(target.y - pv.y, target.x - pv.x);
    }
    if (up) return side ? Math.atan2(-1, f) : -Math.PI / 2;
    if (down) return side ? Math.atan2(1, f) : Math.PI / 2;
    return f > 0 ? 0 : Math.PI;
  }

  /** Touch screens have no mouse: aim at the nearest visible enemy on the side Clawd faces. */
  private autoAimTarget(x: number, y: number, facing: number): { x: number; y: number } | null {
    let best: { x: number; y: number } | null = null;
    let bestD = 230;
    for (const e of this.entities) {
      if (!(e instanceof Enemy) || !e.alive || e.projectile || e.invincible) continue;
      const tx = e.x + e.w / 2;
      const ty = e.y + e.h / 2;
      const d = Math.hypot(tx - x, ty - y);
      if (d >= bestD || (tx - x) * facing < -6 || !this.lineOfSight(x, y, tx, ty)) continue;
      best = { x: tx, y: ty };
      bestD = d;
    }
    return best;
  }

  private lineOfSight(x0: number, y0: number, x1: number, y1: number): boolean {
    const len = Math.hypot(x1 - x0, y1 - y0);
    for (let d = 8; d < len; d += 6) {
      const k = d / len;
      if (isSolidTile(this.level.get(Math.floor((x0 + (x1 - x0) * k) / TILE), Math.floor((y0 + (y1 - y0) * k) / TILE)))) return false;
    }
    return true;
  }

  private updateWeapon(dt: number): void {
    const gun = this.gun;
    if (!gun) return;
    const input = this.app.input;
    const owned = WEAPON_ORDER.filter((w) => this.app.save.weapons.includes(w));
    let next: WeaponId | null = null;
    const cur = owned.indexOf(gun.weapon.id);
    if (input.pressed('next') && owned.length > 1) next = owned[(cur + 1) % owned.length];
    if (input.pressed('prev') && owned.length > 1) next = owned[(cur - 1 + owned.length) % owned.length];
    (['slot1', 'slot2', 'slot3', 'slot4', 'slot5'] as const).forEach((a, i) => {
      if (input.pressed(a) && owned.includes(WEAPON_ORDER[i])) next = WEAPON_ORDER[i];
    });
    if (next && next !== gun.weapon.id) {
      gun.setWeapon(next);
      this.app.save.equipped = next;
      this.weaponLabelT = 1.5;
      this.sfx('select');
    }
    this.weaponLabelT = Math.max(0, this.weaponLabelT - dt);

    const p = this.player;
    p.aim = this.computeAim();
    if (p.state !== 'spin') p.facing = Math.cos(p.aim) >= 0 ? 1 : -1;
    const canShoot = this.phase === 'playing' && p.state !== 'spin' && p.state !== 'hurt' && p.state !== 'dead' && !p.noclip;
    const pv = gunPivot(p, p.cx, p.bottom);
    gun.update(dt, canShoot && input.held('attack'), this, pv.x, pv.y, p.aim);
  }

  /** Called with an enemy that might have just died: drop its tokens. */
  private popTokens(e: Enemy): void {
    if (e.alive) return;
    for (let i = 0; i < e.tokens; i++) this.pending.push(new Token(e.x + e.w / 2, e.y + e.h / 2, true));
    e.tokens = 0;
  }

  private popup(text: string, x: number, y: number, color: string, life = 1.2): void {
    this.popups.push({ text, x, y, t: life, color });
  }

  /** Dev helper: put Clawd on a tile (feet at the tile's bottom edge). */
  warp(tx: number, ty: number): void {
    this.player.spawn(tx * TILE + TILE / 2, (ty + 1) * TILE);
    this.checkpoint = { x: tx * TILE + TILE / 2, bottom: (ty + 1) * TILE };
    this.camera.snapTo(this.player.cx, this.player.y);
  }

  // --- Life & death ---------------------------------------------------------

  private die(): void {
    if (this.phase !== 'playing') return;
    this.phase = 'dying';
    this.phaseTimer = 0;
    this.player.state = 'dead';
    this.app.audio.hoverStop();
    this.sfx('die');
    this.shake(0.5);
    this.particles.emit(this.player.cx, this.player.y + 9, {
      count: 50,
      speed: 160,
      life: 0.9,
      color: [COLORS.orange, COLORS.orangeShade, COLORS.orangeLight],
      gravity: 200,
      size: 2,
    });
  }

  /** Fell into the void: lose a heart, then reappear at the checkpoint. */
  private fellOut(): void {
    this.hearts--;
    this.flashHearts = 0.6;
    this.die();
  }

  private respawn(): void {
    if (this.hearts <= 0) {
      this.hearts = this.maxHearts;
      this.tokens = Math.floor(this.tokens / 2);
    }
    this.player.spawn(this.checkpoint.x, this.checkpoint.bottom);
    this.player.invuln = 1.0;
    this.camera.snapTo(this.player.cx, this.player.y);
    if (this.level.def.risingVoid) {
      this.voidY = this.checkpoint.bottom + TILE * 10;
      this.voidDelay = 2;
    }
    this.phase = 'playing';
    this.fade = 1;
  }

  // --- Update ---------------------------------------------------------------

  update(dt: number): void {
    const input = this.app.input;
    const r = this.app.renderer;
    this.camera.viewW = r.viewW;
    this.camera.viewH = r.viewH;

    if (input.pressed('debug')) this.debug = !this.debug;
    if (input.pressed('noclip') && this.debug) this.player.noclip = !this.player.noclip;
    if (input.pressed('controls')) this.showControls = !this.showControls;

    const touch = this.app.touch;
    touch.setEnabled(!this.paused && !this.showControls && this.phase !== 'complete');
    touch.armed = !!this.gun;
    touch.canSwap = this.app.save.weapons.length > 1;

    if (this.paused) {
      this.updatePause();
      return;
    }
    if (input.pressed('pause') && this.phase === 'playing') {
      if (this.showControls) {
        this.showControls = false;
      } else {
        this.openPause();
        return;
      }
    }
    if (this.showControls) return;

    this.fade = Math.max(0, this.fade - dt * 2.5);
    this.introT += dt;
    this.flashSparks = Math.max(0, this.flashSparks - dt);
    this.flashHearts = Math.max(0, this.flashHearts - dt);
    for (const p of this.popups) {
      p.t -= dt;
      p.y -= 16 * dt;
    }
    this.popups = this.popups.filter((p) => p.t > 0);

    if (this.hitstopTimer > 0) {
      this.hitstopTimer -= dt;
      return;
    }
    this.time += dt;

    for (const e of this.entities) e.savePrev();
    // Platforms move first so riders can be carried this tick.
    for (const e of this.entities) if (isPlatform(e)) e.update(dt, this);

    if (this.phase === 'playing') {
      this.player.update(dt, input, this);
      this.updateWeapon(dt);
      this.handlePlayerEvents();
      this.checkHazards();
      this.checkEnemies();
    } else if (this.phase === 'dying') {
      this.phaseTimer += dt;
      if (this.phaseTimer > 1.1) this.respawn();
    } else if (this.phase === 'complete') {
      this.phaseTimer += dt;
      this.player.prevX = this.player.x;
      this.player.prevY = this.player.y;
      this.player.anim += dt;
      if (this.phaseTimer > 2) this.finish();
    }

    for (const e of this.entities) if (!isPlatform(e)) e.update(dt, this);
    this.checkBullets();
    for (const b of this.beams) b.t -= dt;
    this.beams = this.beams.filter((b) => b.t > 0);
    if (this.pending.length) {
      this.entities.push(...this.pending);
      this.pending.length = 0;
    }
    this.entities = this.entities.filter((e) => e.alive);
    for (let i = this.platforms.length - 1; i >= 0; i--) {
      const p = this.platforms[i] as unknown as Entity;
      if (!p.alive) this.platforms.splice(i, 1);
    }

    this.updateVoid(dt);
    this.particles.update(dt);
    const p = this.player;
    this.camera.update(dt, p.cx, p.y + p.h / 2, p.facing, p.grounded, p.vy);
  }

  private updateVoid(dt: number): void {
    const rv = this.level.def.risingVoid;
    if (!rv || this.phase !== 'playing') return;
    if (this.voidDelay > 0) {
      this.voidDelay -= dt;
      return;
    }
    // Never let the void get too far behind, never past the player too fast.
    const minY = this.player.bottom + TILE * 14;
    if (this.voidY > minY) this.voidY = minY;
    this.voidY -= rv.speed * dt;
    if (this.player.bottom > this.voidY + 4) {
      this.hearts--;
      this.flashHearts = 0.6;
      this.die();
    }
  }

  private handlePlayerEvents(): void {
    const p = this.player;
    for (const ev of p.events) {
      switch (ev) {
        case 'jump':
          this.sfx('jump');
          this.particles.emit(p.cx, p.bottom, { count: 6, speed: 40, angle: -Math.PI / 2, spread: Math.PI, life: 0.3, color: gray(170) });
          break;
        case 'land':
        case 'hardLand':
          this.sfx('land');
          this.particles.emit(p.cx, p.bottom, { count: ev === 'hardLand' ? 12 : 6, speed: 60, angle: -Math.PI / 2, spread: Math.PI * 0.9, life: 0.35, color: [gray(200), gray(130)], gravity: 200 });
          if (ev === 'hardLand') this.shake(0.12);
          break;
        case 'hoverStart':
          this.app.audio.hoverStart();
          this.wasHovering = true;
          break;
        case 'hoverStop':
          this.app.audio.hoverStop();
          this.wasHovering = false;
          break;
        case 'spin':
          this.sfx('spin');
          break;
        case 'poundStart':
          this.sfx('pound');
          break;
        case 'poundLand':
          this.onPoundLand();
          break;
        case 'dropThrough':
          break;
      }
    }
    if (p.hovering) {
      this.app.audio.hoverUpdate(this.time);
      this.particles.emit(p.cx, p.bottom + 2, { count: 2, speed: 30, angle: Math.PI / 2, spread: 0.6, vy: 140, life: 0.25, color: [COLORS.orange, COLORS.orangeLight] });
    } else if (this.wasHovering) {
      this.app.audio.hoverStop();
      this.wasHovering = false;
    }
    if (p.grounded && Math.abs(p.vx) > 120 && Math.random() < 0.25) {
      this.particles.emit(p.cx - p.facing * 6, p.bottom - 1, { count: 1, speed: 15, angle: -Math.PI / 2, spread: 1, life: 0.3, color: gray(110) });
    }
  }

  private onPoundLand(): void {
    const p = this.player;
    this.sfx('poundLand');
    this.shake(0.3);
    this.particles.emit(p.cx, p.bottom, { count: 24, speed: 120, angle: -Math.PI / 2, spread: Math.PI, life: 0.45, color: [gray(220), gray(140), COLORS.orange], gravity: 300 });
    // Break corrupted blocks under the feet (the whole connected cluster).
    const ty = Math.floor((p.bottom + 1) / TILE);
    let broke = false;
    for (let tx = Math.floor(p.x / TILE); tx <= Math.floor((p.x + p.w - 0.01) / TILE); tx++) {
      if (this.level.get(tx, ty) === T.CORRUPT) broke = this.breakCluster(tx, ty) || broke;
    }
    if (broke) {
      this.sfx('break');
      this.hitstop(0.06);
      p.continuePound();
    }
    // Shockwave defeats nearby grounded enemies.
    const wave: Rect = { x: p.cx - 30, y: p.bottom - 14, w: 60, h: 16 };
    for (const e of this.entities) {
      if (e instanceof Enemy && !e.projectile && overlaps(wave, e.rect) && e.hit('pound', this, 4)) this.popTokens(e);
    }
  }

  private breakCluster(sx: number, sy: number): boolean {
    const stack: [number, number][] = [[sx, sy]];
    let n = 0;
    while (stack.length) {
      const [x, y] = stack.pop()!;
      if (this.level.get(x, y) !== T.CORRUPT) continue;
      this.level.set(x, y, T.EMPTY);
      n++;
      this.particles.emit(x * TILE + 8, y * TILE + 8, { count: 10, speed: 90, life: 0.6, color: [gray(200), '#C25BD6', COLORS.orange], gravity: 400, size: 1.5 });
      stack.push([x + 1, y], [x - 1, y], [x, y + 1], [x, y - 1]);
    }
    return n > 0;
  }

  private checkHazards(): void {
    const p = this.player;
    if (p.noclip) return;
    if (p.y > this.level.pixelH + 24) {
      this.fellOut();
      return;
    }
    const hb = p.hitbox;
    const spikeProbe = { x: hb.x + 1, y: hb.y + hb.h - 6, w: hb.w - 2, h: 6 };
    if (rectTouchesTile(spikeProbe, this.level, T.SPIKE)) {
      if (this.player.invuln <= 0) {
        this.hurtPlayer(p.cx + (p.vx > 0 ? 10 : p.vx < 0 ? -10 : 0));
        if (this.phase === 'playing') p.vy = -PLAYER.hurtKnockY * 1.3;
      }
    }
  }

  private checkEnemies(): void {
    const p = this.player;
    if (p.noclip) return;
    const hb = p.hitbox;
    const attack = p.attackBox;
    const beam = p.hoverBeam;
    for (const e of this.entities) {
      if (!(e instanceof Enemy) || !e.alive) continue;
      const er = e.rect;
      // Stomp: falling onto the top part of an enemy.
      if (e.stompable && !e.invincible && (p.vy > 0 || p.state === 'pound') && overlaps(hb, er)) {
        const prevBottom = p.prevY + p.h;
        if (prevBottom <= e.prevY + Math.max(8, e.h * 0.5)) {
          const pound = p.state === 'pound';
          // Stomping always bounces, even if the enemy is briefly immune.
          if (e.hit(pound ? 'pound' : 'stomp', this, pound ? 6 : 4)) this.popTokens(e);
          this.sfx('stomp');
          p.bounce(this.app.input.held('jump'));
          continue;
        }
      }
      if (attack && overlaps(attack, er)) {
        if (e.hit('spin', this, 3)) {
          this.popTokens(e);
          continue;
        }
      }
      if (beam && !e.projectile && overlaps(beam, er)) {
        if (e.hit('beam', this, 1)) {
          this.popTokens(e);
          continue;
        }
      }
      const hurt = e.hurtbox;
      if (hurt && overlaps(hb, hurt)) {
        if (e.projectile && e.consumeOnHit) e.alive = false;
        this.hurtPlayer(er.x + er.w / 2);
      }
    }
  }

  private finish(): void {
    const def = this.level.def;
    const prev = progressFor(this.app.save, def.id);
    const wasCompleted = prev.completed;
    recordRun(this.app.save, def.id, this.sparks, this.agents, this.time, this.tokens);
    this.app.persist();
    this.app.showResults({
      levelIndex: this.levelIndex,
      sparks: this.sparks,
      prevSparks: this.prevSparks,
      agents: this.agents,
      tokens: this.tokens,
      time: this.time,
      firstClear: !wasCompleted,
    });
  }

  private openPause(): void {
    if (this.phase !== 'playing' || this.paused) return;
    this.paused = true;
    this.pauseIndex = 0;
    this.app.audio.hoverStop();
    this.wasHovering = false;
    this.sfx('select');
  }

  private updatePause(): void {
    const input = this.app.input;
    if (input.pressed('pause') || input.pressed('back')) {
      this.paused = false;
      return;
    }
    if (input.pressed('down')) {
      this.pauseIndex = (this.pauseIndex + 1) % PAUSE_ITEMS.length;
      this.sfx('select');
    }
    if (input.pressed('up')) {
      this.pauseIndex = (this.pauseIndex + PAUSE_ITEMS.length - 1) % PAUSE_ITEMS.length;
      this.sfx('select');
    }
    if (input.pressed('confirm')) this.activatePause();
  }

  private activatePause(): void {
    this.sfx('confirm');
    const item = PAUSE_ITEMS[this.pauseIndex];
    if (item === 'RESUME') this.paused = false;
    else if (item === 'RESTART FROM CHECKPOINT') {
      this.paused = false;
      this.hearts = Math.max(1, this.hearts);
      this.respawn();
    } else if (item === 'RESTART LEVEL') this.app.startLevel(this.levelIndex);
    else if (item === 'CRT FILTER') {
      this.app.renderer.crt = !this.app.renderer.crt;
      this.app.persist();
    } else if (item === 'QUIT TO MAP') this.app.goToLevelSelect(this.levelIndex);
  }

  onClick(x: number, y: number): void {
    // Fingers are less precise than a mouse: give every button a few units of slack.
    const pad = this.app.input.touchMode ? 4 : 0;
    const inside = (r: Rect) => x >= r.x - pad && x <= r.x + r.w + pad && y >= r.y - pad && y <= r.y + r.h + pad;
    if (this.paused) {
      const i = this.pauseRows.findIndex(inside);
      if (i >= 0) {
        this.pauseIndex = i;
        this.activatePause();
      }
      return;
    }
    if (!this.hud) return;
    if (inside(this.hud.controls)) this.showControls = !this.showControls;
    else if (inside(this.hud.mute)) this.app.toggleMute();
    else if (inside(this.hud.pause)) this.openPause();
    else if (this.showControls) this.showControls = false;
  }

  leave(): void {
    this.app.audio.hoverStop();
    this.app.renderer.canvas.style.cursor = 'default';
  }

  // --- Render ---------------------------------------------------------------

  render(alpha: number): void {
    const r = this.app.renderer;
    const ctx = r.ctx;
    const def = this.level.def;
    r.begin(def.theme === 'caves' ? '#111111' : COLORS.bg);
    const a = this.paused || this.showControls || this.hitstopTimer > 0 ? 1 : alpha;

    const camX = r.snap(lerp(this.camera.prevX, this.camera.x, a) + this.camera.shakeX);
    const camY = r.snap(lerp(this.camera.prevY, this.camera.y, a) + this.camera.shakeY);

    this.parallax.draw(ctx, camX, camY, this.camera.maxY, r.viewW, r.viewH, this.time);

    ctx.save();
    ctx.translate(-camX, -camY);
    this.terrain.draw(ctx, camX, camY, r.viewW, r.viewH);
    this.terrain.drawCorrupted(ctx, camX, camY, r.viewW, r.viewH, this.time);
    this.terrain.drawShimmer(ctx, camX, camY, r.viewW, r.viewH, this.time);

    const sorted = [...this.entities].sort((e1, e2) => e1.layer - e2.layer);
    for (const e of sorted) {
      if (e.x > camX + r.viewW + 64 || e.x + e.w < camX - 64 || e.y > camY + r.viewH + 64 || e.y + e.h < camY - 200) continue;
      e.draw(r, this, a);
    }

    const p = this.player;
    if (this.phase !== 'dying') {
      const px = r.snap(lerp(p.prevX, p.x, a) + p.w / 2);
      const pb = r.snap(lerp(p.prevY, p.y, a) + p.h);
      const hop = this.phase === 'complete' ? Math.abs(Math.sin(this.phaseTimer * 8)) * 6 : 0;
      drawClawd(ctx, p, px, pb - hop, this.time);
      if (this.gun && !(p.invuln > 0 && p.state !== 'hurt' && Math.floor(this.time * 14) % 2 === 0)) {
        drawArmedExtras(ctx, p, px, pb - hop, this.gun.weapon.id, this.gun.flash, this.gun.recoil);
      }
    }
    this.drawBeams();
    this.particles.draw(ctx);
    this.drawVoid(camX, camY);

    for (const pop of this.popups) {
      r.text(pop.text, pop.x, pop.y, { size: 6, align: 'center', bold: true, color: pop.color, alpha: Math.min(1, pop.t * 2) });
    }
    if (this.debug) this.drawDebugWorld();
    ctx.restore();

    if (def.dark) this.drawDarkness(camX, camY, a);
    if (this.fade > 0 || this.phase === 'dying') {
      const f = this.phase === 'dying' ? Math.min(1, Math.max(0, (this.phaseTimer - 0.5) / 0.5)) : this.fade;
      ctx.fillStyle = `rgba(10,10,10,${f})`;
      ctx.fillRect(0, 0, r.viewW, r.viewH);
    }

    const bossName = this.boss instanceof Codex ? 'CODEX' : 'THE HALLUCINATION';
    const bossHud = this.boss && !this.boss.dead ? { name: bossName, hp: this.boss.hp, maxHp: this.boss.maxHp } : undefined;
    this.hud = drawHud(r, {
      hearts: this.hearts,
      maxHearts: Math.max(this.maxHearts, this.hearts),
      sparks: this.sparks.filter(Boolean).length,
      sparksTotal: this.sparks.length,
      tokens: this.tokens,
      agents: this.agents.filter(Boolean).length,
      agentsTotal: this.agents.length,
      label: `${def.id} · ${def.name.toLowerCase()}`,
      muted: this.app.audio.muted,
      time: this.time,
      flashSparks: this.flashSparks,
      flashHearts: this.flashHearts,
      boss: bossHud,
    });

    const touch = this.app.input.touchMode;
    if (touch && this.app.touch.enabled && this.phase === 'playing') drawTouchControls(r, this.app.touch, this.app.input.touchAim);
    if (this.gun) this.drawWeaponHud();
    if (this.gun && touch && this.phase === 'playing' && !this.paused) this.drawAimMarker(camX, camY, a);
    this.drawIntroCard();
    if (this.phase === 'complete') this.drawCompleteBanner();
    const crosshair = !!this.gun && !this.paused && !this.showControls && this.app.input.mouseAiming(performance.now());
    if (crosshair) this.drawCrosshair();
    // The dotted crosshair replaces the system cursor while aiming.
    r.canvas.style.cursor = crosshair ? 'none' : 'default';
    if (this.debug) this.drawDebugText();
    if (this.paused) this.drawPause();
    if (this.showControls) drawControlsOverlay(r, touch);

    r.postFx();
  }

  /** Touch has no crosshair: a short dotted line shows where the gun points. */
  private drawAimMarker(camX: number, camY: number, a: number): void {
    const ctx = this.app.renderer.ctx;
    const p = this.player;
    const pv = gunPivot(p, lerp(p.prevX, p.x, a) + p.w / 2, lerp(p.prevY, p.y, a) + p.h);
    const dx = Math.cos(p.aim);
    const dy = Math.sin(p.aim);
    ctx.fillStyle = this.gun && this.gun.overheated > 0 ? COLORS.red : COLORS.orange;
    ctx.globalAlpha = 0.55;
    for (let d = 24; d <= 44; d += 5) ctx.fillRect(pv.x - camX + dx * d - 0.75, pv.y - camY + dy * d - 0.75, 1.5, 1.5);
    ctx.globalAlpha = 1;
  }

  private drawBeams(): void {
    const ctx = this.app.renderer.ctx;
    for (const b of this.beams) {
      const len = Math.hypot(b.x1 - b.x0, b.y1 - b.y0);
      const dx = (b.x1 - b.x0) / (len || 1);
      const dy = (b.y1 - b.y0) / (len || 1);
      for (let d = 0; d < len; d += 2) {
        const j = (Math.random() - 0.5) * 1.5;
        ctx.fillStyle = d % 6 === 0 ? '#FFFFFF' : b.color;
        ctx.fillRect(b.x0 + dx * d - dy * j - 1, b.y0 + dy * d + dx * j - 1, 2, 2);
      }
    }
  }

  private drawCrosshair(): void {
    const r = this.app.renderer;
    const ctx = r.ctx;
    const x = Math.round(this.app.input.mouseX);
    const y = Math.round(this.app.input.mouseY);
    const hot = this.gun && this.gun.overheated > 0;
    ctx.fillStyle = hot ? COLORS.red : COLORS.orange;
    for (const [ox, oy] of [[-6, 0], [-4, 0], [4, 0], [6, 0], [0, -6], [0, -4], [0, 4], [0, 6]]) ctx.fillRect(x + ox - 0.5, y + oy - 0.5, 1, 1);
    ctx.fillStyle = '#FFFFFF';
    ctx.fillRect(x - 0.5, y - 0.5, 1, 1);
  }

  /** Bottom-left: current weapon, owned slots and the context (heat) bar. */
  private drawWeaponHud(): void {
    const gun = this.gun;
    if (!gun) return;
    const r = this.app.renderer;
    const ctx = r.ctx;
    const x = 8 + r.safe.left;
    // On touch screens the bottom corners belong to the thumbs: sit under the top bar instead.
    const y = this.app.input.touchMode ? 24 : r.viewH - 30;
    const w = 150;
    panel(ctx, x, y, w, 22);
    const owned = WEAPON_ORDER.filter((id) => this.app.save.weapons.includes(id));
    r.text(gun.weapon.name.toUpperCase(), x + 6, y + 6.5, { size: 5.5, bold: true, color: COLORS.textBright });
    // Slots 1-5.
    WEAPON_ORDER.forEach((id, i) => {
      const sx = x + w - 52 + i * 10;
      const has = owned.includes(id);
      const cur = gun.weapon.id === id;
      ctx.fillStyle = cur ? COLORS.orange : has ? '#5A5A5A' : '#2A2A2A';
      ctx.fillRect(sx, y + 3, 8, 7);
      r.text(String(i + 1), sx + 4, y + 7, { size: 4.5, align: 'center', color: cur ? '#161616' : has ? COLORS.textBright : '#444' });
    });
    // Context bar.
    const hot = gun.overheated > 0;
    const frac = Math.min(1, gun.heat / gun.heatCap);
    r.text(hot ? 'OVERFLOW' : 'CONTEXT', x + 6, y + 16, { size: 4.5, color: hot ? COLORS.red : COLORS.textDim });
    const bx = x + 40;
    const cells = 26;
    for (let i = 0; i < cells; i++) {
      const on = i / cells < frac;
      ctx.fillStyle = on ? (hot ? (Math.floor(this.time * 10) % 2 ? COLORS.red : COLORS.redDark) : i / cells > 0.75 ? COLORS.red : COLORS.orange) : '#2E2E2E';
      ctx.fillRect(bx + i * 4, y + 14, 3, 4);
    }
    if (this.weaponLabelT > 0) {
      r.text(gun.weapon.name, this.player.cx - this.camera.x, this.player.y - this.camera.y - 16, {
        size: 5,
        align: 'center',
        bold: true,
        color: COLORS.orangeLight,
        alpha: Math.min(1, this.weaponLabelT * 2),
      });
    }
  }

  private drawVoid(camX: number, camY: number): void {
    if (!this.level.def.risingVoid || this.voidY > camY + this.app.renderer.viewH + 10) return;
    const ctx = this.app.renderer.ctx;
    const vw = this.app.renderer.viewW;
    const top = this.voidY;
    const frame = Math.floor(this.time * 15);
    ctx.fillStyle = 'rgba(12,12,12,0.92)';
    ctx.fillRect(camX, top + 6, vw, camY + this.app.renderer.viewH - top);
    for (let x = Math.floor(camX / 4) * 4; x < camX + vw; x += 4) {
      const h = hash2(x, frame, 9);
      const edge = top + Math.sin(x * 0.07 + this.time * 3) * 3;
      ctx.fillStyle = h > 0.7 ? COLORS.red : h > 0.4 ? '#C25BD6' : gray(200);
      ctx.fillRect(x, edge, 2, 2);
      if (h > 0.5) {
        ctx.fillStyle = gray(80);
        ctx.fillRect(x + 1, edge + 5 + h * 6, 1, 1);
      }
    }
    if (Math.floor(this.time * 2) % 2 === 0) {
      this.app.renderer.text('NULL ▲ RISING', camX + vw / 2, Math.min(top + 16, camY + this.app.renderer.viewH - 8), {
        size: 5,
        align: 'center',
        color: COLORS.red,
      });
    }
  }

  private drawDarkness(camX: number, camY: number, a: number): void {
    const r = this.app.renderer;
    const ctx = r.ctx;
    const p = this.player;
    const sx = lerp(p.prevX, p.x, a) + p.w / 2 - camX;
    const sy = lerp(p.prevY, p.y, a) + p.h / 2 - camY;
    const radius = 105 + Math.sin(this.time * 2) * 3;
    const g = ctx.createRadialGradient(sx, sy, radius * 0.35, sx, sy, radius);
    g.addColorStop(0, 'rgba(8,8,8,0)');
    g.addColorStop(1, 'rgba(8,8,8,0.93)');
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, r.viewW, r.viewH);
    // Sparks and checkpoints glow through the dark.
    ctx.globalCompositeOperation = 'lighter';
    for (const e of this.entities) {
      if (e instanceof Spark || e instanceof Goal || (e instanceof Checkpoint && e.active)) {
        const ex = e.x + e.w / 2 - camX;
        const ey = e.y + e.h / 2 - camY;
        const gg = ctx.createRadialGradient(ex, ey, 0, ex, ey, 26);
        gg.addColorStop(0, 'rgba(217,119,87,0.35)');
        gg.addColorStop(1, 'rgba(217,119,87,0)');
        ctx.fillStyle = gg;
        ctx.fillRect(ex - 26, ey - 26, 52, 52);
      }
    }
    ctx.globalCompositeOperation = 'source-over';
  }

  private drawIntroCard(): void {
    const t = this.introT;
    if (t > 3) return;
    const r = this.app.renderer;
    const def = this.level.def;
    const a = t < 0.4 ? t / 0.4 : t > 2.4 ? Math.max(0, (3 - t) / 0.6) : 1;
    const cy = r.viewH * 0.32;
    r.text(def.id, r.viewW / 2, cy - 14, { size: 6, align: 'center', color: COLORS.orange, alpha: a, bold: true });
    r.text(def.name.toUpperCase(), r.viewW / 2, cy, { size: 11, align: 'center', color: COLORS.textBright, alpha: a, bold: true });
    r.text(def.subtitle, r.viewW / 2, cy + 13, { size: 5.5, align: 'center', color: COLORS.text, alpha: a });
    const ctx = r.ctx;
    ctx.globalAlpha = a;
    const w = Math.min(1, t * 2) * 120;
    for (let x = -w / 2; x < w / 2; x += 3) {
      ctx.fillStyle = gray(90);
      ctx.fillRect(r.viewW / 2 + x, cy + 21, 1, 1);
    }
    ctx.globalAlpha = 1;
  }

  private drawCompleteBanner(): void {
    const r = this.app.renderer;
    const a = Math.min(1, this.phaseTimer * 3);
    const def = this.level.def;
    r.text(def.boss ? `WORLD ${def.world} CLEAR!` : 'LEVEL COMPLETE', r.viewW / 2, r.viewH * 0.3, {
      size: 12,
      align: 'center',
      bold: true,
      color: COLORS.orange,
      alpha: a,
    });
  }

  private drawPause(): void {
    const r = this.app.renderer;
    const ctx = r.ctx;
    ctx.fillStyle = 'rgba(10,10,10,0.7)';
    ctx.fillRect(0, 0, r.viewW, r.viewH);
    const touch = this.app.input.touchMode;
    // Taller rows on touch screens so each item is a comfortable target.
    const row = touch ? 19 : 13;
    const w = 160;
    const h = 30 + PAUSE_ITEMS.length * row;
    const x = r.viewW / 2 - w / 2;
    const y = r.viewH / 2 - h / 2;
    panel(ctx, x, y, w, h, '#4A4A4A', 'rgba(20,20,20,0.96)');
    r.text('PAUSED', x + w / 2, y + 12, { size: 7, align: 'center', bold: true, color: COLORS.orange });
    this.pauseRows = [];
    PAUSE_ITEMS.forEach((item, i) => {
      const sel = i === this.pauseIndex;
      const label = item === 'CRT FILTER' ? `CRT FILTER: ${r.crt ? 'ON' : 'OFF'}` : item;
      const ly = y + 30 + i * row;
      this.pauseRows.push({ x: x + 6, y: ly - row / 2, w: w - 12, h: row });
      if (touch) panel(ctx, x + 8, ly - row / 2 + 1.5, w - 16, row - 3, sel ? COLORS.orange : '#2C2C2C', 'rgba(18,18,18,0.85)');
      else if (sel) r.text('>', x + 14, ly, { size: 6, color: COLORS.orange, bold: true });
      r.text(label, x + 24, ly, { size: 6, color: sel ? COLORS.textBright : COLORS.text });
    });
  }

  private drawDebugWorld(): void {
    const ctx = this.app.renderer.ctx;
    const box = (rc: Rect | null, c: string) => {
      if (!rc) return;
      ctx.strokeStyle = c;
      ctx.lineWidth = 0.5;
      ctx.strokeRect(rc.x, rc.y, rc.w, rc.h);
    };
    const p = this.player;
    box(p.hitbox, '#4CFF7A');
    box(p.attackBox, '#FFD84C');
    box(p.hoverBeam, '#FFD84C');
    for (const e of this.entities) {
      if (e instanceof Enemy) box(e.hurtbox, '#FF4C4C');
      else box(e.rect, '#4CB8FF');
    }
  }

  private drawDebugText(): void {
    const r = this.app.renderer;
    const p = this.player;
    const lines = [
      `fps ${this.app.fps.toFixed(0)}  scale ${r.scale}  view ${r.viewW.toFixed(0)}x${r.viewH.toFixed(0)}`,
      `pos ${p.x.toFixed(1)},${p.y.toFixed(1)}  tile ${Math.floor(p.cx / TILE)},${Math.floor(p.bottom / TILE) - 1}`,
      `v ${p.vx.toFixed(0)},${p.vy.toFixed(0)}  ${p.state}${p.grounded ? ' grounded' : ''}${p.hovering ? ' hover' : ''}${p.noclip ? ' NOCLIP' : ''}`,
      `entities ${this.entities.length}  F2 noclip`,
    ];
    lines.forEach((l, i) => r.text(l, 8, 30 + i * 8, { size: 5, color: '#4CFF7A' }));
  }
}

function isPlatform(e: Entity): boolean {
  return 'dx' in e && 'active' in e;
}
