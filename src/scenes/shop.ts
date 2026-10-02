import type { App, Scene } from '../app';
import { COLORS, gray } from '../config';
import type { Rect } from '../core/math';
import { drawGun } from '../render/clawdView';
import { Parallax } from '../render/parallax';
import { drawSpark, drawToken, panel } from '../render/shapes';
import { CLAWD, drawSprite } from '../render/sprites';
import { grantWeapon, sparksAvailable } from '../save';
import { UPGRADES, WEAPONS, WEAPON_ORDER, upgradeLevel, type UpgradeDef, type WeaponDef } from '../weapons';

type Item = { type: 'weapon'; def: WeaponDef } | { type: 'upgrade'; def: UpgradeDef };

const HAIKU_PALETTE = { O: '#7F9CC6', o: '#5D7499', E: '#101418' };

const IDLE_HAIKUS = [
  ['tokens in your claw', 'power waits upon the shelf', 'spend them, little crab'],
  ['a bigger model', 'is not always the answer', 'but it sure helps here'],
  ['context overflows', 'like rain in a paper cup', 'buy a bigger cup'],
  ['no refunds, my friend', 'all sales are final, much like', 'a model’s weights are'],
  ['codex waits up north', 'it types faster than it thinks', 'bring the big cannon'],
];
const THANKS = ['thank you, come again', 'your wallet is lighter now', 'your aim is not, though'];
const DENIED = ['not enough to pay', 'go collect a few more, then', 'come back, little crab'];

/** The shop, run by HAIKU — a small, polite model who only speaks in 5-7-5. */
export class ShopScene implements Scene {
  private t = 0;
  private sel = 0;
  private items: Item[];
  private haiku = IDLE_HAIKUS[0];
  private haikuT = 0;
  private bounce = 0;
  private rows: Rect[] = [];
  private backRect: Rect = { x: 0, y: 0, w: 0, h: 0 };
  private detailRect: Rect = { x: 0, y: 0, w: 0, h: 0 };
  private parallax = new Parallax('mesa');

  constructor(private app: App) {
    this.items = [
      ...WEAPON_ORDER.map((id) => ({ type: 'weapon' as const, def: WEAPONS[id] })),
      ...UPGRADES.map((def) => ({ type: 'upgrade' as const, def })),
    ];
    this.haiku = IDLE_HAIKUS[Math.floor(Math.random() * IDLE_HAIKUS.length)];
    app.audio.playMusic('shop');
  }

  private price(item: Item): { tokens: number; sparks: number } | null {
    if (item.type === 'weapon') {
      if (this.app.save.weapons.includes(item.def.id)) return null;
      return { tokens: item.def.price, sparks: item.def.sparks };
    }
    const lv = upgradeLevel(this.app.save, item.def.id);
    if (lv >= item.def.prices.length) return null;
    return { tokens: item.def.prices[lv], sparks: item.def.sparks?.[lv] ?? 0 };
  }

  private activate(): void {
    const item = this.items[this.sel];
    const save = this.app.save;
    if (item.type === 'weapon' && save.weapons.includes(item.def.id)) {
      save.equipped = item.def.id;
      this.app.persist();
      this.app.audio.play('select');
      return;
    }
    const price = this.price(item);
    if (!price) {
      this.app.audio.play('denied');
      return;
    }
    if (save.wallet < price.tokens || sparksAvailable(save) < price.sparks) {
      this.app.audio.play('denied');
      this.say(DENIED);
      return;
    }
    save.wallet -= price.tokens;
    save.sparksSpent += price.sparks;
    if (item.type === 'weapon') {
      grantWeapon(save, item.def.id);
      save.equipped = item.def.id;
    } else {
      save.upgrades[item.def.id] = upgradeLevel(save, item.def.id) + 1;
    }
    this.app.persist();
    this.app.audio.play('buy');
    this.say(THANKS);
  }

  private say(lines: string[]): void {
    this.haiku = lines;
    this.haikuT = 0;
    this.bounce = 0.4;
  }

