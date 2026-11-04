// Generates every sprite and sound for Super Legally Distinct Pipefitting
// Brothers. No dependencies; rerun after editing:  node tools/make-assets.mjs
//
// Art is authored at Atari 2600 resolution (each art pixel is drawn 8x4 real
// pixels by the game). Sound is synthesized TIA-style: square / buzz / noise
// voices whose pitches are quantized to the 2600's divider frequencies and
// whose volume is quantized to 4 bits, updated once per 1/60 s frame.
import { writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { deflateSync } from 'node:zlib';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const APP = join(ROOT, 'app');
mkdirSync(join(APP, 'sprites'), { recursive: true });
mkdirSync(join(APP, 'sounds'), { recursive: true });

// ── PNG ──────────────────────────────────────────────────────────────
const CRC = (() => {
  const t = new Uint32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c >>> 0;
  }
  return t;
})();
const crc32 = (b) => { let c = ~0; for (const x of b) c = CRC[(c ^ x) & 255] ^ (c >>> 8); return ~c >>> 0; };
function chunk(type, data) {
  const out = Buffer.alloc(12 + data.length);
  out.writeUInt32BE(data.length, 0);
  out.write(type, 4, 'ascii');
  data.copy(out, 8);
  out.writeUInt32BE(crc32(out.subarray(4, 8 + data.length)), 8 + data.length);
  return out;
}
function png(img) {
  const { w, h, px } = img;
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4); ihdr[8] = 8; ihdr[9] = 6;
  const raw = Buffer.alloc(h * (1 + w * 4));
  for (let y = 0; y < h; y++) {
    raw[y * (1 + w * 4)] = 0;
    px.copy(raw, y * (1 + w * 4) + 1, y * w * 4, (y + 1) * w * 4);
  }
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk('IHDR', ihdr), chunk('IDAT', deflateSync(raw)), chunk('IEND', Buffer.alloc(0))]);
}
const image = (w, h) => ({ w, h, px: Buffer.alloc(w * h * 4) });
// paint ascii art into img at (ox, oy); dbl doubles every row (2600 line pairs)
function paint(img, ox, oy, rows, pal, dbl = false) {
  rows.forEach((row, r) => {
    for (let x = 0; x < row.length; x++) {
      const c = pal[row[x]];
      if (!c) continue;
      for (let k = 0; k < (dbl ? 2 : 1); k++) {
        const i = ((oy + r * (dbl ? 2 : 1) + k) * img.w + ox + x) * 4;
        img.px[i] = c[0]; img.px[i + 1] = c[1]; img.px[i + 2] = c[2]; img.px[i + 3] = 255;
      }
    }
  });
}
// a horizontal strip of frames, each cw x ch
function strip(frames, cw, ch, pal, dbl) {
  const img = image(cw * frames.length, ch);
  frames.forEach((f, i) => paint(img, i * cw, 0, f, pal, dbl));
  return img;
}
const save = (name, img) => writeFileSync(join(APP, 'sprites', name), png(img));

