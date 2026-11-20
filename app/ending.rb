# The ending, after the main valve on the last jobsite is turned:
#   spin-up   the valve spins faster and faster, hissing steam
#   burst     a steam blast fires it into the sky, shaking the screen
#   race      the camera chases it up through streaking stars
#   slow      the camera eases off and the valve shoots off the top
#   fireworks huge blocky bursts, CONGRATULATION! / JOB COMPLETE, then the
#             credits a line at a time, then THANK YOU FOR PLAYING!!!
#             (with Big Rusty dropping past, upside-down)
#
# This is the Ending scene (Game#start_ending switches to it). While the level is still on
# screen and the camera is rising, the level is drawn into a render target
# and slid down as one sprite; once it's gone it isn't drawn at all.

END_BURST        = 150              # frames of spin-up before the blast
END_SLOW         = END_BURST + 220  # camera starts to ease off
END_FIRE         = END_SLOW + 70    # first firework
END_TEXT         = END_FIRE + 24    # CONGRATULATION!
END_CREDITS      = END_TEXT + 240   # credits, one line at a time
END_THANKS       = END_CREDITS + 400 # THANK YOU FOR PLAYING!!!
END_PROMPT       = END_THANKS + 150 # final score + PRESS START
CREDITS          = ['CODE: JAY MCGAVREN', 'CONCEPT: CPRO', 'WASMCART: LUIS MONTES'].freeze
CREDIT_GAP       = 90
RUSTY_FALL       = END_THANKS + 40  # Big Rusty tumbles past, upside-down
RUSTY_FALL_SPEED = 12               # px/frame: about 1.25 s to cross the screen
END_TOP_SPEED    = 36.0             # the valve's top speed, px/frame
END_LOCK_Y       = 380              # where the camera holds the valve on screen
FIREWORK_GRAVITY = 0.14             # px/frame^2 pulling firework stars down
FIREWORK_COLORS  = [[255, 48, 48], [48, 255, 96], [64, 112, 255]].freeze

