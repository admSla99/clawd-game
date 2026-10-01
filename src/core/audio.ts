// Every sound is synthesized with WebAudio — the game ships no audio files.

export type Sfx =
  | 'jump'
  | 'land'
  | 'spin'
  | 'stomp'
  | 'pound'
  | 'poundLand'
  | 'break'
  | 'spark'
  | 'token'
  | 'hurt'
  | 'die'
  | 'checkpoint'
  | 'rescue'
  | 'shoot'
  | 'enemyDie'
  | 'crush'
  | 'bossHit'
  | 'bossTeleport'
  | 'select'
  | 'confirm'
  | 'complete'
  | 'heart'
  | 'gunToken'
  | 'gunPellet'
  | 'gunGlyph'
  | 'gunBeam'
  | 'gunOrb'
  | 'overheat'
  | 'explode'
  | 'hit'
  | 'deflect'
  | 'buy'
  | 'denied'
  | 'weaponGet'
  | 'typing'
  | 'slam'
  | 'laser';

export type Track = 'title' | 'plains' | 'caves' | 'window' | 'boss' | 'map' | 'mesa' | 'forge' | 'swamp' | 'towers' | 'codex' | 'shop';

interface TrackDef {
  bpm: number;
  /** MIDI roots of the chord progression, one chord per bar. */
  roots: number[];
  /** true = minor triad, false = major triad, per chord. */
  minor: boolean[];
  arp: number[];
  lead?: number[];
  drums: boolean;
}

const TRACKS: Record<Track, TrackDef> = {
  shop: { bpm: 96, roots: [53, 50, 55, 48], minor: [false, true, false, false], arp: [0, 2, 1, 3, 2, 1, 0, 2], drums: false },
  mesa: {
    bpm: 136,
    roots: [52, 52, 48, 50],
    minor: [true, true, false, false],
    arp: [0, 2, 1, 2, 3, 2, 1, 2],
    lead: [7, -1, 7, 10, -1, 12, -1, 10, 7, -1, 5, -1, 3, -1, 5, -1],
    drums: true,
  },
  forge: {
    bpm: 144,
    roots: [45, 45, 43, 41],
    minor: [true, true, false, false],
    arp: [0, 0, 2, 0, 1, 0, 2, 3],
    lead: [12, -1, 12, -1, 10, -1, 7, -1, 8, -1, 7, -1, 5, -1, 3, -1],
    drums: true,
  },
  swamp: { bpm: 112, roots: [50, 53, 48, 46], minor: [true, false, false, false], arp: [0, 1, 2, 1, 0, 2, 1, 3], lead: [3, -1, -1, 5, -1, -1, 7, -1, 10, -1, -1, 7, -1, 5, -1, -1], drums: true },
  towers: {
    bpm: 148,
    roots: [57, 55, 53, 52],
    minor: [true, false, false, true],
    arp: [0, 1, 2, 3, 2, 1, 0, 1],
    lead: [12, -1, 15, -1, 14, -1, 12, 10, -1, 12, -1, 7, -1, -1, 10, -1],
    drums: true,
  },
  codex: {
    bpm: 160,
    roots: [47, 47, 48, 46],
    minor: [true, true, false, false],
    arp: [0, 0, 3, 0, 2, 0, 3, 1],
    lead: [12, 14, 15, -1, 14, 12, -1, 10, 12, -1, 7, -1, 8, 7, -1, -1],
    drums: true,
  },
  title: { bpm: 92, roots: [57, 53, 48, 55], minor: [true, false, false, false], arp: [0, 1, 2, 1, 3, 2, 1, 2], drums: false },
  map: { bpm: 100, roots: [52, 48, 55, 50], minor: [true, false, false, false], arp: [0, 2, 1, 2, 0, 2, 3, 2], drums: false },
  plains: {
    bpm: 128,
    roots: [57, 53, 48, 55],
    minor: [true, false, false, false],
    arp: [0, 1, 2, 3, 2, 1, 2, 1],
    lead: [12, -1, 10, -1, 7, -1, 5, 7, -1, -1, 3, -1, 5, -1, -1, -1],
    drums: true,
  },
  caves: { bpm: 104, roots: [50, 46, 45, 41], minor: [true, false, true, false], arp: [0, 2, 1, 2, 3, 2, 1, 0], drums: true },
  window: {
    bpm: 140,
    roots: [55, 51, 53, 50],
    minor: [true, false, false, true],
    arp: [0, 1, 2, 3, 0, 1, 2, 3],
    lead: [7, -1, 5, -1, 3, -1, 2, -1, 3, 5, -1, 7, -1, 10, -1, -1],
    drums: true,
  },
  boss: {
    bpm: 150,
    roots: [45, 45, 46, 44],
    minor: [true, true, false, false],
    arp: [0, 0, 2, 0, 3, 0, 2, 1],
    lead: [12, 11, 12, -1, 15, -1, 12, -1, 10, -1, 8, -1, 7, -1, -1, -1],
    drums: true,
  },
};

