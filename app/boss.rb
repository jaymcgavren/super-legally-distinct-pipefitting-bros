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
BOLT_WARNING = 64       # frames a bolt's shadow shows before it drops (was 40)
WARN_LENGTH  = 160      # klaxon + WARNING card before each fight
WARN_AHEAD   = 12       # the warning goes off this many tiles before the arena gate
BOSS_WIDTH   = 112
BOSS_HEIGHT  = 104

class Game
  def boss_rand(n)
    @rng = (@rng * 75 + 74) % 65537
    @rng % n
  end

  def boss_level = @lv[:boss] || 1
  def boss_knows?(move) = BOSS_MOVES.index { |m| m[0] == move } < boss_level

  def spawn_boss(c, r)
    boss = Actor.new(:boss, c * TILE - 24, tile_bottom(r), BOSS_WIDTH, BOSS_HEIGHT)
    hp = 6 + boss_level
    boss.data = { hp: hp, max: hp, inv: 0, cd: 90, spiky: 0, warn_spiky: 0, angry: false, minions: 0 }
    boss.state = :wait
    @boss = boss
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
    boss = @boss
    return unless boss
    player = @p
    # the warning goes off on the approach, while the player can still look
    # before stepping in; the gate shuts once they are inside the arena
    unless @boss_warned
      return unless player.x > (@arena_c - WARN_AHEAD) * TILE
      @boss_warned = true
      @warning = WARN_LENGTH
      sfx(:klaxon)
      music_stop
    end
    @warning -= 1 if @warning > 0
    unless @boss_on
      return unless player.x > (@arena_c + 2) * TILE
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
    d = boss.data
    d[:inv] -= 1 if d[:inv] > 0
    boss.t += 1
    if boss.state == :dead
      boss.vy -= 0.6
      boss.y += boss.vy
      if boss.t == 120
        @goal = { c: @arena_c + 10, r: 7, turn: 0 }   # between the arena girders
        sfx(:appear)
        popup(@goal[:c] * TILE, tile_top(7) + 60, 'MAIN VALVE')
      end
      update_shots
      return
    end
    angry = d[:angry]
    spd = angry ? 1.5 : 1.0
    if boss_knows?(:enrage) && !angry && d[:hp] * 2 <= d[:max]
      d[:angry] = true
      popup(boss.x, boss.y + 140, 'RUSTY IS FUMING!')
      sfx(:warn)
      m = @args.audio[:music]
      m[:pitch] = 1.2 if m
    end
    d[:spiky] -= 1 if d[:spiky] > 0
    d[:warn_spiky] -= 1 if d[:warn_spiky] > 0
    d[:spiky] = (angry ? 220 : 160) if d[:warn_spiky] == 1
    dir = player.x + player.w / 2 > boss.x + boss.w / 2 ? 1 : -1
    case boss.state
    when :wait
      boss.vx = 0.0
      boss.state = :walk if @banner < 120
    when :walk
      boss.facing = dir
      boss.vx = dir * 1.3 * spd
      d[:cd] -= 1
      boss_choose if d[:cd] <= 0 && boss.on_ground
    when :hop
      if boss.t == 1
        boss.vy = 13.0
        boss.vx = dir * 3.0 * spd
      elsif boss.on_ground && boss.t > 3
        boss_idle(50)
      end
    when :pound
      if boss.t < 20
        boss.vx = 0.0                                   # crouch
      elsif boss.t == 20
        boss.vy = 21.0
        d[:air] = true
        boss.vx = ((player.x - boss.x) / 42.0).to_f
        boss.vx = 7.0 if boss.vx > 7
        boss.vx = -7.0 if boss.vx < -7
      elsif boss.on_ground && d[:air] && boss.t > 22
        d[:air] = false
        boss.vx = 0.0
        @shake = 20
        sfx(:pound)
        waves = angry ? 2 : 1
        waves.times do |i|
          [-1, 1].each do |sd|
            @shots << { k: :wave, x: boss.x + boss.w / 2 - 20 + sd * 50, y: boss.y, w: 40, h: 36,
                        vx: sd * (6.0 + i * 2.5) * spd, vy: 0.0, t: 0 }
          end
        end
        boss_idle(60)
      end
    when :spit
      boss.vx = 0.0
      n = angry ? 3 : 1 + (boss_level >= 6 ? 1 : 0)
      if boss.t == 24 || (n > 1 && boss.t == 38) || (n > 2 && boss.t == 52)
        sfx(:spit)
        dx = (player.x - boss.x).to_f
        t_air = 50.0
        @shots << { k: :glob, x: boss.x + boss.w / 2 - 16, y: boss.y + 70, w: 32, h: 32,
                    vx: dx / t_air + (boss.t - 38) * 0.08, vy: 12.0, t: 0 }
      end
      boss_idle(50) if boss.t > 30 + n * 14
    when :summon
      boss.vx = 0.0
      if boss.t == 30
        sfx(:appear)
        enemy = Actor.new(:blob, boss.x + boss.w / 2 - 24, boss.y + 60, 48, 40)
        enemy.active = true
        enemy.vx = dir * 1.0
        enemy.vy = 8.0
        enemy.data[:minion] = true
        @enemies << enemy
      end
      boss_idle(60) if boss.t > 50
    when :charge
      if boss.t < 45
        boss.vx = 0.0
        boss.facing = dir if boss.t == 1
        sfx(:warn) if boss.t == 1
      else
        boss.vx = boss.facing * 9.0 * spd
        boss_idle(30) if boss.t > 240
      end
    when :stunned
      boss.vx = 0.0
      boss_idle(40) if boss.t > 70
    when :spikes
      boss.vx = 0.0
      d[:warn_spiky] = 40 if boss.t == 1
      boss_idle(30) if boss.t > 40
    when :bolts
      boss.vx = 0.0
      if boss.t == 1
        sfx(:warn)
        cnt = angry ? 5 : 3
        cnt.times do |i|
          c = @arena_c + 2 + boss_rand(16)
          c = col_at(player.x + player.w / 2) if i == 0
          @shots << { k: :bolt, x: c * TILE + 16, y: 700.0, w: 32, h: 40, vx: 0.0, vy: 0.0, t: -i * 12 }
        end
      end
      boss_idle(40) if boss.t > 60
    end
    # Rusty ignores the girders: he stays on the arena floor, between the walls
    boss.vy -= GRAVITY_FALL
    boss.vy = FALL_MAX if boss.vy < FALL_MAX
    boss.prev_y = boss.y
    boss.y += boss.vy
    boss.on_ground = false
    if boss.y <= 128
      boss.y = 128.0
      boss.vy = 0.0
      boss.on_ground = true
    end
    boss.x += boss.vx
    lo = (@arena_c + 1) * TILE + 4
    hi = @cols * TILE - boss.w - 4
    if boss.x < lo || boss.x > hi
      boss.x = boss.x < lo ? lo.to_f : hi.to_f
      if boss.state == :charge
        @shake = 16
        sfx(:pound)
        boss.state = :stunned
        boss.t = 0
      end
      boss.vx = 0.0
    end
    boss_vs_player
    update_shots
  end

  def boss_idle(cd)
    boss = @boss
    boss.state = :walk
    boss.t = 0
    boss.data[:cd] = boss.data[:angry] ? cd / 2 : cd
  end

  # pick a move: the newest one comes up most often
  def boss_choose
    boss = @boss
    known = []
    BOSS_MOVES.each_with_index { |m, i| known << m[0] if i < boss_level && m[0] != :enrage }
    newest = known[-1]
    move = boss_rand(10) < 4 ? newest : known[boss_rand(known.size)]
    move = :hop if move == :summon && @enemies.count { |enemy| enemy.data[:minion] && enemy.state == :walk } >= 2
    move = :hop if move == :spikes && boss.data[:spiky] > 0
    boss.state = move
    boss.t = 0
  end

  def boss_spiky? = @boss.data[:spiky] > 0

  def boss_hit(dmg)
    boss = @boss
    d = boss.data
    return false if d[:inv] > 0 || boss.state == :dead
    d[:hp] -= dmg
    d[:inv] = 45
    sfx(:bosshit)
    add_score(500, boss.x + 30, boss.y + 140)
    if d[:hp] <= 0
      boss.state = :dead
      boss.t = 0
      boss.vy = 14.0
      @shots = []
      @enemies.each { |enemy| knock(enemy, 1) if enemy.data[:minion] && enemy.state == :walk }
      add_score(5000, boss.x + 30, boss.y + 170)
      music_stop
      sfx(:bossdie, 0.75)
    end
    true
  end

  def boss_vs_player
    boss = @boss
    player = @p
    return if boss.state == :dead || @mode != :play
    return unless overlap?(player, boss)
    # a stomp is the player coming down onto him *relative to his motion*, so
    # Rusty hopping up into your feet counts too
    closing = (player.y - player.prev_y) - (boss.y - boss.prev_y) < 0
    if closing && player.prev_y >= boss.prev_y + boss.h * 0.6 && !boss_spiky?
      if boss_hit(2)
        player.vy = @in_a ? 18.0 : 14.0
        player.jumping = @in_a
        puff(player.x + player.w / 2, player.y)
      else
        player.vy = 10.0
      end
      player.vx = (player.x + player.w / 2 < boss.x + boss.w / 2 ? -1 : 1) * 5.0
    elsif rect_hit?(player, boss.x + 12, boss.y, boss.w - 24, boss.h - 12)
      hurt
      # shove the player away so one touch is one hit
      player.vx = (player.x + player.w / 2 < boss.x + boss.w / 2 ? -1 : 1) * 7.0
      player.vy = 8.0 if player.on_ground
    end
  end

  def update_shots
    player = @p
    @shots.each do |s|
      s[:t] += 1
      case s[:k]
      when :wave
        s[:x] += s[:vx]
        s[:dead] = true if s[:x] < @arena_c * TILE || s[:x] > @cols * TILE
      when :glob
        s[:vy] -= 0.5
        s[:x] += s[:vx]
        s[:y] += s[:vy]
        if s[:y] <= 128 || SOLID[cell(col_at(s[:x] + 16), row_at(s[:y]))]
          s[:dead] = true
          puff(s[:x] + 16, s[:y])
        end
      when :bolt
        next if s[:t] < BOLT_WARNING
        s[:vy] -= 0.506   # 0.9, then 25% slower twice
        s[:y] += s[:vy]
        if s[:y] <= 128
          s[:dead] = true
          puff(s[:x] + 16, 128)
          sfx(:bump)
        end
      end
      next if s[:dead] || (s[:k] == :bolt && s[:t] < BOLT_WARNING)
      hurt if @mode == :play && rect_hit?(player, s[:x] + 4, s[:y], s[:w] - 8, s[:h] - 4)
      if @wrench && s[:k] == :glob && overlap?(@wrench, Actor.new(:x, s[:x], s[:y], s[:w], s[:h]))
        s[:dead] = true
        puff(s[:x] + 16, s[:y] + 16)
      end
    end
    @shots.reject! { |s| s[:dead] }
  end

  def draw_boss(cam)
    boss = @boss
    return unless boss
    d = boss.data
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
        if s[:t] < BOLT_WARNING
          # a growing black shadow ringed by a flashing red/yellow marker, under a warning beam
          k = s[:t] < 0 ? 0 : s[:t]
          flash = (k / 4).even?
          w = 32 + (k * 48 / BOLT_WARNING)
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
    return if d[:inv] > 0 && (d[:inv] / 3).even? && boss.state != :dead
    f = case boss.state
        when :dead, :stunned then 4
        when :pound then boss.t < 20 ? 2 : 3
        when :hop then boss.on_ground ? 2 : 3
        when :spit, :summon then 5
        when :charge then boss.t < 45 ? 2 : 6
        else d[:angry] ? 6 : (boss.t / 12) % 2
        end
    f = 4 if d[:inv] > 0 && boss.state != :dead
    x = boss.x.to_i - cam - 8
    shake = boss.state == :charge && boss.t < 45 ? ((boss.t / 2) % 2) * 8 - 4 : 0
    a = 255
    spr('sprites/rusty.png', x + shake, boss.y.to_i, 128, 112, f * 8, 0, 8, 28, boss.facing > 0, a, 0, boss.state == :dead)
    if d[:spiky] > 0 || (d[:warn_spiky] > 0 && (d[:warn_spiky] / 4).even?)
      spr('sprites/rusty.png', x + shake, boss.y.to_i + 24, 128, 112, 56, 0, 8, 28, false)
    end
  end

  def draw_boss_hud
    boss = @boss
    return unless boss && boss.state != :dead
    return draw_warning if @warning > 0
    return unless @boss_on
    d = boss.data
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
    k = (WARN_LENGTH - @warning) % 48
    on = k < 36
    rect(0, 0, VIEW_WIDTH, PLAY_HEIGHT, [200, 0, 0], 70 - k * 2) if on
    return unless on || @warning < 16
    rect(0, 340, VIEW_WIDTH, 240, [0, 0, 0], 150)
    label(640, 560, 'WARNING', 16, [232, 40, 40], true)
    label(640, 412, 'HUGE ENEMY APPROACH', 5, [236, 212, 64], true)
  end
end
