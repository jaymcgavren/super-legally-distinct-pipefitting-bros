#!/bin/sh
# build the shippable cart
cd "$(dirname "$0")"
npx wasmcart pack --wasm main.wasm --assets app --name pipefitting-bros \
  --width 1280 --height 720 -o pipefitting-bros.wasc
