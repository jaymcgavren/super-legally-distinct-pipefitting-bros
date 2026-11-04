# --- Big Rusty: each D level has the boss, with one more move each time ---
d_levels = (0...LEVELS.size).select { |i| LEVELS[i][:boss] }
check 'eight boss levels', d_levels.size == 8
d_levels.each_with_index do |li, n|
  s = Sim.new.start(li)
  b = s.iv(:boss)
  check "#{LEVELS[li][:name]} has boss level #{n + 1}", b && s.g.boss_level == n + 1
  ac = s.iv(:arena_c)
  s.p.x = (ac + 3) * T + 12.0; s.p.y = s.g.tile_bottom(7).to_f; s.snap
  s.step([], 2)
  check "#{LEVELS[li][:name]} fight starts and gate closes", s.iv(:boss_on) && s.g.cell(ac, 6) == '#'
  # survive a while with invulnerability, record which moves were used
  seen = {}
  1500.times do
    s.p.invuln = 5
    s.step([])
    seen[b.state] = true
    break if s.mode != :play
  end
  known = BOSS_MOVES.first(n + 1).map(&:first) - [:enrage]
  check "#{LEVELS[li][:name]} boss uses its newest move (#{known.last})", seen[known.last]
  # whittle it down with stomps
  hits = 0
  400.times do
    break if b.state == :dead
    s.p.invuln = 5
    b.data[:spiky] = 0; b.data[:warn_spiky] = 0
    if b.data[:inv] == 0
      s.p.x = b.x + 30; s.p.y = b.y + b.h - 2; s.p.vy = -3.0; s.p.prev_y = b.y + b.h + 4
      hits += 1
    end
    s.step([])
  end
  check "#{LEVELS[li][:name]} boss can be defeated", b.state == :dead
  s.p.x = (ac + 8) * T; s.p.y = s.g.tile_bottom(7).to_f; s.p.vy = 0
  s.step([], 130)
  check "#{LEVELS[li][:name]} goal appears after the boss", !s.iv(:goal).nil?
  if n == 7
    check 'final boss got angry', b.data[:angry]
  end
end

# wrench damages the boss
s = Sim.new.start(d_levels[0])
b = s.iv(:boss); ac = s.iv(:arena_c)
s.p.x = (ac + 3) * T + 12.0; s.p.y = s.g.tile_bottom(7).to_f; s.p.powered = true; s.p.facing = 1; s.snap
s.step([], 2)
s.set(:banner, 0)
hp = b.data[:hp]
b.x = s.p.x + 150; b.state = :wait
s.step([:b], 1); s.step([], 20)
check 'wrench hits the boss', b.data[:hp] == hp - 1
