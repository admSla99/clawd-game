import '@fontsource/jetbrains-mono/400.css';
import '@fontsource/jetbrains-mono/700.css';
import './style.css';
import { App } from './app';

const canvas = document.getElementById('game') as HTMLCanvasElement;
const app = new App(canvas);

// Dev shortcuts: ?map / ?shop open those screens, ?rich fills the wallet, ?level=2 jumps into a level, ?tx=40&ty=10 moves Clawd to a tile.
if (import.meta.env.DEV) {
  const q = new URLSearchParams(location.search);
  const level = q.get('level');
  if (q.has('rich')) {
    app.save.wallet = 2000;
    app.save.sparksSpent = -30;
    if (!app.save.weapons.length) app.save.weapons.push('blaster');
  }
  if (q.has('map')) app.goToLevelSelect();
  if (q.has('shop')) app.goToShop();
  if (level !== null) app.startLevel(Number(level), q.has('tx') ? { tx: Number(q.get('tx')), ty: Number(q.get('ty') ?? 0) } : undefined);
  // ?ff=240&hold=KeyD,Space simulates ticks up front (handy for headless screenshots).
  if (q.has('ff')) app.fastForward(Number(q.get('ff')), (q.get('hold') ?? '').split(',').filter(Boolean));
  // ?touch shows the on-screen touch controls on a desktop browser.
  if (q.has('touch')) app.input.touchMode = true;
}

// Start after the bundled font is ready so the first frames already use it.
const ready = document.fonts?.ready ?? Promise.resolve();
void Promise.race([ready, new Promise((r) => setTimeout(r, 1500))]).then(() => app.start());
