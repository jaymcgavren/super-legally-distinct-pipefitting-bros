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
- [x] Predicate methods instead of repeated comparisons where it reads better
      (`playing?` for `@mode == :play`, etc.).
- [x] Commit per file or per kind of change, not one giant diff. (Followed
      throughout step 1; keep doing it.)

### 2. Extract collaborators out of Game
Each as its own file under `app/`, required from main.rb. Game keeps thin
delegating methods at first if that keeps the diff small, then callers move.
- [x] `Screen` (app/screen.rb): `sprite`, `tile`, `rect`, `label`,
      `shadow_label`, `draw_into(target) { }`; holds the current outputs.
      Keyword args only for the optional sprite settings:
      `sprite(path, x, y, w, h, frame, flip: false, alpha: 255, angle: 0, flip_v: false)`
      (w/h/frame positional: see the perf note in the log).
- [x] `Sound` (app/sound.rb): `play`, `chime`, `music(name, looping:)`,
      `stop_music`, `music_playing?`, `pause_music`/`resume_music`,
      `music_pitch=`; owns the once-per-frame dedupe (`@played`).
- [x] `Controls` (app/controls.rb): replaces `poll_input`/`read_input` and the
      `@in_*` ivars with readers (`left?`, `right?`, `jump_held?`,
      `jump_pressed?`, `run_held?`, `start_pressed?`, `code_press`). Watch the
      fixed-step detail: presses are latched in `poll_input` once per frame
      and consumed by `update` steps (`PRESS_KEYS`); keep that behaviour.
- [x] `Level` (app/level.rb): grid, `cell`, `column_at`, `row_at`, `tile_top`,
      `tile_bottom`, `max_camera_x`, loading from `LEVELS[i]` (`load_level`'s grid
      part) and spawning markers into entity lists. Theme lookup.
- [x] `Physics` module (app/physics.rb): `move_x`, `move_y`, `box_free?`,
      `overlap?`, `rect_hit?`, constants for gravity. Mixed into whatever needs
      it, or functions taking the level.
- [x] `Camera` (app/camera.rb): position, follow, shake, `max_camera_x`.
- [x] `Run` / session state (app/run.rb): score, lives, nuts, time, combo,
      rush mode, high score load/save (`save_u32` slot 0).

### 3. Entities with real classes
Replace `Actor` + `kind` symbols + `data` hashes with classes that each own
`update(world)` and `draw(screen, cam)`. `world` = whatever object exposes
level, player, physics, sound, effects (probably the Play scene or Game).
- [x] `Lift` (vertical/horizontal; `amp`, `phase`, base position, `dx/dy`
      for riders; `lower_pit_lift` logic becomes a class method or initializer
      option). Update `tools/reach.rb`.
