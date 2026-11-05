#!/bin/sh
# Build the web player into build/web/, the whole contents of the gh-pages branch:
#   index.html               the page (from web/index.html)
#   pipefitting-bros.wasc    the cart, from pack.sh
#   vendor/wasmcart/         wasmcart's browser host (CartHostWeb), from node_modules
#   vendor/fflate/browser.js its zip dependency (see the import map in index.html)
#   .nojekyll                serve files as-is on GitHub Pages
# Publish it with tools/publish-web.sh.
set -e
cd "$(dirname "$0")/.."
./pack.sh
out=build/web
rm -rf "$out"
mkdir -p "$out/vendor/wasmcart/src" "$out/vendor/fflate"
cp web/index.html pipefitting-bros.wasc "$out/"
cp node_modules/wasmcart/web.js node_modules/wasmcart/LICENSE "$out/vendor/wasmcart/"
# the browser host's modules only: CartHost, remoteCart, assetFiles, cartWorker
# and save are Node-side and would not load in a browser anyway
for f in CartHostWeb abi assetPrefetch jit actions debugState webgl_imports cartMemory cartWorkerWeb; do
  cp node_modules/wasmcart/src/$f.js "$out/vendor/wasmcart/src/"
done
cp -r node_modules/wasmcart/src/wgpu "$out/vendor/wasmcart/src/"
cp node_modules/fflate/esm/browser.js node_modules/fflate/LICENSE "$out/vendor/fflate/"
touch "$out/.nojekyll"
echo "web player ready in $out: serve it, e.g. python3 -m http.server -d $out"
