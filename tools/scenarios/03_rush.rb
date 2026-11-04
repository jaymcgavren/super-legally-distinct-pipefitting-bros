# --- secret code -> Boss Rush ---
def enter_code(s, code = Game::RUSH_CODE)
  code.each { |k| s.step([k], 1); s.step([], 2) }
end

s = Sim.new
s.step([], 5)
enter_code(s, Game::RUSH_CODE[0, 9])
check 'partial code stays on title', s.mode == :title
s.step([:a], 1); s.step([], 2)
check 'A inside the code does not start a normal game', s.mode == :title
s.step([:start], 1); s.step([], 2)
check 'full code starts boss rush', s.iv(:rush) && s.iv(:level) == 3 && s.mode == :intro

s = Sim.new; s.step([], 5)
enter_code(s, %i[up up up down down left right left right b a start])
check 'extra Up still accepted', s.iv(:rush)

s = Sim.new; s.step([], 5)
s.step([:a], 1); s.step([], 2)
check 'plain A still starts normal game', !s.iv(:rush) && s.iv(:level) == 0

# Each boss in turn, starting in the arena with the wrench
s = Sim.new; s.step([], 5); enter_code(s)
s.step([], 1) until s.mode == :play
ok = true
Game::RUSH_LEVELS.each_with_index do |lv, i|
  ok &&= s.iv(:level) == lv && s.p.powered && s.iv(:boss) && s.p.x > s.iv(:arena_c) * T
  check "rush #{i + 1}: in arena #{lv} with wrench", ok
  break unless ok
  if i == 0
    lives = s.iv(:lives)
    s.g.send(:die); s.step([], 200); s.step([], 1) until s.mode == :play
    check 'rush respawn keeps the wrench', s.p.powered && s.iv(:lives) == lives - 1 && s.iv(:level) == lv
  end
  s.step([:right], 40)
  check "rush #{i + 1}: fight starts", s.iv(:boss_on) if i == 0
  s.iv(:boss).data[:inv] = 0; s.g.send(:boss_hit, 99); s.step([], 130)
  g = s.iv(:goal)
  s.put(g[:c] - 3); s.step([:right], 120); s.step([], 700)
  s.step([], 1) until s.mode == :play || s.mode == :win
end
check 'boss rush ends on the win screen', s.mode == :win
