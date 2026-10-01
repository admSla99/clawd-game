import { STEP, TILE } from '../src/config';
import type { Action, InputView } from '../src/core/input';
import { Player, type Platform } from '../src/entities/player';
import { parseLevel, type Level } from '../src/world/level';

export function makeLevel(map: string[]): Level {
  return parseLevel({ id: 'test', world: 1, name: 'Test', subtitle: '', theme: 'plains', music: 'plains', map });
}

/** Scriptable input: set what is held, it derives pressed/released per tick. */
export class FakeInput implements InputView {
  private now = new Set<Action>();
  private prev = new Set<Action>();

  set(...actions: Action[]): void {
    this.prev = this.now;
    this.now = new Set(actions);
  }

  held(a: Action): boolean {
    return this.now.has(a);
  }

  pressed(a: Action): boolean {
    return this.now.has(a) && !this.prev.has(a);
  }

  released(a: Action): boolean {
    return !this.now.has(a) && this.prev.has(a);
  }
}

export class Sim {
  readonly input = new FakeInput();
  readonly player: Player;
  readonly platforms: Platform[] = [];
  frames = 0;

  constructor(readonly level: Level) {
    const s = level.start;
    this.player = new Player(s.x, s.y);
  }

  /** Advance `n` ticks holding `actions`. */
  run(n: number, ...actions: Action[]): void {
    for (let i = 0; i < n; i++) {
      this.input.set(...actions);
      this.player.update(STEP, this.input, { level: this.level, platforms: this.platforms });
      this.frames++;
    }
  }

  /** Run until a predicate holds (or give up). */
  until(pred: () => boolean, max: number, ...actions: Action[]): boolean {
    for (let i = 0; i < max; i++) {
      if (pred()) return true;
      this.run(1, ...actions);
    }
    return pred();
  }

  get tileX(): number {
    return Math.floor(this.player.cx / TILE);
  }
}