# The ending scene; its timer `@frames` is the `elapsed` below.
class Ending < Scene
  STARS = Array.new(70) { |i| [(i * 389 + 41) % VIEW_WIDTH, (i * 157 + 23) % 760, i % 3] }.freeze

  def initialize(game)
    super
    @spin = 0.0                # valve frame phase
    @flying_valve = nil        # the valve, once it's airborne (world coords)
    @rise = 0.0                # how far the camera has risen
    @rise_speed = 0.0
    @locked = false
    @steam = []                # SteamPuffs, world coords
    @fireworks = []
    @fireworks_launched = 0
    @next_firework_at = END_FIRE
    @rng = 12_345
    @twinkle = nil
    @shake = 0.0
  end

  def name = :ending

  def update
    elapsed = @frames
    goal = @game.goal
    follow_valve(goal)
    vx = goal.x + 32           # valve centre, world x
    vy = goal.y + 2 * TILE     # valve bottom, world y
    if elapsed < END_BURST
      spin_up(elapsed, goal, vx, vy)
    elsif elapsed == END_BURST
      blast_off(goal, vx, vy)
    end
    @shake -= 0.3 if elapsed > END_BURST && @shake > 0
    if @flying_valve
      fly_valve(elapsed)
    elsif elapsed > END_BURST
      ease_rise
    end
    @twinkle[:timer] += 1 if @twinkle
    @steam.each(&:update)
    @steam.reject!(&:gone?)
    update_fireworks(elapsed) if elapsed >= END_FIRE
    hiss_vents(elapsed)
    sound.play(:hurt) if elapsed == RUSTY_FALL + 6
    return unless elapsed > END_PROMPT && (controls.start_pressed? || controls.jump_pressed?)
    @game.to_title
  end

  def draw
    elapsed = @frames
    amplitude = @shake
    shake_x = shake_dx
    shake_y = amplitude > 0 ? ((@game.clock % 6) < 3 ? amplitude : -amplitude).to_i / 2 : 0
    rise = @rise.to_i
    draw_backdrop(elapsed, rise, shake_x, shake_y)
    camera_x = @game.camera.x.to_i
    draw_steam(camera_x, rise, shake_x, shake_y)
    draw_flying_valve(elapsed, camera_x, rise, shake_x, shake_y) if @flying_valve
    draw_twinkle(camera_x) if @twinkle && @twinkle[:timer] < 40
    @fireworks.each { |firework| firework.draw(screen) }
    draw_falling_rusty(elapsed) if elapsed >= RUSTY_FALL
    draw_captions(elapsed)
  end

  private

  # ── update phases ─────────────────────────────────────────────────

  # the player turns to watch the valve; effects and the wrench play out
  def follow_valve(goal)
    player = @game.player
    @game.settle_player(goal.x > player.x ? 1 : -1)
    @game.update_effects
    @game.update_wrench
  end

  # the valve spins faster and faster, hissing steam, and the screen
  # starts to shake
  def spin_up(elapsed, goal, vx, vy)
    # frame phase speeds toward one frame per tick
    @spin += [0.2 + elapsed / 120.0, 1.0].min
    goal.turn = (@spin * 5).to_i
    every = [36 - elapsed / 5, 4].max
    sound.play(:steam) if elapsed % every == 0
    n = elapsed / 40 + 1
    n.times do |i|
      angle = (elapsed * 37 + i * 101) % 360 * 0.01745
      @steam << SteamPuff.new(vx + Math.cos(angle) * 24, vy + 40 + Math.sin(angle) * 24, Math.cos(angle) * 2.5, 1.5 + (i % 3),
                              24, 8 + (elapsed % 3) * 4)
    end
    @shake = elapsed > 80 ? (elapsed - 80) / 14.0 : 0.0
  end

  # the steam blast: the valve leaves the level in a ring of steam
  def blast_off(goal, vx, vy)
    goal.gone = true
    @flying_valve = { x: vx - 32, y: vy.to_f, speed: 14.0 }
    @shake = 16.0
    sound.play(:blast)
    sound.play(:pound)
    24.times do |i|
      angle = i * 0.2618
      @steam << SteamPuff.new(vx, vy + 20, Math.cos(angle) * 9, Math.sin(angle).abs * 6 + 1, 40, 48)
    end
  end

  # the valve accelerates up, trailing steam; the camera locks on to it,
  # then eases off and lets it fly off the top with a twinkle
  def fly_valve(elapsed)
    valve = @flying_valve
    valve[:speed] = [valve[:speed] + 2.2, END_TOP_SPEED].min
    valve[:y] += valve[:speed]
    if valve[:y] - @rise < 800
      @steam << SteamPuff.new(valve[:x] + 32 + (elapsed % 3 - 1) * 6, valve[:y] - 8, (elapsed % 5 - 2) * 0.6,
                              -valve[:speed] * 0.15, 18, 32)
    end
    if elapsed < END_SLOW
      @locked = true if !@locked && valve[:y] - @rise > END_LOCK_Y
      if @locked
        new_rise = valve[:y] - END_LOCK_Y
        @rise_speed = new_rise - @rise
        @rise = new_rise
      end
    else
      ease_rise
      if !@twinkle && valve[:y] - @rise > 720
        @twinkle = { x: valve[:x] + 32, timer: 0 }
        sound.play(:appear)
      end
    end
    @flying_valve = nil if valve[:y] - @rise > 1600
  end

  # the camera drifts toward a slow climb through space
  def ease_rise
    @rise_speed -= (@rise_speed - 1.5) * 0.04
    @rise += @rise_speed
  end

  def update_fireworks(elapsed)
    sound.music(:clear, looping: false) if elapsed == END_FIRE
    sound.music(:theme) if elapsed > END_FIRE + 30 && !sound.music_playing?
    if elapsed >= @next_firework_at
      # irregular cadence: quick doubles, short gaps and longer lulls
      (rand_below(4) == 0 ? 2 : 1).times { spawn_firework }
      r = rand_below(10)
      @next_firework_at = elapsed + (r < 3 ? 8 + rand_below(10) : r < 8 ? 22 + rand_below(26) : 55 + rand_below(30))
    end
    @fireworks.each(&:update)
    @fireworks.reject!(&:gone?)
  end

  # the level's vents still hiss while it is on screen
  def hiss_vents(elapsed)
    if elapsed < END_BURST
      @game.vent_sounds(shake_dx)
    elsif @rise.to_i < 720
      @game.vent_sounds
    end
  end

  # ── drawing ───────────────────────────────────────────────────────

  # the level (shaking, then sliding down as one render-target sprite)
  # over the starfield
  def draw_backdrop(elapsed, rise, shake_x, shake_y)
    game = @game
    if elapsed < END_BURST
      game.camera.offset_by(shake_x) { game.draw_world(true) }
      return
    end
    draw_space
    return unless rise < 720
    target = screen.outputs[:world]
    target.w = VIEW_WIDTH
    target.h = 720
    screen.draw_into(target) { game.draw_world(true, false) }
    screen.outputs.sprites << { x: shake_x, y: shake_y - rise, w: VIEW_WIDTH, h: 720, path: :world }
  end

  def draw_steam(camera_x, rise, shake_x, shake_y)
    @steam.each do |steam_puff|
      x = steam_puff.x.to_i - camera_x + shake_x
      y = steam_puff.y.to_i - rise + shake_y
      next if y < -80 || y > 760
      size = steam_puff.width
      screen.rect(x - size / 2, y - size / 2, size, size, STEAM, [steam_puff.life * 5, 200].min)
    end
  end

  def draw_flying_valve(elapsed, camera_x, rise, shake_x, shake_y)
    x = @flying_valve[:x].to_i - camera_x + shake_x
    y = @flying_valve[:y].to_i - rise + shake_y
    return unless y < 760
    screen.tile('sprites/items.png', x, y, frame(:valve, elapsed % 3))
  end

  # a cross-shaped flare where the valve left the top of the screen
  def draw_twinkle(camera_x)
    k = @twinkle[:timer]
    flare = k < 20 ? k * 2 : (40 - k) * 2
    x = @twinkle[:x] - camera_x
    screen.rect(x - flare, 690, flare * 2 + 8, 8, TWINKLE)
    screen.rect(x, 690 - flare, 8, flare * 2 + 8, TWINKLE)
  end

  # Big Rusty's dazed face, flipped upside-down, wobbling as he drops
  def draw_falling_rusty(elapsed)
    rusty_y = 760 - (elapsed - RUSTY_FALL) * RUSTY_FALL_SPEED
    return unless rusty_y > -140
    screen.sprite('sprites/rusty.png', 576 + ((elapsed / 3) % 2) * 8 - 4, rusty_y, 128, 112, FRAMES[:rusty_hurt],
                  flip: (elapsed / 6).even?, flip_v: true)
  end

  # CONGRATULATION!, the credits, THANK YOU, then the score and prompt
  def draw_captions(elapsed)
    if elapsed >= END_THANKS
      screen.label(640, 420, 'THANK YOU FOR PLAYING!!!', 7, PALE_YELLOW, true)
    elsif elapsed >= END_CREDITS
      CREDITS.each_with_index do |c, i|
        next if elapsed < END_CREDITS + i * CREDIT_GAP
        screen.label(640, 500 - i * 110, c, 5, WHITE, true)
      end
    elsif elapsed >= END_TEXT
      screen.label(640, 470, 'CONGRATULATION!', 12, PALE_YELLOW, true)
      screen.label(640, 330, 'JOB COMPLETE', 6, WHITE, true)
    end
    return unless elapsed > END_PROMPT
    screen.label(640, 200, "FINAL SCORE #{pad6(run.score)}", 4, WHITE, true)
    screen.label(640, 130, 'PRESS START', 3, WHITE, true) if (elapsed / 30).even?
  end

  # ── helpers ───────────────────────────────────────────────────────

  # sideways shake this frame, px
  def shake_dx
    amplitude = @shake
    amplitude > 0 ? ((game.clock % 4) < 2 ? amplitude : -amplitude).to_i : 0
  end

  def rand_below(n)
    @rng = (@rng * 75 + 74) % 65_537
    @rng % n
  end

  def spawn_firework
    @fireworks << Firework.new(160 + rand_below(960), 180 + rand_below(400), FIREWORK_COLORS[rand_below(3)], 0)
    @fireworks_launched += 1
    sound.play(:firework)
  end

  # the night sky deepening into space, stars streaking past as the camera rises
  def draw_space
    outputs = screen.outputs
    k = [@rise / 4000.0, 1.0].min
    outputs.background_color = [(8 - 6 * k).to_i, (12 - 10 * k).to_i, (48 - 36 * k).to_i]
    speed = @rise_speed
    STARS.each do |sx, sy, depth|
      star_speed = 0.35 + depth * 0.3
      y = (sy - @rise * star_speed) % 760 - 20
      length = [(speed * star_speed * 0.9).to_i, 4].max
      c = 150 + depth * 50
      outputs.solids << [sx, y.to_i, depth == 2 ? 8 : 4, length, c, c, 255]
    end
  end
end
