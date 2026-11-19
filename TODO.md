# Refactor toward idiomatic Ruby

Goal: clean up the game code (`app/*.rb`) so it reads like idiomatic Ruby,
**without changing how the game plays**. Agreed with the user on 2026-11-19;
nothing below has been started yet.

## Ground rules (read first)

- **Work on `main` only.** `un-refactored` is a frozen snapshot of the code
  before this work: never commit to it or check it out to work. Use it only to
  compare against (`git diff un-refactored -- app/`), or build it in a scratch
  worktree to play side by side.
- **Small steps.** One checklist item per commit (split further if a diff gets
  big). After each step: tests pass, real-runtime check, screenshot, commit,
  push `main` (standing user instruction: commit and push after each change).
- **Behaviour must not change.** Same physics, timings, scores, sounds, level
  layouts. If a step would change behaviour (even fixing a bug), stop and ask
  the user first.
- **Don't open the playtest window** unless the user asks. Verify headlessly.
- This file is git-ignored (`.git/info/exclude`). Tick items off here as you go
  and add notes for anything surprising.

## Constraints that shape the refactor

- **Runtime: mruby 3.4** (patched wasmcart-mruby build; see AGENTS.md, don't
  replace `main.wasm`). Gems: struct, metaprog, enum-ext, array/hash/string/
  numeric/object/kernel/symbol-ext, math, random, sprintf, error, regexp, json.
  - Available: `Struct`, keyword arguments, `Comparable`, `define_method`,
    `send`, `attr_*`, modules/`include`.
  - Not available: `Set` (use a Hash), the standard library, `require` of gems.
    Files load with `require 'app/foo.rb'` (path from the packed app dir).
  - Unverified in mruby, so check before relying on them:
    `Struct.new(..., keyword_init: true)`, endless `def x = ...`,
    pattern matching (`case/in`), `Data`. Prefer plain forms.
- **Tests run under CRuby, the game runs under mruby.** `tools/sim.rb` loads
  `app/main.rb` in host Ruby with a stub `args`. Passing tests do NOT prove the
  code works in mruby, so every step also needs the real-runtime check below.
- **Performance:** `tick` runs 60x/s in WebAssembly. Don't add per-frame
  allocations in hot loops (per tile, per particle, per sprite) beyond what's
  there now. Reusing objects is fine; making a new Struct per particle on spawn
  is fine (arrays are made there today); making one per draw call is not.
- **Entry point contract:** the runtime calls top-level `tick(args)`; `Game` is
  created once and kept in `$game`. The sim relies on `$game` and on
  `Game#tick`, `Game#update`, `Game#draw`. Keep those (or update sim.rb).

## Verification loop (every step)

```sh
timeout 250 ruby tools/sim.rb          # must end with ALL PASS
./pack.sh                              # builds pipefitting-bros.wasc
npx wasmcart pipefitting-bros.wasc --frames 300 --shot <scratchpad>/title.png
```