  update(dt: number): void {
    this.t += dt;
    this.haikuT += dt;
    this.bounce = Math.max(0, this.bounce - dt);
    if (this.haikuT > 9) {
      this.say(IDLE_HAIKUS[Math.floor(Math.random() * IDLE_HAIKUS.length)]);
    }
    const input = this.app.input;
    if (input.pressed('back') || input.pressed('shop')) {
      this.app.audio.play('select');
      this.app.goToLevelSelect();
      return;
    }
    if (input.pressed('down')) {
      this.sel = (this.sel + 1) % this.items.length;
      this.app.audio.play('select');
    }
    if (input.pressed('up')) {
      this.sel = (this.sel + this.items.length - 1) % this.items.length;
      this.app.audio.play('select');
    }
    if (input.pressed('confirm')) this.activate();
  }

  onClick(x: number, y: number): void {
    const touch = this.app.input.touchMode;
    const inside = (b: Rect) => x >= b.x && x <= b.x + b.w && y >= b.y && y <= b.y + b.h;
    if (touch && inside(this.backRect)) {
      this.app.audio.play('select');
      this.app.goToLevelSelect();
      return;
    }
    // On touch screens the detail card is the BUY / EQUIP button.
    if (touch && inside(this.detailRect)) {
      this.activate();
      return;
    }
    const i = this.rows.findIndex(inside);
    if (i < 0) return;
    if (i === this.sel) this.activate();
    else {
      this.sel = i;
      this.app.audio.play('select');
    }
  }