function midiToFreq(m: number): number {
  return 440 * Math.pow(2, (m - 69) / 12);
}

export class AudioEngine {
  private ctx: AudioContext | null = null;
  private master!: GainNode;
  private sfxBus!: GainNode;
  private musicBus!: GainNode;
  private noiseBuffer!: AudioBuffer;
  private hoverNodes: { src: AudioBufferSourceNode; gain: GainNode; filter: BiquadFilterNode } | null = null;
  muted = false;

  private track: Track | null = null;
  private wantedTrack: Track | null = null;
  private nextNoteTime = 0;
  private step = 0;
  private timer: number | null = null;

  unlock(): void {
    if (this.ctx) {
      if (this.ctx.state === 'suspended') void this.ctx.resume();
      return;
    }
    const w = window as unknown as { webkitAudioContext?: typeof AudioContext };
    const Ctor = window.AudioContext ?? w.webkitAudioContext;
    if (!Ctor) return;
    const ctx = new Ctor();
    this.ctx = ctx;
    this.master = ctx.createGain();
    this.master.gain.value = this.muted ? 0 : 0.8;
    this.master.connect(ctx.destination);
    this.sfxBus = ctx.createGain();
    this.sfxBus.gain.value = 0.55;
    this.sfxBus.connect(this.master);
    this.musicBus = ctx.createGain();
    this.musicBus.gain.value = 0.22;
    this.musicBus.connect(this.master);
    const len = ctx.sampleRate;
    this.noiseBuffer = ctx.createBuffer(1, len, ctx.sampleRate);
    const data = this.noiseBuffer.getChannelData(0);
    for (let i = 0; i < len; i++) data[i] = Math.random() * 2 - 1;
    if (this.wantedTrack) {
      const t = this.wantedTrack;
      this.track = null;
      this.playMusic(t);
    }
  }

  setMuted(m: boolean): void {
    this.muted = m;
    if (this.ctx) this.master.gain.setTargetAtTime(m ? 0 : 0.8, this.ctx.currentTime, 0.02);
  }

  private tone(
    type: OscillatorType,
    freq: number,
    freqEnd: number,
    dur: number,
    vol: number,
    delay = 0,
    bus?: AudioNode,
  ): void {
    const ctx = this.ctx;
    if (!ctx) return;
    const t = ctx.currentTime + Math.max(0, delay);
    const osc = ctx.createOscillator();
    const g = ctx.createGain();
    osc.type = type;
    osc.frequency.setValueAtTime(freq, t);
    osc.frequency.exponentialRampToValueAtTime(Math.max(20, freqEnd), t + dur);
    g.gain.setValueAtTime(0.0001, t);
    g.gain.exponentialRampToValueAtTime(vol, t + 0.008);
    g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    osc.connect(g).connect(bus ?? this.sfxBus);
    osc.start(t);
    osc.stop(t + dur + 0.02);
  }

  private noise(dur: number, vol: number, f0: number, f1: number, delay = 0, q = 1, bus?: AudioNode): void {
    const ctx = this.ctx;
    if (!ctx) return;
    const t = ctx.currentTime + Math.max(0, delay);
    const src = ctx.createBufferSource();
    src.buffer = this.noiseBuffer;
    const filter = ctx.createBiquadFilter();
    filter.type = 'bandpass';
    filter.Q.value = q;
    filter.frequency.setValueAtTime(f0, t);
    filter.frequency.exponentialRampToValueAtTime(Math.max(40, f1), t + dur);
    const g = ctx.createGain();
    g.gain.setValueAtTime(vol, t);
    g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    src.connect(filter).connect(g).connect(bus ?? this.sfxBus);
    src.start(t, Math.random() * 0.5);
    src.stop(t + dur + 0.02);
  }

