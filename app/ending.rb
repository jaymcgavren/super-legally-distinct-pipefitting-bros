# The ending, after the main valve on the last jobsite is turned:
#   spin-up   the valve spins faster and faster, hissing steam
#   burst     a steam blast fires it into the sky, shaking the screen
#   race      the camera chases it up through streaking stars
#   slow      the camera eases off and the valve shoots off the top
#   fireworks huge blocky bursts, CONGRATULATION! / JOB COMPLETE, then the
#             credits a line at a time, then THANK YOU FOR PLAYING!!!
#             (with Big Rusty dropping past, upside-down)
#
# Everything here only runs in :ending mode. While the level is still on
# screen and the camera is rising, the level is drawn into a render target
# and slid down as one sprite; once it's gone it isn't drawn at all.

END_BURST = 150                # frames of spin-up before the blast
END_SLOW  = END_BURST + 220    # camera starts to ease off
END_FIRE  = END_SLOW + 70      # first firework
END_TEXT  = END_FIRE + 24      # CONGRATULATION!
END_CREDITS = END_TEXT + 240  # credits, one line at a time
END_THANKS = END_CREDITS + 400 # THANK YOU FOR PLAYING!!!
END_PROMPT = END_THANKS + 150  # final score + PRESS START
CREDITS = ['CODE: JAY MCGAVREN', 'CONCEPT: CPRO', 'WASMCART: LUIS MONTES']
CREDIT_GAP = 90
RUSTY_FALL = END_THANKS + 40   # Big Rusty tumbles past, upside-down
RUSTY_FALL_V = 12             # px/frame: about 1.25 s to cross the screen
END_TOP_V = 36.0               # the valve's top speed, px/frame
END_LOCK_Y = 380               # where the camera holds the valve on screen
FW_COLS = [[255, 48, 48], [48, 255, 96], [64, 112, 255]]

