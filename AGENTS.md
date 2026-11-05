# AGENTS.md

Goal: build an original game as a **wasmcart** cart, written in Ruby with
**wasmcart-mruby**. The user has deliberately not chosen a genre; ask or
propose one before writing gameplay code.

## Originality

Build an original game: your own characters, art, levels and names. Don't
recreate a specific existing game, even renamed. The folder name is a joke and
doesn't set the theme.

## Decisions already made

- **Language/runtime: wasmcart-mruby** (user's choice). It's a prebuilt mruby
  runtime cart with a DragonRuby-style API. No compiler needed.
- **Don't install a compiler** (no wasi-sdk, Emscripten, clang targets, brew).
  The romdev MCP server forbids it, and mruby makes it unnecessary.
- **Don't hand-write WAT/C carts.** That was the fallback before mruby was
  chosen.

## Environment (as of 2026-11-03)

- Node 22+ is available via mise.
- `npm install wasmcart` was run here: `node_modules/wasmcart` is **v0.37.0,
  ABI v4**. Use it as the spec reference:
  `node_modules/wasmcart/SPEC.md`, `node_modules/wasmcart/include/`.
- Ignore the older wasmcart copy in the npx cache
  (`~/.npm/_npx/*/node_modules/wasmcart`, v0.24 / ABI v3).
- The project is a git repo with a GitHub remote, `origin`
  (`jaymcgavren/super-legally-distinct-pipefitting-bros`). Run `git remote -v`
  rather than assuming.

## Setup (from https://wasmcart.org/languages/ruby)

```sh
git clone https://github.com/wasmcart/wasmcart-mruby
cp -r wasmcart-mruby/template/. .          # or into a subdir
cp wasmcart-mruby/build/main.wasm main.wasm
npx wasmcart .                              # dev mode, opens a window
```

Layout: `main.wasm` (runtime), `app/main.rb` (game), optional `run.sh`.
Keep the cloned `wasmcart-mruby/` out of the shipped assets.

## API summary (from the site; verify against the repo)

```ruby
def tick args
  args.state.x ||= 600
  args.state.x += 5 if args.inputs.keyboard.right
  args.outputs.solids << [args.state.x, 300, 80, 80, 90, 220, 130]
  args.outputs.labels << { x: 640, y: 600, text: 'hi', size_px: 6, alignment_enum: 1 }
end
```

- `tick` runs at 60 Hz. The canvas is **1280x720, origin bottom-left**.
- **Outputs:** `solids`, `sprites`, `labels`, `lines`, `borders`,
  `primitives` (redrawn every tick). `static_*` variants persist.
- **Render targets:** draw into `args.outputs[:name]`, then use
  `path: :name` as a sprite.
- **Primitive classes:** `attr_sprite`, `attr_rect`, `attr_label`,
  `attr_line`.
- `args.state`: persistent open struct.
- **Helpers:** `args.geometry` (intersection), `args.easing`,
  `Numeric#to_radians`.
- **Input:** design for a gamepad. On desktop, the arrows and space map to
  pad 1.
- **Save data:** `args.gtk.save_u32 slot, v` (64 slots, written to a `.sav`
  beside the cart).
- Ruby exceptions are drawn on screen instead of crashing the cart.
- It isn't DragonRuby and shares no code with it. Don't assume a DragonRuby
  feature exists until you find it in the repo source or examples.

## Audio (checked in the repo source, commit 57bb06e, 2026-10-02)

Music and sound effects are both supported. Everything goes through
wasmcart's `wc_pcm_mixer`: 16 voices, 48 kHz float output, per-voice gain
and pitch.

- **One-shot effects:** `args.outputs.sounds << 'sounds/hit.wav'`, or a hash
  `{ path:, gain:, looping: }`. Paths are relative to the packed `app/`
  directory (see `examples/flappy`).
- **Music and controllable channels:** set
  `args.audio[:music] = { input: 'music/theme.ogg', gain: 0.5, looping: true }`.
  Change `gain`, `pitch`, `paused` and `playtime` (seek) on that hash and they
  take effect next tick. `args.audio.delete(:music)` stops it, and an entry
  removes itself when a non-looping sound ends (see `examples/showcase`).
- **Beeps without assets:** `args.outputs.sounds << { freq: 440 }` plays a
  fixed 200 ms decaying square wave. `frames:` is ignored, and only 8 distinct
  frequencies are cached; the 9th reuses the first. Fine for prototypes, not
  for real sound effects.
- **Formats:** WAV (8- or 16-bit PCM, mono or stereo, any rate, resampled)
  and OGG Vorbis (stb_vorbis). Use OGG for music to keep the cart small.
- **Limits and gotchas:**
  - At most 32 distinct sound files per run (`MAX_SOUND_PATHS`).
  - Each file is loaded and fully decoded to PCM the first time it plays,
    which can cause a hitch on that frame and costs memory for long OGG
    tracks. Warm sounds at gain 0 on the title screen if it matters.
  - A missing file only logs `sound asset not found: <path>` to the cart
    log; read it with romdev `wasm({op:'events'})`.
  - There's no built-in music sequencer or synth (no tracker or MIDI). Music
    must be a pre-rendered WAV/OGG.
- **Making assets:** `examples/flappy/tools/make-assets.mjs` generates WAVs
  procedurally in plain Node with no dependencies. Reuse that approach for
  original sound effects, and for simple chiptune music if no audio files
  are supplied.

## Check these first (unknown)

1. **Runtime ABI version.** The repo's `runtime/wasmcart.h` says
   `WC_ABI_VERSION 4`, so romdev should accept it. Confirm with
   `wasm({op:'conformance'})` after loading `build/main.wasm`.
2. **Sprite loading.** Find the image formats and asset paths the runtime
   accepts (look at the template and examples such as `flappy-wyvern`).
3. **Gamepad input names.** The site only shows `inputs.keyboard`.

## Test loop

Use the `wasmcart` CLI:

```sh
npx wasmcart .                                        # play
npx wasmcart game.wasc --frames 300 --shot out.png    # headless screenshot
npx wasmcart game.wasc --seed 7 --frames 60 --shot a.png   # deterministic
```

romdev MCP (if the ABI is v4):
- Load with `loadMedia({platform:'wasmcart', path})`.
- Drive it with `input({op:'set'|'press'|'sequence'})`.
- Inspect with `frame({op:'stepAndShot', inline:true})` and
  `frame({op:'verify'})`.
- Show it to the user with `playtest({op:'open'})`.
- Background on the host: `platform({op:'doc', platform:'guide', name:'wasmcart'})`.

## Package

```sh
npx wasmcart pack --wasm main.wasm --assets app --name <game> \
  --width 1280 --height 720 -o <game>.wasc
```

The site's example says `--wasm cart.wasm`. Point it at the runtime you
actually copied (`main.wasm`).

## Branches and the web player

- All work (game, tools, web page source) is committed on **`main`**.
- **`gh-pages`** holds only the built web player (`index.html`, `.nojekyll`,
  the `.wasc`, `vendor/`). Never commit to it directly, check it out, or merge
  `main` into it.
- The page source is `web/index.html`. To update the site after a change:
  ```sh
  tools/build-web.sh                              # packs the cart, builds build/web/
  tools/publish-web.sh "Web player: <what changed>"   # commits build/web/ onto gh-pages
  git push origin gh-pages                        # puts it on the web (GitHub Pages)
  ```
  `publish-web.sh` only makes a local commit. The site doesn't change until
  `gh-pages` is pushed. Push `main` too when the user asks for it.
- `gh-pages-old` is a backup of the branch from before 2026-11-04, when
  `gh-pages` still carried the full source. Don't use it.

## Working style

- Get the template running unchanged before editing anything.
- Make one change at a time and take a screenshot after each.
- Show the user a playable build early. Don't wait until the game is complete.
