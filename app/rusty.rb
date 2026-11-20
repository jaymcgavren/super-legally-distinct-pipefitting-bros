# BIG RUSTY -- the boss at the end of every level. Same boss each time;
# encounter n knows every move from encounters 1..n, and move n is new.
#
# Rusty (the class) is Big Rusty himself: his moves, gravity and the arena
# walls. Game (game.rb) runs the fight around him: the warning and gate,
# his shots, and what touching or hitting him does.

# The move table: encounter n knows moves 1..n, and move n is the new one
# the banner names. [state, banner name, the Rusty method that runs it]
BOSS_MOVES = [
  [:hop,    'HOP',          :hop],
  [:pound,  'GROUND POUND', :ground_pound],
  [:spit,   'RUST SPIT',    :rust_spit],
  [:summon, 'BLOB BELCH',   :blob_belch],
  [:charge, 'BULL CHARGE',  :bull_charge],
  [:spikes, 'SPIKED CROWN', :spiked_crown],
  [:bolts,  'BOLT STORM',   :bolt_storm],
  [:enrage, 'SHORT FUSE',   :short_fuse]   # not a move: fumes at half health
].freeze
BOLT_WARNING = 64       # frames a bolt's shadow shows before it drops (was 40)
WARN_LENGTH  = 160      # klaxon + WARNING card before each fight
WARN_AHEAD   = 12       # the warning goes off this many tiles before the arena gate
BOSS_WIDTH   = 112
BOSS_HEIGHT  = 104