- Headless `npx wasmcart` gets no input, so it only shows the title screen.
  To check gameplay in the real runtime, make a **temp build from a scratch
  copy** of `app/` (never edit repo code for this). Patterns that worked:
  - start straight into level N: in the copy, after `@level = 0\n    to_title`
    add `; new_game(false)`, and change `RUSH_LEVELS[0] : 0` to `: N`.
  - then `npx wasmcart pack --wasm main.wasm --assets <copy> --name x
    --width 1280 --height 720 -o <scratchpad>/x.wasc` and screenshot it
    (romdev `loadMedia` + `frame stepAndShot`, or `--frames N --shot`).
  - Check at least: a B level (indoor, lifts, vents), a D level (Big Rusty),
    and the ending (start at 8-D's valve: `@level = 31; load_level(31, false);
    @boss = nil; @goal = { c: @arena_c + 10, r: 7, turn: 0 }; ... start_ending`).
- Ruby exceptions show on screen in the real runtime, so a screenshot of a
  busy level catches most mruby incompatibilities.
- **Performance check:** take a baseline before step 1 (see step 0) and
  compare after the entity and scene steps.
- Look at `git diff --stat` before committing: only the intended files.

## Test coupling to fix as you go

The scenarios in `tools/scenarios/*.rb` reach into internals, and every
refactor step will break some of them. Update them in the same commit.

- `s.iv(:name)` / `s.set(:name, v)` read and write Game instance variables.
  Most used: `warning, boss, goal, arena_c, lives, level, enemies, mode_t,
  lifts, frame, score, boss_on, banner, rush_armed, rk, wrench, time, rush,
  lift_v, fw_n, shots, spin, fw, vents, steam, nuts, items, locked, cam,
  time_acc`.
- `.data[:key]` on actors: `amp, bx, by, dx, dy` (lifts), `hp, inv, spiky,
  warn_spiky, angry` (boss).
- `s.g.send(:private_method)`: `die, boss_hit, add_nut, draw_firework`.
- Tools that also poke internals: `tools/reach.rb` (`@grid`, `@lifts`,
  `l.data[:axis]`), `tools/bot.rb`. Keep them working (run them once after the
  Level and Lift steps).
- Prefer adding public readers (`attr_reader :boss`, `Boss#hp`) over `iv`.
  Leave a test's intent unchanged; only change how it reaches the state.

## Plan

### 0. Baseline
- [ ] Confirm `git branch --show-current` is `main` and the tree is clean.
- [ ] Run the tests (ALL PASS) and note the run time.
- [ ] Performance baseline: a temp build that starts in a busy level (e.g. 7-D
      boss fight or 8-B) run headlessly for a fixed number of frames, timed
      (e.g. `time npx wasmcart x.wasc --frames 3000 --shot out.png`); record
      the numbers here. Repeat a few times; note the variance.
- [ ] Screenshots of title, a B level, a D level, the ending for later
      comparison. Store in the scratchpad (paths noted here).

### 1. Line-level cleanup (no structural change)
- [ ] One statement per line: remove `;` chains (about 51 lines in main.rb,
      more in boss.rb/ending.rb). Keep short `def x; ...; end` one-liners only
      if they stay readable (or convert to normal defs).
- [ ] Descriptive local names: `p` -> `player` (it also shadows Kernel#p),
      `b` -> `boss`, `e` -> `enemy`, `l` -> `lift`, `w` -> `wrench`,
      `it` -> `item`, `t` -> `time`/`frames` where it helps. Keep `T` (tile
      size) or rename to `TILE` everywhere at once.
- [ ] Name the colours used more than once (`WHITE = [255, 255, 255]`,
      steam `[236, 236, 236]`, label yellow `[252, 240, 160]`, ...). Freeze
      constant arrays/hashes.
- [ ] Name sprite-sheet frames: a `FRAMES` hash, e.g.
      `valve: [64, 0, 8, 16]`, so draw calls say what they draw.
- [ ] Predicate methods instead of repeated comparisons where it reads better
      (`playing?` for `@mode == :play`, etc.).
- [ ] Commit per file or per kind of change, not one giant diff.

### 2. Extract collaborators out of Game
Each as its own file under `app/`, required from main.rb. Game keeps thin
delegating methods at first if that keeps the diff small, then callers move.
- [ ] `Screen` (app/screen.rb): `sprite`, `rect`, `label`, `shadow_label`;
      holds the current outputs (today `@o`, switched to a render target by the
      ending). Use keyword args for the long `spr` signature:
      `sprite(path, x, y, w:, h:, frame:, flip: false, alpha: 255, angle: 0, flip_v: false)`.
- [ ] `Sound` (app/sound.rb): `sfx`, `music`, `stop_music`; owns the
      once-per-frame dedupe (`@played`).
- [ ] `Controls` (app/controls.rb): replaces `poll_input`/`read_input` and the
      `@in_*` ivars with readers (`left?`, `right?`, `jump_held?`,
      `jump_pressed?`, `run_held?`, `start_pressed?`, `code_press`). Watch the
      fixed-step detail: presses are latched in `poll_input` once per frame
      and consumed by `update` steps (`PRESS_KEYS`); keep that behaviour.
- [ ] `Level` (app/level.rb): grid, `cell`, `col_at`, `row_at`, `tile_top`,
      `tile_bottom`, `max_cam`, loading from `LEVELS[i]` (`load_level`'s grid
      part) and spawning markers into entity lists. Theme lookup.
- [ ] `Physics` module (app/physics.rb): `move_x`, `move_y`, `box_free?`,
      `overlap?`, `rect_hit?`, constants for gravity. Mixed into whatever needs
      it, or functions taking the level.
- [ ] `Camera` (app/camera.rb): position, follow, shake, `max_cam`.
- [ ] `Run` / session state (app/run.rb): score, lives, nuts, time, combo,
      rush mode, high score load/save (`save_u32` slot 0).

### 3. Entities with real classes
Replace `Actor` + `kind` symbols + `data` hashes with classes that each own
`update(world)` and `draw(screen, cam)`. `world` = whatever object exposes
level, player, physics, sound, effects (probably the Play scene or Game).
- [ ] `Lift` (vertical/horizontal; `amp`, `phase`, base position, `dx/dy`
      for riders; `lower_pit_lift` logic becomes a class method or initializer
      option). Update `tools/reach.rb`.
- [ ] Items: `PopNut`, `WrenchItem`, `Lunch` (from `update_items` /
      `draw_world`'s `case it.kind`).
- [ ] Static props as small classes or Structs: `Vent`, `Cone`, `Goal`
      (valve: `turn`, `gone`).
- [ ] Enemies: `Enemy` base with walking/turning/gravity, `Blob`
      (flattens when stomped) and `Crab` (spiky cycle, `spiky?`, `warning?`,
      double score). `stomp`/`knock` become methods on the enemy.
- [ ] `Wrench` (boomerang) from `update_wrench`.
- [ ] `Player` gets its own update split out of the 89-line
      `update_player`: `apply_input`, `apply_gravity`, `jump`, `land`,
      `ride_lift`, `animate`.
- [ ] Effects: `Particle` Struct for puff/dust/sparkle/steam; `Popup` for
      floating scores. Keep the existing lifetimes and motion exactly.
- [ ] Performance check against the baseline.

### 4. Modes as scene objects
- [ ] Scenes with `update` and `draw`: `Title`, `Intro`, `Play`, `Paused`,
      `Dying`, `Clear`, `GameOver`/`Win`, `Ending`. Each keeps its own timer
      (replaces the shared `@mode_t`). Game holds `@scene` and swaps it;
      `update`/`draw` become one line each.
- [ ] Note `@frame` (world clock) stops while paused; keep that.
- [ ] Title keeps the Boss Rush code (`RUSH_CODE`, `feed_code`, chime notes).
- [ ] `app/ending.rb` becomes the `Ending` scene (render target `:world`,
      fireworks, credits, Rusty's fall). Keep `CREDITS` text exactly.
- [ ] Tests that check `s.mode == :play` etc.: give scenes a `name` symbol
      (or keep `Game#mode` returning one) so the tests stay readable.
- [ ] Performance check.

### 5. Big Rusty
- [ ] `Boss` class (app/boss.rb). Replace the 167-line `update_boss` with one
      method per move (`hop`, `ground_pound`, `rust_spit`, `blob_belch`,
      `bull_charge`, `spiked_crown`, `bolt_storm`, `short_fuse`), picked from
      `BOSS_MOVES` and the encounter level (`boss_knows?`). Keep the move list
      and the "encounter n learns move n" rule in one table.
- [ ] Real attributes instead of `data`: `hp`, `max_hp`, `invulnerable`,
      `cooldown`, `spiky`, `warn_spiky`, `angry?`, `minions`.
- [ ] Shots (`@shots`: spit, bolts with their shadow warning) as small classes.
- [ ] Keep the warning/klaxon sequence, arena gate, valve placement, and the
      stomp rule (rising into the player's feet counts as a stomp).
- [ ] Keep `boss_rand` (its own LCG in `@rng`) and call order identical so
      fights play the same.

### 6. Tooling and tests (optional; ask the user first)
- [ ] RuboCop with a `.rubocop.yml` tuned for a game (looser method/class
      length, allow short names in tight math). It's a gem for the host Ruby,
      not a compiler, but **ask before installing it**.
- [ ] Move the scenarios to Minitest (ships with CRuby) if the user wants;
      keep `ruby tools/sim.rb` working as the one command either way.

### 7. Finish
- [ ] Full regression: tests, all real-runtime screenshots compared with the
      step 0 ones, performance compared with the baseline.
- [ ] Rebuild and publish the web player (AGENTS.md "Branches and the web
      player": `tools/build-web.sh`, `tools/publish-web.sh "Web player: ..."`,
      `git push origin gh-pages`), only if the user asks to update the site.
- [ ] Update AGENTS.md if file layout or commands changed.

## Notes / progress log
(Add dated notes here: decisions, surprises, baseline numbers, screenshot
paths, anything the next session needs.)
