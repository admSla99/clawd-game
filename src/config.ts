// All gameplay tuning lives here so feel can be adjusted in one place.

export const TILE = 16;
export const DOT = 4; // spacing of the dot-matrix grid in world px
export const BASE_VIEW_H = 270;
export const STEP = 1 / 60;

export const PLAYER = {
  width: 18,
  height: 18,

  runSpeed: 150,
  groundAccel: 1500,
  groundDecel: 1900,
  turnAccel: 2800,
  airAccel: 1100,
  airDecel: 520,

  gravity: 1500,
  fallGravityMult: 1.3,
  apexGravityMult: 0.55,
  apexThreshold: 70,
  maxFall: 430,
  jumpVelocity: 470,
  jumpCutMult: 0.45,
  coyoteTime: 0.1,
  jumpBuffer: 0.12,
  cornerCorrection: 6,
  dropThroughTime: 0.18,

  hoverDuration: 0.85,
  hoverFallSpeed: 18,
  hoverAccel: 2600,

  spinDuration: 0.32,
  spinCooldown: 0.12,
  spinHop: 160,
  spinReach: 10,

  poundWindup: 0.14,
  poundSpeed: 620,
  poundBounce: 140,

  stompBounce: 330,
  stompBounceHeld: 450,

  hurtInvuln: 1.3,
  hurtStun: 0.32,
  hurtKnockX: 170,
  hurtKnockY: 250,

  maxHearts: 3,
  heartCap: 5,
  tokensPerHeart: 100,
};

export const COLORS = {
  bg: '#161616',
  orange: '#D97757',
  orangeShade: '#B35E40',
  orangeLight: '#F0A585',
  eye: '#1A1311',
  red: '#E0605A',
  redDark: '#8F3A37',
  cyan: '#5FD0D8',
  text: '#9A9A9A',
  textDim: '#5C5C5C',
  textBright: '#E6E6E6',
  hudBorder: '#343434',
  hudFill: 'rgba(22,22,22,0.82)',
};

export function gray(v: number): string {
  const c = Math.max(0, Math.min(255, Math.round(v)));
  return `rgb(${c},${c},${c})`;
}
