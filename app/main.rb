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
  glob: [0, 0, 8, 16], bolt: [8, 0, 8, 16]
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

OUTDOOR_THEMES = {
  day: { sky: [[84, 138, 236]], cloud: [236, 236, 236], bush: [56, 156, 40], bush_dark: [24, 104, 24],
         tiles: 'sprites/tiles_day.png' },
  dusk: { sky: [[72, 0, 120], [120, 16, 136], [160, 40, 120], [200, 72, 88], [228, 112, 56], [240, 160, 72]],
          cloud: [248, 184, 168], bush: [48, 100, 80], bush_dark: [28, 64, 52], tiles: 'sprites/tiles_dusk.png',
          sun: true },
  night: { sky: [[8, 12, 48]], cloud: [52, 60, 108], bush: [28, 84, 48], bush_dark: [12, 52, 28],
           tiles: 'sprites/tiles_night.png', stars: true }
}.freeze
INDOOR_TILES = { tiles: 'sprites/tiles_indoor.png', indoor: true }.freeze
# inside a building, the windows showing a day, sunset or night sky
THEMES = OUTDOOR_THEMES.merge(
  indoor: OUTDOOR_THEMES[:day].merge(INDOOR_TILES),
  indoor_dusk: OUTDOOR_THEMES[:dusk].merge(INDOOR_TILES),
  indoor_night: OUTDOOR_THEMES[:night].merge(INDOOR_TILES)
).freeze
BROS = [
  { name: 'DEZ',   path: 'sprites/dez.png' },
  { name: 'OZZIE', path: 'sprites/ozzie.png' }
].freeze
BUMP_ARC = [0, 8, 13, 16, 14, 10, 6, 2].freeze

class Actor
  attr_accessor :kind, :x, :y, :w, :h, :vx, :vy, :on_ground, :state, :timer, :facing,
                :active, :data, :previous_y, :riding

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
    @timer = 0
    @facing = -1
    @active = false
    @data = {}
    @previous_y = @y
    @riding = nil
  end

  def dead? = @state == :dead
  def walking? = @state == :walk
  def gone? = @state == :gone
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
require 'app/player.rb'
require 'app/lift.rb'
require 'app/items.rb'
require 'app/props.rb'
require 'app/enemies.rb'
require 'app/wrench.rb'
require 'app/effects.rb'
require 'app/scenes.rb'

