import { STEP } from './config';
import { AudioEngine } from './core/audio';
import { Input, attachKeyboard, attachMouse, pollGamepad } from './core/input';
import { TouchControls, attachTouch } from './core/touch';
import { Renderer } from './render/renderer';
import { drawRotateHint } from './render/touchView';
import { loadSave, writeSave, type SaveData } from './save';
import { GameScene } from './scenes/game';
import { LevelSelectScene } from './scenes/levelSelect';
import { ResultsScene, type RunResult } from './scenes/results';
import { ShopScene } from './scenes/shop';
import { TitleScene } from './scenes/title';
import { LEVELS } from './world/levels';

export interface Scene {
  update(dt: number): void;
  render(alpha: number): void;
  onClick?(x: number, y: number): void;
  leave?(): void;
}

export class App {
  readonly renderer: Renderer;
  readonly input = new Input();
  readonly audio = new AudioEngine();
  readonly save: SaveData;
  readonly touch: TouchControls;
  readonly levels = LEVELS;
  private scene!: Scene;
  private acc = 0;
  private last = 0;
  fps = 60;
  /** Go fullscreen on the next finger lift (browsers only allow it from a user gesture). */
  private fullscreenPending = false;

  constructor(canvas: HTMLCanvasElement) {
    this.renderer = new Renderer(canvas);
    this.save = loadSave();
    this.audio.muted = this.save.muted;
    this.renderer.crt = this.save.crt;
    const r = this.renderer;
    const toView = (x: number, y: number) => r.toView(x, y);
    this.input.touchMode = typeof matchMedia !== 'undefined' && matchMedia('(pointer: coarse)').matches;
    this.touch = new TouchControls(this.input, () => ({ w: r.viewW, h: r.viewH, safe: r.safe }));
    attachKeyboard(this.input, window);
    attachMouse(this.input, canvas, toView);
    attachTouch(this.touch, canvas, toView, (x, y) => {
      if (!(this.input.touchMode && r.portrait)) this.scene.onClick?.(x, y);
    });
    const unlock = () => this.audio.unlock();
    window.addEventListener('keydown', unlock);
    window.addEventListener('pointerdown', unlock);
    // iOS only lets audio start from the end of a touch.
    window.addEventListener('pointerup', (e) => {
      unlock();
      if (e.pointerType === 'touch' && this.fullscreenPending) {
        this.fullscreenPending = false;
        this.enterFullscreen();
      }
    });
    this.goToTitle();
  }

  setScene(s: Scene): void {
    this.scene?.leave?.();
    this.scene = s;
    this.touch.setEnabled(false);
    this.input.clear();
  }

  /** Ask for fullscreen + landscape when the current tap ends (phones only). */
  requestFullscreen(): void {
    if (this.input.touchMode && !document.fullscreenElement) this.fullscreenPending = true;
  }

  private enterFullscreen(): void {
    const el = document.documentElement;
    if (!el.requestFullscreen) return; // iPhone Safari: no element fullscreen; "Add to Home Screen" instead.
    el.requestFullscreen({ navigationUI: 'hide' })
      .then(() => (screen.orientation as ScreenOrientation & { lock?: (o: string) => Promise<void> }).lock?.('landscape'))
      .catch(() => {});
  }

  goToTitle(): void {
    this.setScene(new TitleScene(this));
  }

  goToLevelSelect(focus?: number): void {
    this.setScene(new LevelSelectScene(this, focus));
  }

  startLevel(index: number, warp?: { tx: number; ty: number }): void {
    const scene = new GameScene(this, index);
    if (warp) scene.warp(warp.tx, warp.ty);
    this.setScene(scene);
  }

  goToShop(): void {
    this.setScene(new ShopScene(this));
  }

  showResults(result: RunResult): void {
    this.setScene(new ResultsScene(this, result));
  }

  persist(): void {
    this.save.muted = this.audio.muted;
    this.save.crt = this.renderer.crt;
    writeSave(this.save);
  }

  toggleMute(): void {
    this.audio.unlock();
    this.audio.setMuted(!this.audio.muted);
    this.persist();
  }

  isUnlocked(index: number): boolean {
    if (index === 0) return true;
    return !!this.save.levels[this.levels[index - 1].id]?.completed;
  }

  /** Dev helper: simulate `ticks` fixed steps immediately (used for headless screenshots). */
  fastForward(ticks: number, hold: string[] = []): void {
    for (const k of hold) this.input.keyDown(k);
    for (let i = 0; i < ticks; i++) {
      this.input.tick();
      this.scene.update(STEP);
    }
    for (const k of hold) this.input.keyUp(k);
  }

  start(): void {
    this.last = performance.now();
    const frame = (now: number) => {
      const dt = Math.min(0.25, (now - this.last) / 1000);
      this.last = now;
      if (dt > 0) this.fps += (1 / dt - this.fps) * 0.05;
      // A phone held upright shows a rotate hint and the game waits.
      const upright = this.input.touchMode && this.renderer.portrait;
      this.acc = upright ? 0 : this.acc + dt;
      while (this.acc >= STEP) {
        pollGamepad(this.input);
        this.input.tick();
        if (this.input.pressed('mute')) this.toggleMute();
        this.scene.update(STEP);
        this.acc -= STEP;
      }
      this.scene.render(this.acc / STEP);
      if (upright) drawRotateHint(this.renderer, now / 1000);
      requestAnimationFrame(frame);
    };
    requestAnimationFrame(frame);
  }
}
