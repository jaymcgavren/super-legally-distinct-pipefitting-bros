# SUPER LEGALLY DISTINCT PIPEFITTING BROTHERS
# Looks like a 2600 cart, plays like a 16-bit platformer.
#
# Screen: 1280x720 (16:9). Playfield is 10 rows of 64px tiles (y 0..640),
# HUD on top. Art is 2600-resolution (8x4 real px per art pixel).
# Controls: d-pad move, A (space / x) jump, B (z) run + throw wrench,
# Start (enter) pause.

require 'app/levels.rb'
require 'app/screen.rb'
require 'app/sound.rb'
require 'app/controls.rb'
require 'app/level.rb'
require 'app/physics.rb'
require 'app/camera.rb'
require 'app/run.rb'

TILE        = 64
ROWS        = 10
VIEW_WIDTH  = 1280
PLAY_HEIGHT = 640

WALK_MAX          = 4.2
RUN_MAX           = 6.8
PLAYER_HEIGHT     = 72
# Two jump heights: the full one only at (almost) top running speed, a lower
# one at any other speed, standing and walking included
JUMP_VELOCITY     = 19.0                # ~4.2 tiles held
JUMP_VELOCITY_RUN = 21.4                # ~5.4 tiles held
RUN_JUMP_SPEED    = RUN_MAX * 0.9
SHIFT_LENGTH      = 300
TICK_LENGTH       = 24                  # frames per SHIFT unit

# Colors used in more than one place (palette tables keep their own)
WHITE          = [255, 255, 255].freeze   # PRESS START, scores, popups
BLACK          = [0, 0, 0].freeze         # dimming overlays, backgrounds
PALE_YELLOW    = [252, 240, 160].freeze   # headline labels
ORANGE         = [244, 120, 24].freeze    # subtitles
GOLD           = [236, 212, 64].freeze    # BROTHERS, HUD text
ALERT_RED      = [232, 72, 64].freeze     # GAME OVER, BOSS RUSH, low time
WARNING_RED    = [232, 40, 40].freeze     # Big Rusty's WARNING card, bolt markers
WARNING_YELLOW = [252, 220, 40].freeze    # bolt markers, flashing
STEAM          = [236, 236, 236].freeze   # steam and dust
LIGHT_GRAY     = [200, 200, 200].freeze   # TOP score, skid dust
DARK_GRAY      = [60, 60, 60].freeze      # HUD rule, unselected slots
NEAR_BLACK     = [16, 16, 16].freeze      # HUD panel
TWINKLE        = [255, 255, 220].freeze   # the valve's twinkle in the ending

# Sprite-sheet frames: [source_x, source_y, source_w, source_h]. Every sheet
# is a horizontal strip of equal frames (see tools/make-assets.mjs), so an
# animation is its first frame here plus an index: `frame(:nut, 2)`.
FRAMES = {
  # tiles_<theme>.png
  brick: [0, 0, 8, 16], brick_top: [8, 0, 8, 16], girder: [16, 0, 8, 16],
  crate: [24, 0, 8, 16], crate_used: [32, 0, 8, 16], pipe: [40, 0, 8, 16],
  pipe_flange: [48, 0, 8, 16], pipe_stand: [56, 0, 8, 16], vent: [64, 0, 8, 16],
  standpipe: [72, 0, 8, 16], lift: [80, 0, 8, 16], back_wall: [88, 0, 8, 16],
  wood_floor: [96, 0, 8, 16], subfloor: [104, 0, 8, 16],
  # items.png
  nut: [0, 0, 8, 16],             # 4 frames: a spinning nut
  wrench_item: [32, 0, 8, 16], lunchbox: [40, 0, 8, 16],
  cone_off: [48, 0, 8, 16], cone_lit: [56, 0, 8, 16],
  valve: [64, 0, 8, 16],          # 3 frames: the handwheel turning
  # enemies.png
  blob: [0, 0, 8, 12],            # 2 walk frames
  blob_flat: [16, 0, 8, 12],
  crab: [24, 0, 8, 12],           # 2 walk frames
  crab_spin: [40, 0, 8, 12],      # 2 frames
  # dez.png / ozzie.png
  bro_stand: [0, 0, 8, 20],
  bro_run: [8, 0, 8, 20],         # 3 frames
  bro_jump: [32, 0, 8, 20], bro_skid: [40, 0, 8, 20], bro_die: [48, 0, 8, 20],
  bro_throw: [56, 0, 8, 20],
  # wrench.png
  wrench_spin: [0, 0, 8, 16],     # 7 frames
  wrench_back: [56, 0, 8, 16],    # slung on the player's back
  # rusty.png
  rusty_walk: [0, 0, 8, 28],      # 2 frames
  rusty_crouch: [16, 0, 8, 28], rusty_air: [24, 0, 8, 28], rusty_hurt: [32, 0, 8, 28],
  rusty_mouth: [40, 0, 8, 28], rusty_angry: [48, 0, 8, 28], rusty_crown: [56, 0, 8, 28],
  # shots.png
  glob: [0, 0, 8, 16], bolt: [8, 0, 8, 16],
}.freeze
FRAMES.each_value(&:freeze)

# FRAMES[name], or frame `index` of the animation starting there
def frame(name, index = 0)
  base = FRAMES[name]
  return base if index == 0
  [base[0] + index * base[2], base[1], base[2], base[3]]
end

SOLID = { '#' => true, 'F' => true, '=' => true, 'C' => true, 'W' => true, 'M' => true, 'U' => true, 'S' => true }.freeze
COMBO = [100, 200, 400, 800, 1000, 2000, 4000, 8000].freeze

THEMES = {
  day:   { sky: [[84, 138, 236]], cloud: [236, 236, 236], bush: [56, 156, 40], bush_dk: [24, 104, 24],
           tiles: 'sprites/tiles_day.png' },
  dusk:  { sky: [[72, 0, 120], [120, 16, 136], [160, 40, 120], [200, 72, 88], [228, 112, 56], [240, 160, 72]],
           cloud: [248, 184, 168], bush: [48, 100, 80], bush_dk: [28, 64, 52], tiles: 'sprites/tiles_dusk.png' },
  night: { sky: [[8, 12, 48]], cloud: [52, 60, 108], bush: [28, 84, 48], bush_dk: [12, 52, 28],
           tiles: 'sprites/tiles_night.png', stars: true },
  indoor: { sky: [[84, 138, 236]], cloud: [236, 236, 236], bush: [56, 156, 40], bush_dk: [24, 104, 24],
            tiles: 'sprites/tiles_indoor.png', indoor: true },
}
THEMES[:dusk][:sun] = true
# inside a building, with the windows showing a sunset or the night sky
THEMES[:indoor_dusk] = THEMES[:dusk].merge(tiles: 'sprites/tiles_indoor.png', indoor: true)
THEMES[:indoor_night] = THEMES[:night].merge(tiles: 'sprites/tiles_indoor.png', indoor: true)
THEMES.freeze
BROS = [
  { name: 'DEZ',   path: 'sprites/dez.png' },
  { name: 'OZZIE', path: 'sprites/ozzie.png' },
].freeze
BUMP_ARC = [0, 8, 13, 16, 14, 10, 6, 2].freeze

