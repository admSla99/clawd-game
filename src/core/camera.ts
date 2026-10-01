import { clamp } from './math';

/** Platformer camera: horizontal look-ahead, vertical deadzone, level bounds, trauma shake. */
export class Camera {
  x = 0;
  y = 0;
  prevX = 0;
  prevY = 0;
  private lookAhead = 0;
  private trauma = 0;
  shakeX = 0;
  shakeY = 0;

  constructor(
    public viewW: number,
    public viewH: number,
    public boundsW: number,
    public boundsH: number,
  ) {}

  snapTo(tx: number, ty: number): void {
    this.x = this.clampX(tx - this.viewW / 2);
    this.y = this.clampY(ty - this.viewH * 0.6);
    this.prevX = this.x;
    this.prevY = this.y;
    this.lookAhead = 0;
  }

  private clampX(x: number): number {
    if (this.boundsW <= this.viewW) return (this.boundsW - this.viewW) / 2;
    return clamp(x, 0, this.boundsW - this.viewW);
  }

  private clampY(y: number): number {
    if (this.boundsH <= this.viewH) return this.boundsH - this.viewH;
    return clamp(y, 0, this.boundsH - this.viewH);
  }

  /** Lowest the camera can go; parallax uses it as the reference height. */
  get maxY(): number {
    return this.clampY(Number.POSITIVE_INFINITY);
  }

  update(dt: number, tx: number, ty: number, facing: number, grounded: boolean, vy: number): void {
    this.prevX = this.x;
    this.prevY = this.y;
    this.lookAhead += (facing * 36 - this.lookAhead) * Math.min(1, dt * 2.5);
    const wantX = tx - this.viewW / 2 + this.lookAhead;
    this.x += (wantX - this.x) * Math.min(1, dt * 7);

    // Vertical: follow tightly when falling fast or grounded, keep a deadzone while jumping.
    const centreY = this.y + this.viewH * 0.58;
    const dz = 34;
    let wantY = this.y;
    if (grounded || vy > 260) wantY = ty - this.viewH * 0.58;
    else if (ty < centreY - dz) wantY = ty + dz - this.viewH * 0.58;
    else if (ty > centreY + dz) wantY = ty - dz - this.viewH * 0.58;
    const rate = vy > 260 ? 10 : grounded ? 5 : 4;
    this.y += (wantY - this.y) * Math.min(1, dt * rate);

    this.x = this.clampX(this.x);
    this.y = this.clampY(this.y);

    this.trauma = Math.max(0, this.trauma - dt * 1.6);
    const s = this.trauma * this.trauma * 7;
    this.shakeX = (Math.random() * 2 - 1) * s;
    this.shakeY = (Math.random() * 2 - 1) * s;
  }

  shake(amount: number): void {
    this.trauma = Math.min(1, this.trauma + amount);
  }
}
