# BIG RUSTY -- the boss at the end of every level. Same boss each time;
# encounter n knows every move from encounters 1..n, and move n is new.
#
# Boss is Rusty himself: his moves, gravity and the arena walls. Game runs
# the fight around him: the warning and gate, his shots, and what touching
# or hitting him does.

# The move table: encounter n knows moves 1..n, and move n is the new one
# the banner names. [state, banner name, the Boss method that runs it]
BOSS_MOVES = [
  [:hop,    'HOP',          :hop],
  [:pound,  'GROUND POUND', :ground_pound],
  [:spit,   'RUST SPIT',    :rust_spit],
  [:summon, 'BLOB BELCH',   :blob_belch],
  [:charge, 'BULL CHARGE',  :bull_charge],
  [:spikes, 'SPIKED CROWN', :spiked_crown],
  [:bolts,  'BOLT STORM',   :bolt_storm],
  [:enrage, 'SHORT FUSE',   :short_fuse],   # not a move: fumes at half health
].freeze
BOLT_WARNING = 64       # frames a bolt's shadow shows before it drops (was 40)
WARN_LENGTH  = 160      # klaxon + WARNING card before each fight
WARN_AHEAD   = 12       # the warning goes off this many tiles before the arena gate
BOSS_WIDTH   = 112
BOSS_HEIGHT  = 104

class Game
  def boss_level = @level.data[:boss] || 1

  def spawn_boss(c, r, seed)
    boss = Boss.new(self, c, r, seed)
    @boss = boss
    @boss_on = false
    @arena_column = boss.arena_column
    @shots = []
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
      8.times { |r| @level.set_cell(@arena_column, r, '#') }   # the gate slams shut
      @sound.play(:bump)
    end
    unless @fight_on
      return if @warning > 0
      @fight_on = true
      @banner = 180
      @sound.music(:boss)
    end
    @banner -= 1 if @banner > 0
    @camera.settle
    boss.update
    if boss.dead?
      reveal_valve if boss.t == 120
    else
      boss_vs_player
    end
    update_shots
  end

  # Rusty is down: the main valve appears between the arena girders
  def reveal_valve
    @goal = Goal.new(@level, @arena_column + 10, 7)
    @sound.play(:appear)
    popup(@goal.x, @level.tile_top(7) + 60, 'MAIN VALVE')
  end

  def boss_hit(damage)
    boss = @boss
    return false if boss.invulnerable? || boss.dead?
    boss.take_hit(damage)
    @sound.play(:bosshit)
    add_score(500, boss.x + 30, boss.y + 140)
    if boss.dead?
      @shots = []
      @enemies.each { |enemy| knock(enemy, 1) if enemy.minion && enemy.walking? }
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
    if closing && player.prev_y >= boss.prev_y + boss.h * 0.6 && !boss.spiky?
      if boss_hit(2)
        player.vy = @controls.jump_held? ? 18.0 : 14.0
        player.jumping = @controls.jump_held?
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
        shot[:dead] = true if shot[:x] < @arena_column * TILE || shot[:x] > @level.width
      when :glob
        shot[:vy] -= 0.5
        shot[:x] += shot[:vx]
        shot[:y] += shot[:vy]
        if shot[:y] <= 128 || SOLID[@level.cell(@level.column_at(shot[:x] + 16), @level.row_at(shot[:y]))]
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
    boss.draw(@screen, camera_x)
  end

  def draw_boss_hud
    boss = @boss
    return unless boss && !boss.dead?
    return draw_warning if @warning > 0
    return unless @boss_on
    @screen.label(640, 628, 'BIG RUSTY', 3, PALE_YELLOW, true)
    max_hp = boss.max_hp
    hp = boss.hp
    w = 16 * max_hp
    left = 640 - w / 2
    @screen.rect(left - 4, 588, w + 8, 20, NEAR_BLACK)
    max_hp.times do |i|
      col = i < hp ? (boss.angry? ? ORANGE : [216, 48, 48]) : DARK_GRAY
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

