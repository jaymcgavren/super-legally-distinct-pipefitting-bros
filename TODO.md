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
- This file is committed. Tick items off here as you go, add notes for
  anything surprising, and include the TODO.md update in the same commit as
  the step it records.

## Constraints that shape the refactor

- **Runtime: mruby 3.4** (patched wasmcart-mruby build; see AGENTS.md, don't
  replace `main.wasm`). Gems: struct, metaprog, enum-ext, array/hash/string/
  numeric/object/kernel/symbol-ext, math, random, sprintf, error, regexp, json.
  - Available: `Struct`, keyword arguments, `Comparable`, `define_method`,
    `send`, `attr_*`, modules/`include`.
  - Not available: `Set` (use a Hash), the standard library, `require` of gems.
    Files load with `require 'app/foo.rb'` (path from the packed app dir).
  - Probed in the real runtime (2026-11-19):
    - works: endless `def x = ...` (used for one-line helpers), `String#chars`.
    - missing: `Struct.new(..., keyword_init: true)` (TypeError), pattern
      matching `case/in` (syntax error), `Data`, `Float#clamp`, and the
      `defined?` keyword (it parses as a method call: NameError /
      NoMethodError). Use `Object.const_defined?`,
      `instance_variable_defined?`, `respond_to?` instead.
    - works (2026-11-19): `freeze` raises FrozenError on mutation, as in CRuby.
    - Probe anything else before relying on it: a one-file cart in the
      scratchpad that draws the result as a label, run with `--frames 3
      --shot`; exceptions print as `[cart] ruby exception ...`.
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
  - There are 8 levels (`LEVELS` in app/levels.rb, index 0-7: 1-A ... 2-D),
    and every one ends in a Big Rusty arena. `tools/bench_start.rb` is a
    working example of a start-in-level patch (appended to a temp copy).
  - Check at least: a B level (indoor, lifts, vents), a D level (Big Rusty),
    and the ending (start at 2-D's valve: `@level = 7; load_level(7, false);
    @boss = nil; @goal = { c: @arena_c + 10, r: 7, turn: 0 }; ... start_ending`).
- Ruby exceptions show on screen in the real runtime, so a screenshot of a
  busy level catches most mruby incompatibilities.
- **Visual regression:** `tools/shots.sh --compare` renders 11 seeded frames
  (title, 1-A/1-B starts, 2-B/2-D fights, four ending stages) from
  `un-refactored` and from the working tree and compares them byte for byte.
  It must print ALL SAME after every step (about 1.5 min). A DIFF means the
  game drew something different: look at both PNGs in the printed folder.
- **Performance check:** `tools/bench.sh` (see its header and the step 0
  note below). Run the baseline and the current code back to back, since
  machine load shifts the numbers by a few percent:
  `BENCH_REF=un-refactored tools/bench.sh 5; tools/bench.sh 5`.
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
- [x] Confirm `git branch --show-current` is `main` and the tree is clean.
- [x] Run the tests (ALL PASS) and note the run time.
- [x] Performance baseline: a temp build that starts in a busy level, run
      headlessly for a fixed number of frames, timed. Done with the new
      `tools/bench.sh`; numbers in the notes below.
- [x] Screenshots of title, a B level, a D level, the ending for later
      comparison. Done as `tools/shots.sh` (see the note below): the set can
      be re-rendered from `un-refactored` at any time, so nothing is stored.

### 1. Line-level cleanup (no structural change)
- [x] One statement per line: remove `;` chains (about 51 lines in main.rb,
      more in boss.rb/ending.rb). Keep short `def x; ...; end` one-liners only
      if they stay readable (or convert to normal defs). Done: no `;` tokens
      left in app/; one-liner helpers became endless defs.
- [x] Descriptive local names: `p` -> `player` (it also shadows Kernel#p),
      `b` -> `boss`, `e` -> `enemy`, `l` -> `lift`, `w` -> `wrench`,
      `it` -> `item`, `t` -> `time`/`frames` where it helps. Rename `T` (tile
      size) to `TILE` everywhere at once.
- [x] Replace abbreviations. E.g. `gravity`, not `grav`.
- [x] Name the colours used more than once (`WHITE = [255, 255, 255]`,
      steam `[236, 236, 236]`, label yellow `[252, 240, 160]`, ...). Freeze
      constant arrays/hashes.
- [x] Name sprite-sheet frames: a `FRAMES` hash, e.g.
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
      (`spr` already takes the frame as one array, `source`.)
- [ ] `Sound` (app/sound.rb): `sfx`, `music`, `stop_music`; owns the
      once-per-frame dedupe (`@played`).
- [ ] `Controls` (app/controls.rb): replaces `poll_input`/`read_input` and the
      `@in_*` ivars with readers (`left?`, `right?`, `jump_held?`,
      `jump_pressed?`, `run_held?`, `start_pressed?`, `code_press`). Watch the
      fixed-step detail: presses are latched in `poll_input` once per frame
      and consumed by `update` steps (`PRESS_KEYS`); keep that behaviour.
- [ ] `Level` (app/level.rb): grid, `cell`, `column_at`, `row_at`, `tile_top`,
      `tile_bottom`, `max_camera_x`, loading from `LEVELS[i]` (`load_level`'s grid
      part) and spawning markers into entity lists. Theme lookup.
- [ ] `Physics` module (app/physics.rb): `move_x`, `move_y`, `box_free?`,
      `overlap?`, `rect_hit?`, constants for gravity. Mixed into whatever needs
      it, or functions taking the level.
- [ ] `Camera` (app/camera.rb): position, follow, shake, `max_camera_x`.
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

- 2026-11-19: step 0 started. On `main`, tree clean, in sync with
  `origin/main` at d85377e.
- 2026-11-19: tests baseline (Ruby 3.4.9, `ruby tools/sim.rb`): ALL PASS,
  185 PASS lines, about 4.4 s wall time. Info lines printed, which should
  stay identical through the refactor:
  - `full jump 268 px (4.19 tiles), tap 136 px`
  - `held jump: standing 268, walking 268, 80% run 268, full run 342 px`
  - `firework gaps [8, 56, 37, 27, 14, 25, 9, 29]`
- 2026-11-19: performance baseline, `tools/bench.sh` (new; with
  `tools/bench_start.rb` and `tools/bench_time.mjs`). 3600 frames, 3 runs
  each. The time is the cart's `runFrame` (Ruby tick + runtime drawing):
  | run | ms/frame |
  |---|---|
  | `tools/bench.sh 7` (2-D, Rusty fight) | 0.38-0.42 |
  | `tools/bench.sh 5` (2-B, Rusty fight) | 0.77-0.80 |
  | `BENCH_START=level tools/bench.sh 5` (2-B start, idle) | 0.76-0.81 |
  | `BENCH_START=level tools/bench.sh 0` (1-A start, idle) | 0.32-0.33 |
  | `BENCH_REF=un-refactored tools/bench.sh 5` | 0.72-0.77 (same code) |
  Findings:
  - Wall-clock timing of `npx wasmcart --frames` is useless: an empty cart
    takes 10.8 s for 3600 frames vs 12.3 s for the 2-D fight, and run-to-run
    noise is about 1 s. The headless player's own overhead is about 3 ms a
    frame.
  - Headless runs need `--seed`. Without it the frame clock is real time,
    headless frames come far faster than 60 Hz, and the game skips updates.
  - In the 2-D fight, `draw` is about 80% of the cost (0.08 ms/frame with
    `draw` stubbed out; an empty cart is 0.02 ms). The indoor 2-B (brick
    background) costs about twice 2-D. So watch draw paths most.
  - Variance between runs is about 5%; treat a change under 10% as noise
    unless it shows up consistently back to back.
  - The whole game uses under 1 ms of a 16.7 ms frame here (this Mac, node).
    Absolute numbers will be higher on slower targets (browsers, Batocera
    boxes), so compare relative changes.
- 2026-11-19: `tools/shots.sh` (new). `bench_start.rb` now takes
  `BENCH_START=title|level|arena|ending` (was `BENCH_ARENA=0/1`). Seeded
  headless runs are fully deterministic: `--compare` against `un-refactored`
  gives ALL SAME, and against `8fdb217~1` (older game code) 8 of 11 differ,
  so it does catch changes. The patch in `bench_start.rb` calls Game
  internals; when the refactor renames them, keep it working for both the
  working tree and `un-refactored` (e.g. `respond_to?` checks), or the
  comparison breaks.
- 2026-11-19: step 1, semicolons. 36 lines (29 main.rb, 5 boss.rb, 2
  ending.rb) split one statement per line; `when 'X' then a; b` became
  multi-line `when`; brace blocks with several statements became `do`
  blocks; the 8 `def x; ...; end` one-liners became endless defs. One small
  rewrite: the grid split `rows.map { |row| a = []; row.size.times { ... } }`
  became `rows.map(&:chars)` (same arrays). Tests ALL PASS with identical
  info lines; `tools/shots.sh --compare` ALL SAME. To find semicolons
  without matching strings, lex with Ripper and look for `:on_semicolon`.
- 2026-11-19: step 1, `T` -> `TILE` (own commit; the rest of the names item
  is still open). Renamed constant tokens only (Ripper `:on_const`), in app/
  and tools/ (sim, scenarios, reach, bot). `bench_start.rb` uses
  `BENCH_TILE = defined?(TILE) ? TILE : T` so it still builds
  `un-refactored`. Checks: tests ALL PASS, shots ALL SAME, and
  `tools/reach.rb` / `tools/bot.rb` output byte-identical to `un-refactored`
  (extract it with `git archive un-refactored app tools | tar -x -C <dir>`
  and run the tools there).
- 2026-11-19: step 1, descriptive local names done. Token-based (Ripper)
  per-method renames: `p`->`player`, `b`->`boss` (also `bounce`, `bump`,
  `bush` where `b` meant those), `e`->`enemy`, `l`->`lift`, `w`->`wrench`
  (widths stay `w`), `it`->`item`, `a`->`actor` in move_x/move_y/
  collect_nuts/rect_hit?, `t`->`elapsed` (ending), `shift_time` (HUD),
  `shade` (sun ramp, with `from`/`to`). `overlap?(a, b)` keeps a/b: it's a
  symmetric pair. Checks: tests ALL PASS (same info lines), shots ALL SAME.
- 2026-11-19: step 1, abbreviations part 1/3: constants. VW->VIEW_WIDTH,
  PLAY_H/PLAYER_H/BOSS_W/BOSS_H -> *_HEIGHT/*_WIDTH, JUMP_V(_RUN) ->
  JUMP_VELOCITY(_RUN), RUSTY_FALL_V/END_TOP_V -> *_SPEED, GRAV_* ->
  GRAVITY_*, FW_GRAV/FW_COLS -> FIREWORK_GRAVITY/FIREWORK_COLORS (the code
  spells it `color`), *_LEN -> *_LENGTH, BOLT_WARN -> BOLT_WARNING,
  WIN_ROWS -> WINDOW_ROWS. Kept: STEP_MS (unit), END_LOCK_Y, WARN_AHEAD.
  Also renamed in tools/. Next: instance variables (@p, @cam, @rk, @fw,
  @lv, ...; tools/sim.rb and bench_start.rb read some of them), then
  methods and locals. Tests ALL PASS, shots ALL SAME.
- 2026-11-19: abbreviations part 2/3: instance variables. @p->@player,
  @cam->@camera_x, @arena_c->@arena_column, @rk->@flying_valve, ending's
  @lift/@lift_v->@rise/@rise_speed, @fw/@fw_n/@fw_next->@fireworks/
  @fireworks_launched/@next_firework_at, @lv->@level_data,
  @code_i->@code_index, @mode_t->@mode_frames, @o->@outputs,
  @step_acc/@time_acc->@step_accumulator/@time_accumulator,
  @hiscore->@high_score, @multi->@hits_left. Kept: @in_a/@in_b etc.
  (button names), @rng/@end_rng (standard term), @bro (game vocabulary),
  Actor's x/y/w/h/vx/vy/t. tools/ updated (`Sim#p` now reads @player;
  scenario `iv(:...)` symbols). bench_start.rb picks old or new names with
  `bench_iv(new, old)`, so shots still build un-refactored. Tests ALL PASS,
  shots ALL SAME, reach/bot output unchanged. Next: methods and locals.