  render(): void {
    const r = this.app.renderer;
    const ctx = r.ctx;
    const save = this.app.save;
    r.begin();
    this.parallax.draw(ctx, this.t * 4, 0, 0, r.viewW, r.viewH, this.t);

    const touch = this.app.input.touchMode;
    const left = 14 + r.safe.left;
    const titleX = touch ? left + 22 : left;
    if (touch) {
      this.backRect = { x: left - 6, y: 8, w: 20, h: 19 };
      panel(ctx, this.backRect.x, 8, 20, 19);
      r.text('<', this.backRect.x + 10, 18, { size: 8, align: 'center', bold: true, color: COLORS.text });
    }
    r.text('SHOP', titleX, 18, { size: 10, bold: true, color: COLORS.orange });
    r.text('run by HAIKU · 5-7-5 customer service', titleX + 38, 19, { size: 5, color: COLORS.textDim });

    // Wallet.
    const wx = r.viewW - 14 - r.safe.right;
    const sp = sparksAvailable(save);
    const sparkLabel = String(sp);
    r.text(sparkLabel, wx, 18, { size: 7, align: 'right', bold: true, color: COLORS.textBright });
    const sw = r.measure(sparkLabel, 7, true);
    drawSpark(ctx, wx - sw - 9, 18, this.t, { scale: 0.6 });
    const tokLabel = String(save.wallet);
    const tx = wx - sw - 26;
    r.text(tokLabel, tx, 18, { size: 7, align: 'right', bold: true, color: COLORS.textBright });
    drawToken(ctx, tx - r.measure(tokLabel, 7, true) - 7, 18, this.t);

    // Item list.
    const lx = left;
    const lw = Math.min(210, r.viewW * 0.45);
    // Taller rows for fingers, as long as the whole list still fits on screen.
    const step = Math.max(13, Math.min(touch ? 18 : 14, Math.floor((r.viewH - 34 - 18 - 16) / this.items.length)));
    const rowH = step - 2;
    let y = 34;
    this.rows = [];
    this.items.forEach((item, i) => {
      if (i === 0 || i === WEAPON_ORDER.length) {
        r.text(i === 0 ? 'WEAPONS' : 'UPGRADES', lx, y + 4, { size: 4.5, color: COLORS.textDim, bold: true });
        y += 9;
      }
      const sel = i === this.sel;
      const row = { x: lx, y, w: lw, h: rowH };
      const mid = y + rowH / 2 + 0.5;
      this.rows.push(row);
      panel(ctx, row.x, row.y, row.w, row.h, sel ? COLORS.orange : '#2C2C2C', sel ? 'rgba(217,119,87,0.08)' : 'rgba(18,18,18,0.85)');
      if (item.type === 'weapon') drawGun(ctx, item.def.id, lx + 5, mid, 0, 1);
      else drawUpgradeIcon(ctx, item.def.id, lx + 9, mid - 0.5);
      r.text(item.def.name, lx + 20, mid, { size: 5, color: sel ? COLORS.textBright : COLORS.text });
      // Right side: state or price.
      const right = lx + lw - 5;
      if (item.type === 'weapon') {
        const owned = save.weapons.includes(item.def.id);
        if (owned) {
          const eq = save.equipped === item.def.id;
          r.text(eq ? 'EQUIPPED' : 'OWNED', right, mid, { size: 4.5, align: 'right', bold: eq, color: eq ? COLORS.orange : COLORS.textDim });
        } else {
          this.drawPrice(right, mid, item.def.price, item.def.sparks);
        }
      } else {
        const lv = upgradeLevel(save, item.def.id);
        const max = item.def.prices.length;
        for (let k = 0; k < max; k++) {
          ctx.fillStyle = k < lv ? COLORS.orange : '#3A3A3A';
          ctx.fillRect(lx + lw - 70 + k * 5, mid - 2, 3, 3);
        }
        if (lv >= max) r.text('MAX', right, mid, { size: 4.5, align: 'right', color: COLORS.textDim });
        else this.drawPrice(right, mid, item.def.prices[lv], item.def.sparks?.[lv] ?? 0);
      }
      y += step;
    });

    // Detail panel.
    const dx = lx + lw + 10;
    const dw = r.viewW - dx - 14 - r.safe.right;
    const dy = 34;
    const dh = 120;
    this.detailRect = { x: dx, y: dy, w: dw, h: dh };
    panel(ctx, dx, dy, dw, dh, '#4A4A4A', 'rgba(20,20,20,0.95)');
    const item = this.items[this.sel];
    r.text(item.def.name.toUpperCase(), dx + 8, dy + 10, { size: 7, bold: true, color: COLORS.textBright });
    wrap(r, item.def.description, dx + 8, dy + 22, dw - 16, 5, COLORS.text);
    if (item.type === 'weapon') {
      const w = item.def;
      drawGun(ctx, w.id, dx + dw - 40, dy + 14, -0.2, 2.2);
      const dps = w.damage * w.pellets * w.fireRate;
      const stat = (label: string, v: number, k: number) => {
        r.text(label, dx + 8, dy + 46 + k * 10, { size: 4.5, color: COLORS.textDim });
        for (let c = 0; c < 20; c++) {
          ctx.fillStyle = c / 20 < v ? COLORS.orange : '#2E2E2E';
          ctx.fillRect(dx + 52 + c * 4, dy + 44 + k * 10, 3, 4);
        }
      };
      stat('DAMAGE', Math.min(1, dps / 36), 0);
      stat('FIRE RATE', Math.min(1, w.fireRate / 20), 1);
      stat('RANGE', w.kind === 'beam' ? 0.85 : Math.min(1, (w.speed * w.life) / 360), 2);
      stat('HEAT', Math.min(1, (w.heat * w.fireRate) / 80), 3);
      if (w.splash) r.text('splash damage · breaks corrupted blocks', dx + 8, dy + 90, { size: 4.5, color: COLORS.orangeLight });
      if (w.kind === 'beam') r.text('pierces every enemy in the line', dx + 8, dy + 90, { size: 4.5, color: COLORS.cyan });
    } else {
      const lv = upgradeLevel(save, item.def.id);
      r.text(`LEVEL ${lv} / ${item.def.prices.length}`, dx + 8, dy + 48, { size: 5.5, bold: true, color: COLORS.orangeLight });
    }
    const price = this.price(item);
    const hint =
      item.type === 'weapon' && save.weapons.includes(item.def.id)
        ? save.equipped === item.def.id
          ? touch
            ? 'equipped — switch in game with SWAP'
            : 'equipped — switch in game with 1-5 / Q E / wheel'
          : touch
            ? 'TAP HERE: EQUIP'
            : 'SPACE / CLICK: EQUIP'
        : price
          ? save.wallet >= price.tokens && sp >= price.sparks
            ? touch
              ? 'TAP HERE: BUY'
              : 'SPACE / CLICK: BUY'
            : 'NOT ENOUGH ' + (save.wallet < price.tokens ? 'TOKENS' : 'SPARKS')
          : 'FULLY UPGRADED';
    r.text(hint, dx + 8, dy + dh - 9, { size: 5, bold: true, color: hint.startsWith('NOT') ? COLORS.red : COLORS.orange });

    // Haiku, the shopkeeper.
    const hx = dx + 22;
    const hy = Math.min(dy + dh + 70, r.viewH - 30);
    const hop = this.bounce > 0 ? Math.abs(Math.sin(this.bounce * 20)) * 4 : 0;
    drawSprite(ctx, Math.sin(this.t * 0.8) > 0.97 ? CLAWD.blink : CLAWD.idle, HAIKU_PALETTE, hx, hy - hop, { px: 2.5 });
    // Tiny bow tie.
    ctx.fillStyle = COLORS.orange;
    ctx.fillRect(hx - 3, hy - hop - 9, 6, 2);
    const bx = hx + 22;
    const bw = Math.max(...this.haiku.map((l) => r.measure(l, 5))) + 14;
    panel(ctx, bx, hy - 46, bw, 32, '#5A6E8C', 'rgba(18,20,26,0.95)');
    const chars = Math.floor(this.haikuT * 40);
    let used = 0;
    this.haiku.forEach((line, i) => {
      const shown = line.slice(0, Math.max(0, chars - used));
      used += line.length;
      r.text(shown, bx + 7, hy - 38 + i * 8, { size: 5, color: '#B8C8E0' });
    });
    r.text('HAIKU', hx, hy + 7, { size: 4.5, align: 'center', bold: true, color: '#7F9CC6' });

    const help = touch ? 'TAP AN ITEM TO SEE IT · TAP IT AGAIN TO BUY / EQUIP' : '↑ ↓ CHOOSE    SPACE BUY / EQUIP    ESC BACK';
    r.text(help, r.viewW / 2, r.viewH - 9 - r.safe.bottom, { size: 5, align: 'center', color: COLORS.textDim });
    r.postFx();
  }