class Actor
  attr_accessor :kind, :x, :y, :w, :h, :vx, :vy, :on_ground, :state, :t, :facing,
                :active, :data, :prev_y, :riding
  def initialize(kind, x, y, w, h)
    @kind = kind
    @x = x.to_f
    @y = y.to_f
    @w = w
    @h = h
    @vx = 0.0
    @vy = 0.0
    @on_ground = false
    @state = :walk
    @t = 0
    @facing = -1
    @active = false
    @data = {}
    @prev_y = @y
    @riding = nil
  end

  def dead? = @state == :dead
  def walking? = @state == :walk
  def gone? = @state == :gone
end

class Player < Actor
  attr_accessor :powered, :invuln, :coyote, :buffer, :jumping, :combo, :anim, :skid, :throw_t
  def initialize(x, y)
    super(:player, x, y, 40, PLAYER_HEIGHT)
    @facing = 1
    @powered = false
    @invuln = 0
    @coyote = 0
    @buffer = 0
    @jumping = false
    @combo = 0
    @anim = 0.0
    @skid = false
    @throw_t = 0
  end

  def invulnerable? = @invuln > 0
end

def pad6(n)
  digits = n.to_i.to_s
  digits.size >= 6 ? digits : ('0' * (6 - digits.size)) + digits
end

def pad3(n)
  digits = [n.to_i, 0].max.to_s
  digits.size >= 3 ? digits : ('0' * (3 - digits.size)) + digits
end

# entities: their class bodies use the constants above
require 'app/lift.rb'
require 'app/items.rb'

