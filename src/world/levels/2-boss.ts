import type { LevelDef } from '../level';

// Legend: # rock  = one-way  ^ spikes  X corrupted (ground-pound or blast it)
//         @ start  S spark  o token  A sub-agent  C checkpoint  G exit  ? sign
//         E bug  F spam bot  R rate limiter (2x2)  M/V moving platform  B boss
//         T turret  Y ceiling turret  D drone  H shield bot  I injector
export const LEVEL_2_BOSS: LevelDef = {
  id: '2-B',
  world: 2,
  name: 'Codex',
  subtitle: 'a rival model has entered the chat',
  theme: 'codex',
  music: 'codex',
  boss: 'codex',
  map: [
    '##                                    ##',
    '##                                    ##',
    '##                                    ##',
    '##                                    ##',
    '##                                    ##',
    '##                  B                 ##',
    '##                                    ##',
    '##                                    ##',
    '##              ========              ##',
    '##                                    ##',
    '##                                    ##',
    '##   ======                  ======   ##',
    '##                                    ##',
    '##                                    ##',
    '##  @                                 ##',
    '########################################',
    '########################################',
    '########################################',
  ],
};
