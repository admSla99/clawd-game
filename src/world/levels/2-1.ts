import type { LevelDef } from '../level';

// Legend: # rock  = one-way  ^ spikes  X corrupted (ground-pound or blast it)
//         @ start  S spark  o token  A sub-agent  C checkpoint  G exit  ? sign
//         E bug  F spam bot  R rate limiter (2x2)  M/V moving platform  B boss
//         T turret  Y ceiling turret  D drone  H shield bot  I injector
export const LEVEL_2_1: LevelDef = {
  id: '2-1',
  world: 2,
  name: 'Merge Conflict Mesa',
  subtitle: 'both branches think they are right',
  theme: 'mesa',
  music: 'mesa',
  signs: [
    'AIM WITH THE MOUSE · HOLD LEFT CLICK TO SHOOT\nno mouse? X shoots, hold ↑ / ↓ to aim',
    'LINT TURRETS TRACK YOU\nshoot them before they shoot you',
    'SHIELD BOTS BLOCK SHOTS FROM THE FRONT\njump over them, or hit them from above',
    'CORRUPTED DATA: ↓ + C in the air\n(the Opus Cannon blasts it too)',
  ],
  touchSigns: [
    'HOLD FIRE TO SHOOT · it aims at the nearest enemy\ndrag FIRE to aim by hand',
    undefined,
    undefined,
    'CORRUPTED DATA: ↓ + SPIN in the air\n(the Opus Cannon blasts it too)',
  ],
  map: [
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '                                                                                        F       F                                                                                               D',
    '                                                                     D                    S                              A                                                      D                      S',
    '                            S                                 S                                           D             ===                                                                          =====',
    '                                                            ======',
    '                                            o o   T                                    o     o                                                                                        T A',
    '                          =====           ###############                             ===   ===                             ====                                                    #####       =====                             ##',
    '           o o o                          ###############                                                                                                        o o o              #####                         o o o o         ##',
    '   @   ?          E     E      E      ?   ###############                     C                                       ?             H           H  ?         C        E   E         #####   E                               E     ##              G',
    '###################################################################################                ###################################################XXXX################################################################################################',
    '###################################################################################                ###################################################    ################################################################################################',
    '###################################################################################                ################################################### S  ################################################################################################',
    '###################################################################################                #######################################################################################################################################################',
    '###################################################################################                #######################################################################################################################################################',
  ],
};