  play(s: Sfx): void {
    if (!this.ctx) return;
    switch (s) {
      case 'jump':
        this.tone('square', 220, 520, 0.12, 0.12);
        break;
      case 'land':
        this.noise(0.08, 0.25, 900, 200, 0, 0.8);
        break;
      case 'spin':
        this.noise(0.22, 0.25, 600, 3000, 0, 2);
        this.tone('triangle', 300, 600, 0.18, 0.08);
        break;
      case 'stomp':
        this.tone('square', 600, 1200, 0.08, 0.14);
        this.tone('square', 900, 1800, 0.08, 0.1, 0.05);
        break;
      case 'pound':
        this.tone('sawtooth', 900, 200, 0.16, 0.08);
        break;
      case 'poundLand':
        this.tone('sine', 140, 40, 0.3, 0.5);
        this.noise(0.25, 0.4, 500, 80, 0, 0.7);
        break;
      case 'break':
        this.noise(0.3, 0.45, 2500, 300, 0, 0.6);
        this.tone('square', 180, 60, 0.2, 0.12);
        break;
      case 'spark':
        [0, 4, 7, 12, 16].forEach((n, i) => this.tone('square', midiToFreq(76 + n), midiToFreq(76 + n), 0.12, 0.1, i * 0.055));
        break;
      case 'token':
        this.tone('square', 1320, 1320, 0.05, 0.06);
        this.tone('square', 1760, 1760, 0.07, 0.06, 0.04);
        break;
      case 'hurt':
        this.tone('sawtooth', 420, 90, 0.3, 0.16);
        this.noise(0.2, 0.2, 1200, 200, 0, 1);
        break;
      case 'die':
        this.tone('square', 500, 60, 0.6, 0.15);
        break;
      case 'checkpoint':
        [0, 7, 12].forEach((n, i) => this.tone('triangle', midiToFreq(69 + n), midiToFreq(69 + n), 0.18, 0.16, i * 0.08));
        break;
      case 'rescue':
        [0, 4, 7, 11, 14].forEach((n, i) => this.tone('triangle', midiToFreq(72 + n), midiToFreq(72 + n), 0.2, 0.14, i * 0.07));
        break;
      case 'shoot':
        this.tone('square', 1400, 500, 0.1, 0.05);
        break;
      case 'enemyDie':
        this.noise(0.18, 0.3, 3000, 400, 0, 1.5);
        this.tone('square', 700, 120, 0.15, 0.08);
        break;
      case 'crush':
        this.tone('sine', 110, 35, 0.35, 0.45);
        this.noise(0.3, 0.35, 400, 60, 0, 0.6);
        break;
      case 'bossHit':
        this.tone('sawtooth', 300, 60, 0.4, 0.2);
        this.noise(0.4, 0.4, 4000, 200, 0, 0.8);
        break;
      case 'bossTeleport':
        this.tone('sine', 200, 1600, 0.3, 0.1);
        this.noise(0.3, 0.12, 6000, 1500, 0, 3);
        break;
      case 'select':
        this.tone('square', 660, 660, 0.05, 0.07);
        break;
      case 'confirm':
        this.tone('square', 660, 660, 0.06, 0.08);
        this.tone('square', 990, 990, 0.1, 0.08, 0.06);
        break;
      case 'complete':
        [0, 4, 7, 12, 7, 12, 16, 19].forEach((n, i) => this.tone('square', midiToFreq(67 + n), midiToFreq(67 + n), 0.16, 0.1, i * 0.09));
        break;
      case 'gunToken':
        this.tone('square', 980, 420, 0.06, 0.06);
        break;
      case 'gunPellet':
        this.noise(0.14, 0.35, 2200, 300, 0, 0.7);
        this.tone('square', 220, 80, 0.1, 0.1);
        break;
      case 'gunGlyph':
        this.tone('square', 1500 + Math.random() * 600, 900, 0.03, 0.035);
        break;
      case 'gunBeam':
        this.tone('sawtooth', 1800, 1700, 0.08, 0.025);
        break;
      case 'gunOrb':
        this.tone('sine', 300, 90, 0.35, 0.3);
        this.tone('square', 600, 150, 0.2, 0.06);
        break;
      case 'overheat':
        this.tone('sawtooth', 700, 120, 0.5, 0.1);
        this.noise(0.5, 0.2, 4000, 500, 0, 2);
        break;
      case 'explode':
        this.tone('sine', 160, 30, 0.45, 0.5);
        this.noise(0.45, 0.5, 1500, 60, 0, 0.6);
        break;
      case 'hit':
        this.tone('square', 420, 300, 0.04, 0.05);
        break;
      case 'deflect':
        this.tone('triangle', 2400, 1800, 0.08, 0.08);
        break;
      case 'buy':
        [0, 7, 12, 16].forEach((n, i) => this.tone('square', midiToFreq(74 + n), midiToFreq(74 + n), 0.1, 0.09, i * 0.05));
        break;
      case 'denied':
        this.tone('square', 180, 160, 0.12, 0.09);
        this.tone('square', 140, 120, 0.16, 0.09, 0.12);
        break;
      case 'weaponGet':
        [0, 4, 7, 12, 16, 19, 24].forEach((n, i) => this.tone('square', midiToFreq(64 + n), midiToFreq(64 + n), 0.25, 0.1, i * 0.08));
        break;
      case 'typing':
        this.noise(0.025, 0.25, 3000 + Math.random() * 2000, 2000, 0, 3);
        break;
      case 'slam':
        this.tone('sine', 90, 30, 0.5, 0.6);
        this.noise(0.4, 0.5, 600, 50, 0, 0.5);
        break;
      case 'laser':
        this.tone('sawtooth', 220, 2200, 0.4, 0.12);
        this.noise(0.4, 0.2, 5000, 800, 0, 1);
        break;
      case 'heart':
        [0, 5, 9, 12].forEach((n, i) => this.tone('triangle', midiToFreq(72 + n), midiToFreq(72 + n), 0.15, 0.14, i * 0.06));
        break;
    }
  }

