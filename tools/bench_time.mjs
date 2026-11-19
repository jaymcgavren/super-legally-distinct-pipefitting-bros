// Preloaded by tools/bench.sh (node --import): times CartHost#runFrame, the
// host call that runs the cart's frame (wc_render: Ruby tick plus the
// runtime's own drawing), and prints the total at exit. This leaves out the
// headless player's per-frame overhead, which is several times larger and
// noisy.
import { CartHost } from '../node_modules/wasmcart/src/CartHost.js';

const run = CartHost.prototype.runFrame;
let total = 0;
let frames = 0;
CartHost.prototype.runFrame = function (...a) {
  const t0 = performance.now();
  const r = run.apply(this, a);
  total += performance.now() - t0;
  frames += 1;
  return r;
};
process.on('exit', () => {
  process.stderr.write(`runFrame: ${frames} frames, ${total.toFixed(0)} ms, ` +
    `${(total / frames).toFixed(3)} ms/frame\n`);
});
