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
  if n == 0
    check 'warning plays the klaxon', s.sounds.include?('sounds/klaxon.wav')
    check 'boss music waits for the warning', s.args.audio[:music].nil?
    s.step([], 80)
    check 'boss holds still during the warning', b.state == :wait && s.iv(:warning) > 0
  end
  s.step([], 1) while s.iv(:warning) > 0
  check "#{LEVELS[li][:name]} boss music after the warning", s.args.audio[:music] && s.args.audio[:music][:input] == 'sounds/boss.wav' if n == 0
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
s.step([], 1) while s.iv(:warning) > 0
s.set(:banner, 0)
hp = b.data[:hp]
b.x = s.p.x + 150; b.state = :wait
s.step([:b], 1); s.step([], 20)
check 'wrench hits the boss', b.data[:hp] == hp - 1

# the boss valve appears between the girders, and clears even if it lands on you
[[:left, -3], [:on, 0], [:right, 4], [:girder, 13], [:far_right, 5]].each do |name, off|
  s = Sim.new.start(d_levels[0])
  ac = s.iv(:arena_c)
  s.put(ac + 3); s.step([], 2); s.step([], 1) while s.iv(:warning) > 0
  s.iv(:boss).data[:inv] = 0; s.g.send(:boss_hit, 99)
  gc = ac + 10
  if name == :girder
    s.put(ac + 16, 4)           # standing on the right girder
  else
    s.put(gc + off)
  end
  s.step([], 1) until s.iv(:goal) || s.mode != :play
  g = s.iv(:goal)
  if name == :left
    check 'boss valve sits between the girders', g && g[:c] == gc &&
      (5..7).all? { |r| s.g.cell(g[:c], r) == '.' } && (6..13).all? { |k| s.g.cell(ac + k, 5) == '.' }
  end
  if %i[right girder far_right].include?(name)
    s.step([], 30)
    check "boss valve does not clear by itself (player #{name})", s.mode == :play
    s.step([], 1) until s.p.on_ground
    s.step([:left], 1) until s.mode != :play || s.p.x < gc * T - 200
  end
  begin
    s.step(name == :left ? [:right] : [], 240)
    s.step([], 700)
    ok = %i[intro play].include?(s.mode) && s.iv(:level) == d_levels[0] + 1
  rescue => e
    puts "  #{e.class}: #{e.message}"; ok = false
  end
  check "boss valve clears the stage (player #{name})", ok
end

# bolt storm: 3 bolts (5 when angry), falling at 0.506 px/frame^2
s = Sim.new.start(d_levels[6])
ac = s.iv(:arena_c)
s.put(ac + 3); s.step([], 2); s.step([], 1) while s.iv(:warning) > 0
s.set(:banner, 0)
b = s.iv(:boss); b.state = :bolts; b.t = 0; s.set(:shots, [])
s.p.invuln = 999
s.step([], 1)
bolts = s.iv(:shots).select { |sh| sh[:k] == :bolt }
check 'bolt storm drops 3 bolts', bolts.size == 3
s.step([], 1) until bolts[0][:t] >= BOLT_WARN - 1
check 'bolt shadow warns for BOLT_WARN frames', bolts[0][:y] == 700.0 && BOLT_WARN > 40
s.step([], 2)
v1 = bolts[0][:vy]; s.step([], 1)
check 'bolts fall 25% slower', (bolts[0][:vy] - v1 + 0.506).abs < 0.001
b.data[:angry] = true; b.state = :bolts; b.t = 0; s.set(:shots, []); s.step([], 1)
check 'angry bolt storm drops 5 bolts', s.iv(:shots).count { |sh| sh[:k] == :bolt } == 5

# wrench at the boss valve from the right side
s = Sim.new.start(d_levels[0])
ac = s.iv(:arena_c)
s.put(ac + 3); s.step([], 2); s.step([], 1) while s.iv(:warning) > 0
s.iv(:boss).data[:inv] = 0; s.g.send(:boss_hit, 99)
s.put(ac + 15); s.p.powered = true
s.step([], 1) until s.iv(:goal)
s.step([], 10)
s.p.facing = -1; s.step([:b], 1)
cleared = false
40.times { s.step([]); (cleared = true; break) if s.mode == :clear }
check 'wrench clears the boss valve from the right', cleared

# Rusty hopping up into the player's feet counts as a stomp, not a hit
[[:rising, 3.0], [:still, 0.0], [:falling, -2.0]].each do |name, pvy|
  s = Sim.new.start(d_levels[0])
  ac = s.iv(:arena_c)
  s.put(ac + 3); s.step([], 2); s.step([], 1) while s.iv(:warning) > 0
  s.set(:banner, 0)
  b = s.iv(:boss); b.state = :wait; b.t = 0; b.data[:inv] = 0
  b.y = 128.0; b.vy = 13.0; b.x = s.p.x + 200
  hp = b.data[:hp]
  s.p.powered = true; s.p.invuln = 0
  s.p.x = b.x + 30; s.p.y = b.y + b.h + 4; s.p.vy = pvy; s.p.on_ground = false; s.snap
  s.step([], 1)
  check "Rusty rising into the player's feet is a stomp (player #{name})",
        b.data[:hp] < hp && s.p.powered && s.mode == :play
end

# ...but walking into him, or him landing on you, still hurts
[[:side, 0.0, 0], [:landed_on, -10.0, 1]].each do |name, bvy, above|
  s = Sim.new.start(d_levels[0])
  ac = s.iv(:arena_c)
  s.put(ac + 3); s.step([], 2); s.step([], 1) while s.iv(:warning) > 0
  s.set(:banner, 0)
  b = s.iv(:boss); b.state = :wait; b.t = 0; b.data[:inv] = 0
  b.x = s.p.x + 200; b.y = 128.0 + above * 60; b.vy = bvy
  hp = b.data[:hp]
  s.p.powered = true; s.p.invuln = 0
  s.p.x = above == 1 ? b.x + 30 : b.x - 20; s.snap
  s.step([], 1)
  check "Rusty still hurts the player (#{name})", !s.p.powered && b.data[:hp] == hp
end