  hoverStart(): void {
    const ctx = this.ctx;
    if (!ctx || this.hoverNodes) return;
    const src = ctx.createBufferSource();
    src.buffer = this.noiseBuffer;
    src.loop = true;
    const filter = ctx.createBiquadFilter();
    filter.type = 'bandpass';
    filter.frequency.value = 1800;
    filter.Q.value = 3;
    const gain = ctx.createGain();
    gain.gain.setValueAtTime(0.0001, ctx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.16, ctx.currentTime + 0.05);
    src.connect(filter).connect(gain).connect(this.sfxBus);
    src.start();
    this.hoverNodes = { src, gain, filter };
  }

  hoverUpdate(t: number): void {
    if (!this.ctx || !this.hoverNodes) return;
    this.hoverNodes.filter.frequency.setTargetAtTime(1400 + Math.sin(t * 40) * 400, this.ctx.currentTime, 0.01);
  }

  hoverStop(): void {
    const ctx = this.ctx;
    const n = this.hoverNodes;
    if (!ctx || !n) return;
    n.gain.gain.setTargetAtTime(0.0001, ctx.currentTime, 0.03);
    n.src.stop(ctx.currentTime + 0.2);
    this.hoverNodes = null;
  }

  // --- music -------------------------------------------------------------

  playMusic(track: Track | null): void {
    this.wantedTrack = track;
    if (!this.ctx) return;
    if (this.track === track) return;
    this.track = track;
    if (this.timer !== null) {
      window.clearInterval(this.timer);
      this.timer = null;
    }
    if (!track) return;
    this.step = 0;
    this.nextNoteTime = this.ctx.currentTime + 0.1;
    this.timer = window.setInterval(() => this.schedule(), 50);
  }

  private schedule(): void {
    const ctx = this.ctx;
    if (!ctx || !this.track) return;
    const def = TRACKS[this.track];
    const stepDur = 60 / def.bpm / 4;
    // After a long tab suspension, skip ahead instead of firing a burst of notes.
    if (this.nextNoteTime < ctx.currentTime - 0.5) this.nextNoteTime = ctx.currentTime + 0.05;
    while (this.nextNoteTime < ctx.currentTime + 0.2) {
      this.scheduleStep(def, this.step, this.nextNoteTime - ctx.currentTime, stepDur);
      this.step++;
      this.nextNoteTime += stepDur;
    }
  }

  private scheduleStep(def: TrackDef, step: number, delay: number, stepDur: number): void {
    const bar = Math.floor(step / 16) % def.roots.length;
    const s = step % 16;
    const root = def.roots[bar];
    const third = def.minor[bar] ? 3 : 4;
    const chord = [0, third, 7, 12];
    const bus = this.musicBus;
    if (s % 4 === 0) this.tone('triangle', midiToFreq(root - 12), midiToFreq(root - 12), stepDur * 3.5, 0.5, delay, bus);
    if (s % 2 === 0) {
      const n = chord[def.arp[(s / 2) % def.arp.length]];
      this.tone('square', midiToFreq(root + 12 + n), midiToFreq(root + 12 + n), stepDur * 1.6, 0.07, delay, bus);
    }
    if (def.lead && Math.floor(step / 64) % 2 === 1) {
      const n = def.lead[s];
      if (n >= 0) this.tone('triangle', midiToFreq(root + 12 + n), midiToFreq(root + 12 + n), stepDur * 1.8, 0.16, delay, bus);
    }
    if (def.drums) {
      if (s % 8 === 0) this.tone('sine', 120, 40, 0.14, 0.6, delay, bus);
      if (s % 8 === 4) this.noise(0.12, 0.35, 1800, 900, delay, 0.8, bus);
      if (s % 2 === 1) this.noise(0.03, 0.12, 8000, 7000, delay, 1, bus);
    }
  }
}