// ── players: 8x10 art, rows doubled -> 8x20 frames ──────────────────
const P_TOP = ['...HHH..', '..HHHHHH', '...SSSS.', '...SSS..'];
const PLAYER_FRAMES = [
  [...P_TOP, '..VVVV..', '.SVVVVS.', '..TTTT..', '..JJJJ..', '..JJ.JJ.', '.BBB.BB.'], // 0 stand
  [...P_TOP, '..VVVV..', '..VVVVS.', '.STTTT..', '..JJJJ..', '.JJ..JJ.', 'BB....BB'], // 1 run a
  [...P_TOP, '..VVVV..', '..VVVV..', '..TSTT..', '..JJJJ..', '...JJ...', '...BBB..'], // 2 run b
  [...P_TOP, '..VVVV..', '.SVVVV..', '..TTTTS.', '..JJJJ..', '..J..JJ.', '.BB..BBB'], // 3 run c
  ['...HHH..', '..HHHHHH', '...SSSS.', 'S..SSS..', 'SVVVVV..', '..VVVVS.', '..TTTT..', '..JJJJJ.', '.JJ...JJ', '.BB....B'], // 4 jump
  ['..HHH...', 'HHHHHH..', '.SSSS...', '..SSS...', '..VVVV..', '.SVVVVS.', '..TTTT..', '..JJJJ..', '.JJ..JJ.', 'BBB...BB'], // 5 skid
  ['..HHHH..', '.HHHHHH.', '..SSSS..', 'S.SSSS.S', 'SVVVVVVS', '..VVVV..', '..TTTT..', '..JJJJ..', '..J..J..', '.BB..BB.'], // 6 die
  [...P_TOP, '..VVVV..', '..VVVVSS', '..TTTT..', '..JJJJ..', '..JJ.JJ.', '.BBB.BB.'], // 7 throw
];
const SKIN = [228, 160, 112];
const BROTHERS = {
  dez:   { H: [236, 212, 64],  S: SKIN, V: [244, 120, 24], T: [252, 240, 160], J: [48, 80, 176],  B: [96, 56, 24] },
  ozzie: { H: [236, 236, 236], S: SKIN, V: [64, 168, 72],  T: [236, 212, 64],  J: [120, 80, 40],  B: [48, 32, 24] },
};
for (const [name, pal] of Object.entries(BROTHERS)) save(`${name}.png`, strip(PLAYER_FRAMES, 8, 20, pal, true));

// ── enemies: 8x6 art, rows doubled -> 8x12 frames ───────────────────
const ENEMY_FRAMES = [
  ['..RRRR..', '.RRRRRR.', 'RRYRRYRR', 'RRRRRRRR', 'RRRRRRRR', 'R.R..R.R'], // 0 blob a
  ['..RRRR..', '.RRRRRR.', 'RRYRRYRR', 'RRRRRRRR', 'RRRRRRRR', '.R.RR.R.'], // 1 blob b
  ['........', '........', '........', '........', '.RYRRYR.', 'RRRRRRRR'], // 2 blob flat
  ['...GG...', '.VVVVVV.', 'VV.VV.VV', '.VVVVVV.', '..L..L..', '.L....L.'], // 3 crab a
  ['...GG...', '.VVVVVV.', 'VV.VV.VV', '.VVVVVV.', '..L..L..', '..L..L..'], // 4 crab b
  ['V..GG..V', '.VVVVVV.', 'VVVVVVVV', '.VVVVVV.', 'V.L..L.V', '........'], // 5 crab spin a
  ['...GG...', 'VVVVVVVV', '.VVVVVV.', 'VVVVVVVV', '.VL..LV.', '........'], // 6 crab spin b
];
save('enemies.png', strip(ENEMY_FRAMES, 8, 12, {
  R: [168, 84, 32], Y: [252, 220, 96], G: [160, 160, 168], V: [216, 48, 48], L: [120, 24, 24],
}, true));

