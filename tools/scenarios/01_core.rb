# spawn a lone active blob on the start segment's open floor
def lone_blob(s, col)
  s.iv(:enemies).clear
  e = Actor.new(:blob, col * T + 8, s.g.tile_bottom(7), 48, 40)
  e.active = true; e.vx = -1.0
  s.iv(:enemies) << e
  e
end

# --- jump feel ---
s = Sim.new.start(0)
s.put(4)
y0 = s.p.y; peak = y0
s.step([:a], 1); 40.times { s.step([:a]); peak = [peak, s.p.y].max }
full = peak - y0
s.step([], 60)
s.put(4); peak = s.p.y
s.step([:a], 3); 40.times { s.step([]); peak = [peak, s.p.y].max }
tap = peak - y0
puts "  full jump #{full.round} px (#{(full / T).round(2)} tiles), tap #{tap.round} px"
check 'full jump clears 3+ tiles', full > 3 * T
check 'tap jump is much lower', tap < full * 0.6

# --- run speed ---
s.put(1); s.step(%i[right b], 60)
check 'run reaches RUN_MAX', (s.p.vx - RUN_MAX).abs < 0.01

# --- stomp a blob ---
s = Sim.new.start(0)
e = s.iv(:enemies).find { |en| en.kind == :blob }
s.p.x = e.x; s.p.y = e.y + e.h + 8; s.p.vy = -2.0; s.snap
s.iv(:enemies).each { |en| en.active = true }
sc = s.iv(:score)
s.step([], 6)
check 'stomp flattens blob', e.state == :flat || e.state == :gone
check 'stomp scores', s.iv(:score) > sc
check 'stomp bounces player', s.p.vy > 0 || s.p.y > e.y + 40
check 'still playing after stomp', s.mode == :play

# --- touching a blob kills unpowered player ---
s = Sim.new.start(0)
s.put(3); e = lone_blob(s, 8)
e.active = true
s.step([:right], 90)
check 'side contact kills', s.mode == :dying

# --- powered player shrinks to unpowered instead ---
s = Sim.new.start(0)
s.put(3); e = lone_blob(s, 8)
s.p.powered = true
e.active = true
s.step([:right], 90)
check 'powered contact only loses power', s.mode == :play && !s.p.powered && s.p.invuln > 0

# --- wrench crate -> pickup -> throw ---
s = Sim.new.start(0)
g = s.g
# a wrench crate with open air beneath it down to the floor
c, r = nil
g.instance_variable_get(:@cols).times do |cc|
  rr = (0..7).find { |k| g.cell(cc, k) == 'W' }
  next unless rr && ((rr + 1)..7).all? { |k| g.cell(cc, k) == '.' } && SOLID[g.cell(cc, 8)]
  c, r = cc, rr
  break
end
check 'found a W crate over open floor', !c.nil?
s.put(c)
s.p.x = c * T + 12
s.step([:a], 30); s.step([], 40)
check 'W crate used', g.cell(c, r) == 'U'
item = s.iv(:items).find { |i| i.kind == :wrench_item }
check 'wrench item spawned', !item.nil?
s.step([], 40)
s.p.x = item.x; s.p.y = item.y; s.step([], 2) if item
check 'wrench pickup powers up', s.p.powered
s.step([], 30)
s.put(c + 1)
e = lone_blob(s, 0)
e.x = s.p.x + 220; e.y = s.p.y
s.p.facing = 1
s.step([:b], 1); s.step([], 40)
check 'thrown wrench knocks enemy', e.state == :dead
s.step([], 80)
check 'wrench comes back', s.iv(:wrench).nil?

# --- pit death and respawn ---
s = Sim.new.start(0)
lives = s.iv(:lives)
pit = (0...s.g.instance_variable_get(:@cols)).find { |c| (0..9).none? { |r| SOLID[s.g.cell(c, r)] || s.g.cell(c, r) == '-' } && (0..9).none? { |r| SOLID[s.g.cell(c + 1, r)] } }
s.p.x = pit * T + 12; s.p.y = 300; s.snap
s.step([], 60)
check 'pit kills', s.mode == :dying
s.step([], 200)
check 'life lost', s.iv(:lives) == lives - 1
check 'back to intro', s.mode == :intro

# --- checkpoint respawn ---
s = Sim.new.start(0)
cone = s.iv(:cones)[0]
s.put(cone[:c] + 1)
s.step([], 2)
check 'checkpoint lit', cone[:lit]
s.g.send(:die); s.step([], 200)
s.step([], 1) until s.mode == :play
check 'respawn at checkpoint', (s.p.x - cone[:c] * T).abs < 64

# --- timer runs out ---
s = Sim.new.start(0)
s.set(:time, 1); s.set(:time_acc, 0)
s.step([], TICK_LEN + 1)
check 'timer death', s.mode == :dying

# --- vent steam hurts ---
s = Sim.new.start(0)
v = s.iv(:vents)[0]
s.put(v[:c])
s.p.x = v[:c] * T + 12
hurt = false
200.times { s.step([]); s.p.x = v[:c] * T + 12; (hurt = true; break) if s.mode == :dying }
check 'vent steam hurts', hurt

# --- lift carries the player ---
lift_lv = (0...LEVELS.size).find { |i| LEVELS[i][:rows].any? { |row| row =~ /[LH]/ } }
s = Sim.new.start(lift_lv)
l = s.iv(:lifts)[0]
s.step([], 1)
s.p.x = l.x + 40; s.p.y = l.y + l.h + 2; s.p.vy = 0
s.step([], 3)
x0 = s.p.x
s.step([], 60)
check 'player rides lift', s.p.riding.equal?(l) || (s.p.x - x0).abs > 20

# --- goal -> clear -> next level ---
s = Sim.new.start(0)
g = s.iv(:goal)
s.put(g[:c] - 3)
s.step([:right], 120)
check 'goal triggers clear', s.mode == :clear
s.step([], 600)
check 'advances to 1-B', s.iv(:level) == 1 && %i[intro play].include?(s.mode)

# --- game over and back to title ---
s = Sim.new.start(0)
s.set(:lives, 1)
s.g.send(:die); s.step([], 200)
check 'game over', s.mode == :gameover
s.step([], 130); s.step([:start])
check 'back to title', s.mode == :title

# --- win after last level ---
s = Sim.new.start(LEVELS.size - 1)
if s.iv(:boss)
  s.put(s.iv(:arena_c) + 3); s.step([], 2)
  s.step([], 1) while s.iv(:warning) > 0
  s.iv(:boss).data[:inv] = 0; s.g.send(:boss_hit, 99); s.step([], 130)
end
g = s.iv(:goal)
s.put(g[:c] - 3); s.step([:right], 120)
check 'last level plays the ending', s.mode == :ending

# --- 50 nuts = 1UP ---
s = Sim.new.start(0)
s.set(:nuts, 49); l0 = s.iv(:lives)
s.g.send(:add_nut)
check '50 nuts gives 1UP', s.iv(:lives) == l0 + 1 && s.iv(:nuts) == 0

# --- a thrown wrench that hits the main valve clears the level ---
s = Sim.new.start(0)
g = s.iv(:goal)
s.put(g[:c] - 5); s.p.powered = true; s.p.facing = 1
s.iv(:enemies).clear
s.step([:b], 1)
cleared = false
40.times { s.step([]); (cleared = true; break) if s.mode == :clear }
check 'wrench hitting the valve clears the level', cleared && s.p.x < g[:c] * T - 3 * T
check 'wrench is put away on valve hit', s.iv(:wrench).nil?
s.step([], 700)
check 'wrench clear advances to 1-B', s.iv(:level) == 1
