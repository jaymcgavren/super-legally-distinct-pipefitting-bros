# BIG RUSTY -- the boss at the end of every level. Same boss each time;
# encounter n knows every move from encounters 1..n, and move n is new.
BOSS_MOVES = [
  [:hop,    'HOP'],
  [:pound,  'GROUND POUND'],
  [:spit,   'RUST SPIT'],
  [:summon, 'BLOB BELCH'],
  [:charge, 'BULL CHARGE'],
  [:spikes, 'SPIKED CROWN'],
  [:bolts,  'BOLT STORM'],
  [:enrage, 'SHORT FUSE'],
]
BOLT_WARN = 64   # frames a bolt's shadow shows before it drops (was 40)
WARN_LEN = 160   # klaxon + WARNING card before each fight
WARN_AHEAD = 12  # the warning goes off this many tiles before the arena gate
BOSS_W = 112
BOSS_H = 104

class Game
  def boss_rand(n)
    @rng = (@rng * 75 + 74) % 65537
    @rng % n
  end

  def boss_level; @lv[:boss] || 1; end
  def boss_knows?(move); BOSS_MOVES.index { |m| m[0] == move } < boss_level; end

  def spawn_boss(c, r)
    b = Actor.new(:boss, c * T - 24, tile_bottom(r), BOSS_W, BOSS_H)
    hp = 6 + boss_level
    b.data = { hp: hp, max: hp, inv: 0, cd: 90, spiky: 0, warn_spiky: 0, angry: false, minions: 0 }
    b.state = :wait
    @boss = b
    @boss_on = false
    @arena_c = @cols - 20
    @shots = []
    @shake = 0
    @banner = 0
    @warning = 0
    @boss_warned = false   # the klaxon has gone off (on the approach)
    @fight_on = false      # warning over and the player is shut in: Rusty moves
  end

  # call every play tick when this level has a boss
  def update_boss
    b = @boss
    return unless b
    p = @p
    # the warning goes off on the approach, while the player can still look
    # before stepping in; the gate shuts once they are inside the arena
    unless @boss_warned
      return unless p.x > (@arena_c - WARN_AHEAD) * T
      @boss_warned = true
      @warning = WARN_LEN
      sfx(:klaxon)
      music_stop
    end
    @warning -= 1 if @warning > 0
    unless @boss_on
      return unless p.x > (@arena_c + 2) * T
      @boss_on = true
      8.times { |r| @grid[r][@arena_c] = '#' }   # the gate slams shut
      sfx(:bump)
    end
    unless @fight_on
      return if @warning > 0
      @fight_on = true
      @banner = 180
      music(:boss)
    end
    @banner -= 1 if @banner > 0
    @shake -= 1 if @shake > 0
    d = b.data
    d[:inv] -= 1 if d[:inv] > 0
    b.t += 1
    if b.state == :dead
      b.vy -= 0.6
      b.y += b.vy
      if b.t == 120
        @goal = { c: @arena_c + 10, r: 7, turn: 0 }   # between the arena girders
        sfx(:appear)
        popup(@goal[:c] * T, tile_top(7) + 60, 'MAIN VALVE')
      end
      update_shots
      return
    end
    angry = d[:angry]
    spd = angry ? 1.5 : 1.0
    if boss_knows?(:enrage) && !angry && d[:hp] * 2 <= d[:max]
      d[:angry] = true
      popup(b.x, b.y + 140, 'RUSTY IS FUMING!')
      sfx(:warn)
      m = @args.audio[:music]
      m[:pitch] = 1.2 if m
    end
    d[:spiky] -= 1 if d[:spiky] > 0
    d[:warn_spiky] -= 1 if d[:warn_spiky] > 0
    d[:spiky] = (angry ? 220 : 160) if d[:warn_spiky] == 1
    dir = p.x + p.w / 2 > b.x + b.w / 2 ? 1 : -1
    case b.state
    when :wait
      b.vx = 0.0
      b.state = :walk if @banner < 120
    when :walk
      b.facing = dir
      b.vx = dir * 1.3 * spd
      d[:cd] -= 1
      boss_choose if d[:cd] <= 0 && b.on_ground
    when :hop
      if b.t == 1
        b.vy = 13.0; b.vx = dir * 3.0 * spd
      elsif b.on_ground && b.t > 3
        boss_idle(50)
      end
    when :pound
      if b.t < 20
        b.vx = 0.0                                   # crouch
      elsif b.t == 20
        b.vy = 21.0
        d[:air] = true
        b.vx = ((p.x - b.x) / 42.0).to_f
        b.vx = 7.0 if b.vx > 7; b.vx = -7.0 if b.vx < -7
      elsif b.on_ground && d[:air] && b.t > 22
        d[:air] = false
        b.vx = 0.0
        @shake = 20
        sfx(:pound)
        waves = angry ? 2 : 1
        waves.times do |i|
          [-1, 1].each do |sd|
            @shots << { k: :wave, x: b.x + b.w / 2 - 20 + sd * 50, y: b.y, w: 40, h: 36,
                        vx: sd * (6.0 + i * 2.5) * spd, vy: 0.0, t: 0 }
          end
        end
        boss_idle(60)
      end
    when :spit
      b.vx = 0.0
      n = angry ? 3 : 1 + (boss_level >= 6 ? 1 : 0)
      if b.t == 24 || (n > 1 && b.t == 38) || (n > 2 && b.t == 52)
        sfx(:spit)
        dx = (p.x - b.x).to_f
        t_air = 50.0
        @shots << { k: :glob, x: b.x + b.w / 2 - 16, y: b.y + 70, w: 32, h: 32,
                    vx: dx / t_air + (b.t - 38) * 0.08, vy: 12.0, t: 0 }
      end
      boss_idle(50) if b.t > 30 + n * 14
    when :summon
      b.vx = 0.0
      if b.t == 30
        sfx(:appear)
        e = Actor.new(:blob, b.x + b.w / 2 - 24, b.y + 60, 48, 40)
        e.active = true
        e.vx = dir * 1.0
        e.vy = 8.0
        e.data[:minion] = true
        @enemies << e
      end
      boss_idle(60) if b.t > 50
    when :charge
      if b.t < 45
        b.vx = 0.0
        b.facing = dir if b.t == 1
        sfx(:warn) if b.t == 1
      else
        b.vx = b.facing * 9.0 * spd
        boss_idle(30) if b.t > 240
      end
    when :stunned
      b.vx = 0.0
      boss_idle(40) if b.t > 70
    when :spikes
      b.vx = 0.0
      d[:warn_spiky] = 40 if b.t == 1
      boss_idle(30) if b.t > 40
    when :bolts
      b.vx = 0.0
      if b.t == 1
        sfx(:warn)
        cnt = angry ? 5 : 3
        cnt.times do |i|
          c = @arena_c + 2 + boss_rand(16)
          c = col_at(p.x + p.w / 2) if i == 0
          @shots << { k: :bolt, x: c * T + 16, y: 700.0, w: 32, h: 40, vx: 0.0, vy: 0.0, t: -i * 12 }
        end
      end
      boss_idle(40) if b.t > 60
    end
    # Rusty ignores the girders: he stays on the arena floor, between the walls
    b.vy -= GRAV_FALL
    b.vy = FALL_MAX if b.vy < FALL_MAX
    b.prev_y = b.y
    b.y += b.vy
    b.on_ground = false
    if b.y <= 128
      b.y = 128.0; b.vy = 0.0; b.on_ground = true
    end
    b.x += b.vx
    lo = (@arena_c + 1) * T + 4; hi = @cols * T - b.w - 4
    if b.x < lo || b.x > hi
      b.x = b.x < lo ? lo.to_f : hi.to_f
      if b.state == :charge
        @shake = 16
        sfx(:pound)
        b.state = :stunned
        b.t = 0
      end
      b.vx = 0.0
    end
    boss_vs_player
    update_shots
  end

  def boss_idle(cd)
    b = @boss
    b.state = :walk
    b.t = 0
    b.data[:cd] = b.data[:angry] ? cd / 2 : cd
  end

  # pick a move: the newest one comes up most often
  def boss_choose
    b = @boss
    known = []
    BOSS_MOVES.each_with_index { |m, i| known << m[0] if i < boss_level && m[0] != :enrage }
    newest = known[-1]
    move = boss_rand(10) < 4 ? newest : known[boss_rand(known.size)]
    move = :hop if move == :summon && @enemies.count { |e| e.data[:minion] && e.state == :walk } >= 2
    move = :hop if move == :spikes && b.data[:spiky] > 0
    b.state = move
    b.t = 0
  end

  def boss_spiky?; @boss.data[:spiky] > 0; end

  def boss_hit(dmg)
    b = @boss
    d = b.data
    return false if d[:inv] > 0 || b.state == :dead
    d[:hp] -= dmg
    d[:inv] = 45
    sfx(:bosshit)
    add_score(500, b.x + 30, b.y + 140)
    if d[:hp] <= 0
      b.state = :dead
      b.t = 0
      b.vy = 14.0
      @shots = []
      @enemies.each { |e| knock(e, 1) if e.data[:minion] && e.state == :walk }
      add_score(5000, b.x + 30, b.y + 170)
      music_stop
      sfx(:bossdie)
    end
    true
  end

  def boss_vs_player
    b = @boss
    p = @p
    return if b.state == :dead || @mode != :play
    return unless overlap?(p, b)
    # a stomp is the player coming down onto him *relative to his motion*, so
    # Rusty hopping up into your feet counts too
    closing = (p.y - p.prev_y) - (b.y - b.prev_y) < 0
    if closing && p.prev_y >= b.prev_y + b.h * 0.6 && !boss_spiky?
      if boss_hit(2)
        p.vy = @in_a ? 18.0 : 14.0
        p.jumping = @in_a
        puff(p.x + p.w / 2, p.y)
      else
        p.vy = 10.0
      end
      p.vx = (p.x + p.w / 2 < b.x + b.w / 2 ? -1 : 1) * 5.0
    elsif rect_hit?(p, b.x + 12, b.y, b.w - 24, b.h - 12)
      hurt
      # shove the player away so one touch is one hit
      p.vx = (p.x + p.w / 2 < b.x + b.w / 2 ? -1 : 1) * 7.0
      p.vy = 8.0 if p.on_ground
    end
  end

  def update_shots
    p = @p
    @shots.each do |s|
      s[:t] += 1
      case s[:k]
      when :wave
        s[:x] += s[:vx]
        s[:dead] = true if s[:x] < @arena_c * T || s[:x] > @cols * T
      when :glob
        s[:vy] -= 0.5
        s[:x] += s[:vx]; s[:y] += s[:vy]
        if s[:y] <= 128 || SOLID[cell(col_at(s[:x] + 16), row_at(s[:y]))]
          s[:dead] = true
          puff(s[:x] + 16, s[:y])
        end
      when :bolt
        next if s[:t] < BOLT_WARN
        s[:vy] -= 0.506   # 0.9, then 25% slower twice
        s[:y] += s[:vy]
        if s[:y] <= 128
          s[:dead] = true
          puff(s[:x] + 16, 128)
          sfx(:bump)
        end
      end
      next if s[:dead] || (s[:k] == :bolt && s[:t] < BOLT_WARN)
      hurt if @mode == :play && rect_hit?(p, s[:x] + 4, s[:y], s[:w] - 8, s[:h] - 4)
      if @wrench && s[:k] == :glob && overlap?(@wrench, Actor.new(:x, s[:x], s[:y], s[:w], s[:h]))
        s[:dead] = true
        puff(s[:x] + 16, s[:y] + 16)
      end
    end
    @shots.reject! { |s| s[:dead] }
  end

  def draw_boss(cam)
    b = @boss
    return unless b
    d = b.data
    @shots.each do |s|
      x = s[:x].to_i - cam
      case s[:k]
      when :wave
        3.times do |i|
          h = 36 - i * 10 + ((s[:t] / 3 + i) % 2) * 6
          rect(x + i * 12 - (s[:vx] > 0 ? 0 : 12), 128, 16, h, [236, 236, 236], 220 - i * 50)
        end
      when :glob then spr('sprites/shots.png', x, s[:y].to_i, 32, 32, 0, 0, 8, 16)
      when :bolt
        if s[:t] < BOLT_WARN
          # a growing black shadow ringed by a flashing red/yellow marker, under a warning beam
          k = s[:t] < 0 ? 0 : s[:t]
          flash = (k / 4).even?
          w = 32 + (k * 48 / BOLT_WARN)
          cx = x + 16
          rect(cx - 16, 128, 32, 592, [232, 40, 40], flash ? 80 : 45) if k > 0
          rect(cx - w / 2 - 8, 124, w + 16, 26, flash ? [252, 220, 40] : [232, 40, 40], 255)
          rect(cx - w / 2, 130, w, 14, [0, 0, 0], 235)
          label(cx, 236, '!', 6, flash ? [252, 220, 40] : [232, 40, 40], true) if k > 0
        else
          spr('sprites/shots.png', x - 8, s[:y].to_i, 48, 48, 8, 0, 8, 16)
        end
      end
    end
    return if d[:inv] > 0 && (d[:inv] / 3).even? && b.state != :dead
    f = case b.state
        when :dead, :stunned then 4
        when :pound then b.t < 20 ? 2 : 3
        when :hop then b.on_ground ? 2 : 3
        when :spit, :summon then 5
        when :charge then b.t < 45 ? 2 : 6
        else d[:angry] ? 6 : (b.t / 12) % 2
        end
    f = 4 if d[:inv] > 0 && b.state != :dead
    x = b.x.to_i - cam - 8
    shake = b.state == :charge && b.t < 45 ? ((b.t / 2) % 2) * 8 - 4 : 0
    a = 255
    spr('sprites/rusty.png', x + shake, b.y.to_i, 128, 112, f * 8, 0, 8, 28, b.facing > 0, a, 0, b.state == :dead)
    if d[:spiky] > 0 || (d[:warn_spiky] > 0 && (d[:warn_spiky] / 4).even?)
      spr('sprites/rusty.png', x + shake, b.y.to_i + 24, 128, 112, 56, 0, 8, 28, false)
    end
  end

  def draw_boss_hud
    b = @boss
    return unless b && b.state != :dead
    return draw_warning if @warning > 0
    return unless @boss_on
    d = b.data
    label(640, 628, 'BIG RUSTY', 3, [252, 240, 160], true)
    w = 16 * d[:max]
    x0 = 640 - w / 2
    rect(x0 - 4, 588, w + 8, 20, [16, 16, 16])
    d[:max].times do |i|
      col = i < d[:hp] ? (d[:angry] ? [244, 120, 24] : [216, 48, 48]) : [60, 60, 60]
      rect(x0 + i * 16 + 2, 592, 12, 12, col)
    end
    return unless @banner > 0
    n = boss_level
    label(640, 470, n == 1 ? 'BIG RUSTY BLOCKS MAIN!!!' : 'BIG RUSTY RETURN!!!', 5, [252, 240, 160], true)
    label(640, 410, "NEW MOVE: #{BOSS_MOVES[n - 1][1]}", 4, [244, 120, 24], true)
  end

  # three red pulses in time with the klaxon wails
  def draw_warning
    k = (WARN_LEN - @warning) % 48
    on = k < 36
    rect(0, 0, VW, PLAY_H, [200, 0, 0], 70 - k * 2) if on
    return unless on || @warning < 16
    rect(0, 340, VW, 240, [0, 0, 0], 150)
    label(640, 560, 'WARNING', 16, [232, 40, 40], true)
    label(640, 412, 'HUGE ENEMY APPROACH', 5, [236, 212, 64], true)
  end
end