// ── items: 8x8 art, rows doubled -> 8x16 frames ─────────────────────
// valve handwheel: fixed rim, hub, and 4 spokes rasterized at `deg`
function wheelFrame(deg) {
  const rim = ['..VVVV..', '.V....V.', 'V......V', 'V......V', 'V......V', 'V......V', '.V....V.', '..VVVV..'];
  const g = rim.map((r) => r.split(''));
  for (let k = 0; k < 4; k++) {
    const a = ((deg + k * 90) * Math.PI) / 180, dx = Math.cos(a), dy = -Math.sin(a);
    for (let y = 1; y < 7; y++) for (let x = 1; x < 7; x++) {
      const px = x + 0.5 - 4, py = y + 0.5 - 4;          // pixel centre from wheel centre
      const t = px * dx + py * dy;                      // distance along the spoke
      if (t > 0 && t < 3.6 && Math.abs(px * dy - py * dx) < 0.72) g[y][x] = 'V';
    }
  }
  for (const [x, y] of [[3, 3], [4, 3], [3, 4], [4, 4]]) g[y][x] = 'P';
  return g.map((r) => r.join(''));
}
if (process.env.SHOW_WHEEL) [0, 30, 60].forEach((d) => console.log(wheelFrame(d).join('\n') + '\n'));
const ITEM_FRAMES = [
  ['........', '.NNNNN..', 'NN...NN.', 'NN...NN.', 'NN...NN.', '.NNNNN..', '........', '........'], // 0 nut
  ['........', '..NNN...', '.NN.NN..', '.NN.NN..', '.NN.NN..', '..NNN...', '........', '........'], // 1 nut turn
  ['........', '...N....', '...N....', '...N....', '...N....', '...N....', '........', '........'], // 2 nut edge
  ['........', '..NNN...', '.NN.NN..', '.NN.NN..', '.NN.NN..', '..NNN...', '........', '........'], // 3 nut turn
  ['.W....W.', '.WW..WW.', '..WWWW..', '...WW...', '...WW...', '...WW...', '...WW...', '...WW...'], // 4 wrench item
  ['..KKKK..', '.K....K.', 'LLLLLLLL', 'LLLLLLLL', 'LLAAALLL', 'LLLLLLLL', 'LLLLLLLL', '........'], // 5 lunchbox
  ['...CC...', '...CC...', '..cccc..', '..CCCC..', '.CCCCCC.', '.cccccc.', 'CCCCCCCC', 'GGGGGGGG'], // 6 cone off
  ['...ll...', '..llll..', '..cccc..', '..CCCC..', '.CCCCCC.', '.cccccc.', 'CCCCCCCC', 'GGGGGGGG'], // 7 cone lit
  wheelFrame(0),  // 8  valve wheel, 4 spokes turned 0 / 30 / 60 degrees
  wheelFrame(30), // 9
  wheelFrame(60), // 10
];
save('items.png', strip(ITEM_FRAMES, 8, 16, {
  N: [228, 184, 48], W: [176, 180, 196], K: [80, 80, 88], L: [56, 120, 200], A: [236, 236, 236],
  C: [244, 120, 24], c: [236, 236, 236], G: [80, 80, 88], l: [255, 240, 96],
  V: [216, 48, 48], P: [160, 160, 168],
}, true));
// spinning wrench: 7 pre-drawn frames (no runtime rotation). An open-end
// wrench outline is rasterized at 360/7 degree steps onto an 8x8 art grid
// (rows doubled -> 8x16 frames), keeping the chunky 2600 look.
function wrenchFrame(deg) {
  const a = deg * Math.PI / 180, ca = Math.cos(a), sa = Math.sin(a);
  const inShape = (x, y) => {
    const ax = Math.abs(x);
    if (ax <= 0.75 && y >= -3.6 && y <= 1.0) return 'W';            // handle
    if (ax <= 1.9 && y >= 0.6 && y <= 1.8) return 'H';             // head
    if (ax >= 0.7 && ax <= 1.9 && y >= 1.0 && y <= 3.6) return 'H'; // jaws
    return null;
  };
  const rows = [];
  for (let r = 0; r < 8; r++) {
    let row = '';
    for (let c = 0; c < 8; c++) {
      const hits = {}; let n = 0;
      for (let sy = 0; sy < 4; sy++) for (let sx = 0; sx < 4; sx++) {
        const px = c + (sx + 0.5) / 4 - 4, py = 4 - (r + (sy + 0.5) / 4);
        const k = inShape(px * ca + py * sa, -px * sa + py * ca);
        if (k) { hits[k] = (hits[k] || 0) + 1; n++; }
      }
      row += n >= 6 ? ((hits.H || 0) > (hits.W || 0) ? 'H' : 'W') : '.';
    }
    rows.push(row);
  }
  return rows;
}
const WRENCH_FRAMES = [0, 1, 2, 3, 4, 5, 6].map((i) => wrenchFrame(i * 360 / 7));
save('wrench.png', strip(WRENCH_FRAMES, 8, 16, { W: [196, 200, 212], H: [236, 236, 244] }, true));
if (process.env.SHOW_WRENCH) WRENCH_FRAMES.forEach((f, i) => console.log(`frame ${i}\n${f.join('\n')}`));
// ── Big Rusty (boss): 8x14 art, rows doubled -> 8x28 frames, drawn at
// double width (a 2600 NUSIZ quad-ish player) by the game ────────────
const RUSTY_HEAD = ['..VVVV..', '.V.GG.V.', '..VVVV..', '..RRRR..', '.RRRRRR.'];
const RUSTY_FRAMES = [
  [...RUSTY_HEAD, 'RRYYRYYR', 'RRKYRKYR', 'RRRRRRRR', 'RRKKKKRR', 'RRRRRRRR', 'RDRRRRDR', 'RRRRRRRR', '.RR..RR.', 'RR....RR'], // 0 walk a
  [...RUSTY_HEAD, 'RRYYRYYR', 'RRYKRYKR', 'RRRRRRRR', 'RRKKKKRR', 'RRRRRRRR', 'RDRRRRDR', 'RRRRRRRR', '.RR..RR.', '.RR..RR.'], // 1 walk b
  ['........', '........', ...RUSTY_HEAD, 'RRYYRYYR', 'RRKYRKYR', 'RRRRRRRR', 'RRKKKKRR', 'RDRRRRDR', 'RRRRRRRR', 'RRRRRRRR', 'RRR..RRR'], // 2 crouch
  [...RUSTY_HEAD, 'RRYYRYYR', 'RRKYRKYR', 'RRRRRRRR', 'RKKKKKKR', 'RRRRRRRR', 'RDRRRRDR', 'RRRRRRRR', 'R.R..R.R', '........'], // 3 air
  [...RUSTY_HEAD, 'RYRYRYRY', 'RRYRRYRR', 'RYRYRYRY', 'RRRRRRRR', 'RRKKKKRR', 'RDRRRRDR', 'RRRRRRRR', '.RR..RR.', 'RR....RR'], // 4 hurt
  [...RUSTY_HEAD, 'RRYYRYYR', 'RRKYRKYR', 'RKKKKKKR', 'RKOOOOKR', 'RKKKKKKR', 'RDRRRRDR', 'RRRRRRRR', '.RR..RR.', 'RR....RR'], // 5 mouth open
  [...RUSTY_HEAD, 'RYYYRYYY', 'RYKYRYKY', 'RRRRRRRR', 'RRKKKKRR', 'RRRRRRRR', 'RDRRRRDR', 'RRRRRRRR', '.RR..RR.', 'RR....RR'], // 6 angry
  ['.S.SS.S.', 'SS.SS.SS', 'SSSSSSSS', ...Array(11).fill('........')],                                                  // 7 spiked crown
];
save('rusty.png', strip(RUSTY_FRAMES, 8, 28, {
  V: [216, 48, 48], G: [160, 160, 168], R: [168, 84, 32], D: [104, 48, 20], Y: [252, 220, 96],
  K: [40, 16, 8], O: [236, 120, 40], S: [208, 212, 224],
}, true));
// boss projectiles: 0 rust glob, 1 bolt  (8x8 art doubled -> 8x16)
save('shots.png', strip([
  ['........', '..RRR...', '.RRORR..', '.RRRRR..', '..RRR...', '........', '........', '........'],
  ['..GGGG..', '..GGGG..', '...GG...', '...GG...', '...GG...', '...GG...', '...GG...', '........'],
], 8, 16, { R: [168, 84, 32], O: [236, 120, 40], G: [176, 180, 196] }, true));
// 1x1 white pixel for tinted rectangles drawn in sprite order
save('px.png', strip([['W']], 1, 1, { W: [255, 255, 255] }, false));