class Rusty < Actor
  FLOOR = 128          # the arena floor: Rusty ignores the girders
  ANGRY_SPEED = 1.5
  HIT_INVULNERABLE = 45   # frames of flashing after a hit

  # the step method for each state: every move in BOSS_MOVES, plus waiting
  # out the banner, walking between moves, and reeling after a charge
  STEPS = { wait: :wait_for_banner, walk: :walk, stunned: :reel } # rubocop:disable Style/MutableConstant -- frozen below
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
    @timer = 0
    @vy = 14.0
  end

  # one step of the fight
  def update
    @invulnerable -= 1 if @invulnerable > 0
    @timer += 1
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
    direction = player.x + player.w / 2 > @x + @w / 2 ? 1 : -1
    send(STEPS[@state], direction, angry)
    move_in_arena
  end

  def draw(screen, camera_x)
    return if invulnerable? && (@invulnerable / 3).even? && !dead?
    source = case @state
             when :dead, :stunned then FRAMES[:rusty_hurt]
             when :pound then FRAMES[@timer < 20 ? :rusty_crouch : :rusty_air]
             when :hop then FRAMES[@on_ground ? :rusty_crouch : :rusty_air]
             when :spit, :summon then FRAMES[:rusty_mouth]
             when :charge then FRAMES[@timer < 45 ? :rusty_crouch : :rusty_angry]
             else @angry ? FRAMES[:rusty_angry] : frame(:rusty_walk, (@timer / 12) % 2)
             end
    source = FRAMES[:rusty_hurt] if invulnerable? && !dead?
    x = @x.to_i - camera_x - 8
    shake = @state == :charge && @timer < 45 ? ((@timer / 2) % 2) * 8 - 4 : 0
    screen.sprite('sprites/rusty.png', x + shake, @y.to_i, 128, 112, source, flip: @facing > 0, alpha: 255, flip_v: dead?)
    return unless spiky? || (@warn_spiky > 0 && (@warn_spiky / 4).even?)
    screen.sprite('sprites/rusty.png', x + shake, @y.to_i + 24, 128, 112, FRAMES[:rusty_crown])
  end

  private

  def sound = @game.sound

  def rand_below(n)
    @rng = (@rng * 75 + 74) % 65_537
    @rng % n
  end

  def pace(angry) = angry ? ANGRY_SPEED : 1.0

  # back to walking, with a cooldown before the next move
  def idle(cooldown)
    @state = :walk
    @timer = 0
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
    @timer = 0
  end

  # SHORT FUSE: at half health he fumes, and moves faster from then on
  def short_fuse
    @angry = true
    @game.popup(@x, @y + 140, 'RUSTY IS FUMING!')
    sound.play(:warn)
    sound.music_pitch = 1.2
  end

  # stands still until the banner has been up a second
  def wait_for_banner(_direction, _angry)
    @vx = 0.0
    @state = :walk if @game.banner < 120
  end

  # walks at the player until the cooldown runs out, then picks a move
  def walk(direction, angry)
    speed = pace(angry)
    @facing = direction
    @vx = direction * 1.3 * speed
    @cooldown -= 1
    choose_move if @cooldown <= 0 && @on_ground
  end

  # a short hop toward the player
  def hop(direction, angry)
    speed = pace(angry)
    if @timer == 1
      @vy = 13.0
      @vx = direction * 3.0 * speed
    elsif @on_ground && @timer > 3
      idle(50)
    end
  end

  # crouch, leap at the player, and land sending steam waves along the floor
  def ground_pound(_direction, angry)
    speed = pace(angry)
    if @timer < 20
      @vx = 0.0   # crouch
    elsif @timer == 20
      @vy = 21.0
      @airborne = true
      @vx = ((@game.player.x - @x) / 42.0).to_f
      @vx = 7.0 if @vx > 7
      @vx = -7.0 if @vx < -7
    elsif @on_ground && @airborne && @timer > 22
      @airborne = false
      @vx = 0.0
      @game.camera.shake(20)
      sound.play(:pound)
      waves = angry ? 2 : 1
      waves.times do |i|
        [-1, 1].each do |side|
          @game.shots << SteamWave.new(@x + @w / 2 - 20 + side * 50, @y, side * (6.0 + i * 2.5) * speed,
                                       @arena_column * TILE, @level.width)
        end
      end
      idle(60)
    end
  end

  # lobs globs of rust at the player (more when angry, or from encounter 6)
  def rust_spit(_direction, angry)
    @vx = 0.0
    n = angry ? 3 : 1 + (@encounter >= 6 ? 1 : 0)
    if @timer == 24 || (n > 1 && @timer == 38) || (n > 2 && @timer == 52)
      sound.play(:spit)
      dx = (@game.player.x - @x).to_f
      air_time = 50.0
      @game.shots << RustGlob.new(@x + @w / 2 - 16, @y + 70, dx / air_time + (@timer - 38) * 0.08)
    end
    idle(50) if @timer > 30 + n * 14
  end

  # coughs up a minion Blob
  def blob_belch(direction, _angry)
    @vx = 0.0
    if @timer == 30
      sound.play(:appear)
      @game.enemies << Blob.minion(@x + @w / 2 - 24, @y + 60, direction)
    end
    idle(60) if @timer > 50
  end

  # shakes, then charges until he hits a wall (and is stunned)
  def bull_charge(direction, angry)
    speed = pace(angry)
    if @timer < 45
      @vx = 0.0
      @facing = direction if @timer == 1
      sound.play(:warn) if @timer == 1
    else
      @vx = @facing * 9.0 * speed
      idle(30) if @timer > 240
    end
  end

  # stunned after charging into a wall
  def reel(_direction, _angry)
    @vx = 0.0
    idle(40) if @timer > 70
  end

  # warns, then grows a spiked crown: no stomping for a while
  def spiked_crown(_direction, _angry)
    @vx = 0.0
    @warn_spiky = 40 if @timer == 1
    idle(30) if @timer > 40
  end

  # bolts drop on shadows, the first one on the player
  def bolt_storm(_direction, angry)
    @vx = 0.0
    if @timer == 1
      sound.play(:warn)
      count = angry ? 5 : 3
      count.times do |i|
        c = @arena_column + 2 + rand_below(16)
        c = @level.column_at(@game.player.x + @game.player.w / 2) if i == 0
        @game.shots << Bolt.new(c * TILE + 16, -i * 12)   # staggered
      end
    end
    idle(40) if @timer > 60
  end

  # gravity, the arena floor and walls; a charge into a wall stuns him
  def move_in_arena
    @game.fall(self)
    @previous_y = @y
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
    return unless @x < min_x || @x > max_x
    @x = @x < min_x ? min_x.to_f : max_x.to_f
    if @state == :charge
      @game.camera.shake(16)
      sound.play(:pound)
      @state = :stunned
      @timer = 0
    end
    @vx = 0.0
  end
end