class Game
  include Physics

  def playing? = @mode == :play

  def initialize(args)
    @args = args
    @screen = Screen.new(args.outputs)
    @sound = Sound.new(args)
    @controls = Controls.new(args)
    @high_score = HighScore.new(args.gtk)
    @run = Run.new
    @bro = 0
    @frame = 0
    @level_index = 0
    to_title
  end

  # ── secret code ───────────────────────────────────────────────────
  # Up Up Down Down Left Right Left Right on the title screen locks in
  # Boss Rush; the next game started is a Boss Rush run.
  RUSH_CODE = %i[up up down down left right left right].freeze

  # nut chime climbing a major scale, one step per correct code press
  CODE_STEPS = [0, 2, 4, 5, 7, 9, 11, 12].freeze
  def code_note(i)
    @sound.chime(CODE_STEPS[i])
  end

  # advance the secret-code matcher; true once the whole code is in
  def feed_code
    press = @controls.code_press
    return false unless press
    if press == RUSH_CODE[@code_index]
      @code_index += 1
    else
      @code_index = press == :up ? (@code_index == 2 ? 2 : 1) : 0
    end
    code_note(@code_index - 1) if @code_index > 0
    return false unless @code_index == RUSH_CODE.size
    @code_index = 0
    true
  end

  # ── modes ─────────────────────────────────────────────────────────
  def to_title
    @mode = :title
    @mode_frames = 0
    @run.rush = false
    @rush_armed = false
    @code_index = 0
    load_level(0, false)
    @sound.stop_music
  end

  def new_game(rush = false)
    @run = Run.new(rush)
    @level_index = 0
    to_intro
  end

  def to_intro
    @mode = :intro
    @mode_frames = 0
    @sound.stop_music
    load_level(@level_index, true)
  end

  # The game runs in fixed 60 Hz steps whatever the display's refresh rate.
  STEP_MS = 1000.0 / 60
  MAX_STEPS = 4      # catch-up limit per frame, so a long stall can't spiral

  # One host frame: run as many 60 Hz updates as the elapsed time calls for
  # (none on some frames of a 120 Hz display, two after a slow frame), then
  # draw once. update changes state and plays sounds but draws nothing; draw
  # only draws, so it is safe to skip or repeat.
  def tick
    @screen.outputs = @args.outputs
    @sound.new_frame
    @controls.poll
    @step_accumulator = (@step_accumulator || 0.0) + frame_ms
    n = 0
    while @step_accumulator >= STEP_MS && n < MAX_STEPS
      update
      @step_accumulator -= STEP_MS
      n += 1
    end
    @step_accumulator = 0.0 if @step_accumulator >= STEP_MS   # too far behind: drop the backlog
    draw
    @args.gtk.debug_score = @run.score
    @args.gtk.debug_aux = @player ? @player.x.to_i : 0
  end

  # Milliseconds since the last frame, from the host. A frame within 1 ms of
  # 60 Hz counts as exactly one step, so vsync jitter on a 60 Hz display
  # doesn't turn into the odd skipped or doubled update. A runtime without
  # args.gtk.delta_ms (stock wasmcart-mruby) gets one step per frame.
  def frame_ms
    gtk = @args.gtk
    return STEP_MS unless gtk.respond_to?(:delta_ms)
    ms = gtk.delta_ms.to_f
    return STEP_MS if (ms - STEP_MS).abs < 1.0
    [[ms, 0.0].max, 250.0].min
  end

  def update
    # @frame is the world clock (lifts, vents, blinking lights), so it stops
    # during the coffee break
    @frame += 1 unless @mode == :paused
    @mode_frames += 1
    @controls.read
    case @mode
    when :title    then step_title
    when :intro    then step_intro
    when :play     then step_play
    when :paused   then step_paused
    when :dying    then step_dying
    when :clear    then step_clear
    when :gameover, :win then step_end
    when :ending   then step_ending
    end
  end

  def draw
    case @mode
    when :title    then draw_title
    when :intro    then draw_intro
    when :play     then draw_play
    when :paused   then draw_paused
    when :dying    then draw_world(true)
    when :clear    then draw_clear
    when :gameover then draw_end(:gameover)
    when :win      then draw_end(:win)
    when :ending   then draw_ending
    end
  end

  # ── level loading ─────────────────────────────────────────────────
  def load_level(index, use_checkpoint)
    @level = Level.new(index)
    @enemies = []
    @lifts = []
    @vents = []
    @cones = []
    @items = []
    @particles = []
    @popups = []
    @bumps = {}
    @hits_left = {}
    @wrench = nil
    @goal = nil
    @boss = nil
    @boss_on = false
    @shots = []
    @camera = Camera.new(@level)
    @banner = 0
    @rng = 1 + index * 31
    boss_at = nil
    start = [2, 7]
    @level.each_marker do |tile, c, r|
      case tile
      when 'P'
        start = [c, r]
      when 'r'
        @enemies << Actor.new(:blob, c * TILE + 8, @level.tile_bottom(r), 48, 40)
      when 'v'
        enemy = Actor.new(:crab, c * TILE + 6, @level.tile_bottom(r), 52, 44)
        enemy.data[:cycle] = (c * 29) % 200
        @enemies << enemy
      when 'L', 'H'
        @lifts << Lift.new(@level, c, r, tile == 'H' ? :x : :y)
      when 'S' then @vents << { c: c, r: r, phase: (c * 37) % 180, h: 0 }
      when 'K'
        @cones << { c: c, r: r, lit: false }
      when 'G'
        @goal = { c: c, r: r, turn: 0 }
      when 'B'
        boss_at = [c, r]
      end
    end
    spawn_boss(boss_at[0], boss_at[1]) if boss_at
    @vents.each do |vent|
      h = 0
      h += 1 while h < 3 && !SOLID[@level.cell(vent[:c], vent[:r] - h - 1)]
      vent[:h] = h * TILE
    end
    if use_checkpoint && @run.checkpoint && @run.checkpoint[0] == index
      cone = @cones[@run.checkpoint[1]]
      start = [cone[:c], cone[:r]]
      cone[:lit] = true
    end
    if @run.rush? && @boss
      start = [@arena_column + 1, 7]
      @enemies.reject! { |enemy| enemy.x < (@arena_column + 1) * TILE }
    end
    @player = Player.new(start[0] * TILE + 12, @level.tile_bottom(start[1]))
    @player.powered = @run.powered if use_checkpoint
    @player.powered = true if @run.rush?
    @run.start_shift(@level.data[:time] || SHIFT_LENGTH)
    @camera.jump_to(@player.x - 480)
  end

  # ── title ─────────────────────────────────────────────────────────
  def step_title
    @camera.x = (@mode_frames * 1.5) % @camera.max_x
    if @controls.left_pressed? || @controls.right_pressed?
      @bro = 1 - @bro
      @sound.play(:tick)
    end
    if !@rush_armed && feed_code
      @rush_armed = true
      @sound.play(:oneup)
    end
    if @controls.start_pressed? || @controls.jump_pressed?
      @sound.play(:checkpoint)
      new_game(@rush_armed)
    end
  end

  def draw_title
    draw_world(false)
    @screen.rect(0, 0, VIEW_WIDTH, 720, BLACK, 120)
    @screen.shadow_label(640, 640, 'SUPER LEGALLY DISTINCT', 5, PALE_YELLOW)
    @screen.shadow_label(640, 580, 'PIPEFITTING', 12, ORANGE)
    @screen.shadow_label(640, 470, 'BROTHERS', 12, GOLD)
    2.times do |i|
      x = 480 + i * 320
      selected = i == @bro
      @screen.rect(x - 56, 196, 112, 120, selected ? PALE_YELLOW : DARK_GRAY)
      @screen.rect(x - 48, 204, 96, 104, [20, 20, 40])
      source = selected ? frame(:bro_run, (@mode_frames / 8) % 3) : FRAMES[:bro_stand]
      @screen.sprite(BROS[i][:path], x - 32, 216, 64, 80, source, flip: i == 1)
      @screen.shadow_label(x, 180, BROS[i][:name], 4, selected ? PALE_YELLOW : [140, 140, 140])
    end
    @screen.shadow_label(640, 120, 'PRESS START', 4, WHITE) if (@mode_frames / 30) % 2 == 0
    @screen.shadow_label(640, 366, 'BOSS RUSH', 4, ALERT_RED) if @rush_armed
    @screen.shadow_label(640, 70, "TOP #{pad6(@high_score.value)}", 3, LIGHT_GRAY)
    @screen.shadow_label(640, 30, 'ANY RESEMBLANCE TO PLUMBERS LIVING OR DEAD IS PURELY COINCIDENTAL', 2, [180, 180, 180])
  end

  # ── intro card ────────────────────────────────────────────────────
  def step_intro
    return unless @mode_frames > 150
    @mode = :play
    @mode_frames = 0
    @sound.music(:theme)
  end

  def draw_intro
    @args.outputs.background_color = BLACK
    draw_hud
    @screen.label(640, 440, @level.name, 6, PALE_YELLOW)
    @screen.label(640, 370, @level.title, 4, ORANGE)
    @screen.label(640, 560, "BOSS RUSH #{@level_index + 1} OF #{LEVELS.size}", 4, ALERT_RED) if @run.rush?
    @screen.sprite(BROS[@bro][:path], 560, 210, 64, 80, FRAMES[:bro_stand])
    @screen.label(680, 270, "x #{@run.lives}", 5, WHITE)
  end

  # ── gameplay ──────────────────────────────────────────────────────
  def step_play
    if @controls.start_pressed?
      @mode = :paused
      @sound.play(:pause)
      @sound.pause_music
      vent_sounds
      return
    end
    update_timer
    @lifts.each { |lift| lift.update(@frame) }
    update_player
    update_enemies if playing?
    update_boss if @boss && playing?
    update_wrench
    update_items
    update_effects
    @camera.follow(@player, @boss_on)
    vent_sounds(shake_x)
  end

  def shake_x = @camera.shake_x(@frame)

  def draw_play
    @camera.offset_by(shake_x) { draw_world(true) }
  end

  def step_paused
    return unless @controls.start_pressed?
    @mode = :play
    @sound.play(:pause)
    @sound.resume_music
  end

  def draw_paused
    draw_world(true)
    @screen.rect(0, 0, VIEW_WIDTH, PLAY_HEIGHT, BLACK, 140)
    @screen.label(640, 380, 'COFFEE BREAK', 7, PALE_YELLOW)
    @screen.label(640, 300, 'PRESS START', 3, WHITE)
  end

  def update_timer
    return if @boss && @boss.dead?   # the clock stops once the boss falls
    return unless @run.tick_clock
    if @run.low_time_warning?
      @sound.play(:warn)
      @sound.music_pitch = 1.15
    end
    die if @run.time <= 0
  end

  def update_player
    player = @player
    if player.riding
      player.x += player.riding.dx
      player.y += player.riding.dy
    end
    player.prev_y = player.y
    dir = (@controls.right? ? 1 : 0) - (@controls.left? ? 1 : 0)
    run = @controls.run_held?
    max_speed = run ? RUN_MAX : WALK_MAX
    ground = player.on_ground
    player.skid = false
    if dir != 0
      if player.vx * dir < 0
        player.vx += dir * (ground ? 0.5 : 0.3)
        player.skid = ground && player.vx.abs > 1.5
        dust(player.x + player.w / 2, player.y) if player.skid && @frame % 4 == 0
      elsif player.vx.abs <= max_speed
        player.vx += dir * (ground ? (run ? 0.28 : 0.2) : 0.18)
        player.vx = max_speed * dir if player.vx.abs > max_speed
      elsif ground
        player.vx -= dir * 0.12
      end
      player.facing = dir
    else
      f = ground ? 0.25 : 0.04
      player.vx = player.vx.abs <= f ? 0.0 : player.vx - f * (player.vx > 0 ? 1 : -1)
    end

    player.buffer = @controls.jump_pressed? ? 7 : player.buffer - 1
    player.coyote = ground ? 6 : player.coyote - 1
    if player.buffer > 0 && player.coyote > 0
      player.vy = player.vx.abs >= RUN_JUMP_SPEED ? JUMP_VELOCITY_RUN : JUMP_VELOCITY
      player.buffer = 0
      player.coyote = 0
      player.jumping = true
      player.riding = nil
      @sound.play(:jump)
    end
    gravity = player.vy > 0 ? (player.jumping && @controls.jump_held? ? GRAVITY_HOLD : GRAVITY_CUT) : GRAVITY_FALL
    player.vy -= gravity
    player.vy = FALL_MAX if player.vy < FALL_MAX

    player.vx = 0.0 if move_x(player)
    heads = move_y(player, true, true)
    if player.on_ground
      player.jumping = false
      player.combo = 0
    end
    unless heads.empty?
      cx = player.x + player.w / 2
      best = heads[0]
      heads.each { |h| best = h if ((h[0] * TILE + TILE / 2) - cx).abs < ((best[0] * TILE + TILE / 2) - cx).abs }
      bump(best[0], best[1])
    end

    player.anim += player.vx.abs * 0.05 if player.vx.abs > 0.3 && player.on_ground
    player.invuln -= 1 if player.invuln > 0
    player.throw_t -= 1 if player.throw_t > 0

    # throw the wrench
    if @controls.throw_pressed? && player.powered && @wrench.nil?
      wrench = Actor.new(:wrench, player.x + (player.facing > 0 ? player.w : -40), player.y + 36, 40, 20)
      wrench.vx = player.facing * 16.0 + player.vx * 0.5
      wrench.facing = player.facing
      wrench.data[:back] = false
      @wrench = wrench
      player.throw_t = 12
      @sound.play(:throw)
    end

    collect_nuts(player)
    @vents.each do |vent|
      k = (@frame + vent[:phase]) % 180
      next unless k >= 130 && vent[:h] > 0
      hurt if rect_hit?(player, vent[:c] * TILE + 14, @level.tile_top(vent[:r]), 36, vent[:h] - 8)
    end
    @cones.each_with_index do |cone, i|
      next if cone[:lit] || player.x < cone[:c] * TILE
      cone[:lit] = true
      @run.checkpoint = [@level_index, i]
      @sound.play(:checkpoint)
      popup(cone[:c] * TILE, @level.tile_top(cone[:r]) + 20, 'CHECKPOINT')
    end
    if goal_touched?(player)
      player.x = @goal[:c] * TILE + 8 - player.w if player.x < @goal[:c] * TILE
      player.vx = 0.0
      start_clear
      return
    end
    die if player.y < -140
  end

  # Walking in from the left stops you at the valve. The boss valve can also
  # appear on top of you, or you can walk back into it from the right: that
  # counts only if you actually overlap it (it is 3 tiles tall).
  def goal_touched?(player)
    return false unless @goal
    goal_x = @goal[:c] * TILE
    return player.x + player.w > goal_x + 8 if player.x < goal_x
    player.x < goal_x + TILE - 8 && player.y < @level.tile_bottom(@goal[:r]) + 3 * TILE
  end

  def collect_nuts(actor)
    r0 = @level.row_at(actor.y + actor.h - 8)
    r1 = @level.row_at(actor.y + 8)
    c0 = @level.column_at(actor.x + 6)
    c1 = @level.column_at(actor.x + actor.w - 6)
    r0.upto(r1) do |r|
      next if r < 0 || r >= ROWS
      c0.upto(c1) do |c|
        next unless @level.cell(c, r) == 'o'
        @level.set_cell(c, r, '.')
        add_nut
        sparkle(c * TILE + 32, @level.tile_bottom(r) + 32)
      end
    end
  end

  def add_nut
    extra_life = @run.add_nut
    @sound.play(:nut, 0.75)
    one_up(@player.x, @player.y + 90) if extra_life
  end

  def one_up(x, y)
    @run.lives += 1
    @sound.play(:oneup)
    popup(x, y, '1UP')
  end

  def add_score(n, x, y)
    @run.add_score(n)
    popup(x, y, n.to_s)
  end

  def bump(c, r)
    tile = @level.cell(c, r)
    key = r * 10000 + c
    @bumps[key] = BUMP_ARC.size
    x = c * TILE
    top = @level.tile_top(r)
    case tile
    when 'C'
      @level.set_cell(c, r, 'U')
      pop_nut(x, top)
    when 'M'
      n = (@hits_left[key] ||= 8)
      pop_nut(x, top)
      @hits_left[key] = n - 1
      @level.set_cell(c, r, 'U') if n - 1 <= 0
    when 'W'
      @level.set_cell(c, r, 'U')
      @items << WrenchItem.new(x, top)
      @sound.play(:appear)
    when 'I'
      @level.set_cell(c, r, 'U')
      @items << Lunch.new(x, top)
      @sound.play(:appear)
    else
      @sound.play(:bump)
    end
    # knock out enemies standing on the bumped tile
    @enemies.each do |enemy|
      next unless enemy.active && enemy.walking?
      next unless (enemy.y - top).abs < 6 && enemy.x + enemy.w > x && enemy.x < x + TILE
      knock(enemy, x + 32 < enemy.x + enemy.w / 2 ? 1 : -1)
      add_score(200, enemy.x, enemy.y + 60)
    end
  end

  def pop_nut(x, top)
    @items << PopNut.new(x, top)
    add_nut
  end

  def hurt
    player = @player
    return if player.invulnerable? || !playing?
    if player.powered
      player.powered = false
      player.invuln = 120
      @sound.play(:hurt)
    else
      die
    end
  end

  def die
    return unless playing?
    @mode = :dying
    @mode_frames = 0
    @run.powered = false
    @player.vx = 0.0
    @player.vy = 0.0
    @sound.music(:death, looping: false)
  end

  def step_dying
    player = @player
    if @mode_frames > 30
      player.vy = 15.0 if @mode_frames == 31
      player.vy -= 0.8
      player.y += player.vy
    end
    update_effects
    vent_sounds
    return if @mode_frames < 190
    @run.lives -= 1
    if @run.lives <= 0
      @mode = :gameover
      @mode_frames = 0
      save_hiscore
      @sound.music(:gameover, looping: false)
    else
      to_intro
    end
  end

  def start_clear
    return start_ending if @level_index == LEVELS.size - 1
    @mode = :clear
    @mode_frames = 0
    @run.powered = @player.powered
    @sound.music(:clear, looping: false)
  end

  def step_clear
    player = @player
    player.vy -= GRAVITY_FALL
    player.vx = 0.0
    move_y(player, true, false)
    player.facing = 1
    @goal[:turn] += 1 if @mode_frames < 100
    if @mode_frames > 110 && @run.time > 0
      @run.bank_time(2)
      @sound.play(:tick) if @mode_frames % 4 == 0
    end
    update_effects
    update_wrench
    @camera.follow(@player, @boss_on)
    vent_sounds
    return unless @run.time <= 0 && @mode_frames > 300
    @level_index += 1
    @run.checkpoint = nil
    if @level_index >= LEVELS.size
      @mode = :win
      @mode_frames = 0
      save_hiscore
      @sound.music(:clear, looping: false)
    else
      to_intro
    end
  end

  def draw_clear
    draw_world(true)
    @screen.label(640, 470, 'MAIN SHUTOFF CLOSED!', 5, PALE_YELLOW, true)
    @screen.label(640, 420, 'TIME BONUS', 3, WHITE, true) if @mode_frames > 110
  end

  def step_end
    to_title if @mode_frames > 120 && (@controls.start_pressed? || @controls.jump_pressed?)
  end

  def draw_end(kind)
    @args.outputs.background_color = BLACK
    draw_hud
    if kind == :gameover
      @screen.label(640, 440, 'GAME OVER', 8, ALERT_RED)
      @screen.label(640, 350, 'YOU ARE FIRED', 4, WHITE)
    else
      @screen.label(640, 500, @run.rush? ? 'BOSS RUSH CLEARED!' : 'ALL MAINS SHUT OFF!', 6, PALE_YELLOW)
      @screen.label(640, 420, @run.rush? ? 'BIG RUSTY IS SCRAP' : 'OVERTIME APPROVED', 4, ORANGE)
      @screen.label(640, 340, "FINAL SCORE #{pad6(@run.score)}", 4, WHITE)
    end
    @screen.label(640, 260, "TOP #{pad6(@high_score.value)}", 3, LIGHT_GRAY)
    @screen.label(640, 160, 'PRESS START', 3, WHITE) if @mode_frames > 120 && (@mode_frames / 30) % 2 == 0
  end

  def save_hiscore
    @high_score.submit(@run.score)
  end

  # ── enemies ───────────────────────────────────────────────────────
  def knock(enemy, dir)
    enemy.state = :dead
    enemy.vy = 12.0
    enemy.vx = dir * 2.0
    @sound.play(:kick)
  end

  def update_enemies
    player = @player
    @enemies.each do |enemy|
      unless enemy.active
        next if enemy.x > @camera.x + VIEW_WIDTH + 48
        enemy.active = true
        enemy.vx = enemy.kind == :crab ? -1.2 : -1.0
      end
      enemy.t += 1
      if enemy.dead?
        enemy.vy -= 0.8
        enemy.x += enemy.vx
        enemy.y += enemy.vy
        next
      end
      next unless enemy.walking?
      next if enemy.x < @camera.x - 900 || enemy.x > @camera.x + VIEW_WIDTH + 600
      spiky = false
      speed = 1.0
      if enemy.kind == :crab
        k = (enemy.t + enemy.data[:cycle]) % 220
        spiky = k >= 150
        enemy.data[:spin] = spiky
        enemy.data[:warn] = k >= 120 && k < 150
        speed = spiky ? 2.6 : 1.2
      end
      enemy.vx = (enemy.vx < 0 ? -1 : 1) * speed
      fall(enemy)
      enemy.vx = -enemy.vx if move_x(enemy)
      move_y(enemy, false, false)
      if enemy.on_ground
        front_x = enemy.vx > 0 ? enemy.x + enemy.w + 2 : enemy.x - 2
        below = @level.cell(@level.column_at(front_x), @level.row_at(enemy.y - 4))
        enemy.vx = -enemy.vx unless SOLID[below] || below == '-'
      end
      enemy.state = :dead if enemy.y < -100
      @enemies.each do |other|
        next if other.equal?(enemy) || !other.active || !other.walking?
        enemy.vx = -enemy.vx if overlap?(enemy, other) && ((other.x - enemy.x) * enemy.vx) > 0
      end
      next unless playing? && overlap?(player, enemy)
      # full box for stomps, a smaller one for getting hurt (forgiving)
      if player.vy < 0 && player.prev_y >= enemy.y + enemy.h * 0.4 && !spiky
        stomp(enemy)
      elsif rect_hit?(player, enemy.x + 8, enemy.y, enemy.w - 16, enemy.h - 8)
        hurt
      end
    end
    @enemies.each do |enemy|
      next unless enemy.state == :flat
      enemy.data[:flat_t] = (enemy.data[:flat_t] || 0) + 1
      enemy.state = :gone if enemy.data[:flat_t] > 30
    end
    @enemies.reject! { |enemy| enemy.gone? || (enemy.dead? && enemy.y < -200) }
  end

  def stomp(enemy)
    player = @player
    if player.combo >= COMBO.size
      one_up(enemy.x, enemy.y + 60)
    else
      add_score(COMBO[player.combo] * (enemy.kind == :crab ? 2 : 1), enemy.x + 20, enemy.y + 60)
    end
    player.combo += 1
    player.vy = @controls.jump_held? ? 17.0 : 10.0
    player.jumping = @controls.jump_held?
    puff(enemy.x + enemy.w / 2, enemy.y + 10)
    @sound.play(:stomp)
    if enemy.kind == :blob
      enemy.state = :flat
    else
      knock(enemy, player.facing)
    end
  end

  # ── wrench boomerang ──────────────────────────────────────────────
  def update_wrench
    wrench = @wrench
    return unless wrench
    player = @player
    wrench.t += 1
    if (bounce = wrench.data[:bounce]) && bounce > 0
      # knocked back off the main valve: a short arc before it heads home
      wrench.data[:bounce] = bounce - 1
      wrench.vy -= 0.7
      wrench.x += wrench.vx
      wrench.y += wrench.vy
      return
    elsif !wrench.data[:back]
      wrench.vx -= wrench.facing * 0.5
      wrench.data[:back] = true if wrench.vx * wrench.facing <= 0
    else
      dx = (player.x + player.w / 2) - (wrench.x + wrench.w / 2)
      dy = (player.y + 40) - (wrench.y + wrench.h / 2)
      distance = Math.sqrt(dx * dx + dy * dy)
      distance = 1 if distance < 1
      speed = [wrench.vx.abs + wrench.vy.abs + 0.6, 13.0].min
      wrench.vx = dx / distance * speed
      wrench.vy = dy / distance * speed
      if distance < 40
        @wrench = nil
        return
      end
    end
    wrench.x += wrench.vx
    wrench.y += wrench.vy
    collect_nuts(wrench)
    @enemies.each do |enemy|
      next unless enemy.active && enemy.walking? && overlap?(wrench, enemy)
      knock(enemy, wrench.vx > 0 ? 1 : -1)
      add_score(200, enemy.x, enemy.y + 60)
    end
    if @boss && @boss_on && overlap?(wrench, @boss) && !wrench.data[:back]
      boss_hit(1)
      wrench.data[:back] = true
    end
    # a wrench that hits the main valve turns it: level clear. It bounces
    # off and flies back to the player while the level ends.
    if @goal && playing? &&
       rect_hit?(wrench, @goal[:c] * TILE, @level.tile_bottom(@goal[:r]), TILE, 3 * TILE)
      wrench.vx = wrench.vx > 0 ? -7.0 : 7.0
      wrench.vy = 7.0
      wrench.data[:back] = true
      wrench.data[:bounce] = 14
      wrench.t = 0
      @sound.play(:bump)
      popup(@goal[:c] * TILE, @level.tile_bottom(@goal[:r]) + 3 * TILE + 80, 'NICE SHOT')
      start_clear
      return
    end
    @wrench = nil if wrench.t > 150
  end

  # ── items ─────────────────────────────────────────────────────────
  def update_items
    player = @player
    @items.each do |item|
      next unless item.update(self)
      next unless overlap?(player, item)
      item.state = :gone
      if item.is_a?(Lunch)
        one_up(item.x, item.y + 70)
      else
        add_score(1000, item.x, item.y + 70)
        player.powered = true
        @sound.play(:powerup)
      end
    end
    @items.reject!(&:gone?)
  end

  # ── effects ───────────────────────────────────────────────────────
  def popup(x, y, text)
    @popups << [x, y, text, 0]
  end

  def puff(x, y)
    6.times do |i|
      angle = i * 1.047
      @particles << [x, y, Math.cos(angle) * 3, Math.sin(angle) * 3 + 1, 16, STEAM]
    end
  end

  def dust(x, y)
    @particles << [x, y + 4, -@player.facing * 1.5, 1.0, 12, LIGHT_GRAY]
  end

  def sparkle(x, y)
    4.times do |i|
      angle = i * 1.571 + 0.785
      @particles << [x, y, Math.cos(angle) * 4, Math.sin(angle) * 4, 10, PALE_YELLOW]
    end
  end

  def update_effects
    @particles.each do |particle|
      particle[0] += particle[2]
      particle[1] += particle[3]
      particle[3] -= 0.15
      particle[4] -= 1
    end
    @particles.reject! { |particle| particle[4] <= 0 }
    @popups.each do |popup|
      popup[1] += 1.5
      popup[3] += 1
    end
    @popups.reject! { |popup| popup[3] > 45 }
    @bumps.keys.each do |k|
      @bumps[k] -= 1
      @bumps.delete(k) if @bumps[k] <= 0
    end
  end


  # ── drawing ───────────────────────────────────────────────────────

  def draw_background
    theme = @level.theme
    outputs = @screen.outputs
    sky = theme[:sky]
    outputs.background_color = sky[0]
    # outdoors the sky runs to the bottom of the screen, so pits show sky;
    # indoors the bottom 128 px stay a black alley (see the end)
    floor = theme[:indoor] ? 128 : 0
    if sky.size > 1
      band = 72
      sky.each_with_index do |color, i|
        top = PLAY_HEIGHT - i * band
        bottom = i == sky.size - 1 ? floor : top - band
        outputs.solids << [0, bottom, VIEW_WIDTH, top - bottom, color[0], color[1], color[2]]
      end
    else
      outputs.solids << [0, floor, VIEW_WIDTH, PLAY_HEIGHT - floor, sky[0][0], sky[0][1], sky[0][2]]
    end
    if theme[:stars]
      40.times do |i|
        star_x = ((i * 211 + 57) - @camera.x * 0.05) % VIEW_WIDTH
        star_y = 300 + (i * 97) % 330
        brightness = (@frame / 20 + i) % 7 == 0 ? 120 : 230
        outputs.solids << [star_x.to_i, star_y, 8, 4, brightness, brightness, 255]
      end
      [[6, 0], [10, 1], [12, 2], [12, 3], [12, 4], [10, 5], [6, 6]].each do |w, dy|
        outputs.solids << [1040 - w * 4, 560 - dy * 8, w * 8, 8, 236, 232, 196]
      end
    end
    SUN_ROWS.each { |r| outputs.solids << r } if theme[:sun]
    cloud = theme[:cloud]
    [[100, 560], [620, 600], [1050, 520], [1500, 580]].each do |cx, cy|
      x = (((cx - @camera.x * 0.25) % 1800) - 260).to_i
      outputs.solids << [x + 32, cy, 64, 16, cloud[0], cloud[1], cloud[2]]
      outputs.solids << [x, cy - 16, 160, 16, cloud[0], cloud[1], cloud[2]]
      outputs.solids << [x - 16, cy - 32, 208, 16, cloud[0], cloud[1], cloud[2]]
    end
    bush = theme[:bush]
    bush_dark = theme[:bush_dk]
    # trees of varying heights, trunks rising from the bottom of the screen
    # (indoors, from the floor) into blocky canopies; indoors they show
    # through the windows (y 192..384)
    TREES.each do |tree_x, w, cy|
      x = (((tree_x - @camera.x * 0.5) % 1600) - 160).to_i
      trunk_width = w >= 120 ? 24 : 16
      outputs.solids << [x + w / 2 - trunk_width / 2, floor, trunk_width, cy + 8 - floor, 104, 68, 36]
      outputs.solids << [x + w / 2 - trunk_width / 2, floor, 8, cy + 8 - floor, 72, 44, 20]
      outputs.solids << [x, cy, w, 16, bush_dark[0], bush_dark[1], bush_dark[2]]
      outputs.solids << [x - 8, cy + 16, w + 16, 40, bush[0], bush[1], bush[2]]
      outputs.solids << [x, cy + 56, w, 24, bush[0], bush[1], bush[2]]
      outputs.solids << [x + 16, cy + 80, w - 32, 16, bush[0], bush[1], bush[2]]
      outputs.solids << [x + w / 4 + 8, cy + 96, w / 2 - 16, 16, bush[0], bush[1], bush[2]]
    end
    # indoors, the dark below the floor
    outputs.solids << [0, 0, VIEW_WIDTH, 128, 0, 0, 0] if theme[:indoor]
  end

  # The sunset sun, vaporwave style: a whole disc in 8 px rows, yellow at the
  # top through orange to magenta, with slits across the lower half that get
  # closer together toward the bottom. Built once as solids.
  SUN_GAPS = [3, 6, 9, 11, 13, 15, 17, 19].freeze   # 8 px rows below the centre left out
  SUN_RAMP = [[255, 236, 112], [255, 176, 72], [248, 88, 136], [216, 32, 168]].freeze
  SUN_ROWS = begin
    cx = 900
    cy = 340
    r = 168
    rows = []
    (2 * r / 8).times do |n|
      y = cy - r + n * 8
      dy = y + 4 - cy
      next if dy < 0 && SUN_GAPS.include?(-dy / 8)
      hw = (Math.sqrt([r * r - dy * dy, 0].max) / 8).floor * 8
      next if hw <= 0
      shade = ((1 - (dy + r) / (2.0 * r)) * 8).floor / 7.0
      sc = shade * (SUN_RAMP.size - 1)
      i = [sc.floor, SUN_RAMP.size - 2].min
      from = SUN_RAMP[i]
      to = SUN_RAMP[i + 1]
      k = sc - i
      col = (0..2).map { |j| (from[j] + (to[j] - from[j]) * k).round }
      rows << [cx - hw, y, hw * 2, 8, col[0], col[1], col[2]]
    end
    rows
  end.freeze

  # Indoors: a brick back wall over the sky, with occasional windows (holes
  # in the wall) that show the parallax sky, clouds and trees outside.
  WINDOW_ROWS = (4..6)
  # [x, canopy width, canopy bottom y] for the background trees
  TREES = [[16, 96, 232], [240, 144, 296], [512, 80, 208], [784, 128, 272], [1056, 112, 312], [1300, 96, 248]].freeze
  def window_at?(c)
    phase = c % 13
    return false unless phase == 6 || phase == 7
    left = c - (phase - 6)
    WINDOW_ROWS.all? { |r| !SOLID[@level.cell(left, r)] && !SOLID[@level.cell(left + 1, r)] }
  end

  def draw_back_wall(camera_x, tiles, c0, c1)
    c0.upto(c1 + 1) do |c|
      window = window_at?(c)
      x = c * TILE - camera_x
      8.times do |r|
        next if window && WINDOW_ROWS.include?(r)
        @screen.tile(tiles, x, @level.tile_bottom(r), FRAMES[:back_wall])
      end
    end
    wood = [140, 88, 44]
    sill = [196, 148, 92]
    c0.upto(c1 + 1) do |c|
      next unless c % 13 == 6 && window_at?(c)
      x = c * TILE - camera_x
      bottom = @level.tile_bottom(WINDOW_ROWS.last)
      top = @level.tile_top(WINDOW_ROWS.first)
      w = 2 * TILE
      @screen.rect(x, bottom, w, 8, sill)                 # sill
      @screen.rect(x - 8, bottom - 8, w + 16, 8, wood)
      @screen.rect(x, top - 8, w, 8, wood)             # head
      @screen.rect(x, bottom, 8, top - bottom, wood)         # jambs
      @screen.rect(x + w - 8, bottom, 8, top - bottom, wood)
      @screen.rect(x + TILE - 4, bottom, 8, top - bottom, wood) # mullion
      @screen.rect(x, (bottom + top) / 2 - 4, w, 8, wood) # transom bar
    end
  end

  def draw_tiles
    camera_x = @camera.x.to_i
    tiles = @level.theme[:tiles]
    c0 = [camera_x / TILE, 0].max
    c1 = [(camera_x + VIEW_WIDTH) / TILE, @level.columns - 1].min
    nut_f = (@frame / 8) % 4
    draw_back_wall(camera_x, tiles, c0, c1) if @level.theme[:indoor]
    ROWS.times do |r|
      row = @level.row(r)
      y = @level.tile_bottom(r)
      c0.upto(c1) do |c|
        tile = row[c]
        next if tile == '.' || tile == 'I'
        x = c * TILE - camera_x
        bump = @bumps[r * 10000 + c]
        bumped_y = bump ? y + BUMP_ARC[BUMP_ARC.size - bump] : y
        case tile
        when '#' then @screen.tile(tiles, x, bumped_y, FRAMES[r == 0 || SOLID[@level.cell(c, r - 1)] ? :brick : :brick_top])
        when 'F' then @screen.tile(tiles, x, bumped_y, FRAMES[@level.cell(c, r - 1) == 'F' ? :subfloor : :wood_floor])
        when '=' then @screen.tile(tiles, x, bumped_y, FRAMES[:girder])
        when 'C', 'W', 'M' then @screen.tile(tiles, x, bumped_y, FRAMES[:crate])
        when 'U' then @screen.tile(tiles, x, bumped_y, FRAMES[:crate_used])
        when '-'
          # extend a stand up behind the pipe so it meets the pipe's underside
          @screen.tile(tiles, x, y, FRAMES[:pipe_stand]) if @level.cell(c, r + 1) == '|'
          if @level.cell(c + 1, r) != '-'
            @screen.sprite(tiles, x, bumped_y, TILE, TILE, FRAMES[:pipe_flange], flip: true)
          elsif @level.cell(c - 1, r) != '-' || c % 4 == 0
            @screen.tile(tiles, x, bumped_y, FRAMES[:pipe_flange])
          else
            @screen.tile(tiles, x, bumped_y, FRAMES[:pipe])
          end
        when '|' then @screen.tile(tiles, x, bumped_y, FRAMES[:pipe_stand])
        when 'S' then @screen.tile(tiles, x, bumped_y, FRAMES[:vent])
        when 'o' then @screen.tile('sprites/items.png', x, bumped_y, frame(:nut, nut_f))
        end
      end
    end
  end

  # A vent on screen hisses as its plume shoots up. dx is the screen-shake
  # offset the world is drawn with this frame.
  def vent_sounds(dx = 0)
    camera_x = @camera.x.to_i + dx
    @vents.each do |vent|
      next unless (@frame + vent[:phase]) % 180 == 130 && vent[:h] > 0
      x = vent[:c] * TILE - camera_x
      @sound.play(:steam) unless x < -TILE || x > VIEW_WIDTH
    end
  end

  def draw_world(entities, hud = true)
    draw_background
    camera_x = @camera.x.to_i
    draw_tiles
    @lifts.each { |lift| lift.draw(@screen, camera_x, @level.theme[:tiles]) }
    @cones.each do |cone|
      lit = cone[:lit] && (@frame / 10) % 2 == 0
      @screen.tile('sprites/items.png', cone[:c] * TILE - camera_x, @level.tile_bottom(cone[:r]), FRAMES[lit ? :cone_lit : :cone_off])
    end
    if @goal
      goal_x = @goal[:c] * TILE - camera_x
      goal_y = @level.tile_bottom(@goal[:r])
      @screen.tile(@level.theme[:tiles], goal_x, goal_y, FRAMES[:standpipe])
      @screen.tile(@level.theme[:tiles], goal_x, goal_y + TILE, FRAMES[:standpipe])
      unless @goal[:gone]
        f = (@goal[:turn] / 5) % 3
        @screen.tile('sprites/items.png', goal_x, goal_y + 2 * TILE, frame(:valve, f))
        @screen.label(goal_x + 32, goal_y + 3 * TILE + 28, 'MAIN', 2, WHITE, true)
      end
    end
    @vents.each do |vent|
      k = (@frame + vent[:phase]) % 180
      next if k < 100 || vent[:h] <= 0
      x = vent[:c] * TILE - camera_x
      next if x < -TILE || x > VIEW_WIDTH
      base = @level.tile_top(vent[:r])
      if k < 130
        @screen.rect(x + 24, base + (k % 10) * 2, 16, 8, STEAM, 180) if (k / 5).even?
      else
        (vent[:h] / 16).times do |i|
          wob = ((i + @frame / 3) % 3 - 1) * 8
          w = 24 + (i * 3) % 16
          @screen.rect(x + 32 - w / 2 + wob, base + i * 16, w, 16, STEAM, 200 - i * 6)
        end
      end
    end
    return unless entities
    @items.each { |item| item.draw(@screen, camera_x, @frame) }
    @enemies.each do |enemy|
      x = enemy.x.to_i - camera_x
      next if x < -TILE || x > VIEW_WIDTH + TILE
      if enemy.kind == :blob
        source = enemy.state == :flat ? FRAMES[:blob_flat] : frame(:blob, (enemy.t / 10) % 2)
        @screen.sprite('sprites/enemies.png', x - 8, enemy.y.to_i, TILE, 48, source, flip: enemy.vx > 0, flip_v: enemy.dead?)
      else
        source = enemy.data[:spin] ? frame(:crab_spin, (enemy.t / 4) % 2) : frame(:crab, (enemy.t / 12) % 2)
        alpha = enemy.data[:warn] && (enemy.t / 3).even? ? 110 : 255
        @screen.sprite('sprites/enemies.png', x - 6, enemy.y.to_i, TILE, 48, source, alpha: alpha, flip_v: enemy.dead?)
      end
    end
    draw_boss(camera_x) if @boss
    draw_player
    draw_boss_hud if @boss
    if @wrench
      wrench = @wrench
      # 7 hand-drawn spin frames; mirroring reverses the spin for left throws
      f = (wrench.t / 2) % 7
      @screen.sprite('sprites/wrench.png', wrench.x.to_i - camera_x - 4, wrench.y.to_i - 14, 48, 48, frame(:wrench_spin, f), flip: wrench.facing < 0)
    end
    @particles.each do |particle|
      @screen.rect(particle[0].to_i - camera_x, particle[1].to_i, 8, 8, particle[5], [particle[4] * 20, 255].min)
    end
    @popups.each do |popup|
      @screen.label(popup[0].to_i - camera_x + 20, popup[1].to_i, popup[2], 3, WHITE, true)
    end
    draw_hud if hud
  end

  def draw_player
    player = @player
    return if player.invulnerable? && (player.invuln / 3) % 2 == 0 && playing?
    camera_x = @camera.x.to_i
    pose = if @mode == :dying then :bro_die
           elsif player.throw_t > 0 then :bro_throw
           elsif !player.on_ground then :bro_jump
           elsif player.skid then :bro_skid
           elsif player.vx.abs > 0.3 then :bro_run
           else :bro_stand
           end
    run_frame = pose == :bro_run ? [0, 1, 2, 1][player.anim.to_i % 4] : 0
    flip = pose == :bro_skid ? player.facing > 0 : player.facing < 0
    flip = false if pose == :bro_die
    x = player.x.to_i - camera_x - 12
    if player.powered && pose != :bro_die && @wrench.nil?
      wrench_x = player.facing > 0 ? x - 6 : x + 22
      @screen.sprite('sprites/wrench.png', wrench_x, player.y.to_i + 22, 40, 40, FRAMES[:wrench_back], flip: player.facing > 0)
    end
    @screen.sprite(BROS[@bro][:path], x, player.y.to_i, 64, 80, frame(pose, run_frame), flip: flip)
  end

  def draw_hud
    @screen.rect(0, PLAY_HEIGHT, VIEW_WIDTH, 720 - PLAY_HEIGHT, NEAR_BLACK)
    @screen.rect(0, PLAY_HEIGHT, VIEW_WIDTH, 4, DARK_GRAY)
    color = GOLD
    labels = @screen.outputs.labels
    labels << { x: 24, y: 700, text: "#{BROS[@bro][:name]} x#{@run.lives}", size_px: 4, r: color[0], g: color[1], b: color[2] }
    labels << { x: 230, y: 700, text: pad6(@run.score), size_px: 4, r: 255, g: 255, b: 255 }
    labels << { x: 470, y: 700, text: "NUTS x#{@run.nuts}", size_px: 4, r: color[0], g: color[1], b: color[2] }
    labels << { x: 720, y: 700, text: @level.name, size_px: 4, r: color[0], g: color[1], b: color[2] }
    shift_time = @run.time || SHIFT_LENGTH
    time_color = shift_time <= 100 && (@frame / 15) % 2 == 0 ? ALERT_RED : color
    labels << { x: 1256, y: 700, text: "SHIFT #{pad3(shift_time)}", size_px: 4, alignment_enum: 2, r: time_color[0], g: time_color[1], b: time_color[2] }
  end
end

require 'app/boss.rb'
require 'app/ending.rb'

def tick(args)
  $game ||= Game.new(args)
  $game.tick
end