// ── tiles: 8x16 art (native lines), one atlas per theme ─────────────
const BRICK = ['mBBBBBBB', 'mBBBBBBB', 'mBBBBBBB', 'mmmmmmmm', 'BBBBmBBB', 'BBBBmBBB', 'BBBBmBBB', 'mmmmmmmm'];
const TILES = [
  [...BRICK, ...BRICK],                                                     // 0 brick
  ['CCCCCCCC', 'cccccccc', 'cccccccc', 'kkkkkkkk', ...BRICK, ...BRICK.slice(0, 4)], // 1 brick w/ coping
  ['hhhhhhhh', 'hhhhhhhh', 'gggggggg', 'grgggrgg', ...Array(8).fill('gggggggg'),
    'grgggrgg', 'gggggggg', 'dddddddd', 'dddddddd'],                        // 2 girder
  ['..yyyy..', '.y....y.', 'RRRRRRRR', 'rrrrrrrr', 'rrrrrrrr', 'rrrrrrrr', 'xxxxxxxx', 'rrryyrrr',
    'rrryyrrr', 'rrrrrrrr', 'rrrrrrrr', 'rrrrrrrr', 'rrrrrrrr', 'rrrrrrrr', 'rrrrrrrr', 'xxxxxxxx'], // 3 crate
  ['..qqqq..', '.q....q.', 'UUUUUUUU', 'uuuuuuuu', 'uuuuuuuu', 'uuuuuuuu', 'qqqqqqqq', 'uuuuuuuu',
    'uuuuuuuu', 'uuuuuuuu', 'uuuuuuuu', 'uuuuuuuu', 'uuuuuuuu', 'uuuuuuuu', 'uuuuuuuu', 'qqqqqqqq'], // 4 used crate
  ['PPPPPPPP', 'pppppppp', 'pppppppp', 'pppppppp', 'pppppppp', 'oooooooo', ...Array(10).fill('........')], // 5 pipe
  ['ffPPPPPP', 'ffpppppp', 'ffpppppp', 'ffpppppp', 'ffpppppp', 'ffoooooo', 'ff......', ...Array(9).fill('........')], // 6 pipe flange
  Array(16).fill('...sS...'),                                              // 7 pipe stand
  ['..gggg..', '..gddg..', 'hhhhhhhh', 'gdgdgdgd', 'gggggggg', 'gdgdgdgd', 'gggggggg', 'gdgdgdgd',
    'gggggggg', 'gdgdgdgd', 'gggggggg', 'gdgdgdgd', 'gggggggg', 'gdgdgdgd', 'gggggggg', 'dddddddd'], // 8 steam vent
  ['.oPPPPo.', ...Array(6).fill('.spppps.'), '.oPPPPo.', ...Array(8).fill('.spppps.')], // 9 standpipe
  ['hhhhhhhh', 'yyKKyyKK', 'KyyKKyyK', 'dddddddd', ...Array(12).fill('........')], // 10 lift
  BRICK.concat(BRICK).map((s) => s.replace(/B/g, '1').replace(/m/g, '2')),  // 11 back wall (indoors)
  ['WWWWWWWW', 'wwwwwwww', 'wwwwwww3', 'wwwwwwww', '33333333', 'www3wwww', 'wwwwwwww', '33333333',
    'wwwwww3w', 'wwwwwwww', '33333333', '44444444', '4..44..4', '44444444', '4..44..4', '44444444'], // 12 wood floor
  ['44444444', '4..44..4', '44444444', '4..44..4', '44444444', '33333333', '44444444', '4..44..4',
    '44444444', '4..44..4', '44444444', '33333333', '44444444', '4..44..4', '44444444', '33333333'], // 13 subfloor
];
const THEMES = {
  day:   { B: [176, 76, 40],  m: [92, 36, 20],  C: [212, 208, 196], c: [180, 176, 164], k: [96, 92, 88] },
  dusk:  { B: [140, 60, 84],  m: [64, 24, 48],  C: [220, 168, 140], c: [176, 132, 124], k: [84, 48, 64] },
  night: { B: [92, 96, 128],  m: [36, 36, 60],  C: [168, 172, 196], c: [128, 132, 160], k: [48, 48, 72] },
  indoor: { B: [156, 72, 48], m: [84, 36, 24],  C: [180, 120, 72],  c: [148, 92, 52],   k: [84, 52, 32] },
};
const COMMON = {
  h: [188, 196, 208], g: [128, 136, 152], r: [72, 76, 92], d: [80, 84, 100],
  y: [236, 212, 64], R: [232, 72, 64], r_: null, x: [124, 20, 20],
  q: [72, 56, 48], U: [150, 120, 100], u: [120, 96, 80],
  P: [236, 152, 80], p: [200, 108, 44], o: [140, 68, 24], f: [140, 68, 24],
  s: [140, 68, 24], S: [200, 108, 44], K: [24, 24, 24],
  1: [96, 44, 36], 2: [56, 24, 20],                       // back wall brick / mortar
  W: [220, 164, 96], w: [184, 120, 64], 3: [120, 72, 36], 4: [92, 56, 28], // wood
};
for (const [name, t] of Object.entries(THEMES)) {
  // crate body uses lowercase r for red; rivets use r in girder -> remap
  const tiles = TILES.map((rows, i) => i === 3 ? rows.map((s) => s.replace(/r/g, 'z')) : rows);
  const pal = { ...COMMON, z: [200, 40, 40], ...t };
  save(`tiles_${name}.png`, strip(tiles, 8, 16, pal, false));
}