  private drawPrice(right: number, y: number, tokens: number, sparks: number): void {
    const r = this.app.renderer;
    const ctx = r.ctx;
    const save = this.app.save;
    let x = right;
    if (sparks > 0) {
      const ok = sparksAvailable(save) >= sparks;
      x -= r.text(String(sparks), x, y, { size: 5, align: 'right', color: ok ? COLORS.textBright : COLORS.red });
      drawSpark(ctx, x - 5, y, this.t, { scale: 0.35 });
      x -= 14;
    }
    const ok = save.wallet >= tokens;
    x -= r.text(String(tokens), x, y, { size: 5, align: 'right', color: ok ? COLORS.textBright : COLORS.red });
    drawToken(ctx, x - 4, y, this.t);
  }
}

function wrap(r: App['renderer'], text: string, x: number, y: number, maxW: number, size: number, color: string): void {
  const words = text.split(' ');
  let line = '';
  let ly = y;
  for (const w of words) {
    const test = line ? `${line} ${w}` : w;
    if (r.measure(test, size) > maxW && line) {
      r.text(line, x, ly, { size, color });
      line = w;
      ly += size + 3;
    } else {
      line = test;
    }
  }
  if (line) r.text(line, x, ly, { size, color });
}

function drawUpgradeIcon(ctx: CanvasRenderingContext2D, id: string, x: number, y: number): void {
  ctx.fillStyle = COLORS.orange;
  switch (id) {
    case 'hearts':
      ctx.fillRect(x - 3, y - 2, 2, 2);
      ctx.fillRect(x + 1, y - 2, 2, 2);
      ctx.fillRect(x - 3, y, 6, 2);
      ctx.fillRect(x - 1, y + 2, 2, 1);
      break;
    case 'damage':
      ctx.fillRect(x - 1, y - 3, 2, 6);
      ctx.fillRect(x - 3, y - 1, 6, 2);
      break;
    case 'rate':
      for (let i = 0; i < 3; i++) ctx.fillRect(x - 4 + i * 3, y - 1, 2, 2);
      break;
    case 'context':
      ctx.fillStyle = gray(160);
      ctx.fillRect(x - 4, y - 2, 8, 4);
      ctx.fillStyle = COLORS.orange;
      ctx.fillRect(x - 3, y - 1, 5, 2);
      break;
    case 'hover':
      ctx.fillRect(x - 3, y - 2, 6, 2);
      ctx.fillStyle = COLORS.orangeLight;
      ctx.fillRect(x - 2, y + 1, 1, 2);
      ctx.fillRect(x + 1, y + 1, 1, 2);
      break;
    case 'magnet':
      ctx.fillRect(x - 3, y - 3, 2, 5);
      ctx.fillRect(x + 1, y - 3, 2, 5);
      ctx.fillRect(x - 3, y + 1, 6, 2);
      break;
  }
}
