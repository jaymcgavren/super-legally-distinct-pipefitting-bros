# --- the ending: turning the last valve launches it into the sky ---
def to_ending(rush = false)
  s = Sim.new.start(LEVELS.size - 1)
  s.run.rush = rush
  s.put(s.iv(:arena_column) + 3); s.step([], 2)
  s.step([], 1) while s.iv(:warning) > 0
  s.iv(:boss).invulnerable = 0; s.g.send(:boss_hit, 99); s.step([], 130)
  g = s.iv(:goal)
  s.put(g.c - 3)
  s.step([:right], 1) until s.mode != :play
  s
end

# (only one Sim can run at a time: each one replaces $game)
check 'no render target during normal play', Sim.new.start(0).tap { |x| x.step([:right], 60) }
                                                             .args.outputs.instance_variable_get(:@targets).nil?
s = to_ending
check 'ending starts at the last valve', s.mode == :ending
check 'time bonus is paid at once', s.run.time == 0 && s.iv(:high_score).value == s.run.score && s.run.score > 0
sp = []
END_BURST.times { |_i| t0 = s.scene_iv(:spin); s.step([]); sp << s.scene_iv(:spin) - t0 }
check 'valve spins faster and faster', sp[10] < sp[60] && sp[60] < sp[-2] && !s.scene_iv(:steam).empty?
check 'steam blast launches the valve', s.iv(:goal).gone? && s.scene_iv(:flying_valve) && s.sounds.include?('sounds/blast.wav')
check 'blast shakes the screen', s.scene_iv(:shake) > 10
s.step([], 1) until s.scene_iv(:locked)
s.step([], 2)
check 'level is drawn through a render target while rising',
      s.scene_iv(:rise) > 0 && s.scene_iv(:rise) < 720 && !s.args.outputs[:world].sprites.empty? &&
      s.args.outputs.sprites.any? { |sp| sp[:path] == :world }
check 'camera follows the valve up', (s.scene_iv(:flying_valve)[:y] - s.scene_iv(:rise) - END_LOCK_Y).abs < 1
s.step([], 1) until s.scene_iv(:rise) > 900
s.step([])
check 'level stops being drawn once it is off screen', s.args.outputs.sprites.none? { |sp| sp[:path] == :world }
fast = s.scene_iv(:rise_speed)
check 'camera races at the valve speed', (fast - END_TOP_SPEED).abs < 0.01
s.step([], 1) until s.mode_frames >= END_SLOW + 60
check 'camera slows down', s.scene_iv(:rise_speed) < fast * 0.3 && s.scene_iv(:rise_speed) > 1
check 'valve flies off the top', s.scene_iv(:flying_valve).nil? || s.scene_iv(:flying_valve)[:y] - s.scene_iv(:rise) > 720
spawns = []
until s.mode_frames >= END_TEXT + 200
  n0 = s.scene_iv(:fireworks_launched); s.step([]); spawns << s.mode_frames if s.scene_iv(:fireworks_launched) > n0
end
gaps = spawns.each_cons(2).map { |a, b| b - a }
puts "  firework gaps #{gaps.inspect}"
check 'fireworks burst on an irregular cadence', gaps.uniq.size >= 3 && gaps.max > gaps.min * 2
labels = s.args.outputs.labels.map { |l| l[:text] }
check 'fireworks burst', !s.scene_iv(:fireworks).empty? && s.sounds.include?('sounds/firework.wav')
check 'CONGRATULATION! / JOB COMPLETE', labels.include?('CONGRATULATION!') && labels.include?('JOB COMPLETE')
s.step([:start], 1); s.step([], 1)
check 'start does not skip the ending too early', s.mode == :ending
txt = -> { s.args.outputs.labels.map { |l| l[:text] } }
s.step([], 1) until s.mode_frames >= END_CREDITS + 1
check 'credits replace CONGRATULATION!', txt.call.include?('CODE: JAY MCGAVREN') && !txt.call.include?('CONGRATULATION!') &&
                                         !txt.call.include?('CONCEPT: CPRO')
s.step([], CREDIT_GAP)
check 'second credit joins the first', txt.call.include?('CODE: JAY MCGAVREN') && txt.call.include?('CONCEPT: CPRO') &&
                                       !txt.call.include?('WASMCART: LUIS MONTES')
s.step([], CREDIT_GAP)
credit_ys = -> { s.args.outputs.labels.select { |l| CREDITS.include?(l[:text]) && l[:r] == 255 }.map { |l| l[:y] } }
check 'third credit joins below', CREDITS.all? { |c| txt.call.include?(c) } &&
                                  credit_ys.call.each_cons(2).all? { |a, b| a > b }
check 'fireworks behind the credits', !s.scene_iv(:fireworks).empty?
s.step([], 1) until s.mode_frames >= END_THANKS + 1
rusty = []
(RUSTY_FALL - END_THANKS + 100).times do
  s.step([])
  r = s.args.outputs.sprites.find { |sp| sp[:path] == 'sprites/rusty.png' }
  rusty << r if r
end
check 'Big Rusty falls past the centre, upside-down, during THANK YOU',
      rusty.size.between?(60, 90) &&
      rusty.all? { |r| r[:flip_vertically] } && rusty.each_cons(2).all? { |a, b| b[:y] < a[:y] } &&
      rusty.any? { |r| (r[:y] + 56 - 360).abs < 40 } && (rusty[0][:x] + 64 - 640).abs < 16 &&
      s.args.outputs.labels.any? { |l| l[:text] == 'THANK YOU FOR PLAYING!!!' }
check 'credits clear for THANK YOU FOR PLAYING!!!',
      txt.call.include?('THANK YOU FOR PLAYING!!!') && CREDITS.none? { |c| txt.call.include?(c) }
s.step([], 1) until s.mode_frames > END_PROMPT
s.step([], 2)
fires = s.scene_iv(:fireworks_launched)
check 'fireworks keep coming', fires >= 8
s.step([:start], 1)
check 'start after the ending goes to the title', s.mode == :title

s = to_ending(true)
check 'boss rush ends with the same ending', s.mode == :ending

# firework stars fall under gravity: the burst's centre of mass sinks, accelerating
s = Sim.new.start(0)
mean_y = lambda do |k|
  s.args.outputs.clear; s.iv(:screen).outputs = s.args.outputs
  Firework.new(640, 400, [255, 0, 0], k).draw(s.iv(:screen))
  ys = s.args.outputs.sprites.map { |r| r[:y] + r[:h] / 2.0 }
  ys.sum / ys.size
end
y20 = mean_y.call(20)
y40 = mean_y.call(40)
y60 = mean_y.call(60)
check 'firework stars are pulled down by gravity', y20 > y40 && y40 > y60 && (y40 - y60) > (y20 - y40) * 1.5 && 400 - y60 > 200
