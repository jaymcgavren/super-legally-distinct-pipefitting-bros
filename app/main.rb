# SUPER LEGALLY DISTINCT PIPEFITTING BROTHERS
# Looks like a 2600 cart, plays like a 16-bit platformer.
#
# Screen: 1280x720 (16:9). Playfield is 10 rows of 64px tiles (y 0..640),
# HUD on top. Art is 2600-resolution (8x4 real px per art pixel).
# Controls: d-pad move, A (space / x) jump, B (z) run + throw wrench,
# Start (enter) pause.

require 'app/levels.rb'

T       = 64
ROWS    = 10
VW      = 1280
PLAY_H  = 640

WALK_MAX  = 4.2
RUN_MAX   = 6.8
JUMP_V    = 19.5
GRAV_HOLD = 0.65
GRAV_CUT  = 1.6
GRAV_FALL = 1.0
FALL_MAX  = -15.0
SHIFT_LEN = 300
TICK_LEN  = 24      # frames per SHIFT unit

SOLID = { '#' => true, 'F' => true, '=' => true, 'C' => true, 'W' => true, 'M' => true, 'U' => true, 'S' => true }
COMBO = [100, 200, 400, 800, 1000, 2000, 4000, 8000]

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
BROS = [
  { name: 'DEZ',   path: 'sprites/dez.png' },
  { name: 'OZZIE', path: 'sprites/ozzie.png' },
]
BUMP_ARC = [0, 8, 13, 16, 14, 10, 6, 2]

class Actor
  attr_accessor :kind, :x, :y, :w, :h, :vx, :vy, :on_ground, :state, :t, :facing,
                :active, :data, :prev_y, :riding
  def initialize(kind, x, y, w, h)
    @kind = kind; @x = x.to_f; @y = y.to_f; @w = w; @h = h
    @vx = 0.0; @vy = 0.0; @on_ground = false; @state = :walk; @t = 0
    @facing = -1; @active = false; @data = {}; @prev_y = @y; @riding = nil
  end
end

class Player < Actor
  attr_accessor :powered, :invuln, :coyote, :buffer, :jumping, :combo, :anim, :skid, :throw_t
  def initialize(x, y)
    super(:player, x, y, 40, 72)
    @facing = 1; @powered = false; @invuln = 0; @coyote = 0; @buffer = 0
    @jumping = false; @combo = 0; @anim = 0.0; @skid = false; @throw_t = 0
  end
end

def pad6(n)
  s = n.to_i.to_s
  s.size >= 6 ? s : ('0' * (6 - s.size)) + s
end

def pad3(n)
  s = [n.to_i, 0].max.to_s
  s.size >= 3 ? s : ('0' * (3 - s.size)) + s
end