// ── TIA-style audio ──────────────────────────────────────────────────
const RATE = 22050;
const FRAME = RATE / 60;
// divider bases (Hz) for the voices: AUDC4 pure (/2), AUDC12 pure (/6), AUDC6 buzz (/31)
const BASE = { sq: 15700, sq6: 5233, buzz: 1013, noise: 31400 };
const tiaHz = (wave, f) => BASE[wave] / (Math.max(0, Math.min(31, f)) + 1);
function writeWav(path, samples) {
  const data = Buffer.alloc(samples.length);
  for (let i = 0; i < samples.length; i++) data[i] = Math.max(0, Math.min(255, Math.round(128 + samples[i] * 127)));
  const h = Buffer.alloc(44);
  h.write('RIFF', 0); h.writeUInt32LE(36 + data.length, 4); h.write('WAVE', 8);
  h.write('fmt ', 12); h.writeUInt32LE(16, 16); h.writeUInt16LE(1, 20); h.writeUInt16LE(1, 22);
  h.writeUInt32LE(RATE, 24); h.writeUInt32LE(RATE, 28); h.writeUInt16LE(1, 32); h.writeUInt16LE(8, 34);
  h.write('data', 36); h.writeUInt32LE(data.length, 40);
  writeFileSync(path, Buffer.concat([h, data]));
}
// a voice renders [wave, hz, vol0..15] per frame into out (additive)
function voice(out, frames, startSample = 0) {
  let phase = 0, lfsr = 0x1ff, noiseAcc = 0, noiseBit = 1;
  frames.forEach((fr, n) => {
    const s0 = startSample + Math.round(n * FRAME), s1 = startSample + Math.round((n + 1) * FRAME);
    if (!fr) return;
    const [wave, hz, vol] = fr;
    const amp = (Math.max(0, Math.min(15, Math.round(vol))) / 15) * 0.3;
    for (let s = s0; s < s1 && s < out.length; s++) {
      let v;
      if (wave === 'noise') {
        noiseAcc += hz / RATE;
        while (noiseAcc >= 1) { noiseAcc -= 1; const b = ((lfsr >> 0) ^ (lfsr >> 4)) & 1; lfsr = (lfsr >> 1) | (b << 8); noiseBit = lfsr & 1; }
        v = noiseBit ? 1 : -1;
      } else {
        phase = (phase + hz / RATE) % 1;
        v = wave === 'buzz' ? (phase < 18 / 31 ? 1 : -1) : (phase < 0.5 ? 1 : -1);
      }
      out[s] += v * amp;
    }
  });
}
function sfx(name, frames) {
  const out = new Float32Array(Math.ceil((frames.length + 2) * FRAME));
  voice(out, frames.map((f) => f && [f[0], tiaHz(f[0], f[1]), f[2]]));
  writeWav(join(APP, 'sounds', `${name}.wav`), out);
}
const R = (n, fn) => Array.from({ length: n }, (_, i) => fn(i));
const notes = (seq, per) => seq.flatMap(([w, f]) => R(per, (i) => [w, f, 10 - i * (4 / per)]));
sfx('jump', R(12, (i) => ['sq', Math.round(24 - i * 1.5), 10 - i * 0.5]));
sfx('stomp', [...R(3, () => ['noise', 10, 12]), ...R(7, (i) => ['sq6', 6 + i * 2, 10 - i])]);
sfx('nut', [...R(3, () => ['sq', 9, 10]), ...R(12, (i) => ['sq', 6, 10 - i * 0.7])]);
sfx('bump', R(7, (i) => ['buzz', 6 + i, 13 - i * 1.6]));
sfx('appear', notes([['sq6', 14], ['sq6', 11], ['sq6', 9], ['sq6', 7]], 4));
sfx('powerup', notes([[ 'sq6', 15], ['sq6', 12], ['sq6', 10], ['sq6', 7], ['sq6', 12], ['sq6', 10], ['sq6', 7], ['sq6', 5],
  ['sq6', 10], ['sq6', 7], ['sq6', 5], ['sq6', 4]], 3));