- [x] Items: `PopNut`, `WrenchItem`, `Lunch` (from `update_items` /
      `draw_world`'s `case it.kind`).
- [x] Static props as small classes or Structs: `Vent`, `Cone`, `Goal`
      (valve: `turn`, `gone`).
- [x] Enemies: `Enemy` base with walking/turning/gravity, `Blob`
      (flattens when stomped) and `Crab` (spiky cycle, `spiky?`, `warning?`,
      double score). `stomp`/`knock` become methods on the enemy.
- [x] `Wrench` (boomerang) from `update_wrench`.
- [x] `Player` gets its own update split out of the 89-line
      `update_player`: `apply_input`, `apply_gravity`, `jump`, `land`,
      `ride_lift`, `animate`.
- [x] Effects: `Particle` Struct for puff/dust/sparkle/steam; `Popup` for
      floating scores. Keep the existing lifetimes and motion exactly.
- [x] Performance check against the baseline.

### 4. Modes as scene objects
- [x] Scenes with `update` and `draw`: `Title`, `Intro`, `Play`, `Paused`,
      `Dying`, `Clear`, `GameOver`/`Win`, `Ending`. Each keeps its own timer
      (replaces the shared `@mode_t`). Game holds `@scene` and swaps it;
      `update`/`draw` become one line each.
- [x] Note `@frame` (world clock) stops while paused; keep that.
- [x] Title keeps the Boss Rush code (`RUSH_CODE`, `feed_code`, chime notes).
- [x] `app/ending.rb` becomes the `Ending` scene (render target `:world`,
      fireworks, credits, Rusty's fall). Keep `CREDITS` text exactly.
- [x] Tests that check `s.mode == :play` etc.: give scenes a `name` symbol
      (or keep `Game#mode` returning one) so the tests stay readable.
- [x] Performance check.

### 5. Big Rusty
- [x] `Boss` class (app/boss.rb). Replace the 167-line `update_boss` with one
      method per move (`hop`, `ground_pound`, `rust_spit`, `blob_belch`,
      `bull_charge`, `spiked_crown`, `bolt_storm`, `short_fuse`), picked from
      `BOSS_MOVES` and the encounter level (`boss_knows?`). Keep the move list
      and the "encounter n learns move n" rule in one table.
- [x] Real attributes instead of `data`: `hp`, `max_hp`, `invulnerable`,
      `cooldown`, `spiky`, `warn_spiky`, `angry?`, `minions`.
- [x] Shots (`@shots`: spit, bolts with their shadow warning) as small classes.
- [x] Keep the warning/klaxon sequence, arena gate, valve placement, and the
      stomp rule (rising into the player's feet counts as a stomp).
- [x] Keep `boss_rand` (its own LCG in `@rng`) and call order identical so
      fights play the same.

### 6. Tooling and tests (optional; ask the user first)
- [x] RuboCop with a `.rubocop.yml` tuned for a game (looser method/class
      length, allow short names in tight math). It's a gem for the host Ruby,
      not a compiler, but **ask before installing it**.
- [x] Move the scenarios to Minitest (ships with CRuby) if the user wants;
      keep `ruby tools/sim.rb` working as the one command either way.

### 7. Finish
- [ ] Full regression: tests, all real-runtime screenshots compared with the
      step 0 ones, performance compared with the baseline.
- [ ] Rebuild and publish the web player (AGENTS.md "Branches and the web
      player": `tools/build-web.sh`, `tools/publish-web.sh "Web player: ..."`,
      `git push origin gh-pages`), only if the user asks to update the site.
- [x] Update AGENTS.md if file layout or commands changed.

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
- 2026-11-19: step 1, predicates (step 1 done). `Game#playing?` (was
  `@mode == :play`, 9 places), `Actor#dead?`/`#walking?`/`#gone?` (state
  checks, ~20 places), `Player#invulnerable?`, `boss_invulnerable?`, and the
  existing `boss_spiky?` used where `data[:spiky] > 0` was repeated. The
  `x -= 1 if x > 0` countdowns stay as they are. Endless defs. Tests ALL PASS
  (185), shots ALL SAME, 2-B bench within noise of the previous commit.
  Next: step 2, `Screen`.
- 2026-11-19: step 2, `Screen` (app/screen.rb). Game holds `@screen`; every
  draw call is `@screen.sprite/tile/rect/label/shadow_label`, the raw
  outputs are `@screen.outputs`, and the ending draws the level into its
  render target with `@screen.draw_into(target) { draw_world(true, false) }`
  instead of swapping `@outputs` by hand. Optional sprite settings are
  keywords (`flip: true`, `alpha:`, `flip_v:`), so call sites name what
  they change instead of passing `false, 255, 0, true`.
  PERF NOTE: in mruby, keyword parameters slow every call to the method,
  even calls that pass none. All-keyword `sprite(path, x, y, w:, h:, frame:)`
  made the 2-B fight 1.16 vs 0.90 ms/frame (+28%); keywords for the optional
  settings only still made level 1 ~8% slower (0.99 vs 0.90), because it
  draws hundreds of tiles a frame. Fix: `Screen#tile(path, x, y, frame)`,
  positional, for the TILE-sized, unflipped case (21 calls, all of
  draw_tiles). Now level 1 0.90-0.92 vs 0.90-0.93 at HEAD, 2-B 0.90-0.91
  vs 0.91. Tests ALL PASS (185), shots ALL SAME, reach/bot unchanged.
  Scenario 04 sets `s.iv(:screen).outputs` instead of `@outputs`.
- 2026-11-19: step 2, `Sound` (app/sound.rb). Game holds `@sound`.
  `sfx(:jump)` is now `@sound.play(:jump)`; `music(:clear, false)` is
  `@sound.music(:clear, looping: false)`; `music_stop` is
  `@sound.stop_music`. The four "fetch args.audio[:music] and poke it if
  present" blocks became `pause_music`, `resume_music` and
  `music_pitch = 1.15`, and the ending's `@args.audio[:music].nil?` is
  `!@sound.music_playing?`. The code chime is `@sound.chime(semitones)`.
  `tick` calls `@sound.new_frame` where it reset `@played`. Game no longer
  touches args.audio or outputs.sounds. Tests ALL PASS (185; they cover
  sounds per frame at 30-144 Hz, boss music and the klaxon), shots ALL
  SAME, reach/bot unchanged, 2-B bench 0.88-0.91 vs 0.89 at HEAD.
- 2026-11-19: step 2, `Controls` (app/controls.rb). Game holds
  `@controls`; `tick` calls `@controls.poll` every host frame and `update`
  calls `@controls.read` every step, exactly where `poll_input`/
  `read_input` ran, so the latched-press behaviour is unchanged (the 30-144
  Hz scenarios cover it). The ten `@in_*` ivars became readers: `left?`,
  `right?`, `jump_held?`, `run_held?` (held), `jump_pressed?`,
  `throw_pressed?`, `start_pressed?`, `left_pressed?`, `right_pressed?`
  (pressed since the last step) and `code_press`. They return the same raw
  values as before (nil or false), since `player.jumping = jump_held?`
  stores one. tools/reach.rb now sets the readers' ivars on `@controls`.
  Tests ALL PASS (185), shots ALL SAME, reach/bot unchanged, level 1 bench
  0.90-0.92 vs 0.92 at HEAD.
- 2026-11-19: step 2, `Level` (app/level.rb). `Level.new(index)` builds the
  grid from LEVELS[index] (own rows, or segments side by side) and holds
  `data`, `theme`, `columns`, `name`, `title`; `cell`, `set_cell`, `row`,
  `column_at`, `row_at`, `tile_top`, `tile_bottom`, `width`,
  `max_camera_x`. `each_marker { |tile, c, r| }` walks the start markers in
  the old scan order and clears each one after the block (vents stay), so
  `load_level` keeps only the entity spawning. Game's `@level` is now the
  Level; the level number is `@level_index` (scenarios use
  `iv(:level_index)`). `@grid`, `@cols`, `@theme`, `@level_data` are gone;
  grid writes are `@level.set_cell(c, r, 'U')`.
  Tools: `Sim#level`; bot/reach/scenarios call `level.cell` etc. instead
  of `g.cell` and use `set_cell` instead of writing `@grid`; bot/reach
  params renamed `level` -> `index`. bench_start.rb sets `@level_index` (or
  `@level` on old refs) and reads max_camera_x from the Level when there
  is one, so BENCH_REF=un-refactored still works.
  Tests ALL PASS (185), shots ALL SAME, reach/bot unchanged; bench level 1
  0.92-0.93 vs 0.90-0.91, 2-B 0.89-0.92 vs 0.90-0.91 (noise).
- 2026-11-19: step 2, `Physics` (app/physics.rb), a module included in
  Game: `box_free?`, `overlap?`, `rect_hit?`, `move_x`, `move_y` moved
  over unchanged (they read `@level` and `@lifts`, documented at the top),
  plus GRAVITY_HOLD/CUT/FALL and FALL_MAX as `Physics::` constants (Game,
  boss.rb and ending.rb see them through the include). New `fall(actor)`:
  gravity plus the terminal-velocity cap, replacing the two copies (enemies,
  Big Rusty). The player's variable gravity and the uncapped death arcs and
  popped items keep their own lines, since they differ. Mixin rather than
  functions taking the level: Game is the only user, and step 3's entity
  classes can include it or take the level then.
  Tests ALL PASS (185), shots ALL SAME, reach/bot unchanged; bench level 1
  0.91-0.92 vs 0.90-0.92, 2-B 0.90 vs 0.89-0.90.
- 2026-11-19: step 2, `Camera` (app/camera.rb). `@camera_x` and `@shake`
  became `@camera`: `x`, `max_x`, `jump_to(x)` (clamped, used on level
  load and by `Sim#snap`), `follow(player, arena)` (was `update_camera`),
  `shake(frames)`, `settle` (one step of shake running down), `shake_x(frame)`
  and `offset_by(dx) { }` for drawing shaken; the play screen and the
  ending used to `+=`/`-=` the camera by hand around `draw_world`. A new
  Camera comes with each level load, which also clears the shake, so
  spawn_boss's `@shake = 0` went. bench_start.rb sets `@camera.x` when there
  is a camera (old refs still get the ivar).
  Tests ALL PASS (185), shots ALL SAME (the ending ones included),
  reach/bot unchanged; bench level 1 0.92 vs 0.91-0.93, 2-B 0.91-0.94 vs
  0.90-0.91 (noise).
- 2026-11-19: step 2, `Run` and `HighScore` (app/run.rb). Step 2 done.
  `Run.new(rush)` per game holds `score`, `lives`, `nuts`, `time`, `rush?`,
  `checkpoint`, `powered` (the wrench carried between levels), with
  `add_nut` (true on the 50th: Game plays the sound and awards the 1UP, in
  the old order), `add_score`, and the shift clock: `start_shift(length)`,
  `tick_clock` (true when a unit passes), `low_time_warning?` (true once at
  100) and `bank_time(n = all)` for the end-of-level count-up and the
  ending's lump sum. Points and life counts are named constants.
  `HighScore.new(gtk)` loads slot 0; `submit(score)` saves if higher.
  Not moved: combo stays on Player (it's the stomp chain, reset on
  landing); `@level_index` stays on Game for now (8 scenario uses; could
  join Run with the level-flow code later); `@rush_armed` is title state.
  `to_title` still clears only the rush flag, not the score, so
  `debug_score` reads as before.
  Tools: `Sim#run`; scenarios use `s.run.lives` etc. and
  `s.run.start_shift(1)` instead of setting @time/@time_accumulator;
  bench_start.rb sets `@run.lives` (old refs: `@lives`).
  Tests ALL PASS (185), shots ALL SAME, reach/bot unchanged; bench level 1
  0.92 vs 0.91-0.92, 2-B 0.93 vs 0.91-0.92 (noise).
- 2026-11-19: step 3, `Lift` (app/lift.rb). `Lift.new(level, c, r, axis)`
  replaces `Actor.new(:lift, ...)` plus its data hash; the old data keys are
  readers: `base_x`, `base_y`, `amplitude`, `phase`, `axis`, `dx`, `dy`
  (riders follow `riding.dx/dy`). `lower_pit_lift` is the private
  `fit_under_ceiling`, run by the initializer for vertical lifts, and
  JUMP_RISE moved with it (`Lift::JUMP_RISE`). `update(frame)` was
  `update_lifts`'s loop body; `draw(screen, camera_x, tiles)` was in
  `draw_world`. Swing size and period are named (SWING, PERIOD).
  Interface note for the rest of step 3: plain arguments (`frame`,
  `screen`, `camera_x`) rather than a `world` object until an entity needs
  more than two or three things from Game.
  main.rb requires entity files after its constants, since their class
  bodies use them. Scenarios and reach.rb read the new readers.
  Tests ALL PASS (185), shots ALL SAME, reach/bot unchanged; bench level 1
  0.98-1.03 vs 0.98-0.99 at HEAD (machine slower this run; noise).
- 2026-11-19: step 3, items (app/items.rb). `PopNut`, and `WrenchItem` /
  `Lunch` on a shared `RisingItem` (rises 64 px out of its crate, then
  `move`s). All still subclass Actor for now (Physics and `gone?` need
  its fields; Actor slims down once everything has a class). Each has
  `update(world)` (returns true when it can be picked up this step;
  `world` is the Game, used for Lunch's move_x/move_y) and
  `draw(screen, camera_x, frame)`. The `data[:rise]` hash entry is
  `rising?`. What a pickup does (1UP; score, power-up, sound) stays in
  `Game#update_items`, by class. `frame(name, i)` is now top-level next
  to FRAMES, so entity classes can use it.
  Lunch isn't covered by the scenarios, so I traced a lunchbox for 300
  steps on 4 levels against the previous commit (x, y, vx, state every
  step, wall bounces included): identical. Tests ALL PASS (185), shots
  ALL SAME, reach/bot unchanged; bench level 1 1.00-1.01 vs 1.00-1.01.
- 2026-11-19: step 3, static props (app/props.rb): `Vent`, `Cone`, `Goal`
  replace the `{ c:, r:, ... }` hashes. Each keeps `c`/`r` and works out
  its world `x`/`y` once. Vent computes its jet height in `initialize`
  (was a separate pass in load_level) and has `jetting?(frame)` /
  `jet_starts?(frame)`, with the cycle numbers named (CYCLE, SPUTTER, JET).
  Cone has `lit?`/`light`; Goal has `turn`, `gone?`. Each draws itself.
  What touching them does (hurt, checkpoint, clear) stays in Game.
  Tools: scenarios use `.c`/`.lit?`/`.gone?`; reach.rb reads `goal.c`;
  bench_start builds a Goal when the class exists (old refs get the hash).
  Tests ALL PASS (185), shots ALL SAME, reach/bot unchanged; bench level 1
  0.86-0.87 vs 0.84-0.87, 2-B arena 0.83 vs 0.82, ending start runs.
- 2026-11-19: step 3, enemies (app/enemies.rb). `Enemy < Actor` wakes as
  the camera nears, walks, falls, turns at walls, ledges and other
  enemies; `update(world, level, camera_x, others)` returns true when it
  can touch the player this step, and the stomp/hurt decision stays in
  Game. `knock(dir)` and `stomp(dir)` are methods (Game still plays the
  sounds); `stomp_points` doubles for crabs. `Blob` squashes (`flat?`,
  its 30-step timer now runs in its own update, starting at 1 on the
  stomp step, which matches the old separate pass); `Blob.minion` is what
  Rusty spits out (`minion` replaces `data[:minion]`). `Crab` has the
  spin cycle with named steps (CYCLE, WARN, SPIN), `spiky?`, `warning?`.
  Both place themselves from markers with `.at(level, c, r)` and draw
  themselves. The level is passed in (Game has no `level` reader).
  Checked with a trace (all 8 levels, 1500 steps of running/jumping/
  throwing, every enemy's x, y, vx, state, t, active plus score each
  step, with 356 flat and 148 knocked-out samples) against the previous
  commit: identical. Tests ALL PASS (185), shots ALL SAME, reach/bot
  unchanged; bench level 1 0.83-0.84 vs 0.82-0.88, arena 0.82 vs 0.77
  (noise band).
- 2026-11-19: step 3, `Wrench` (app/wrench.rb, `< Actor`). `Wrench.new(player)`
  is the throw; `update(player)` flies it (out, drag, turn, home in) and
  returns true when it's in free flight and can hit things; `caught?`,
  `expired?`, `back?`, `heading`; `turn_back` (hit Rusty) and `bounce_off`
  (hit the valve) replace the `data[:back]`/`data[:bounce]` writes. The
  numbers are named (THROW_SPEED, DRAG, HOME_MAX, LIFETIME, ...). What it
  hits (nuts, enemies, Rusty, the valve, globs) stays in Game. Traced
  against the previous commit (8 levels x 1500 steps, powered, throwing
  every 37 steps both ways; wrench x/y/vx/vy/t, enemies, score, nuts):
  identical. Tests ALL PASS (185), shots ALL SAME, reach/bot unchanged;
  bench level 1 0.85 vs 0.85-0.93, arena 0.84 vs 0.85-0.86.
- 2026-11-19: step 3, `Player` moved to app/player.rb with its own steps:
  `ride_lift` (also sets prev_y), `apply_input(dir, run)` (returns true
  when skidding; Game makes the dust), `jump(pressed)` (buffer + coyote;
  returns true when a jump starts; Game plays the sound),
  `apply_gravity(jump_held)`, `land`, `throw_wrench`, `animate`. The
  tuning numbers are named (ACCEL_*, FRICTION, JUMP_BUFFER, COYOTE_TIME,
  ...). `Game#update_player` is now the order of those steps plus
  collision, `bump_nearest` (the head-bump pick), the throw and touching
  props (vents, cones, valve), ~40 lines. Traced against the previous
  commit (8 levels x 2000 steps, run/walk, direction changes with skids,
  jumps, throws; player x/y/vx/vy/anim/skid/coyote/buffer/jumping/
  throw_t/invuln/combo/facing, score, lives, particles, sounds):
  identical. Tests ALL PASS (185), shots ALL SAME, reach/bot unchanged;
  bench level 1 0.87 vs 0.86 (+2%), arena 0.85-0.86 vs 0.85-0.88.
- 2026-11-19: step 3, effects (app/effects.rb): `Particle` (x, y, vx, vy,
  life, color), `Popup` (x, y, text, t) and, for the ending, `SteamPuff`
  (x, y, vx, vy, life, size), each a `class X < Struct.new(...)` with
  `update`, `gone?` and (Particle, Popup) `draw`, replacing the index
  arrays. Constants live in the class bodies; a `Struct.new do` block
  would have put them at top level. Traced against the previous commit
  (particles and popups every step on 3 levels x 1200 steps, and the
  ending's steam, 399 steps with puffs, compared via `to_a`): identical.
  Tests ALL PASS (185), shots ALL SAME, reach/bot unchanged. Bench:
  level 1 0.87-0.88 vs 0.86 (+2%), arena 0.86 vs 0.85-0.90, ending
  0.45-0.46 vs 0.42 (+6-8%, consistent: Struct accessors on ~100 steam
  puffs; under the noise bar and the ending costs half a level).
- 2026-11-19: step 3 performance check, `un-refactored` vs c8633a8,
  interleaved, 3 pairs per row (3600 frames; the ending 900), median
  ms/frame:
  | run | baseline | now | change |
  |---|---|---|---|
  | arena 7 (2-D fight) | 0.412 | 0.424 | +3% |
  | arena 5 (2-B fight) | 0.842 | 0.850 | +1% |
  | level 5 (2-B start) | 0.857 | 0.896 | +4.5% |
  | level 0 (1-A start) | 0.332 | 0.342 | +3% |
  | level 1 (1-B start) | 0.855 | 0.867 | +1.4% |
  | ending | 0.428 | 0.459 | +7% |
  | title | 0.352 | 0.355 | +1% |
  Every row is under the 10% bar, but the refactor is consistently a
  little slower (one more method call per object here and there). The
  biggest is the ending (+7%, most of it from SteamPuff's Struct accessors,
  see the effects entry). Worst absolute is level 5 at 0.90 ms, still
  about 5% of a 16.7 ms frame. No action; if a later step adds more,
  SteamPuff back to arrays and level 5's draw path are the first places
  to look.
  (Note to self: in zsh, `set -- $cfg` doesn't split words. A loop over
  config strings must run under sh, or every run benches the exception
  banner.)
- 2026-11-19: step 4, scenes (app/scenes.rb). `Scene` (game, own `frames`
  timer, `update`, `draw`, `freezes_world?`, `name`) and `Title`,
  `Intro`, `Play`, `Paused`, `Dying`, `Clear`, `Final` (game over and win:
  `name` is :gameover / :win), `Ending`. Game holds `@scene`, swaps it
  with `switch_to`; `Game#update` is the world clock + the scene's timer +
  `scene.update`, `Game#draw` is `@scene.draw`. `@mode`/`@mode_frames`
  are gone; `Game#mode` returns the scene's name, so the tests'
  `s.mode == :play` stay as they were (sim: `s.mode_frames` reads the
  scene's timer). The world clock stops while `Paused`
  (`freezes_world?`). Title owns the Boss Rush code (RUSH_CODE,
  CODE_STEPS, `feed_code`, `rush_armed?`) and the bro select (`Game#bro`
  stays: the HUD and player sprite use it). Paused goes back to the same
  Play object. The world stays in Game, which scenes reach through
  readers (screen, sound, controls, run, camera, player, level, goal,
  ...): `update_world` (was step_play), and new `settle_player(facing)`,
  `follow_player`, `next_level`, `finish(kind)` for the scene code.
  The ending is a thin `Ending` scene for now: `step_ending(elapsed)` /
  `draw_ending(elapsed)` take the scene's timer. Moving ending.rb into
  the scene is the next item.
  One difference, in a timer nothing reads: the old shared `@mode_frames`
  kept counting from play into the pause; the Paused scene's own timer
  starts at 1 (and Play's timer stops while paused).
  Checked with a scene trace against the previous commit (title with
  bro switch and partial code, intro, play, pause and resume, three
  deaths to game over, back to the title, a new game, beating the boss,
  the clear's tally, the next intro and play; 2687 steps of mode, timer,
  world clock, player, score, lives, shift time, bro, camera, sounds and
  every label's text): identical apart from the 51 paused steps' timer.
  Tests ALL PASS (185), shots ALL SAME, reach/bot unchanged; bench level
  1 0.88 vs 0.88, arena 0.87-0.89 vs 0.86-0.89, title 0.36-0.37 vs 0.37.
- 2026-11-19: step 4, app/ending.rb is the `Ending` scene. Its state
  (spin, flying valve, rise, steam, fireworks, rng, twinkle, shake) is
  the scene's own ivars instead of Game's; `elapsed` is the scene timer.
  `Game#start_ending` just switches to it and banks the bonus.
  Fireworks are `Firework < Struct.new(:x, :y, :color, :t)` with `update`,
  `gone?`, `draw(screen)` (the gravity test draws one directly). The star
  field is the constant `Ending::STARS` (was `@end_stars ||=` on Game).
  The player's settling uses `Game#settle_player`, the shake jitter uses
  `Game#clock` (the world clock). Renamed: `@end_shake` -> `@shake`,
  `end_shake_x` -> `shake_dx`, `end_rand` -> `rand_below`. CREDITS and
  the END_* timings are unchanged (still top level; the tests use them).
  sim.rb: `s.scene_iv(:name)` reads a scene ivar.
  Traced against the previous commit: the whole ending to the title,
  normal and Boss Rush (4000 steps: mode, timer, score, music channels,
  background colour, an MD5 of every sprite/solid/label/primitive drawn,
  sounds): identical. Tests ALL PASS (185), shots ALL SAME (incl. the
  four ending stages, render target and all), reach/bot unchanged; bench
  ending 0.43-0.44 vs 0.43-0.44, level 1 0.86 vs 0.89.
- 2026-11-19: step 4 performance check, `un-refactored` vs 90dcd74,
  interleaved, 3 pairs per row, median ms/frame (step 3's change in
  brackets):
  | run | baseline | now | change |
  |---|---|---|---|
  | arena 7 (2-D fight) | 0.414 | 0.428 | +3% (+3%) |
  | arena 5 (2-B fight) | 0.842 | 0.869 | +3% (+1%) |
  | level 5 (2-B start) | 0.820 | 0.825 | +1% (+4.5%) |
  | level 0 (1-A start) | 0.336 | 0.341 | +1.5% (+3%) |
  | level 1 (1-B start) | 0.859 | 0.881 | +2.6% (+1.4%) |
  | ending | 0.426 | 0.453 | +6% (+7%) |
  | title | 0.345 | 0.354 | +2.6% (+1%) |
  The scenes cost nothing measurable: the rows moved within noise of
  step 3's, all under the 10% bar.
- 2026-11-19: step 5, `Boss < Actor` in app/boss.rb. `update_boss` is
  split: Game keeps the fight around Rusty (warning, gate, banner, shots,
  `boss_vs_player`, `boss_hit`, and the new `reveal_valve` when he's
  down); `Boss#update` is Rusty himself: one step method per state, from
  `STEPS`, which is built from `BOSS_MOVES` (now [state, banner name,
  method]: `hop`, `ground_pound`, `rust_spit`, `blob_belch`,
  `bull_charge`, `spiked_crown`, `bolt_storm`, and `short_fuse`, his
  half-health anger) plus `wait_for_banner`, `walk`, `reel` (stunned).
  So the move list, its order (encounter n learns move n) and the code
  for each are one table. `move_in_arena` is gravity, the floor and walls
  and the charge stun. `knows?`, `spiky?`, `invulnerable?`, `idle`,
  `choose_move` and Rusty's draw moved onto Boss. The LCG is Boss's own
  `@rng` with the same seed (1 + level * 31) and call order. Moves still
  get the step's starting mood (`angry`), so the fuming step keeps calm
  speed as before. Game gains readers `enemies`, `shots`, `banner`.
  `data` is untouched (next item).
  Traced against the previous commit: all 8 fights, approaching mortal,
  invincible, and invincible with Rusty hit every 150 steps, 3000 steps
  each (70,180 steps: every move, anger, death, valve, clears and a game
  over), recording Rusty's whole state and LCG, shots, enemies, popups,
  sounds and an MD5 of everything drawn: identical. Tests ALL PASS
  (185), shots ALL SAME, reach/bot unchanged; bench arena 7 0.425-0.431
  vs 0.424-0.430, arena 5 0.854-0.867 vs 0.860-0.869.
- 2026-11-19: step 5, Rusty's `data` hash is attributes: `hp`,
  `max_hp` (reader), `invulnerable`, `spiky`, `warn_spiky`, `cooldown`
  (frame counters, with `invulnerable?`/`spiky?`), `angry?` (+ writer
  for the tests), and private `@airborne` (the ground pound's `:air`).
  `minions` is gone: it was always 0 and never read (the minion cap
  counts `enemies`). `Boss#take_hit(damage)` takes the hp, starts the
  flashing (`HIT_INVULNERABLE` 45) and knocks him out at 0; `boss_hit`
  keeps the sound, score and clean-up. Scenarios/sim.rb use the
  attributes. Fight trace (same 70,180 steps, Rusty's numbers read from
  `data` on the old side): identical. Tests ALL PASS (185), shots ALL
  SAME, reach/bot unchanged; bench arena 7 0.432-0.437 vs 0.424-0.431,
  arena 5 0.861-0.876 vs 0.857-0.900.
- 2026-11-19: step 5, Rusty's shots are classes (end of app/boss.rb):
  `Shot` (x, y, w, h, vx, vy, t; `gone?`, `harmful?`) and `SteamWave`
  (ground pound; dies leaving the arena, bounds given by Boss),
  `RustGlob` (rust spit; `burst(game, dy)` on the floor, a solid tile or
  the wrench) and `Bolt` (bolt storm; `falling?` once its shadow has shown
  BOLT_WARNING steps; only then `harmful?`). Each has `update(game)` and
  `draw(screen, camera_x)`; the shadow/beam warning drawing moved into
  `Bolt#draw`. `Game#update_shots` is now: update, hurt the player if
  harmful, pop globs the wrench touches (overlap? on the shot itself, no
  throwaway Actor), drop the gone ones. `draw_boss` draws the shots, then
  Rusty. Floor y is `Boss::FLOOR`. Scenario 02 uses `is_a?(Bolt)`, `.t`,
  `.y`, `.vy`. Fight trace (same 70,180 steps; ~10,000 shot-steps of
  waves, globs and bolts): identical. Tests ALL PASS (185), shots ALL
  SAME, reach/bot unchanged; bench arena 7 0.430-0.435 vs 0.425-0.434,
  arena 5 0.863-0.865 vs 0.866-0.878.
- 2026-11-19: step 5's two "keep" items, checked for the whole of step 5
  at once: the fight trace (all 8 fights; mortal approach, invincible,
  invincible with Rusty hit every 150 steps; 70,180 steps recording
  Rusty's state and LCG, shots, enemies, popups, sounds, warning, banner,
  gate, valve column and an MD5 of everything drawn) run on 1f5d8b4 and on
  3d7c90b (before step 5): identical, through 88 distinct LCG values.
  The LCG is now Boss's `@rng`, same seed (1 + level * 31), drawn only by
  `choose_move` and `bolt_storm` in the same order. Scenario 02 still pins
  the rules: warning on the approach with the gate open, the klaxon once,
  the gate shutting as you step in, music after the warning, the valve
  between the girders, and Rusty rising into your feet is a stomp.
- 2026-11-19: step 6, RuboCop (user chose "Both": RuboCop, then Minitest).
  `rubocop` at the root: 30 files, no offenses. `.rubocop.yml` explains
  each choice. Ruby 3.4 target. Size limits are raised for game code
  (method 45 lines, ABC 60, complexity 20, class 700) and off for tools/.
  It allows short maths names (x, c, r, dx). Some cops are off because
  their fix would be slower or wrong under mruby: `n > 0` over
  `n.positive?`, a ternary over `[a, b].max` or `.include?` (allocates
  an array), no Comparable#clamp (the camera's bounds can cross), and
  `class X < Struct.new` (constants in a Struct block go top level).
  Others are off as house style: comment alignment, nested ternaries,
  several small classes per file, the `require 'x.rb'` paths, and $game
  and $fails. Scenarios keep `check 'x', a.any? { }` braces, since
  do/end would bind the block to `check` and always pass.
  `rubocop -a` plus hand fixes:
  - guard clauses, `.even?`, `&.`, `_unused` args, frozen constants,
    hand-wrapped long lines;
  - THEMES built as one frozen hash, with no mutation after the literal;
  - SteamPuff `size` -> `width`, since `size` shadowed Struct#size.
  Fixes outside the game:
  - tools/gen-levels.rb now writes `].freeze` (31b6602 froze LEVELS in
    the generated file only, so regenerating would have unfrozen it).
  - Dead locals removed from bot.rb and 01_core.
  - Caught one bad autocorrect: Style/RedundantParentheses turned sim.rb's
    `def clear = (@h.clear; @t&.each_value(&:clear))` into a def plus a
    stray class-body statement, so render targets stopped clearing and
    the ending's render-target check could pass on stale sprites. Now a
    plain method.
  Nine methods are still over the limits and carry `rubocop:todo` on the
  def line as candidates to split:
  - Ending#update and #draw;
  - load_level, update_player, draw_background and draw_tiles;
  - Physics#move_y, a hot path; and boss_vs_player.
  Not split here, since splitting is a refactor of its own.
  Checked: tests ALL PASS (185); boss trace (70,180 lines) and ending
  trace the same as HEAD; reach and bot the same; shots ALL SAME;
  regenerated levels.rb the same. Real-runtime bench vs HEAD (ms/frame,
  3 runs each): arena 7 0.406/0.461/0.396 vs 0.420/0.427/0.394, arena 5
  0.75 vs 0.74-0.75, level 1 0.755-0.785 vs 0.743-0.762, ending 5
  0.397-0.405 vs 0.396-0.415. Same within noise.
- 2026-11-19: step 6, Minitest (6.0.6, bundled with Ruby 3.4). `ruby
  tools/sim.rb` is still the one command and still ends with ALL PASS or
  N FAILED, and exits 1 on any failure. Each file in tools/scenarios is
  now one test (`test_01_core` ... `test_05_refresh`), run in file order
  (`run_order :alpha`). `ruby tools/sim.rb -n test_02_boss` runs one.
  The scenario files are unchanged. `check` still prints PASS/FAIL and
  counts as an assertion, but a failed check doesn't stop its scenario;
  the test fails at the end listing every failed check, as before. New:
  an exception in one scenario is a Minitest error instead of aborting
  the rest. Each scenario prints a `== name` header (that also keeps
  Minitest's progress dot off the next PASS line). `$scenario` is the
  running test, added to the RuboCop global allow-list. reach.rb, bot.rb
  and friends `require` sim.rb and don't start Minitest. Checked: 185
  PASS lines, 190 assertions (185 checks + 5 tests), the info lines
  unchanged; a deliberate double failure in 03_rush failed the test with
  both names and exit 1; reach and bot the same; rubocop 0 offenses.
- 2026-11-19: step 7, AGENTS.md. Two new parts under "Test loop":
  - "Headless tests and checks" covers `ruby tools/sim.rb` (and `-n`
    for one scenario), `rubocop`, `tools/shots.sh --compare` and
    `tools/bench.sh`. It also says where scenarios live, what reach.rb
    and bot.rb are for, that levels.rb is generated from segments.rb,
    and that RuboCop's CRuby idioms can be slow or missing on mruby.
  - "Code layout (app/)" lists one line per file.