- 2026-11-19: abbreviations part 3/3 (item done): methods and locals.
  `col_at`->`column_at`, `max_cam`->`max_camera_x` (tools updated;
  bench_start.rb uses whichever exists). Locals per method (Ripper,
  with a clash check against identifiers already in the method): cam->
  camera_x, th->theme, kb->keyboard, d->data/distance/depth/pressed/down,
  s->segment/swing/shot/steam_puff/digits, v->vent/speed, m->track (not
  `music`: it would sit beside calls to the `music` method), a->alpha/angle,
  col->color, ch->tile, pp/pt->popup/particle, o->outputs/labels/other,
  dmg/cnt/spd/cd/sz/len/off/ang -> full words, and so on. Kept on purpose:
  x/y/w/h, dx/dy, vx/vy, c/r and c0/c1/r0/r1 (grid column/row), cx/cy,
  i/j/k/n/f, `spr`'s sx/sy/sw/sh (step 2's Screen redoes that signature),
  `spr`/`sfx` themselves (renamed in step 2), `ms`, `gtk`. Tests ALL PASS,
  shots ALL SAME, reach/bot unchanged.
- 2026-11-19: HARNESS BUG, fixed. Since 0875030, tools/bench_start.rb used
  `defined?(TILE)`, which mruby lacks, so every shot on BOTH sides was the
  "RUBY EXCEPTION" banner and `shots.sh --compare` said ALL SAME without
  testing anything. The shot checks logged for 0875030, 592f7bc, f1700c2,
  3f0037b and 4ecdf84 were therefore void (their CRuby tests and reach/bot
  checks were real). Fixed with `Object.const_defined?(:TILE)`; bench.sh now
  exits 1 when the cart logs a Ruby exception, so shots.sh stops instead of
  comparing banners (checked by re-introducing a FrozenError: it stopped).
  Re-run against un-refactored on the current tree: ALL SAME with 11
  distinct real images, which covers all of those commits at once.
