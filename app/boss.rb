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
].freeze
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

  def boss_level = @level_data[:boss] || 1
  def boss_knows?(move) = BOSS_MOVES.index { |entry| entry[0] == move } < boss_level

  def spawn_boss(c, r)
    boss = Actor.new(:boss, c * TILE - 24, tile_bottom(r), BOSS_WIDTH, BOSS_HEIGHT)
    hp = 6 + boss_level
    boss.data = { hp: hp, max: hp, inv: 0, cd: 90, spiky: 0, warn_spiky: 0, angry: false, minions: 0 }
    boss.state = :wait
    @boss = boss
    @boss_on = false
    @arena_column = @cols - 20
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
    player = @player
    # the warning goes off on the approach, while the player can still look
    # before stepping in; the gate shuts once they are inside the arena
    unless @boss_warned
      return unless player.x > (@arena_column - WARN_AHEAD) * TILE
      @boss_warned = true
      @warning = WARN_LENGTH
      @sound.play(:klaxon)
      @sound.stop_music
    end
    @warning -= 1 if @warning > 0
    unless @boss_on
      return unless player.x > (@arena_column + 2) * TILE
      @boss_on = true
      8.times { |r| @grid[r][@arena_column] = '#' }   # the gate slams shut
      @sound.play(:bump)
    end
    unless @fight_on
      return if @warning > 0
      @fight_on = true
      @banner = 180
      @sound.music(:boss)
    end
    @banner -= 1 if @banner > 0
    @shake -= 1 if @shake > 0
    data = boss.data
    data[:inv] -= 1 if data[:inv] > 0
    boss.t += 1
    if boss.dead?
      boss.vy -= 0.6
      boss.y += boss.vy
      if boss.t == 120
        @goal = { c: @arena_column + 10, r: 7, turn: 0 }   # between the arena girders
        @sound.play(:appear)
        popup(@goal[:c] * TILE, tile_top(7) + 60, 'MAIN VALVE')
      end
      update_shots
      return
    end
    angry = data[:angry]
    speed = angry ? 1.5 : 1.0
    if boss_knows?(:enrage) && !angry && data[:hp] * 2 <= data[:max]
      data[:angry] = true
      popup(boss.x, boss.y + 140, 'RUSTY IS FUMING!')
      @sound.play(:warn)
      @sound.music_pitch = 1.2
    end
    data[:spiky] -= 1 if data[:spiky] > 0
    data[:warn_spiky] -= 1 if data[:warn_spiky] > 0
    data[:spiky] = (angry ? 220 : 160) if data[:warn_spiky] == 1
    dir = player.x + player.w / 2 > boss.x + boss.w / 2 ? 1 : -1
    case boss.state
    when :wait
      boss.vx = 0.0
      boss.state = :walk if @banner < 120
    when :walk
      boss.facing = dir
      boss.vx = dir * 1.3 * speed
      data[:cd] -= 1
      boss_choose if data[:cd] <= 0 && boss.on_ground
    when :hop
      if boss.t == 1
        boss.vy = 13.0
        boss.vx = dir * 3.0 * speed
      elsif boss.on_ground && boss.t > 3
        boss_idle(50)
      end
    when :pound
      if boss.t < 20
        boss.vx = 0.0                                   # crouch
      elsif boss.t == 20
        boss.vy = 21.0
        data[:air] = true
        boss.vx = ((player.x - boss.x) / 42.0).to_f
        boss.vx = 7.0 if boss.vx > 7
        boss.vx = -7.0 if boss.vx < -7
      elsif boss.on_ground && data[:air] && boss.t > 22
        data[:air] = false
        boss.vx = 0.0
        @shake = 20
        @sound.play(:pound)
        waves = angry ? 2 : 1
        waves.times do |i|
          [-1, 1].each do |side|
            @shots << { k: :wave, x: boss.x + boss.w / 2 - 20 + side * 50, y: boss.y, w: 40, h: 36,
                        vx: side * (6.0 + i * 2.5) * speed, vy: 0.0, t: 0 }
          end
        end
        boss_idle(60)
      end
    when :spit
      boss.vx = 0.0
      n = angry ? 3 : 1 + (boss_level >= 6 ? 1 : 0)
      if boss.t == 24 || (n > 1 && boss.t == 38) || (n > 2 && boss.t == 52)
        @sound.play(:spit)
        dx = (player.x - boss.x).to_f
        t_air = 50.0
        @shots << { k: :glob, x: boss.x + boss.w / 2 - 16, y: boss.y + 70, w: 32, h: 32,
                    vx: dx / t_air + (boss.t - 38) * 0.08, vy: 12.0, t: 0 }
      end
      boss_idle(50) if boss.t > 30 + n * 14
    when :summon
      boss.vx = 0.0
      if boss.t == 30
        @sound.play(:appear)
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
        @sound.play(:warn) if boss.t == 1
      else
        boss.vx = boss.facing * 9.0 * speed
        boss_idle(30) if boss.t > 240
      end
    when :stunned
      boss.vx = 0.0
      boss_idle(40) if boss.t > 70
    when :spikes
      boss.vx = 0.0
      data[:warn_spiky] = 40 if boss.t == 1
      boss_idle(30) if boss.t > 40
    when :bolts
      boss.vx = 0.0
      if boss.t == 1
        @sound.play(:warn)
        count = angry ? 5 : 3
        count.times do |i|
          c = @arena_column + 2 + boss_rand(16)
          c = column_at(player.x + player.w / 2) if i == 0
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
    min_x = (@arena_column + 1) * TILE + 4
    max_x = @cols * TILE - boss.w - 4
    if boss.x < min_x || boss.x > max_x
      boss.x = boss.x < min_x ? min_x.to_f : max_x.to_f
      if boss.state == :charge
        @shake = 16
        @sound.play(:pound)
        boss.state = :stunned
        boss.t = 0
      end
      boss.vx = 0.0
    end
    boss_vs_player
    update_shots
  end

  def boss_idle(cooldown)
    boss = @boss
    boss.state = :walk
    boss.t = 0
    boss.data[:cd] = boss.data[:angry] ? cooldown / 2 : cooldown
  end

  # pick a move: the newest one comes up most often
  def boss_choose
    boss = @boss
    known = []
    BOSS_MOVES.each_with_index { |entry, i| known << entry[0] if i < boss_level && entry[0] != :enrage }
    newest = known[-1]
    move = boss_rand(10) < 4 ? newest : known[boss_rand(known.size)]
    move = :hop if move == :summon && @enemies.count { |enemy| enemy.data[:minion] && enemy.walking? } >= 2
    move = :hop if move == :spikes && boss_spiky?
    boss.state = move
    boss.t = 0
  end

  def boss_spiky? = @boss.data[:spiky] > 0
  def boss_invulnerable? = @boss.data[:inv] > 0

  def boss_hit(damage)
    boss = @boss
    data = boss.data
    return false if boss_invulnerable? || boss.dead?
    data[:hp] -= damage
    data[:inv] = 45
    @sound.play(:bosshit)
    add_score(500, boss.x + 30, boss.y + 140)
    if data[:hp] <= 0
      boss.state = :dead
      boss.t = 0
      boss.vy = 14.0
      @shots = []
      @enemies.each { |enemy| knock(enemy, 1) if enemy.data[:minion] && enemy.walking? }
      add_score(5000, boss.x + 30, boss.y + 170)
      @sound.stop_music
      @sound.play(:bossdie, 0.75)
    end
    true
  end

  def boss_vs_player
    boss = @boss
    player = @player
    return if boss.dead? || !playing?
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
    player = @player
    @shots.each do |shot|
      shot[:t] += 1
      case shot[:k]
      when :wave
        shot[:x] += shot[:vx]
        shot[:dead] = true if shot[:x] < @arena_column * TILE || shot[:x] > @cols * TILE
      when :glob
        shot[:vy] -= 0.5
        shot[:x] += shot[:vx]
        shot[:y] += shot[:vy]
        if shot[:y] <= 128 || SOLID[cell(column_at(shot[:x] + 16), row_at(shot[:y]))]
          shot[:dead] = true
          puff(shot[:x] + 16, shot[:y])
        end
      when :bolt
        next if shot[:t] < BOLT_WARNING
        shot[:vy] -= 0.506   # 0.9, then 25% slower twice
        shot[:y] += shot[:vy]
        if shot[:y] <= 128
          shot[:dead] = true
          puff(shot[:x] + 16, 128)
          @sound.play(:bump)
        end
      end
      next if shot[:dead] || (shot[:k] == :bolt && shot[:t] < BOLT_WARNING)
      hurt if playing? && rect_hit?(player, shot[:x] + 4, shot[:y], shot[:w] - 8, shot[:h] - 4)
      if @wrench && shot[:k] == :glob && overlap?(@wrench, Actor.new(:x, shot[:x], shot[:y], shot[:w], shot[:h]))
        shot[:dead] = true
        puff(shot[:x] + 16, shot[:y] + 16)
      end
    end
    @shots.reject! { |shot| shot[:dead] }
  end

  def draw_boss(camera_x)
    boss = @boss
    return unless boss
    data = boss.data
    @shots.each do |shot|
      x = shot[:x].to_i - camera_x
      case shot[:k]
      when :wave
        3.times do |i|
          h = 36 - i * 10 + ((shot[:t] / 3 + i) % 2) * 6
          @screen.rect(x + i * 12 - (shot[:vx] > 0 ? 0 : 12), 128, 16, h, STEAM, 220 - i * 50)
        end
      when :glob then @screen.sprite('sprites/shots.png', x, shot[:y].to_i, 32, 32, FRAMES[:glob])
      when :bolt
        if shot[:t] < BOLT_WARNING
          # a growing black shadow ringed by a flashing red/yellow marker, under a warning beam
          k = shot[:t] < 0 ? 0 : shot[:t]
          flash = (k / 4).even?
          w = 32 + (k * 48 / BOLT_WARNING)
          cx = x + 16
          @screen.rect(cx - 16, 128, 32, 592, WARNING_RED, flash ? 80 : 45) if k > 0
          @screen.rect(cx - w / 2 - 8, 124, w + 16, 26, flash ? WARNING_YELLOW : WARNING_RED, 255)
          @screen.rect(cx - w / 2, 130, w, 14, BLACK, 235)
          @screen.label(cx, 236, '!', 6, flash ? WARNING_YELLOW : WARNING_RED, true) if k > 0
        else
          @screen.sprite('sprites/shots.png', x - 8, shot[:y].to_i, 48, 48, FRAMES[:bolt])
        end
      end
    end
    return if boss_invulnerable? && (data[:inv] / 3).even? && !boss.dead?
    source = case boss.state
             when :dead, :stunned then FRAMES[:rusty_hurt]
             when :pound then FRAMES[boss.t < 20 ? :rusty_crouch : :rusty_air]
             when :hop then FRAMES[boss.on_ground ? :rusty_crouch : :rusty_air]
             when :spit, :summon then FRAMES[:rusty_mouth]
             when :charge then FRAMES[boss.t < 45 ? :rusty_crouch : :rusty_angry]
             else data[:angry] ? FRAMES[:rusty_angry] : frame(:rusty_walk, (boss.t / 12) % 2)
             end
    source = FRAMES[:rusty_hurt] if boss_invulnerable? && !boss.dead?
    x = boss.x.to_i - camera_x - 8
    shake = boss.state == :charge && boss.t < 45 ? ((boss.t / 2) % 2) * 8 - 4 : 0
    alpha = 255
    @screen.sprite('sprites/rusty.png', x + shake, boss.y.to_i, 128, 112, source, flip: boss.facing > 0, alpha: alpha, flip_v: boss.dead?)
    if boss_spiky? || (data[:warn_spiky] > 0 && (data[:warn_spiky] / 4).even?)
      @screen.sprite('sprites/rusty.png', x + shake, boss.y.to_i + 24, 128, 112, FRAMES[:rusty_crown])
    end
  end

  def draw_boss_hud
    boss = @boss
    return unless boss && !boss.dead?
    return draw_warning if @warning > 0
    return unless @boss_on
    data = boss.data
    @screen.label(640, 628, 'BIG RUSTY', 3, PALE_YELLOW, true)
    w = 16 * data[:max]
    left = 640 - w / 2
    @screen.rect(left - 4, 588, w + 8, 20, NEAR_BLACK)
    data[:max].times do |i|
      col = i < data[:hp] ? (data[:angry] ? ORANGE : [216, 48, 48]) : DARK_GRAY
      @screen.rect(left + i * 16 + 2, 592, 12, 12, col)
    end
    return unless @banner > 0
    n = boss_level
    @screen.label(640, 470, n == 1 ? 'BIG RUSTY BLOCKS MAIN!!!' : 'BIG RUSTY RETURN!!!', 5, PALE_YELLOW, true)
    @screen.label(640, 410, "NEW MOVE: #{BOSS_MOVES[n - 1][1]}", 4, ORANGE, true)
  end

  # three red pulses in time with the klaxon wails
  def draw_warning
    k = (WARN_LENGTH - @warning) % 48
    on = k < 36
    @screen.rect(0, 0, VIEW_WIDTH, PLAY_HEIGHT, [200, 0, 0], 70 - k * 2) if on
    return unless on || @warning < 16
    @screen.rect(0, 340, VIEW_WIDTH, 240, BLACK, 150)
    @screen.label(640, 560, 'WARNING', 16, WARNING_RED, true)
    @screen.label(640, 412, 'HUGE ENEMY APPROACH', 5, GOLD, true)
  end
end