sfx('throw', R(8, (i) => ['noise', 2 + (i % 2) * 3, 9 - i]));
sfx('hurt', R(24, (i) => ['sq6', 6 + i, 12 - i / 2]));
sfx('oneup', notes([['sq', 9], ['sq', 7], ['sq', 5], ['sq', 9], ['sq', 7], ['sq', 5], ['sq', 4]], 5));
sfx('kick', R(14, (i) => ['buzz', 2 + i, 12 - i * 0.8]));
sfx('steam', R(30, (i) => ['noise', 0, 6 - i * 0.18]));
sfx('tick', R(2, () => ['sq', 5, 8]));
sfx('checkpoint', [...R(6, () => ['sq6', 9, 10]), ...R(14, (i) => ['sq6', 6, 10 - i * 0.6])]);
sfx('pause', [...R(4, () => ['sq', 10, 9]), null, null, null, null, ...R(4, () => ['sq', 10, 9])]);
sfx('warn', notes([['sq6', 6], ['sq6', 8], ['sq6', 6], ['sq6', 8]], 6));
sfx('pound', [...R(4, () => ['noise', 30, 15]), ...R(26, (i) => ['buzz', 18 + (i >> 2), 13 - i * 0.5])]);
sfx('bosshit', [...R(4, () => ['noise', 4, 14]), ...R(16, (i) => ['sq6', 20 - i, 12 - i * 0.7])]);
sfx('bossdie', R(90, (i) => [i % 6 < 3 ? 'noise' : 'buzz', 8 + (i >> 3), 14 - i * 0.15]));
sfx('spit', R(10, (i) => ['buzz', 4 + i, 11 - i]));
// klaxon: three rising wails, 48 frames apart (matches the WARNING flash)
sfx('klaxon', R(144, (i) => {
  const k = i % 48;
  return k < 36 ? [k % 2 ? 'sq6' : 'buzz', k % 2 ? 16 - (k >> 2) : 3, 13 - (k >> 4)] : null;
}));