class Boss < Actor
  FLOOR = 128          # the arena floor: Rusty ignores the girders
  ANGRY_SPEED = 1.5
  HIT_INVULNERABLE = 45   # frames of flashing after a hit

  # the step method for each state: every move in BOSS_MOVES, plus waiting
  # out the banner, walking between moves, and reeling after a charge
  STEPS = { wait: :wait_for_banner, walk: :walk, stunned: :reel }
  BOSS_MOVES.each { |state, _name, step| STEPS[state] = step unless state == :enrage }
  STEPS.freeze

  attr_reader :encounter, :arena_column, :max_hp
  # hp left; the rest count down frames: flashing after a hit, the spiked
  # crown, its warning flash, and the walk before the next move
  attr_accessor :hp, :invulnerable, :spiky, :warn_spiky, :cooldown
  attr_writer :angry   # fuming (SHORT FUSE): faster, shorter cooldowns

  def initialize(game, c, r, seed)
    level = game.level
    super(:boss, c * TILE - 24, level.tile_bottom(r), BOSS_WIDTH, BOSS_HEIGHT)
    @game = game
    @level = level
    @encounter = level.data[:boss] || 1
    @arena_column = level.columns - 20
    @rng = seed          # Rusty's own LCG: fights replay the same
    @max_hp = @hp = 6 + @encounter
    @invulnerable = 0
    @cooldown = 90
    @spiky = 0
    @warn_spiky = 0
    @angry = false
    @airborne = false    # in the leap of a ground pound
    @state = :wait
  end

  def knows?(move) = BOSS_MOVES.index { |entry| entry[0] == move } < @encounter
  def spiky? = @spiky > 0
  def invulnerable? = @invulnerable > 0
  def angry? = @angry

  def take_hit(damage)
    @hp -= damage
    @invulnerable = HIT_INVULNERABLE
    return if @hp > 0
    @state = :dead
    @t = 0
    @vy = 14.0
  end

  # one step of the fight
  def update
    @invulnerable -= 1 if @invulnerable > 0
    @t += 1
    if dead?
      @vy -= 0.6
      @y += @vy
      return
    end
    angry = @angry   # this step's moves go at the speed he started it with
    short_fuse if knows?(:enrage) && !angry && @hp * 2 <= @max_hp
    @spiky -= 1 if @spiky > 0
    @warn_spiky -= 1 if @warn_spiky > 0
    @spiky = (angry ? 220 : 160) if @warn_spiky == 1
    player = @game.player
    dir = player.x + player.w / 2 > @x + @w / 2 ? 1 : -1
    send(STEPS[@state], dir, angry)
    move_in_arena
  end

  def draw(screen, camera_x)
    return if invulnerable? && (@invulnerable / 3).even? && !dead?
    source = case @state
             when :dead, :stunned then FRAMES[:rusty_hurt]
             when :pound then FRAMES[@t < 20 ? :rusty_crouch : :rusty_air]
             when :hop then FRAMES[@on_ground ? :rusty_crouch : :rusty_air]
             when :spit, :summon then FRAMES[:rusty_mouth]
             when :charge then FRAMES[@t < 45 ? :rusty_crouch : :rusty_angry]
             else @angry ? FRAMES[:rusty_angry] : frame(:rusty_walk, (@t / 12) % 2)
             end
    source = FRAMES[:rusty_hurt] if invulnerable? && !dead?
    x = @x.to_i - camera_x - 8
    shake = @state == :charge && @t < 45 ? ((@t / 2) % 2) * 8 - 4 : 0
    screen.sprite('sprites/rusty.png', x + shake, @y.to_i, 128, 112, source, flip: @facing > 0, alpha: 255, flip_v: dead?)
    if spiky? || (@warn_spiky > 0 && (@warn_spiky / 4).even?)
      screen.sprite('sprites/rusty.png', x + shake, @y.to_i + 24, 128, 112, FRAMES[:rusty_crown])
    end
  end

  private

  def sound = @game.sound

  def rand_below(n)
    @rng = (@rng * 75 + 74) % 65537
    @rng % n
  end

  def pace(angry) = angry ? ANGRY_SPEED : 1.0

  # back to walking, with a cooldown before the next move
  def idle(cooldown)
    @state = :walk
    @t = 0
    @cooldown = @angry ? cooldown / 2 : cooldown
  end

  # pick a move: the newest one comes up most often
  def choose_move
    known = []
    BOSS_MOVES.each_with_index { |entry, i| known << entry[0] if i < @encounter && entry[0] != :enrage }
    newest = known[-1]
    move = rand_below(10) < 4 ? newest : known[rand_below(known.size)]
    move = :hop if move == :summon && @game.enemies.count { |enemy| enemy.minion && enemy.walking? } >= 2
    move = :hop if move == :spikes && spiky?
    @state = move
    @t = 0
  end

  # SHORT FUSE: at half health he fumes, and moves faster from then on
  def short_fuse
    @angry = true
    @game.popup(@x, @y + 140, 'RUSTY IS FUMING!')
    sound.play(:warn)
    sound.music_pitch = 1.2
  end

  # stands still until the banner has been up a second
  def wait_for_banner(dir, angry)
    @vx = 0.0
    @state = :walk if @game.banner < 120
  end

  # walks at the player until the cooldown runs out, then picks a move
  def walk(dir, angry)
    speed = pace(angry)
    @facing = dir
    @vx = dir * 1.3 * speed
    @cooldown -= 1
    choose_move if @cooldown <= 0 && @on_ground
  end

  # a short hop toward the player
  def hop(dir, angry)
    speed = pace(angry)
    if @t == 1
      @vy = 13.0
      @vx = dir * 3.0 * speed
    elsif @on_ground && @t > 3
      idle(50)
    end
  end

  # crouch, leap at the player, and land sending steam waves along the floor
  def ground_pound(dir, angry)
    speed = pace(angry)
    if @t < 20
      @vx = 0.0   # crouch
    elsif @t == 20
      @vy = 21.0
      @airborne = true
      @vx = ((@game.player.x - @x) / 42.0).to_f
      @vx = 7.0 if @vx > 7
      @vx = -7.0 if @vx < -7
    elsif @on_ground && @airborne && @t > 22
      @airborne = false
      @vx = 0.0
      @game.camera.shake(20)
      sound.play(:pound)
      waves = angry ? 2 : 1
      waves.times do |i|
        [-1, 1].each do |side|
          @game.shots << { k: :wave, x: @x + @w / 2 - 20 + side * 50, y: @y, w: 40, h: 36,
                           vx: side * (6.0 + i * 2.5) * speed, vy: 0.0, t: 0 }
        end
      end
      idle(60)
    end
  end

  # lobs globs of rust at the player (more when angry, or from encounter 6)
  def rust_spit(dir, angry)
    @vx = 0.0
    n = angry ? 3 : 1 + (@encounter >= 6 ? 1 : 0)
    if @t == 24 || (n > 1 && @t == 38) || (n > 2 && @t == 52)
      sound.play(:spit)
      dx = (@game.player.x - @x).to_f
      t_air = 50.0
      @game.shots << { k: :glob, x: @x + @w / 2 - 16, y: @y + 70, w: 32, h: 32,
                       vx: dx / t_air + (@t - 38) * 0.08, vy: 12.0, t: 0 }
    end
    idle(50) if @t > 30 + n * 14
  end

  # coughs up a minion Blob
  def blob_belch(dir, angry)
    @vx = 0.0
    if @t == 30
      sound.play(:appear)
      @game.enemies << Blob.minion(@x + @w / 2 - 24, @y + 60, dir)
    end
    idle(60) if @t > 50
  end

  # shakes, then charges until he hits a wall (and is stunned)
  def bull_charge(dir, angry)
    speed = pace(angry)
    if @t < 45
      @vx = 0.0
      @facing = dir if @t == 1
      sound.play(:warn) if @t == 1
    else
      @vx = @facing * 9.0 * speed
      idle(30) if @t > 240
    end
  end

  # stunned after charging into a wall
  def reel(dir, angry)
    @vx = 0.0
    idle(40) if @t > 70
  end

  # warns, then grows a spiked crown: no stomping for a while
  def spiked_crown(dir, angry)
    @vx = 0.0
    @warn_spiky = 40 if @t == 1
    idle(30) if @t > 40
  end

  # bolts drop on shadows, the first one on the player
  def bolt_storm(dir, angry)
    @vx = 0.0
    if @t == 1
      sound.play(:warn)
      count = angry ? 5 : 3
      count.times do |i|
        c = @arena_column + 2 + rand_below(16)
        c = @level.column_at(@game.player.x + @game.player.w / 2) if i == 0
        @game.shots << { k: :bolt, x: c * TILE + 16, y: 700.0, w: 32, h: 40, vx: 0.0, vy: 0.0, t: -i * 12 }
      end
    end
    idle(40) if @t > 60
  end

  # gravity, the arena floor and walls; a charge into a wall stuns him
  def move_in_arena
    @game.fall(self)
    @prev_y = @y
    @y += @vy
    @on_ground = false
    if @y <= FLOOR
      @y = FLOOR.to_f
      @vy = 0.0
      @on_ground = true
    end
    @x += @vx
    min_x = (@arena_column + 1) * TILE + 4
    max_x = @level.width - @w - 4
    if @x < min_x || @x > max_x
      @x = @x < min_x ? min_x.to_f : max_x.to_f
      if @state == :charge
        @game.camera.shake(16)
        sound.play(:pound)
        @state = :stunned
        @t = 0
      end
      @vx = 0.0
    end
  end
end