class Game
  def initialize(args)
    @args = args
    @hiscore = args.gtk.load_u32(0) || 0
    @bro = 0
    @frame = 0
    @score = 0; @nuts = 0; @lives = 3; @level = 0
    to_title
  end

  # ── input / audio helpers ─────────────────────────────────────────
  def read_input
    kb = @args.inputs.keyboard
    ax = kb.left_analog_x_perc || 0
    @in_left  = kb.left || ax < -0.5
    @in_right = kb.right || ax > 0.5
    @in_a     = kb.a
    @in_b     = kb.b || kb.x
    d = kb.key_down
    @in_a_down = d.a
    @in_b_down = d.b || d.x
    @in_start_down = d.start
    @in_left_down = d.left
    @in_right_down = d.right
    @in_code = if d.up then :up
               elsif d.down then :down
               elsif d.left then :left
               elsif d.right then :right
               end
  end

  # Up Up Down Down Left Right Left Right on the title screen locks in
  # Boss Rush; the next game started is a Boss Rush run.
  RUSH_CODE = %i[up up down down left right left right]
  RUSH_LEVELS = [3, 7, 11, 15, 19, 23, 27, 31]

  # nut chime climbing a major scale, one step per correct code press
  CODE_STEPS = [0, 2, 4, 5, 7, 9, 11, 12]
  def code_note(i)
    @args.audio[:code] = { input: 'sounds/nut.wav', gain: 1.0, pitch: 2.0**(CODE_STEPS[i] / 12.0) }
  end

  # advance the secret-code matcher; true once the whole code is in
  def feed_code
    return false unless @in_code
    if @in_code == RUSH_CODE[@code_i]
      @code_i += 1
    else
      @code_i = @in_code == :up ? (@code_i == 2 ? 2 : 1) : 0
    end
    code_note(@code_i - 1) if @code_i > 0
    return false unless @code_i == RUSH_CODE.size
    @code_i = 0
    true
  end

  def sfx(name)
    return if @played[name]
    @played[name] = true
    @args.outputs.sounds << "sounds/#{name}.wav"
  end

  def music(name, looping = true)
    @args.audio.delete(:music)
    @args.audio[:music] = { input: "sounds/#{name}.wav", gain: 0.5, looping: looping }
  end

  def music_stop
    @args.audio.delete(:music)
  end

  # ── modes ─────────────────────────────────────────────────────────
  def to_title
    @mode = :title
    @mode_t = 0
    @rush = false
    @rush_armed = false
    @code_i = 0
    load_level(0, false)
    music_stop
  end

  def new_game(rush = false)
    @rush = rush
    @score = 0; @nuts = 0; @lives = rush ? 5 : 3
    @level = rush ? RUSH_LEVELS[0] : 0
    @checkpoint = nil
    @powered = rush
    to_intro
  end

  def to_intro
    @mode = :intro
    @mode_t = 0
    music_stop
    load_level(@level, true)
  end

  def tick
    @o = @args.outputs
    @frame += 1
    @mode_t += 1
    @played = {}
    read_input
    case @mode
    when :title    then tick_title
    when :intro    then tick_intro
    when :play     then tick_play
    when :paused   then tick_paused
    when :dying    then tick_dying
    when :clear    then tick_clear
    when :gameover then tick_end(:gameover)
    when :win      then tick_end(:win)
    when :ending   then tick_ending
    end
    @args.gtk.debug_score = @score
    @args.gtk.debug_aux = @p ? @p.x.to_i : 0
  end

  # ── level loading ─────────────────────────────────────────────────
  def load_level(idx, use_checkpoint)
    lv = LEVELS[idx]
    @lv = lv
    @theme = THEMES[lv[:theme]]
    if lv[:rows]
      rows = lv[:rows]
    else
      rows = Array.new(ROWS) { '' }
      lv[:segs].each { |s| s.each_with_index { |row, r| rows[r] += row } }
    end
    @cols = rows[0].size
    @grid = rows.map { |row| a = []; row.size.times { |i| a << row[i] }; a }
    @enemies = []; @lifts = []; @vents = []; @cones = []; @items = []
    @particles = []; @popups = []; @bumps = {}; @multi = {}
    @wrench = nil; @goal = nil
    @boss = nil; @boss_on = false; @shots = []; @shake = 0; @banner = 0
    @rng = 1 + idx * 31
    boss_at = nil
    start = [2, 7]
    @grid.each_with_index do |row, r|
      row.each_with_index do |ch, c|
        case ch
        when 'P' then start = [c, r]; row[c] = '.'
        when 'r'
          @enemies << Actor.new(:blob, c * T + 8, tile_bottom(r), 48, 40)
          row[c] = '.'
        when 'v'
          e = Actor.new(:crab, c * T + 6, tile_bottom(r), 52, 44)
          e.data[:cycle] = (c * 29) % 200
          @enemies << e
          row[c] = '.'
        when 'L', 'H'
          l = Actor.new(:lift, c * T, tile_top(r) - 16, 128, 16)
          l.data = { bx: l.x, by: l.y, axis: ch == 'H' ? :x : :y, phase: c * 0.7, dx: 0.0, dy: 0.0 }
          @lifts << l
          row[c] = '.'
        when 'S' then @vents << { c: c, r: r, phase: (c * 37) % 180, h: 0 }
        when 'K' then @cones << { c: c, r: r, lit: false }; row[c] = '.'
        when 'G' then @goal = { c: c, r: r, turn: 0 }; row[c] = '.'
        when 'B' then boss_at = [c, r]; row[c] = '.'
        end
      end
    end
    spawn_boss(boss_at[0], boss_at[1]) if boss_at
    @vents.each do |v|
      h = 0
      h += 1 while h < 3 && !SOLID[cell(v[:c], v[:r] - h - 1)]
      v[:h] = h * T
    end
    if use_checkpoint && @checkpoint && @checkpoint[0] == idx
      cone = @cones[@checkpoint[1]]
      start = [cone[:c], cone[:r]]
      cone[:lit] = true
    end
    if @rush && @boss
      start = [@arena_c + 1, 7]
      @enemies.reject! { |e| e.x < (@arena_c + 1) * T }
    end
    @p = Player.new(start[0] * T + 12, tile_bottom(start[1]))
    @p.powered = @powered if use_checkpoint
    @p.powered = true if @rush
    @time = lv[:time] || SHIFT_LEN
    @time_acc = 0
    @warned = false
    @cam = [[@p.x - 480, 0].max, max_cam].min.to_f
  end

  # ── tile helpers ──────────────────────────────────────────────────
  def cell(c, r)
    return '#' if c < 0 || c >= @cols
    return '.' if r < 0 || r >= ROWS
    @grid[r][c]
  end

  def col_at(x); (x / T).floor; end
  def row_at(y); ROWS - 1 - (y / T).floor; end
  def tile_bottom(r); (ROWS - 1 - r) * T; end
  def tile_top(r); (ROWS - r) * T; end
  def max_cam; @cols * T - VW; end

  def box_free?(x, y, w, h)
    r0 = row_at(y + h - 0.01); r1 = row_at(y + 0.01)
    c0 = col_at(x + 0.01); c1 = col_at(x + w - 0.01)
    r0.upto(r1) { |r| c0.upto(c1) { |c| return false if SOLID[cell(c, r)] } }
    true
  end

  def overlap?(a, b)
    a.x < b.x + b.w && a.x + a.w > b.x && a.y < b.y + b.h && a.y + a.h > b.y
  end

  def rect_hit?(a, x, y, w, h)
    a.x < x + w && a.x + a.w > x && a.y < y + h && a.y + a.h > y
  end

  # horizontal move with tile collision; returns true on wall hit
  def move_x(a)
    a.x += a.vx
    r0 = row_at(a.y + a.h - 0.01); r1 = row_at(a.y + 0.01)
    if a.vx > 0
      c = col_at(a.x + a.w - 0.01)
      r0.upto(r1) { |r| if SOLID[cell(c, r)] then a.x = c * T - a.w; return true end }
    elsif a.vx < 0
      c = col_at(a.x)
      r0.upto(r1) { |r| if SOLID[cell(c, r)] then a.x = (c + 1) * T; return true end }
    end
    false
  end

  # vertical move; lands on solids, one-way pipes and lifts. Returns the
  # list of [col, row] cells hit by the head (empty if none).
  def move_y(a, use_lifts, corner_fix)
    prev = a.y
    a.y += a.vy
    a.on_ground = false
    a.riding = nil
    c0 = col_at(a.x + 0.01); c1 = col_at(a.x + a.w - 0.01)
    if a.vy <= 0
      r = row_at(a.y)
      top = tile_top(r)
      c0.upto(c1) do |c|
        ch = cell(c, r)
        if SOLID[ch] || (ch == '-' && prev >= top - 0.01)
          a.y = top; a.vy = 0.0; a.on_ground = true
          break
        end
      end
      if use_lifts && !a.on_ground
        @lifts.each do |l|
          lt = l.y + l.h
          if a.x + a.w > l.x + 4 && a.x < l.x + l.w - 4 && a.y <= lt && prev >= lt - 14
            a.y = lt; a.vy = 0.0; a.on_ground = true; a.riding = l
            break
          end
        end
      end
      return []
    end
    r = row_at(a.y + a.h)
    hits = []
    c0.upto(c1) { |c| ch = cell(c, r); hits << c if SOLID[ch] || ch == 'I' }
    return hits if hits.empty?
    # a hidden crate only blocks if the head started below it
    hits = hits.select { |c| cell(c, r) != 'I' || prev + a.h <= tile_bottom(r) + 0.01 }
    return hits if hits.empty?
    if corner_fix && hits.size == 1
      c = hits[0]
      left_over = a.x + a.w - c * T
      right_over = (c + 1) * T - a.x
      if left_over <= 18 && box_free?(a.x - left_over, a.y, a.w, a.h)
        a.x -= left_over
        return []
      elsif right_over <= 18 && box_free?(a.x + right_over, a.y, a.w, a.h)
        a.x += right_over
        return []
      end
    end
    a.y = tile_bottom(r) - a.h
    a.vy = 0.0
    hits.map { |c| [c, r] }
  end

  # ── title ─────────────────────────────────────────────────────────
  def tick_title
    @cam = (@mode_t * 1.5) % max_cam
    if @in_left_down || @in_right_down
      @bro = 1 - @bro
      sfx(:tick)
    end
    draw_world(false)
    rect(0, 0, VW, 720, [0, 0, 0], 120)
    shadow_label(640, 640, 'SUPER LEGALLY DISTINCT', 5, [252, 240, 160])
    shadow_label(640, 580, 'PIPEFITTING', 12, [244, 120, 24])
    shadow_label(640, 470, 'BROTHERS', 12, [236, 212, 64])
    2.times do |i|
      x = 480 + i * 320
      sel = i == @bro
      rect(x - 56, 196, 112, 120, sel ? [252, 240, 160] : [60, 60, 60])
      rect(x - 48, 204, 96, 104, [20, 20, 40])
      f = sel ? 1 + (@mode_t / 8) % 3 : 0
      spr(BROS[i][:path], x - 32, 216, 64, 80, f * 8, 0, 8, 20, i == 1)
      shadow_label(x, 180, BROS[i][:name], 4, sel ? [252, 240, 160] : [140, 140, 140])
    end
    shadow_label(640, 120, 'PRESS START', 4, [255, 255, 255]) if (@mode_t / 30) % 2 == 0
    shadow_label(640, 366, 'BOSS RUSH', 4, [232, 72, 64]) if @rush_armed
    shadow_label(640, 70, "TOP #{pad6(@hiscore)}", 3, [200, 200, 200])
    shadow_label(640, 30, 'ANY RESEMBLANCE TO PLUMBERS LIVING OR DEAD IS PURELY COINCIDENTAL', 2, [180, 180, 180])
    if !@rush_armed && feed_code
      @rush_armed = true
      sfx(:oneup)
    end
    if @in_start_down || @in_a_down
      sfx(:checkpoint)
      new_game(@rush_armed)
    end
  end

  # ── intro card ────────────────────────────────────────────────────
  def tick_intro
    @args.outputs.background_color = [0, 0, 0]
    draw_hud
    label(640, 440, @lv[:name], 6, [252, 240, 160])
    label(640, 370, @lv[:title], 4, [244, 120, 24])
    label(640, 560, "BOSS RUSH #{@level / 4 + 1} OF 8", 4, [232, 72, 64]) if @rush
    spr(BROS[@bro][:path], 560, 210, 64, 80, 0, 0, 8, 20)
    label(680, 270, "x #{@lives}", 5, [255, 255, 255])
    return unless @mode_t > 150
    @mode = :play
    @mode_t = 0
    music(:theme)
  end

  # ── gameplay ──────────────────────────────────────────────────────
  def tick_play
    if @in_start_down
      @mode = :paused
      sfx(:pause)
      m = @args.audio[:music]
      m[:paused] = true if m
      draw_world(true)
      return
    end
    update_timer
    update_lifts
    update_player
    update_enemies if @mode == :play
    update_boss if @boss && @mode == :play
    update_wrench
    update_items
    update_effects
    update_camera
    sh = @shake > 0 ? ((@frame % 4) < 2 ? 6 : -6) : 0
    @cam += sh
    draw_world(true)
    @cam -= sh
  end

  def tick_paused
    draw_world(true)
    rect(0, 0, VW, PLAY_H, [0, 0, 0], 140)
    label(640, 380, 'COFFEE BREAK', 7, [252, 240, 160])
    label(640, 300, 'PRESS START', 3, [255, 255, 255])
    return unless @in_start_down
    @mode = :play
    sfx(:pause)
    m = @args.audio[:music]
    m[:paused] = false if m
  end

  def update_timer
    @time_acc += 1
    return if @time_acc < TICK_LEN
    @time_acc = 0
    @time -= 1
    if @time == 100 && !@warned
      @warned = true
      sfx(:warn)
      m = @args.audio[:music]
      m[:pitch] = 1.15 if m
    end
    die if @time <= 0
  end

  def update_lifts
    @lifts.each do |l|
      d = l.data
      s = Math.sin(@frame * 6.2832 / 240 + d[:phase])
      if d[:axis] == :x
        nx = d[:bx] + s * 2 * T
        d[:dx] = nx - l.x; d[:dy] = 0.0; l.x = nx
      else
        ny = d[:by] + s * 2 * T
        d[:dy] = ny - l.y; d[:dx] = 0.0; l.y = ny
      end
    end
  end

  def update_player
    p = @p
    if p.riding
      p.x += p.riding.data[:dx]
      p.y += p.riding.data[:dy]
    end
    p.prev_y = p.y
    dir = (@in_right ? 1 : 0) - (@in_left ? 1 : 0)
    run = @in_b
    maxv = run ? RUN_MAX : WALK_MAX
    ground = p.on_ground
    p.skid = false
    if dir != 0
      if p.vx * dir < 0
        p.vx += dir * (ground ? 0.5 : 0.3)
        p.skid = ground && p.vx.abs > 1.5
        dust(p.x + p.w / 2, p.y) if p.skid && @frame % 4 == 0
      elsif p.vx.abs <= maxv
        p.vx += dir * (ground ? (run ? 0.28 : 0.2) : 0.18)
        p.vx = maxv * dir if p.vx.abs > maxv
      elsif ground
        p.vx -= dir * 0.12
      end
      p.facing = dir
    else
      f = ground ? 0.25 : 0.04
      p.vx = p.vx.abs <= f ? 0.0 : p.vx - f * (p.vx > 0 ? 1 : -1)
    end

    p.buffer = @in_a_down ? 7 : p.buffer - 1
    p.coyote = ground ? 6 : p.coyote - 1
    if p.buffer > 0 && p.coyote > 0
      p.vy = JUMP_V + p.vx.abs * 0.28
      p.buffer = 0; p.coyote = 0; p.jumping = true
      p.riding = nil
      sfx(:jump)
    end
    g = p.vy > 0 ? (p.jumping && @in_a ? GRAV_HOLD : GRAV_CUT) : GRAV_FALL
    p.vy -= g
    p.vy = FALL_MAX if p.vy < FALL_MAX

    p.vx = 0.0 if move_x(p)
    heads = move_y(p, true, true)
    if p.on_ground
      p.jumping = false
      p.combo = 0
    end
    unless heads.empty?
      cx = p.x + p.w / 2
      best = heads[0]
      heads.each { |h| best = h if ((h[0] * T + T / 2) - cx).abs < ((best[0] * T + T / 2) - cx).abs }
      bump(best[0], best[1])
    end

    p.anim += p.vx.abs * 0.05 if p.vx.abs > 0.3 && p.on_ground
    p.invuln -= 1 if p.invuln > 0
    p.throw_t -= 1 if p.throw_t > 0

    # throw the wrench
    if @in_b_down && p.powered && @wrench.nil?
      w = Actor.new(:wrench, p.x + (p.facing > 0 ? p.w : -40), p.y + 36, 40, 20)
      w.vx = p.facing * 16.0 + p.vx * 0.5
      w.facing = p.facing
      w.data[:back] = false
      @wrench = w
      p.throw_t = 12
      sfx(:throw)
    end

    collect_nuts(p)
    @vents.each do |v|
      k = (@frame + v[:phase]) % 180
      next unless k >= 130 && v[:h] > 0
      hurt if rect_hit?(p, v[:c] * T + 14, tile_top(v[:r]), 36, v[:h] - 8)
    end
    @cones.each_with_index do |cone, i|
      next if cone[:lit] || p.x < cone[:c] * T
      cone[:lit] = true
      @checkpoint = [@level, i]
      sfx(:checkpoint)
      popup(cone[:c] * T, tile_top(cone[:r]) + 20, 'CHECKPOINT')
    end
    if goal_touched?(p)
      p.x = @goal[:c] * T + 8 - p.w if p.x < @goal[:c] * T
      p.vx = 0.0
      start_clear
      return
    end
    die if p.y < -140
  end

  # Walking in from the left stops you at the valve. The boss valve can also
  # appear on top of you, or you can walk back into it from the right: that
  # counts only if you actually overlap it (it is 3 tiles tall).
  def goal_touched?(p)
    return false unless @goal
    gx = @goal[:c] * T
    return p.x + p.w > gx + 8 if p.x < gx
    p.x < gx + T - 8 && p.y < tile_bottom(@goal[:r]) + 3 * T
  end

  def collect_nuts(a)
    r0 = row_at(a.y + a.h - 8); r1 = row_at(a.y + 8)
    c0 = col_at(a.x + 6); c1 = col_at(a.x + a.w - 6)
    r0.upto(r1) do |r|
      next if r < 0 || r >= ROWS
      c0.upto(c1) do |c|
        next unless cell(c, r) == 'o'
        @grid[r][c] = '.'
        add_nut
        sparkle(c * T + 32, tile_bottom(r) + 32)
      end
    end
  end

  def add_nut
    @nuts += 1
    @score += 50
    sfx(:nut)
    return if @nuts < 50
    @nuts -= 50
    one_up(@p.x, @p.y + 90)
  end

  def one_up(x, y)
    @lives += 1
    sfx(:oneup)
    popup(x, y, '1UP')
  end

  def add_score(n, x, y)
    @score += n
    popup(x, y, n.to_s)
  end

  def bump(c, r)
    ch = cell(c, r)
    key = r * 10000 + c
    @bumps[key] = BUMP_ARC.size
    x = c * T; top = tile_top(r)
    case ch
    when 'C'
      @grid[r][c] = 'U'
      pop_nut(x, top)
    when 'M'
      n = (@multi[key] ||= 8)
      pop_nut(x, top)
      @multi[key] = n - 1
      @grid[r][c] = 'U' if n - 1 <= 0
    when 'W'
      @grid[r][c] = 'U'
      it = Actor.new(:wrench_item, x + 4, top - 64, 56, 56)
      it.data[:rise] = 64
      @items << it
      sfx(:appear)
    when 'I'
      @grid[r][c] = 'U'
      it = Actor.new(:lunch, x + 4, top - 64, 56, 56)
      it.data[:rise] = 64
      it.vx = 2.5
      @items << it
      sfx(:appear)
    else
      sfx(:bump)
    end
    # knock out enemies standing on the bumped tile
    @enemies.each do |e|
      next unless e.active && e.state == :walk
      next unless (e.y - top).abs < 6 && e.x + e.w > x && e.x < x + T
      knock(e, x + 32 < e.x + e.w / 2 ? 1 : -1)
      add_score(200, e.x, e.y + 60)
    end
  end

  def pop_nut(x, top)
    it = Actor.new(:popnut, x, top, 64, 64)
    it.vy = 16.0
    @items << it
    add_nut
  end

  def hurt
    p = @p
    return if p.invuln > 0 || @mode != :play
    if p.powered
      p.powered = false
      p.invuln = 120
      sfx(:hurt)
    else
      die
    end
  end

  def die
    return if @mode != :play
    @mode = :dying
    @mode_t = 0
    @powered = false
    @p.vx = 0.0
    @p.vy = 0.0
    music(:death, false)
  end

  def tick_dying
    p = @p
    if @mode_t > 30
      p.vy = 15.0 if @mode_t == 31
      p.vy -= 0.8
      p.y += p.vy
    end
    update_effects
    draw_world(true)
    return if @mode_t < 190
    @lives -= 1
    if @lives <= 0
      @mode = :gameover
      @mode_t = 0
      save_hiscore
      music(:gameover, false)
    else
      to_intro
    end
  end

  def start_clear
    return start_ending if @level == LEVELS.size - 1
    @mode = :clear
    @mode_t = 0
    @powered = @p.powered
    music(:clear, false)
  end

  def tick_clear
    p = @p
    p.vy -= GRAV_FALL
    p.vx = 0.0
    move_y(p, true, false)
    p.facing = 1
    @goal[:turn] += 1 if @mode_t < 100
    if @mode_t > 110 && @time > 0
      n = [@time, 2].min
      @time -= n
      @score += n * 50
      sfx(:tick) if @mode_t % 4 == 0
    end
    update_effects
    update_camera
    draw_world(true)
    label(640, 470, 'MAIN SHUTOFF CLOSED!', 5, [252, 240, 160], true)
    label(640, 420, 'TIME BONUS', 3, [255, 255, 255], true) if @mode_t > 110
    return unless @time <= 0 && @mode_t > 300
    @level += @rush ? 4 : 1
    @checkpoint = nil
    if @level >= LEVELS.size
      @mode = :win
      @mode_t = 0
      save_hiscore
      music(:clear, false)
    else
      to_intro
    end
  end

  def tick_end(kind)
    @args.outputs.background_color = [0, 0, 0]
    draw_hud
    if kind == :gameover
      label(640, 440, 'GAME OVER', 8, [232, 72, 64])
      label(640, 350, 'YOU ARE FIRED', 4, [255, 255, 255])
    else
      label(640, 500, @rush ? 'BOSS RUSH CLEARED!' : 'ALL MAINS SHUT OFF!', 6, [252, 240, 160])
      label(640, 420, @rush ? 'BIG RUSTY IS SCRAP' : 'OVERTIME APPROVED', 4, [244, 120, 24])
      label(640, 340, "FINAL SCORE #{pad6(@score)}", 4, [255, 255, 255])
    end
    label(640, 260, "TOP #{pad6(@hiscore)}", 3, [200, 200, 200])
    label(640, 160, 'PRESS START', 3, [255, 255, 255]) if @mode_t > 120 && (@mode_t / 30) % 2 == 0
    to_title if @mode_t > 120 && (@in_start_down || @in_a_down)
  end

  def save_hiscore
    return unless @score > @hiscore
    @hiscore = @score
    @args.gtk.save_u32(0, @hiscore)
  end

  # ── enemies ───────────────────────────────────────────────────────
  def knock(e, dir)
    e.state = :dead
    e.vy = 12.0
    e.vx = dir * 2.0
    sfx(:kick)
  end

  def update_enemies
    p = @p
    @enemies.each do |e|
      unless e.active
        next if e.x > @cam + VW + 48
        e.active = true
        e.vx = e.kind == :crab ? -1.2 : -1.0
      end
      e.t += 1
      if e.state == :dead
        e.vy -= 0.8
        e.x += e.vx
        e.y += e.vy
        next
      end
      next if e.state != :walk
      next if e.x < @cam - 900 || e.x > @cam + VW + 600
      spiky = false
      speed = 1.0
      if e.kind == :crab
        k = (e.t + e.data[:cycle]) % 220
        spiky = k >= 150
        e.data[:spin] = spiky
        e.data[:warn] = k >= 120 && k < 150
        speed = spiky ? 2.6 : 1.2
      end
      e.vx = (e.vx < 0 ? -1 : 1) * speed
      e.vy -= GRAV_FALL
      e.vy = FALL_MAX if e.vy < FALL_MAX
      e.vx = -e.vx if move_x(e)
      move_y(e, false, false)
      if e.on_ground
        fx = e.vx > 0 ? e.x + e.w + 2 : e.x - 2
        below = cell(col_at(fx), row_at(e.y - 4))
        e.vx = -e.vx unless SOLID[below] || below == '-'
      end
      e.state = :dead if e.y < -100
      @enemies.each do |o|
        next if o.equal?(e) || !o.active || o.state != :walk
        e.vx = -e.vx if overlap?(e, o) && ((o.x - e.x) * e.vx) > 0
      end
      next unless @mode == :play && overlap?(p, e)
      # full box for stomps, a smaller one for getting hurt (forgiving)
      if p.vy < 0 && p.prev_y >= e.y + e.h * 0.4 && !spiky
        stomp(e)
      elsif rect_hit?(p, e.x + 8, e.y, e.w - 16, e.h - 8)
        hurt
      end
    end
    @enemies.each do |e|
      next unless e.state == :flat
      e.data[:flat_t] = (e.data[:flat_t] || 0) + 1
      e.state = :gone if e.data[:flat_t] > 30
    end
    @enemies.reject! { |e| e.state == :gone || (e.state == :dead && e.y < -200) }
  end

  def stomp(e)
    p = @p
    if p.combo >= COMBO.size
      one_up(e.x, e.y + 60)
    else
      add_score(COMBO[p.combo] * (e.kind == :crab ? 2 : 1), e.x + 20, e.y + 60)
    end
    p.combo += 1
    p.vy = @in_a ? 17.0 : 10.0
    p.jumping = @in_a
    puff(e.x + e.w / 2, e.y + 10)
    sfx(:stomp)
    if e.kind == :blob
      e.state = :flat
    else
      knock(e, p.facing)
    end
  end

  # ── wrench boomerang ──────────────────────────────────────────────
  def update_wrench
    w = @wrench
    return unless w
    p = @p
    w.t += 1
    if !w.data[:back]
      w.vx -= w.facing * 0.5
      w.data[:back] = true if w.vx * w.facing <= 0
    else
      dx = (p.x + p.w / 2) - (w.x + w.w / 2)
      dy = (p.y + 40) - (w.y + w.h / 2)
      d = Math.sqrt(dx * dx + dy * dy)
      d = 1 if d < 1
      sp = [w.vx.abs + w.vy.abs + 0.6, 13.0].min
      w.vx = dx / d * sp
      w.vy = dy / d * sp
      if d < 40
        @wrench = nil
        return
      end
    end
    w.x += w.vx
    w.y += w.vy
    collect_nuts(w)
    @enemies.each do |e|
      next unless e.active && e.state == :walk && overlap?(w, e)
      knock(e, w.vx > 0 ? 1 : -1)
      add_score(200, e.x, e.y + 60)
    end
    if @boss && @boss_on && overlap?(w, @boss) && !w.data[:back]
      boss_hit(1)
      w.data[:back] = true
    end
    # a wrench that hits the main valve turns it: level clear
    if @goal && @mode == :play &&
       rect_hit?(w, @goal[:c] * T, tile_bottom(@goal[:r]), T, 3 * T)
      @wrench = nil
      sfx(:bump)
      popup(@goal[:c] * T, tile_bottom(@goal[:r]) + 3 * T + 80, 'NICE SHOT')
      start_clear
      return
    end
    @wrench = nil if w.t > 150
  end

  # ── items ─────────────────────────────────────────────────────────
  def update_items
    p = @p
    @items.each do |it|
      it.t += 1
      if it.kind == :popnut
        it.vy -= 1.2
        it.y += it.vy
        it.state = :gone if it.t > 26
        next
      end
      if it.data[:rise] > 0
        it.data[:rise] -= 2
        it.y += 2
        next
      end
      if it.kind == :lunch
        it.vy -= GRAV_FALL
        it.vx = -it.vx if move_x(it)
        move_y(it, false, false)
        it.state = :gone if it.y < -100
      end
      next unless overlap?(p, it)
      it.state = :gone
      if it.kind == :lunch
        one_up(it.x, it.y + 70)
      else
        add_score(1000, it.x, it.y + 70)
        p.powered = true
        sfx(:powerup)
      end
    end
    @items.reject! { |it| it.state == :gone }
  end

  # ── effects ───────────────────────────────────────────────────────
  def popup(x, y, text)
    @popups << [x, y, text, 0]
  end

  def puff(x, y)
    6.times do |i|
      a = i * 1.047
      @particles << [x, y, Math.cos(a) * 3, Math.sin(a) * 3 + 1, 16, [236, 236, 236]]
    end
  end

  def dust(x, y)
    @particles << [x, y + 4, -@p.facing * 1.5, 1.0, 12, [200, 200, 200]]
  end

  def sparkle(x, y)
    4.times do |i|
      a = i * 1.571 + 0.785
      @particles << [x, y, Math.cos(a) * 4, Math.sin(a) * 4, 10, [252, 240, 160]]
    end
  end

  def update_effects
    @particles.each do |pt|
      pt[0] += pt[2]; pt[1] += pt[3]; pt[3] -= 0.15; pt[4] -= 1
    end
    @particles.reject! { |pt| pt[4] <= 0 }
    @popups.each { |pp| pp[1] += 1.5; pp[3] += 1 }
    @popups.reject! { |pp| pp[3] > 45 }
    @bumps.keys.each do |k|
      @bumps[k] -= 1
      @bumps.delete(k) if @bumps[k] <= 0
    end
  end

  def update_camera
    p = @p
    target = p.x + p.w / 2 - 560 + p.facing * 90
    target = max_cam if @boss_on
    @cam += (target - @cam) * 0.1
    @cam = 0.0 if @cam < 0
    @cam = max_cam.to_f if @cam > max_cam
  end

  # ── drawing ───────────────────────────────────────────────────────
  def spr(path, x, y, w, h, sx, sy, sw, sh, flip = false, a = 255, angle = 0, flipv = false)
    @o.sprites << { x: x, y: y, w: w, h: h, path: path, source_x: sx, source_y: sy,
                               source_w: sw, source_h: sh, flip_horizontally: flip, flip_vertically: flipv,
                               a: a, angle: angle }
  end

  def rect(x, y, w, h, col, a = 255)
    @o.sprites << { x: x, y: y, w: w, h: h, path: 'sprites/px.png',
                               r: col[0], g: col[1], b: col[2], a: a }
  end

  def label(x, y, text, size, col, shadow = false)
    if shadow
      @o.labels << { x: x + size, y: y - size, text: text, size_px: size, alignment_enum: 1, r: 0, g: 0, b: 0 }
    end
    @o.labels << { x: x, y: y, text: text, size_px: size, alignment_enum: 1, r: col[0], g: col[1], b: col[2] }
  end

  def shadow_label(x, y, text, size, col)
    label(x, y, text, size, col, true)
  end

  def draw_background
    th = @theme
    o = @o
    sky = th[:sky]
    o.background_color = sky[0]
    if sky.size > 1
      band = 72
      sky.each_with_index do |col, i|
        top = PLAY_H - i * band
        bottom = i == sky.size - 1 ? 128 : top - band
        o.solids << [0, bottom, VW, top - bottom, col[0], col[1], col[2]]
      end
    else
      o.solids << [0, 128, VW, PLAY_H - 128, sky[0][0], sky[0][1], sky[0][2]]
    end
    if th[:stars]
      40.times do |i|
        sx = ((i * 211 + 57) - @cam * 0.05) % VW
        sy = 300 + (i * 97) % 330
        tw = (@frame / 20 + i) % 7 == 0 ? 120 : 230
        o.solids << [sx.to_i, sy, 8, 4, tw, tw, 255]
      end
      [[6, 0], [10, 1], [12, 2], [12, 3], [12, 4], [10, 5], [6, 6]].each do |w, dy|
        o.solids << [1040 - w * 4, 560 - dy * 8, w * 8, 8, 236, 232, 196]
      end
    end
    if th[:sun]
      [[8, 0], [14, 1], [18, 2], [20, 3], [20, 4], [20, 5]].each do |w, dl|
        o.solids << [900 - w * 4, 300 - dl * 16, w * 8, 16, 252, 224, 104]
      end
    end
    cc = th[:cloud]
    [[100, 560], [620, 600], [1050, 520], [1500, 580]].each do |cx, cy|
      x = (((cx - @cam * 0.25) % 1800) - 260).to_i
      o.solids << [x + 32, cy, 64, 16, cc[0], cc[1], cc[2]]
      o.solids << [x, cy - 16, 160, 16, cc[0], cc[1], cc[2]]
      o.solids << [x - 16, cy - 32, 208, 16, cc[0], cc[1], cc[2]]
    end
    b = th[:bush]; bd = th[:bush_dk]
    if th[:indoor]
      # indoors, trees of varying heights, so the windows (y 192..384) show
      # trunks rising from the ground into blocky canopies
      TREES.each do |bx, w, cy|
        x = (((bx - @cam * 0.5) % 1600) - 160).to_i
        tw = w >= 120 ? 24 : 16
        o.solids << [x + w / 2 - tw / 2, 128, tw, cy - 120, 104, 68, 36]
        o.solids << [x + w / 2 - tw / 2, 128, 8, cy - 120, 72, 44, 20]
        o.solids << [x, cy, w, 16, bd[0], bd[1], bd[2]]
        o.solids << [x - 8, cy + 16, w + 16, 40, b[0], b[1], b[2]]
        o.solids << [x, cy + 56, w, 24, b[0], b[1], b[2]]
        o.solids << [x + 16, cy + 80, w - 32, 16, b[0], b[1], b[2]]
        o.solids << [x + w / 4 + 8, cy + 96, w / 2 - 16, 16, b[0], b[1], b[2]]
      end
    else
      [[16, 96], [240, 144], [512, 80], [784, 128], [1056, 112], [1300, 96]].each do |bx, w|
        x = (((bx - @cam * 0.5) % 1600) - 160).to_i
        o.solids << [x + w / 4, 192, w / 2, 16, b[0], b[1], b[2]]
        o.solids << [x + 8, 176, w - 16, 16, b[0], b[1], b[2]]
        o.solids << [x, 140, w, 36, b[0], b[1], b[2]]
        o.solids << [x, 128, w, 12, bd[0], bd[1], bd[2]]
      end
    end
    # the alley between buildings
    o.solids << [0, 0, VW, 128, 0, 0, 0]
  end

  # Indoors: a brick back wall over the sky, with occasional windows (holes
  # in the wall) that show the parallax sky, clouds and bushes outside.
  WIN_ROWS = (4..6)
  # [x, canopy width, canopy bottom y] for the trees seen through windows
  TREES = [[16, 96, 232], [240, 144, 296], [512, 80, 208], [784, 128, 272], [1056, 112, 312], [1300, 96, 248]]
  def window_at?(c)
    m = c % 13
    return false unless m == 6 || m == 7
    left = c - (m - 6)
    WIN_ROWS.all? { |r| !SOLID[cell(left, r)] && !SOLID[cell(left + 1, r)] }
  end

  def draw_back_wall(cam, tiles, c0, c1)
    c0.upto(c1 + 1) do |c|
      win = window_at?(c)
      x = c * T - cam
      8.times do |r|
        next if win && WIN_ROWS.include?(r)
        spr(tiles, x, tile_bottom(r), T, T, 88, 0, 8, 16)
      end
    end
    wood = [140, 88, 44]; sill = [196, 148, 92]
    c0.upto(c1 + 1) do |c|
      next unless c % 13 == 6 && window_at?(c)
      x = c * T - cam
      bot = tile_bottom(WIN_ROWS.last); top = tile_top(WIN_ROWS.first)
      w = 2 * T
      rect(x, bot, w, 8, sill)                 # sill
      rect(x - 8, bot - 8, w + 16, 8, wood)
      rect(x, top - 8, w, 8, wood)             # head
      rect(x, bot, 8, top - bot, wood)         # jambs
      rect(x + w - 8, bot, 8, top - bot, wood)
      rect(x + T - 4, bot, 8, top - bot, wood) # mullion
      rect(x, (bot + top) / 2 - 4, w, 8, wood) # transom bar
    end
  end

  def draw_tiles
    cam = @cam.to_i
    tiles = @theme[:tiles]
    c0 = [cam / T, 0].max
    c1 = [(cam + VW) / T, @cols - 1].min
    nut_f = (@frame / 8) % 4
    draw_back_wall(cam, tiles, c0, c1) if @theme[:indoor]
    ROWS.times do |r|
      row = @grid[r]
      y = tile_bottom(r)
      c0.upto(c1) do |c|
        ch = row[c]
        next if ch == '.' || ch == 'I'
        x = c * T - cam
        b = @bumps[r * 10000 + c]
        yy = b ? y + BUMP_ARC[BUMP_ARC.size - b] : y
        case ch
        when '#' then spr(tiles, x, yy, T, T, r == 0 || SOLID[cell(c, r - 1)] ? 0 : 8, 0, 8, 16)
        when 'F' then spr(tiles, x, yy, T, T, cell(c, r - 1) == 'F' ? 104 : 96, 0, 8, 16)
        when '=' then spr(tiles, x, yy, T, T, 16, 0, 8, 16)
        when 'C', 'W', 'M' then spr(tiles, x, yy, T, T, 24, 0, 8, 16)
        when 'U' then spr(tiles, x, yy, T, T, 32, 0, 8, 16)
        when '-'
          # extend a stand up behind the pipe so it meets the pipe's underside
          spr(tiles, x, y, T, T, 56, 0, 8, 16) if cell(c, r + 1) == '|'
          if cell(c + 1, r) != '-'
            spr(tiles, x, yy, T, T, 48, 0, 8, 16, true)
          elsif cell(c - 1, r) != '-' || c % 4 == 0
            spr(tiles, x, yy, T, T, 48, 0, 8, 16)
          else
            spr(tiles, x, yy, T, T, 40, 0, 8, 16)
          end
        when '|' then spr(tiles, x, yy, T, T, 56, 0, 8, 16)
        when 'S' then spr(tiles, x, yy, T, T, 64, 0, 8, 16)
        when 'o' then spr('sprites/items.png', x, yy, T, T, nut_f * 8, 0, 8, 16)
        end
      end
    end
  end

  def draw_world(entities, hud = true)
    draw_background
    cam = @cam.to_i
    draw_tiles
    @lifts.each do |l|
      x = l.x.to_i - cam
      spr(@theme[:tiles], x, l.y.to_i - 48, T, T, 80, 0, 8, 16)
      spr(@theme[:tiles], x + T, l.y.to_i - 48, T, T, 80, 0, 8, 16)
    end
    @cones.each do |cone|
      lit = cone[:lit] && (@frame / 10) % 2 == 0
      spr('sprites/items.png', cone[:c] * T - cam, tile_bottom(cone[:r]), T, T, lit ? 56 : 48, 0, 8, 16)
    end
    if @goal
      gx = @goal[:c] * T - cam
      gy = tile_bottom(@goal[:r])
      spr(@theme[:tiles], gx, gy, T, T, 72, 0, 8, 16)
      spr(@theme[:tiles], gx, gy + T, T, T, 72, 0, 8, 16)
      unless @goal[:gone]
        f = (@goal[:turn] / 5) % 3
        spr('sprites/items.png', gx, gy + 2 * T, T, T, 64 + f * 8, 0, 8, 16)
        label(gx + 32, gy + 3 * T + 28, 'MAIN', 2, [255, 255, 255], true)
      end
    end
    @vents.each do |v|
      k = (@frame + v[:phase]) % 180
      next if k < 100 || v[:h] <= 0
      x = v[:c] * T - cam
      next if x < -T || x > VW
      base = tile_top(v[:r])
      if k < 130
        rect(x + 24, base + (k % 10) * 2, 16, 8, [236, 236, 236], 180) if (k / 5).even?
      else
        (v[:h] / 16).times do |i|
          wob = ((i + @frame / 3) % 3 - 1) * 8
          w = 24 + (i * 3) % 16
          rect(x + 32 - w / 2 + wob, base + i * 16, w, 16, [236, 236, 236], 200 - i * 6)
        end
        sfx(:steam) if k == 130 && entities
      end
    end
    return unless entities
    @items.each do |it|
      x = it.x.to_i - cam
      case it.kind
      when :popnut then spr('sprites/items.png', x, it.y.to_i, T, T, ((it.t / 3) % 4) * 8, 0, 8, 16)
      when :wrench_item
        bob = it.data[:rise] > 0 ? 0 : ((@frame / 12) % 2) * 4
        spr('sprites/items.png', x - 4, it.y.to_i + bob, T, T, 32, 0, 8, 16)
      when :lunch then spr('sprites/items.png', x - 4, it.y.to_i, T, T, 40, 0, 8, 16)
      end
    end
    @enemies.each do |e|
      x = e.x.to_i - cam
      next if x < -T || x > VW + T
      if e.kind == :blob
        f = e.state == :flat ? 2 : (e.t / 10) % 2
        spr('sprites/enemies.png', x - 8, e.y.to_i, T, 48, f * 8, 0, 8, 12, e.vx > 0, 255, 0, e.state == :dead)
      else
        f = e.data[:spin] ? 5 + (e.t / 4) % 2 : 3 + (e.t / 12) % 2
        a = e.data[:warn] && (e.t / 3).even? ? 110 : 255
        spr('sprites/enemies.png', x - 6, e.y.to_i, T, 48, f * 8, 0, 8, 12, false, a, 0, e.state == :dead)
      end
    end
    draw_boss(cam) if @boss
    draw_player
    draw_boss_hud if @boss
    if @wrench
      w = @wrench
      # 7 hand-drawn spin frames; mirroring reverses the spin for left throws
      f = (w.t / 2) % 7
      spr('sprites/wrench.png', w.x.to_i - cam - 4, w.y.to_i - 14, 48, 48, f * 8, 0, 8, 16, w.facing < 0)
    end
    @particles.each do |pt|
      rect(pt[0].to_i - cam, pt[1].to_i, 8, 8, pt[5], [pt[4] * 20, 255].min)
    end
    @popups.each do |pp|
      label(pp[0].to_i - cam + 20, pp[1].to_i, pp[2], 3, [255, 255, 255], true)
    end
    draw_hud if hud
  end

  def draw_player
    p = @p
    return if p.invuln > 0 && (p.invuln / 3) % 2 == 0 && @mode == :play
    cam = @cam.to_i
    f = if @mode == :dying then 6
        elsif p.throw_t > 0 then 7
        elsif !p.on_ground then 4
        elsif p.skid then 5
        elsif p.vx.abs > 0.3 then [1, 2, 3, 2][p.anim.to_i % 4]
        else 0
        end
    flip = f == 5 ? p.facing > 0 : p.facing < 0
    flip = false if f == 6
    x = p.x.to_i - cam - 12
    if p.powered && f != 6 && @wrench.nil?
      wx = p.facing > 0 ? x - 6 : x + 22
      spr('sprites/wrench.png', wx, p.y.to_i + 22, 40, 40, 8, 0, 8, 16, p.facing < 0)
    end
    spr(BROS[@bro][:path], x, p.y.to_i, 64, 80, f * 8, 0, 8, 20, flip)
  end

  def draw_hud
    rect(0, PLAY_H, VW, 720 - PLAY_H, [16, 16, 16])
    rect(0, PLAY_H, VW, 4, [60, 60, 60])
    col = [236, 212, 64]
    o = @o.labels
    o << { x: 24, y: 700, text: "#{BROS[@bro][:name]} x#{@lives}", size_px: 4, r: col[0], g: col[1], b: col[2] }
    o << { x: 230, y: 700, text: pad6(@score), size_px: 4, r: 255, g: 255, b: 255 }
    o << { x: 470, y: 700, text: "NUTS x#{@nuts}", size_px: 4, r: col[0], g: col[1], b: col[2] }
    o << { x: 720, y: 700, text: @lv[:name], size_px: 4, r: col[0], g: col[1], b: col[2] }
    t = @time || SHIFT_LEN
    tc = t <= 100 && (@frame / 15) % 2 == 0 ? [232, 72, 64] : col
    o << { x: 1256, y: 700, text: "SHIFT #{pad3(t)}", size_px: 4, alignment_enum: 2, r: tc[0], g: tc[1], b: tc[2] }
  end
end

require 'app/boss.rb'
require 'app/ending.rb'

def tick(args)
  $game ||= Game.new(args)
  $game.tick
end