// ── music: notes quantized to the nearest TIA divider pitch ─────────
const NOTE = { C: 0, 'C#': 1, D: 2, 'D#': 3, E: 4, F: 5, 'F#': 6, G: 7, 'G#': 8, A: 9, 'A#': 10, B: 11 };
const hzOf = (n) => { const m = /^([A-G]#?)(\d)$/.exec(n); return 440 * 2 ** ((NOTE[m[1]] + 12 * (+m[2] + 1) - 69) / 12); };
function nearest(hz, waves) {
  let best = null;
  for (const w of waves) for (let f = 0; f < 32; f++) {
    const d = Math.abs(Math.log(tiaHz(w, f) / hz));
    if (!best || d < best.d) best = { w, hz: tiaHz(w, f), d };
  }
  return best;
}
// seq: [[note|null, frames]], waves the lead may use; returns per-frame list
function melody(seq, waves, vol = 10, decay = 3) {
  const out = [];
  for (const [n, len] of seq) {
    if (!n) { for (let i = 0; i < len; i++) out.push(null); continue; }
    const q = nearest(hzOf(n), waves);
    for (let i = 0; i < len; i++) out.push(i >= len - 1 && len > 3 ? null : [q.w, q.hz, Math.max(vol - decay, vol - (i * decay) / len)]);
  }
  return out;
}
function track(name, parts) {
  const len = Math.max(...parts.map((p) => p.length));
  const out = new Float32Array(Math.ceil(len * FRAME));
  for (const p of parts) voice(out, p);
  writeWav(join(APP, 'sounds', `${name}.wav`), out);
}
const E8 = 12; // frames per eighth note (150 bpm)
const parse = (s, unit = E8) => {
  // "C5 - E5 ." : note, '-' rest, '.' extends previous
  const seq = [];
  for (const tok of s.trim().split(/\s+/)) {
    if (tok === '.') seq[seq.length - 1][1] += unit;
    else seq.push([tok === '-' ? null : tok, unit]);
  }
  return seq;
};
const LEAD = ['sq', 'sq6'];
const BASS = ['sq6', 'buzz'];
const themeLead = parse(`
  C5 - C5 E5 G5 . E5 -   F5 . A5 . G5 E5 D5 -   C5 - C5 E5 G5 . C6 .   B5 A5 G5 . . . - -
  A5 . A5 G5 F5 . E5 -   D5 . E5 F5 E5 . C5 -   D5 - D5 E5 F5 E5 D5 B4   C5 . . . G4 . - -
  E5 . G5 . A5 . G5 E5   F5 . . D5 E5 . C5 -    E5 . G5 . A5 . C6 .      B5 . G5 . D5 . . -
  A4 . C5 . E5 . A5 .    G5 . F5 . E5 . D5 .    C5 E5 G5 C6 B5 G5 D5 F5  E5 . C5 . . . - -`);
const roots = ['C3', 'F2', 'C3', 'G2', 'F2', 'D3', 'G2', 'C3', 'C3', 'F2', 'C3', 'G2', 'A2', 'G2', 'C3', 'C3'];
const up = (n) => n.replace(/\d/, (d) => +d + 1);
const fifth = { C3: 'G2', F2: 'C3', G2: 'D3', D3: 'A2', A2: 'E3' };
const themeBass = parse(roots.map((r) => `${r} - ${up(r)} - ${fifth[r]} - ${r} ${up(r)}`).join(' '));
const drums = [];
for (let bar = 0; bar < 16; bar++) for (let e = 0; e < 8; e++) {
  const hit = e % 4 === 0 ? [['noise', 1100, 11], ['noise', 900, 8], ['noise', 700, 5]]
    : e % 4 === 2 ? [['noise', 9000, 9], ['noise', 9000, 6], ['noise', 9000, 3]]
    : [['noise', 31400, 3]];
  for (let i = 0; i < E8; i++) drums.push(hit[i] || null);
}
track('theme', [melody(themeLead, LEAD, 10, 3), melody(themeBass, BASS, 9, 4), drums]);

// boss theme: A minor riff, faster drums
const bossLead = parse(`
  A4 . A4 C5 . A4 D#5 .   E5 . D5 C5 . B4 . .    A4 . A4 C5 . A4 E5 .   F5 . E5 D5 . C5 B4 .
  A4 . A4 C5 . A4 D#5 .   E5 . G5 F5 . E5 . .    A5 . G5 F5 E5 D5 C5 B4  A4 . . . E4 . . .`, 10);
const bossBass = parse(['A2', 'A2', 'F2', 'E2', 'A2', 'A2', 'D3', 'E2']
  .map((r) => `${r} ${r} ${up(r)} ${r} ${r} ${up(r)} ${r} ${up(r)}`).join(' '), 10);
const bossDrums = [];
for (let bar = 0; bar < 8; bar++) for (let e = 0; e < 8; e++) {
  const hit = e % 2 === 0 ? [['noise', 1100, 11], ['noise', 900, 7], ['noise', 700, 4]] : [['noise', 9000, 6], ['noise', 9000, 3]];
  for (let i = 0; i < 10; i++) bossDrums.push(hit[i] || null);
}
track('boss', [melody(bossLead, LEAD, 10, 3), melody(bossBass, BASS, 9, 3), bossDrums]);
track('clear', [
  melody([['C5', 6], ['E5', 6], ['G5', 6], ['C6', 18], ['G5', 6], ['A5', 6], ['B5', 6], ['C6', 48]], LEAD, 11, 3),
  melody([['C3', 18], ['G2', 18], ['F2', 18], ['C3', 48]], BASS, 9, 3),
]);
track('death', [
  melody([['G5', 8], ['F#5', 8], ['F5', 8], ['E5', 24], [null, 8], ['C5', 8], ['G4', 8], ['C5', 30]], LEAD, 11, 4),
  melody([[null, 48], [null, 8], ['C3', 8], ['G2', 8], ['C2', 30]], BASS, 9, 3),
]);
track('gameover', [
  melody([['E5', 20], ['D5', 20], ['C5', 20], ['B4', 20], ['A4', 20], ['G#4', 40], ['A4', 60]], LEAD, 10, 4),
  melody([['A2', 40], ['F2', 40], ['E2', 60], ['A2', 60]], BASS, 9, 3),
]);
console.log('assets written to', APP);
