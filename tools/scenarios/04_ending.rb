# --- the ending: turning the last valve launches it into the sky ---
def to_ending(rush = false)
  s = Sim.new.start(LEVELS.size - 1)
  s.set(:rush, rush)
  s.put(s.iv(:arena_c) + 3); s.step([], 2)
  s.step([], 1) while s.iv(:warning) > 0
  s.iv(:boss).data[:inv] = 0; s.g.send(:boss_hit, 99); s.step([], 130)
  g = s.iv(:goal)
  s.put(g[:c] - 3)
  s.step([:right], 1) until s.mode != :play
  s
end

# (only one Sim can run at a time: each one replaces $game)
check 'no render target during normal play', Sim.new.start(0).tap { |x| x.step([:right], 60) }
  .args.outputs.instance_variable_get(:@t).nil?
s = to_ending
check 'ending starts at the last valve', s.mode == :ending
check 'time bonus is paid at once', s.iv(:time) == 0 && s.iv(:hiscore) == s.iv(:score) && s.iv(:score) > 0
sp = []
END_BURST.times { |i| t0 = s.iv(:spin); s.step([]); sp << s.iv(:spin) - t0 }
check 'valve spins faster and faster', sp[10] < sp[60] && sp[60] < sp[-2] && s.iv(:steam).size > 0
check 'steam blast launches the valve', s.iv(:goal)[:gone] && s.iv(:rk) && s.sounds.include?('sounds/blast.wav')
check 'blast shakes the screen', s.iv(:end_shake) > 10
s.step([], 1) until s.iv(:locked)
s.step([], 2)
check 'level is drawn through a render target while rising', s.iv(:lift) > 0 && s.iv(:lift) < 720 &&
  s.args.outputs[:world].sprites.size > 0 && s.args.outputs.sprites.any? { |sp| sp[:path] == :world }
check 'camera follows the valve up', (s.iv(:rk)[:y] - s.iv(:lift) - END_LOCK_Y).abs < 1
s.step([], 1) until s.iv(:lift) > 900
s.step([])
check 'level stops being drawn once it is off screen', s.args.outputs.sprites.none? { |sp| sp[:path] == :world }
fast = s.iv(:lift_v)
check 'camera races at the valve speed', (fast - END_TOP_V).abs < 0.01
s.step([], 1) until s.iv(:mode_t) >= END_SLOW + 60
check 'camera slows down', s.iv(:lift_v) < fast * 0.3 && s.iv(:lift_v) > 1
check 'valve flies off the top', s.iv(:rk).nil? || s.iv(:rk)[:y] - s.iv(:lift) > 720
s.step([], 1) until s.iv(:mode_t) >= END_TEXT + 40
labels = s.args.outputs.labels.map { |l| l[:text] }
check 'fireworks burst', s.iv(:fw).size > 0 && s.sounds.include?('sounds/firework.wav')
check 'CONGRATULATION! / JOB COMPLETE', labels.include?('CONGRATULATION!') && labels.include?('JOB COMPLETE')
s.step([:start], 1); s.step([], 1)
check 'start does not skip the ending too early', s.mode == :ending
txt = -> { s.args.outputs.labels.map { |l| l[:text] } }
s.step([], 1) until s.iv(:mode_t) >= END_CREDITS + 1
check 'credits replace CONGRATULATION!', txt.().include?('CODE: JAY MCGAVREN') && !txt.().include?('CONGRATULATION!') &&
  !txt.().include?('CONCEPT: CPRO')
s.step([], CREDIT_GAP)
check 'second credit joins the first', txt.().include?('CODE: JAY MCGAVREN') && txt.().include?('CONCEPT: CPRO') &&
  !txt.().include?('WASMCART: LUIS MONTES')
s.step([], CREDIT_GAP)
check 'third credit joins below', CREDITS.all? { |c| txt.().include?(c) } &&
  s.args.outputs.labels.select { |l| CREDITS.include?(l[:text]) && l[:r] == 255 }.map { |l| l[:y] }.each_cons(2).all? { |a, b| a > b }
check 'fireworks behind the credits', s.iv(:fw).size > 0
s.step([], 1) until s.iv(:mode_t) >= END_THANKS + 1
rusty = []
(RUSTY_FALL - END_THANKS + 40).times do
  s.step([])
  r = s.args.outputs.sprites.find { |sp| sp[:path] == 'sprites/rusty.png' }
  rusty << r if r
end
check 'Big Rusty falls past the centre, upside-down, during THANK YOU', rusty.size.between?(10, 60) &&
  rusty.all? { |r| r[:flip_vertically] } && rusty.each_cons(2).all? { |a, b| b[:y] < a[:y] } &&
  rusty.any? { |r| (r[:y] + 56 - 360).abs < 40 } && (rusty[0][:x] + 64 - 640).abs < 16 &&
  s.args.outputs.labels.any? { |l| l[:text] == 'THANK YOU FOR PLAYING!!!' }
check 'credits clear for THANK YOU FOR PLAYING!!!', txt.().include?('THANK YOU FOR PLAYING!!!') && CREDITS.none? { |c| txt.().include?(c) }
s.step([], 1) until s.iv(:mode_t) > END_PROMPT
s.step([], 2)
fires = s.iv(:fw_n)
check 'fireworks keep coming', fires >= 8
s.step([:start], 1)
check 'start after the ending goes to the title', s.mode == :title

s = to_ending(true)
check 'boss rush ends with the same ending', s.mode == :ending