class Game
  include Physics

  attr_reader :screen, :sound, :controls, :run, :high_score, :camera, :player,
              :level, :level_index, :goal, :scene, :enemies, :shots, :banner
  attr_accessor :bro   # 0 Dez, 1 Ozzie

  def mode = @scene.name
  # the world clock
  def clock = @frame
  def playing? = @scene.name == :play

  def switch_to(scene)
    @scene = scene
  end

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

  # ── modes ─────────────────────────────────────────────────────────
  def to_title
    switch_to(Title.new(self))
    @run.rush = false
    load_level(0, false)
    @sound.stop_music
  end

  def new_game(rush = false)
    @run = Run.new(rush)
    @level_index = 0
    to_intro
  end

  def to_intro
    switch_to(Intro.new(self))
    @sound.stop_music
    load_level(@level_index, true)
  end

  # The game runs in fixed 60 Hz steps whatever the display's refresh rate.
  STEP_MILLISECONDS = 1000.0 / 60
  MAX_STEPS = 4      # catch-up limit per frame, so a long stall can't spiral

  # One host frame: run as many 60 Hz updates as the elapsed time calls for
  # (none on some frames of a 120 Hz display, two after a slow frame), then
  # draw once. update changes state and plays sounds but draws nothing; draw
  # only draws, so it is safe to skip or repeat.
  def tick
    @screen.outputs = @args.outputs
    @sound.new_frame
    @controls.poll
    @step_accumulator = (@step_accumulator || 0.0) + frame_milliseconds
    n = 0
    while @step_accumulator >= STEP_MILLISECONDS && n < MAX_STEPS
      update
      @step_accumulator -= STEP_MILLISECONDS
      n += 1
    end
    @step_accumulator = 0.0 if @step_accumulator >= STEP_MILLISECONDS   # too far behind: drop the backlog
    draw
    @args.gtk.debug_score = @run.score
    @args.gtk.debug_aux = @player ? @player.x.to_i : 0
  end

  # Milliseconds since the last frame, from the host. A frame within 1 ms of
  # 60 Hz counts as exactly one step, so vsync jitter on a 60 Hz display
  # doesn't turn into the odd skipped or doubled update. A runtime without
  # args.gtk.delta_ms (stock wasmcart-mruby) gets one step per frame.
  def frame_milliseconds
    gtk = @args.gtk
    return STEP_MILLISECONDS unless gtk.respond_to?(:delta_ms)
    milliseconds = gtk.delta_ms.to_f
    return STEP_MILLISECONDS if (milliseconds - STEP_MILLISECONDS).abs < 1.0
    [[milliseconds, 0.0].max, 250.0].min
  end

  def update
    scene = @scene
    # @frame is the world clock (lifts, vents, blinking lights), so it stops
    # during the coffee break
    @frame += 1 unless scene.freezes_world?
    scene.frames += 1
    @controls.read
    scene.update
  end

  def draw
    @scene.draw
  end

  # ── level loading ─────────────────────────────────────────────────
  def load_level(index, use_checkpoint)
    @level = Level.new(index)
    clear_world
    start, boss_at = place_markers
    spawn_boss(boss_at[0], boss_at[1], 1 + index * 31) if boss_at
    start = player_start(index, start, use_checkpoint)
    @player = Player.new(start[0] * TILE + 12, @level.tile_bottom(start[1]))
    @player.powered = @run.powered if use_checkpoint
    @player.powered = true if @run.rush?
    @run.start_shift(@level.data[:time] || SHIFT_LENGTH)
    @camera.jump_to(@player.x - 480)
  end

  # everything that lives in a level, emptied for a fresh one
  def clear_world
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
  end

  # Spawns what the level's marker letters stand for. Returns the player
  # start and Big Rusty's spot (nil if none), as [column, row] pairs.
  def place_markers
    boss_at = nil
    start = [2, 7]
    @level.each_marker do |tile, c, r|
      case tile
      when 'P'
        start = [c, r]
      when 'r'
        @enemies << Blob.at(@level, c, r)
      when 'v'
        @enemies << Crab.at(@level, c, r)
      when 'L', 'H'
        @lifts << Lift.new(@level, c, r, tile == 'H' ? :x : :y)
      when 'S' then @vents << Vent.new(@level, c, r)
      when 'K'
        @cones << Cone.new(@level, c, r)
      when 'G'
        @goal = Goal.new(@level, c, r)
      when 'B'
        boss_at = [c, r]
      end
    end
    [start, boss_at]
  end

  # the level start, or the last lit cone, or the arena door in a boss rush
  def player_start(index, start, use_checkpoint)
    if use_checkpoint && @run.checkpoint && @run.checkpoint[0] == index
      cone = @cones[@run.checkpoint[1]]
      start = [cone.c, cone.r]
      cone.light
    end
    if @run.rush? && @boss
      start = [@arena_column + 1, 7]
      @enemies.reject! { |enemy| enemy.x < (@arena_column + 1) * TILE }
    end
    start
  end

  # ── gameplay ──────────────────────────────────────────────────────
  # one step of play (the Play scene)
  def update_world
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

  def update_timer
    return if @boss&.dead?   # the clock stops once the boss falls
    return unless @run.tick_clock
    if @run.low_time_warning?
      @sound.play(:warn)
      @sound.music_pitch = 1.15
    end
    die if @run.time <= 0
  end

  def update_player
    player = @player
    move_player(player)
    throw_wrench(player) if @controls.throw_pressed? && player.powered && @wrench.nil?
    collect_nuts(player)
    vent_burns(player)
    pass_cones(player)
    if goal_touched?(player)
      player.x = @goal.x + 8 - player.w if player.x < @goal.x
      player.vx = 0.0
      start_clear
      return
    end
    die if player.y < -140
  end

  # input, gravity and collision for one step
  def move_player(player)
    player.ride_lift
    direction = (@controls.right? ? 1 : 0) - (@controls.left? ? 1 : 0)
    skidding = player.apply_input(direction, @controls.run_held?)
    dust(player.x + player.w / 2, player.y) if skidding && @frame % 4 == 0
    @sound.play(:jump) if player.jump(@controls.jump_pressed?)
    player.apply_gravity(@controls.jump_held?)

    player.vx = 0.0 if move_x(player)
    heads = move_y(player, true, true)
    player.land if player.on_ground
    bump_nearest(heads, player) unless heads.empty?
    player.animate
  end

  def throw_wrench(player)
    @wrench = Wrench.new(player)
    player.throw_wrench
    @sound.play(:throw)
  end

  # a jetting steam vent hurts
  def vent_burns(player)
    @vents.each do |vent|
      next unless vent.jetting?(@frame)
      hurt if rect_hit?(player, vent.x + 14, vent.top, 36, vent.height - 8)
    end
  end

  # walking past a cone lights it and makes it the checkpoint
  def pass_cones(player)
    @cones.each_with_index do |cone, i|
      next if cone.lit? || player.x < cone.x
      cone.light
      @run.checkpoint = [@level_index, i]
      @sound.play(:checkpoint)
      popup(cone.x, cone.y + TILE + 20, 'CHECKPOINT')
    end
  end

  # A jump that hits more than one tile bumps the one nearest the
  # player's middle.
  def bump_nearest(heads, player)
    cx = player.x + player.w / 2
    best = heads[0]
    heads.each { |h| best = h if ((h[0] * TILE + TILE / 2) - cx).abs < ((best[0] * TILE + TILE / 2) - cx).abs }
    bump(best[0], best[1])
  end

  # Walking in from the left stops you at the valve. The boss valve can also
  # appear on top of you, or you can walk back into it from the right: that
  # counts only if you actually overlap it (it is 3 tiles tall).
  def goal_touched?(player)
    return false unless @goal
    goal_x = @goal.x
    return player.x + player.w > goal_x + 8 if player.x < goal_x
    player.x < goal_x + TILE - 8 && player.y < @goal.y + 3 * TILE
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
    key = r * 10_000 + c
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
      player.invulnerable = 120
      @sound.play(:hurt)
    else
      die
    end
  end

  def die
    return unless playing?
    switch_to(Dying.new(self))
    @run.powered = false
    @player.vx = 0.0
    @player.vy = 0.0
    @sound.music(:death, looping: false)
  end

  def start_clear
    return start_ending if @level_index == LEVELS.size - 1
    switch_to(Clear.new(self))
    @run.powered = @player.powered
    @sound.music(:clear, looping: false)
  end

  # after the valve's turned: the player just drops to the ground
  def settle_player(facing)
    player = @player
    player.vy -= GRAVITY_FALL
    player.vx = 0.0
    move_y(player, true, false)
    player.facing = facing
  end

  def follow_player
    @camera.follow(@player, @boss_on)
  end

  def next_level
    @level_index += 1
    @run.checkpoint = nil
    if @level_index >= LEVELS.size
      finish(:win)
    else
      to_intro
    end
  end

  # the last level's valve is turned: the whole time bonus at once
  def start_ending
    switch_to(Ending.new(self))
    @run.bank_time
    save_high_score
    @sound.stop_music
  end

  # game over, or every level done
  def finish(kind)
    switch_to(Final.new(self, kind))
    save_high_score
    @sound.music(kind == :gameover ? :gameover : :clear, looping: false)
  end

  def save_high_score
    @high_score.submit(@run.score)
  end

  # ── enemies ───────────────────────────────────────────────────────
  def knock(enemy, direction)
    enemy.knock(direction)
    @sound.play(:kick)
  end

  def update_enemies
    player = @player
    camera_x = @camera.x
    @enemies.each do |enemy|
      next unless enemy.update(self, @level, camera_x, @enemies)
      next unless playing? && overlap?(player, enemy)
      # full box for stomps, a smaller one for getting hurt (forgiving)
      if player.vy < 0 && player.previous_y >= enemy.y + enemy.h * 0.4 && !enemy.spiky?
        stomp(enemy)
      elsif rect_hit?(player, enemy.x + 8, enemy.y, enemy.w - 16, enemy.h - 8)
        hurt
      end
    end
    @enemies.reject! { |enemy| enemy.gone? || (enemy.dead? && enemy.y < -200) }
  end

  def stomp(enemy)
    player = @player
    if player.combo >= COMBO.size
      one_up(enemy.x, enemy.y + 60)
    else
      add_score(enemy.stomp_points(COMBO[player.combo]), enemy.x + 20, enemy.y + 60)
    end
    player.combo += 1
    player.vy = @controls.jump_held? ? 17.0 : 10.0
    player.jumping = @controls.jump_held?
    puff(enemy.x + enemy.w / 2, enemy.y + 10)
    @sound.play(:stomp)
    enemy.stomp(player.facing)
    @sound.play(:kick) if enemy.dead?
  end

  # ── wrench boomerang ──────────────────────────────────────────────
  def update_wrench
    wrench = @wrench
    return unless wrench
    flying = wrench.update(@player)
    return @wrench = nil if wrench.caught?
    return unless flying
    collect_nuts(wrench)
    @enemies.each do |enemy|
      next unless enemy.active && enemy.walking? && overlap?(wrench, enemy)
      knock(enemy, wrench.heading)
      add_score(200, enemy.x, enemy.y + 60)
    end
    if @boss && @boss_on && overlap?(wrench, @boss) && !wrench.back?
      boss_hit(1)
      wrench.turn_back
    end
    # a wrench that hits the main valve turns it: level clear. It bounces
    # off and flies back to the player while the level ends.
    if @goal && playing? &&
       rect_hit?(wrench, @goal.x, @goal.y, TILE, 3 * TILE)
      wrench.bounce_off
      @sound.play(:bump)
      popup(@goal.x, @goal.y + 3 * TILE + 80, 'NICE SHOT')
      start_clear
      return
    end
    @wrench = nil if wrench.expired?
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
    @popups << Popup.new(x, y, text, 0)
  end

  def puff(x, y)
    6.times do |i|
      angle = i * 1.047
      @particles << Particle.new(x, y, Math.cos(angle) * 3, Math.sin(angle) * 3 + 1, 16, STEAM)
    end
  end

  def dust(x, y)
    @particles << Particle.new(x, y + 4, -@player.facing * 1.5, 1.0, 12, LIGHT_GRAY)
  end

  def sparkle(x, y)
    4.times do |i|
      angle = i * 1.571 + 0.785
      @particles << Particle.new(x, y, Math.cos(angle) * 4, Math.sin(angle) * 4, 10, PALE_YELLOW)
    end
  end

  def update_effects
    @particles.each(&:update)
    @particles.reject!(&:gone?)
    @popups.each(&:update)
    @popups.reject!(&:gone?)
    @bumps.keys.each do |k|   # rubocop:disable Style/HashEachMethods -- deletes as it goes
      @bumps[k] -= 1
      @bumps.delete(k) if @bumps[k] <= 0
    end
  end

  # ── drawing ───────────────────────────────────────────────────────

  # Sky, stars and moon or sun, clouds and trees, back to front, in
  # parallax with the camera.
  def draw_background
    theme = @level.theme
    outputs = @screen.outputs
    # outdoors the sky runs to the bottom of the screen, so pits show sky;
    # indoors the bottom 128 px stay a black alley (see the end)
    floor = theme[:indoor] ? 128 : 0
    draw_sky(outputs, theme[:sky], floor)
    draw_stars_and_moon(outputs) if theme[:stars]
    SUN_ROWS.each { |r| outputs.solids << r } if theme[:sun]
    draw_clouds(outputs, theme[:cloud])
    draw_trees(outputs, theme[:bush], theme[:bush_dark], floor)
    # indoors, the dark below the floor
    outputs.solids << [0, 0, VIEW_WIDTH, 128, 0, 0, 0] if theme[:indoor]
  end

  # one colour, or bands of colour (a sunset) from the top down
  def draw_sky(outputs, sky, floor)
    outputs.background_color = sky[0]
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
  end

  # twinkling stars, drifting slowly, and a blocky moon
  def draw_stars_and_moon(outputs)
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

  def draw_clouds(outputs, cloud)
    [[100, 560], [620, 600], [1050, 520], [1500, 580]].each do |cx, cy|
      x = (((cx - @camera.x * 0.25) % 1800) - 260).to_i
      outputs.solids << [x + 32, cy, 64, 16, cloud[0], cloud[1], cloud[2]]
      outputs.solids << [x, cy - 16, 160, 16, cloud[0], cloud[1], cloud[2]]
      outputs.solids << [x - 16, cy - 32, 208, 16, cloud[0], cloud[1], cloud[2]]
    end
  end

  # trees of varying heights, trunks rising from the bottom of the screen
  # (indoors, from the floor) into blocky canopies; indoors they show
  # through the windows (y 192..384)
  def draw_trees(outputs, bush, bush_dark, floor)
    solids = outputs.solids
    r = bush[0]
    g = bush[1]
    b = bush[2]
    dark_r = bush_dark[0]
    dark_g = bush_dark[1]
    dark_b = bush_dark[2]
    TREES.each do |tree_x, w, cy|
      x = (((tree_x - @camera.x * 0.5) % 1600) - 160).to_i
      trunk_width = w >= 120 ? 24 : 16
      trunk_x = x + w / 2 - trunk_width / 2
      solids << [trunk_x, floor, trunk_width, cy + 8 - floor, 104, 68, 36]
      solids << [trunk_x, floor, 8, cy + 8 - floor, 72, 44, 20]
      solids << [x, cy, w, 16, dark_r, dark_g, dark_b]
      solids << [x - 8, cy + 16, w + 16, 40, r, g, b]
      solids << [x, cy + 56, w, 24, r, g, b]
      solids << [x + 16, cy + 80, w - 32, 16, r, g, b]
      solids << [x + w / 4 + 8, cy + 96, w / 2 - 16, 16, r, g, b]
    end
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
      half_width = (Math.sqrt([r * r - dy * dy, 0].max) / 8).floor * 8
      next if half_width <= 0
      shade = ((1 - (dy + r) / (2.0 * r)) * 8).floor / 7.0
      scaled_shade = shade * (SUN_RAMP.size - 1)
      i = [scaled_shade.floor, SUN_RAMP.size - 2].min
      from = SUN_RAMP[i]
      to = SUN_RAMP[i + 1]
      k = scaled_shade - i
      color = (0..2).map { |j| (from[j] + (to[j] - from[j]) * k).round }
      rows << [cx - half_width, y, half_width * 2, 8, color[0], color[1], color[2]]
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
        bump = @bumps[r * 10_000 + c]
        bumped_y = bump ? y + BUMP_ARC[BUMP_ARC.size - bump] : y
        case tile
        when '#' then @screen.tile(tiles, x, bumped_y, FRAMES[r == 0 || SOLID[@level.cell(c, r - 1)] ? :brick : :brick_top])
        when 'F' then @screen.tile(tiles, x, bumped_y, FRAMES[@level.cell(c, r - 1) == 'F' ? :subfloor : :wood_floor])
        when '=' then @screen.tile(tiles, x, bumped_y, FRAMES[:girder])
        when 'C', 'W', 'M' then @screen.tile(tiles, x, bumped_y, FRAMES[:crate])
        when 'U' then @screen.tile(tiles, x, bumped_y, FRAMES[:crate_used])
        when '-' then draw_pipe(tiles, c, r, x, y, bumped_y)
        when '|' then @screen.tile(tiles, x, bumped_y, FRAMES[:pipe_stand])
        when 'S' then @screen.tile(tiles, x, bumped_y, FRAMES[:vent])
        when 'o' then @screen.tile('sprites/items.png', x, bumped_y, frame(:nut, nut_f))
        end
      end
    end
  end

  # A one-way pipe tile: flanged at each end and every 4 tiles, with a stand
  # extended up behind it to meet its underside.
  def draw_pipe(tiles, c, r, x, y, bumped_y)
    @screen.tile(tiles, x, y, FRAMES[:pipe_stand]) if @level.cell(c, r + 1) == '|'
    if @level.cell(c + 1, r) != '-'
      @screen.sprite(tiles, x, bumped_y, TILE, TILE, FRAMES[:pipe_flange], flip: true)
    elsif @level.cell(c - 1, r) != '-' || c % 4 == 0
      @screen.tile(tiles, x, bumped_y, FRAMES[:pipe_flange])
    else
      @screen.tile(tiles, x, bumped_y, FRAMES[:pipe])
    end
  end

  # A vent on screen hisses as its plume shoots up. dx is the screen-shake
  # offset the world is drawn with this frame.
  def vent_sounds(dx = 0)
    camera_x = @camera.x.to_i + dx
    @vents.each do |vent|
      next unless vent.jet_starts?(@frame)
      x = vent.x - camera_x
      @sound.play(:steam) unless x < -TILE || x > VIEW_WIDTH
    end
  end

  def draw_world(entities, hud = true)
    draw_background
    camera_x = @camera.x.to_i
    draw_tiles
    @lifts.each { |lift| lift.draw(@screen, camera_x, @level.theme[:tiles]) }
    @cones.each { |cone| cone.draw(@screen, camera_x, @frame) }
    @goal&.draw(@screen, camera_x, @level.theme[:tiles])
    @vents.each { |vent| vent.draw(@screen, camera_x, @frame) }
    return unless entities
    @items.each { |item| item.draw(@screen, camera_x, @frame) }
    @enemies.each do |enemy|
      x = enemy.x.to_i - camera_x
      enemy.draw(@screen, x) unless x < -TILE || x > VIEW_WIDTH + TILE
    end
    draw_boss(camera_x) if @boss
    draw_player
    draw_boss_hud if @boss
    @wrench&.draw(@screen, camera_x)
    @particles.each { |particle| particle.draw(@screen, camera_x) }
    @popups.each { |popup| popup.draw(@screen, camera_x) }
    draw_hud if hud
  end

  def draw_player
    player = @player
    return if player.invulnerable? && (player.invulnerable / 3).even? && playing?
    camera_x = @camera.x.to_i
    pose = if mode == :dying then :bro_die
           elsif player.throw_timer > 0 then :bro_throw
           elsif !player.on_ground then :bro_jump
           elsif player.skid then :bro_skid
           elsif player.vx.abs > 0.3 then :bro_run
           else :bro_stand
           end
    run_frame = pose == :bro_run ? [0, 1, 2, 1][player.animation.to_i % 4] : 0
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
    time_color = shift_time <= 100 && (@frame / 15).even? ? ALERT_RED : color
    labels << { x: 1256, y: 700, text: "SHIFT #{pad3(shift_time)}", size_px: 4, alignment_enum: 2, r: time_color[0],
                g: time_color[1], b: time_color[2] }
  end
end

require 'app/boss.rb'
require 'app/ending.rb'

def tick(args)
  $game ||= Game.new(args)
  $game.tick
end
