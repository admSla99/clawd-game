import { STEP } from './config';
import { AudioEngine } from './core/audio';
import { Input, attachKeyboard, attachMouse, pollGamepad } from './core/input';
import { Renderer } from './render/renderer';
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
  readonly levels = LEVELS;
  private scene!: Scene;
  private acc = 0;
  private last = 0;
  fps = 60;

  constructor(canvas: HTMLCanvasElement) {
    this.renderer = new Renderer(canvas);
    this.save = loadSave();
    this.audio.muted = this.save.muted;
    this.renderer.crt = this.save.crt;
    attachKeyboard(this.input, window);
    attachMouse(this.input, canvas, (x, y) => this.renderer.toView(x, y));
    const unlock = () => this.audio.unlock();
    window.addEventListener('keydown', unlock);
    window.addEventListener('pointerdown', unlock);
    canvas.addEventListener('pointerdown', (e) => {
      const p = this.renderer.toView(e.clientX, e.clientY);
      this.scene.onClick?.(p.x, p.y);
    });
    this.goToTitle();
  }

  setScene(s: Scene): void {
    this.scene?.leave?.();
    this.scene = s;
    this.input.clear();
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
      this.acc += dt;
      while (this.acc >= STEP) {
        pollGamepad(this.input);
        this.input.tick();
        if (this.input.pressed('mute')) this.toggleMute();
        this.scene.update(STEP);
        this.acc -= STEP;
      }
      this.scene.render(this.acc / STEP);
      requestAnimationFrame(frame);
    };
    requestAnimationFrame(frame);
  }
}
