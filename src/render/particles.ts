export interface Particle {
  x: number;
  y: number;
  vx: number;
  vy: number;
  life: number;
  maxLife: number;
  size: number;
  color: string;
  gravity: number;
  drag: number;
}

export interface EmitOpts {
  count?: number;
  speed?: number;
  /** Direction in radians and cone spread; default is all directions. */
  angle?: number;
  spread?: number;
  life?: number;
  size?: number;
  color?: string | string[];
  gravity?: number;
  drag?: number;
  vx?: number;
  vy?: number;
}

export class Particles {
  private list: Particle[] = [];

  emit(x: number, y: number, o: EmitOpts = {}): void {
    const count = o.count ?? 8;
    for (let i = 0; i < count; i++) {
      const angle = (o.angle ?? 0) + (o.spread === undefined ? Math.random() * Math.PI * 2 : (Math.random() - 0.5) * o.spread);
      const speed = (o.speed ?? 80) * (0.4 + Math.random() * 0.6);
      const life = (o.life ?? 0.5) * (0.6 + Math.random() * 0.4);
      const colors = o.color ?? '#ffffff';
      this.list.push({
        x,
        y,
        vx: Math.cos(angle) * speed + (o.vx ?? 0),
        vy: Math.sin(angle) * speed + (o.vy ?? 0),
        life,
        maxLife: life,
        size: o.size ?? 1,
        color: Array.isArray(colors) ? colors[Math.floor(Math.random() * colors.length)] : colors,
        gravity: o.gravity ?? 0,
        drag: o.drag ?? 0,
      });
    }
    if (this.list.length > 1500) this.list.splice(0, this.list.length - 1500);
  }

  update(dt: number): void {
    let w = 0;
    for (let i = 0; i < this.list.length; i++) {
      const p = this.list[i];
      p.life -= dt;
      if (p.life <= 0) continue;
      p.vy += p.gravity * dt;
      if (p.drag) {
        const k = Math.max(0, 1 - p.drag * dt);
        p.vx *= k;
        p.vy *= k;
      }
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      this.list[w++] = p;
    }
    this.list.length = w;
  }

  draw(ctx: CanvasRenderingContext2D): void {
    for (const p of this.list) {
      const t = p.life / p.maxLife;
      ctx.globalAlpha = Math.min(1, t * 1.6);
      ctx.fillStyle = p.color;
      const s = p.size * (t > 0.3 ? 1 : 0.6);
      ctx.fillRect(p.x - s / 2, p.y - s / 2, s, s);
    }
    ctx.globalAlpha = 1;
  }

  clear(): void {
    this.list.length = 0;
  }
}