- 2026-11-19: step 1, named colours + frozen constants. 13 colours used more
  than once are constants at the top of main.rb (WHITE, BLACK, PALE_YELLOW,
  ORANGE, GOLD, ALERT_RED, WARNING_RED, WARNING_YELLOW, STEAM, LIGHT_GRAY,
  DARK_GRAY, NEAR_BLACK, TWINKLE), frozen. The THEMES/BROS palette tables
  keep their literals (they're sprite/theme data). Top-level freeze (not
  deep) on every array/hash constant: LEVELS, SOLID, COMBO, THEMES (after
  the indoor_* entries are added), BROS, BUMP_ARC, PRESS_KEYS, RUSH_CODE,
  CODE_STEPS, SUN_*, TREES, BOSS_MOVES, CREDITS, FIREWORK_COLORS. The 1-B
  lift scenario used to push a level onto LEVELS; it now swaps the constant
  for a frozen copy. Tests ALL PASS (185), shots ALL SAME (real images),
  reach/bot unchanged, 2-B bench 0.68 ms/frame vs 0.70 for un-refactored.
- 2026-11-19: step 1, FRAMES. `FRAMES` (main.rb, frozen) names every
  sprite-sheet frame used, with the names from tools/make-assets.mjs
  (brick, brick_top, girder, crate, ..., nut, valve, blob, crab_spin,
  bro_run, wrench_spin, rusty_hurt, glob, bolt). `frame(name, index)` gives
  frame `index` of an animation strip. `spr` now takes the source rect as
  one array (`spr(path, x, y, w, h, source, flip, ...)`) instead of
  sx/sy/sw/sh. The player, Big Rusty, enemy and title pose logic now
  picks named poses instead of numbers (`pose = :bro_skid`, not `f = 5`).
  PERF NOTE: a first version splatted (`*FRAMES[:brick]`) into the old
  signature and the 2-B fight went from ~0.87 to ~1.06 ms/frame (+20%,
  mruby splat calls are slow). Passing the array removed it: 0.85-0.92
  vs 0.87-0.89 for un-refactored, interleaved. Avoid splats in draw code.
  Tests ALL PASS (185), shots ALL SAME.