class Game
  def start_ending
    @mode = :ending
    @mode_t = 0
    @score += @time * 50       # the whole time bonus at once
    @time = 0
    save_hiscore
    music_stop
    @spin = 0.0                # valve frame phase
    @rk = nil                  # the valve, once it's airborne (world coords)
    @lift = 0.0                # how far the camera has risen
    @lift_v = 0.0
    @locked = false
    @steam = []                # [x, y, vx, vy, life, size], world coords
    @fw = []
    @fw_n = 0
    @fw_next = END_FIRE
    @end_rng = 12345
    @twinkle = nil
    @end_shake = 0.0
    @end_stars ||= Array.new(70) { |i| [(i * 389 + 41) % VW, (i * 157 + 23) % 760, i % 3] }
  end

  def tick_ending
    t = @mode_t
    p = @p
    p.vy -= GRAV_FALL
    p.vx = 0.0
    move_y(p, true, false)
    p.facing = @goal[:c] * T > p.x ? 1 : -1
    update_effects
    vx = @goal[:c] * T + 32                  # valve centre, world x
    vy = tile_bottom(@goal[:r]) + 2 * T      # valve bottom, world y

    if t < END_BURST
      # spin up: frame phase speeds toward one frame per tick
      @spin += [0.2 + t / 120.0, 1.0].min
      @goal[:turn] = (@spin * 5).to_i
      every = [36 - t / 5, 4].max
      sfx(:steam) if t % every == 0
      n = t / 40 + 1
      n.times do |i|
        a = (t * 37 + i * 101) % 360 * 0.01745
        @steam << [vx + Math.cos(a) * 24, vy + 40 + Math.sin(a) * 24, Math.cos(a) * 2.5, 1.5 + (i % 3), 24, 8 + (t % 3) * 4]
      end
      @end_shake = t > 80 ? (t - 80) / 14.0 : 0.0
    elsif t == END_BURST
      @goal[:gone] = true
      @rk = { x: vx - 32, y: vy.to_f, v: 14.0 }
      @end_shake = 16.0
      sfx(:blast); sfx(:pound)
      24.times do |i|
        a = i * 0.2618
        @steam << [vx, vy + 20, Math.cos(a) * 9, Math.sin(a).abs * 6 + 1, 40, 48]
      end
    end
    @end_shake -= 0.3 if t > END_BURST && @end_shake > 0

    if @rk
      @rk[:v] = [@rk[:v] + 2.2, END_TOP_V].min
      @rk[:y] += @rk[:v]
      # steam trail
      if @rk[:y] - @lift < 800
        @steam << [@rk[:x] + 32 + (t % 3 - 1) * 6, @rk[:y] - 8, (t % 5 - 2) * 0.6, -@rk[:v] * 0.15, 18, 32]
      end
      if t < END_SLOW
        if !@locked && @rk[:y] - @lift > END_LOCK_Y
          @locked = true
        end
        if @locked
          nl = @rk[:y] - END_LOCK_Y
          @lift_v = nl - @lift
          @lift = nl
        end
      else
        @lift_v -= (@lift_v - 1.5) * 0.04
        @lift += @lift_v
        if !@twinkle && @rk[:y] - @lift > 720
          @twinkle = { x: @rk[:x] + 32, t: 0 }
          sfx(:appear)
        end
      end
      @rk = nil if @rk[:y] - @lift > 1600
    elsif t > END_BURST
      @lift_v -= (@lift_v - 1.5) * 0.04
      @lift += @lift_v
    end
    @twinkle[:t] += 1 if @twinkle

    @steam.each { |s| s[0] += s[2]; s[1] += s[3]; s[2] *= 0.94; s[4] -= 1; s[5] += 1 }
    @steam.reject! { |s| s[4] <= 0 }

    if t >= END_FIRE
      music(:clear, false) if t == END_FIRE
      music(:theme) if t > END_FIRE + 30 && @args.audio[:music].nil?
      if t >= @fw_next
        # irregular cadence: quick doubles, short gaps and longer lulls
        (end_rand(4) == 0 ? 2 : 1).times { spawn_firework }
        r = end_rand(10)
        @fw_next = t + (r < 3 ? 8 + end_rand(10) : r < 8 ? 22 + end_rand(26) : 55 + end_rand(30))
      end
      @fw.each { |f| f[:t] += 1 }
      @fw.reject! { |f| f[:t] > 72 }
    end

    draw_ending
    if t > END_PROMPT && (@in_start_down || @in_a_down)
      to_title
    end
  end

  def end_rand(n)
    @end_rng = (@end_rng * 75 + 74) % 65537
    @end_rng % n
  end

  def spawn_firework
    @fw << { x: 160 + end_rand(960), y: 180 + end_rand(400), col: FW_COLS[end_rand(3)], t: 0 }
    @fw_n += 1
    sfx(:firework)
  end

  def draw_ending
    t = @mode_t
    amp = @end_shake
    shx = amp > 0 ? ((@frame % 4) < 2 ? amp : -amp).to_i : 0
    shy = amp > 0 ? ((@frame % 6) < 3 ? amp : -amp).to_i / 2 : 0
    lift = @lift.to_i
    if t < END_BURST
      @cam += shx
      draw_world(true)
      @cam -= shx
    else
      draw_space
      if lift < 720
        rt = @args.outputs[:world]
        rt.w = VW
        rt.h = 720
        @o = rt
        draw_world(true, false)
        @o = @args.outputs
        @o.sprites << { x: shx, y: shy - lift, w: VW, h: 720, path: :world }
      end
    end
    cam = @cam.to_i
    @steam.each do |s|
      x = s[0].to_i - cam + shx
      y = s[1].to_i - lift + shy
      next if y < -80 || y > 760
      sz = s[5]
      rect(x - sz / 2, y - sz / 2, sz, sz, [236, 236, 236], [s[4] * 5, 200].min)
    end
    if @rk
      x = @rk[:x].to_i - cam + shx
      y = @rk[:y].to_i - lift + shy
      if y < 760
        f = t % 3
        spr('sprites/items.png', x, y, T, T, 64 + f * 8, 0, 8, 16)
      end
    end
    if @twinkle && @twinkle[:t] < 40
      k = @twinkle[:t]
      s = k < 20 ? k * 2 : (40 - k) * 2
      x = @twinkle[:x] - cam
      rect(x - s, 690, s * 2 + 8, 8, [255, 255, 220])
      rect(x, 690 - s, 8, s * 2 + 8, [255, 255, 220])
    end
    @fw.each { |f| draw_firework(f) }
    if t >= RUSTY_FALL
      ry = 760 - (t - RUSTY_FALL) * RUSTY_FALL_V
      sfx(:hurt) if t == RUSTY_FALL + 6
      if ry > -140
        # dazed face, flipped upside-down, wobbling as he drops
        spr('sprites/rusty.png', 576 + ((t / 3) % 2) * 8 - 4, ry, 128, 112, 32, 0, 8, 28,
            (t / 6).even?, 255, 0, true)
      end
    end
    if t >= END_THANKS
      label(640, 420, 'THANK YOU FOR PLAYING!!!', 7, [252, 240, 160], true)
    elsif t >= END_CREDITS
      CREDITS.each_with_index do |c, i|
        next if t < END_CREDITS + i * CREDIT_GAP
        label(640, 500 - i * 110, c, 5, [255, 255, 255], true)
      end
    elsif t >= END_TEXT
      label(640, 470, 'CONGRATULATION!', 12, [252, 240, 160], true)
      label(640, 330, 'JOB COMPLETE', 6, [255, 255, 255], true)
    end
    if t > END_PROMPT
      label(640, 200, "FINAL SCORE #{pad6(@score)}", 4, [255, 255, 255], true)
      label(640, 130, 'PRESS START', 3, [255, 255, 255], true) if (@mode_t / 30) % 2 == 0
    end
  end

  # the night sky deepening into space, stars streaking past as the camera rises
  def draw_space
    o = @o
    k = [@lift / 4000.0, 1.0].min
    o.background_color = [(8 - 6 * k).to_i, (12 - 10 * k).to_i, (48 - 36 * k).to_i]
    v = @lift_v
    @end_stars.each do |sx, sy, d|
      sp = 0.35 + d * 0.3
      y = (sy - @lift * sp) % 760 - 20
      len = [(v * sp * 0.9).to_i, 4].max
      c = 150 + d * 50
      o.solids << [sx, y.to_i, d == 2 ? 8 : 4, len, c, c, 255]
    end
  end

  # a huge blocky burst: three rings of chunky squares racing outward
  def draw_firework(f)
    k = f[:t]
    col = f[:col]
    a = 150 - k * 2
    return if a <= 0
    if k < 5
      rect(f[:x] - 80, f[:y] - 80, 160, 160, [255, 255, 255], 200 - k * 30)
    end
    droop = k * k / 40
    [[1.0, 0.0, 64], [0.72, 0.13, 48], [0.45, 0.26, 32]].each do |rf, off, sz|
      r = (40 + k * 10) * rf
      12.times do |i|
        ang = i * 0.5236 + off
        x = ((f[:x] + Math.cos(ang) * r) / 16).to_i * 16
        y = ((f[:y] + Math.sin(ang) * r - droop) / 16).to_i * 16
        rect(x - sz / 2, y - sz / 2, sz, sz, col, a)
      end
    end
  end
end
