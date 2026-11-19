# spawn a lone active blob on the start segment's open floor
def lone_blob(s, col)
  s.iv(:enemies).clear
  e = Actor.new(:blob, col * TILE + 8, s.level.tile_bottom(7), 48, 40)
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
puts "  full jump #{full.round} px (#{(full / TILE).round(2)} tiles), tap #{tap.round} px"
check 'full jump clears 3+ tiles', full > 3 * TILE
check 'tap jump is much lower', tap < full * 0.6

# --- full height only at (almost) top running speed ---
# held-jump peak from open floor (everything above cleared) at a given speed
held_peak = lambda do |vx, keys|
  s = Sim.new.start(0)
  (0..7).each { |r| (0...60).each { |c| s.level.set_cell(c, r, '.') } }
  s.iv(:enemies).clear
  s.put(4); s.p.vx = vx
  y0 = s.p.y; pk = y0
  s.step(keys + [:a], 1); 50.times { s.step(keys + [:a]); pk = [pk, s.p.y].max }
  pk - y0
end
stand = held_peak.(0.0, [])
walk  = held_peak.(WALK_MAX, [:right])
part  = held_peak.(RUN_MAX * 0.8, %i[right b])
run   = held_peak.(RUN_MAX, %i[right b])
puts "  held jump: standing #{stand.round}, walking #{walk.round}, 80% run #{part.round}, full run #{run.round} px"
check 'standing, walking and part-speed jumps share the lower max height', [walk, part].all? { |h| (h - stand).abs < 2 }
check 'lower max still clears 4 tiles', stand > 4 * TILE
check 'full-speed run jumps clearly higher (1+ tile)', run > stand + TILE

# --- run speed ---
s.put(1); s.step(%i[right b], 60)
check 'run reaches RUN_MAX', (s.p.vx - RUN_MAX).abs < 0.01

# --- stomp a blob ---
s = Sim.new.start(0)
e = s.iv(:enemies).find { |en| en.kind == :blob }
s.p.x = e.x; s.p.y = e.y + e.h + 8; s.p.vy = -2.0; s.snap
s.iv(:enemies).each { |en| en.active = true }
sc = s.run.score
s.step([], 6)
check 'stomp flattens blob', e.state == :flat || e.state == :gone
check 'stomp scores', s.run.score > sc
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
level = s.level
# a wrench crate with open air beneath it down to the floor
c, r = nil
level.columns.times do |cc|
  rr = (0..7).find { |k| level.cell(cc, k) == 'W' }
  next unless rr && ((rr + 1)..7).all? { |k| level.cell(cc, k) == '.' } && SOLID[level.cell(cc, 8)]
  c, r = cc, rr
  break
end
check 'found a W crate over open floor', !c.nil?
s.put(c)
s.p.x = c * TILE + 12
s.step([:a], 30); s.step([], 40)
check 'W crate used', level.cell(c, r) == 'U'
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
lives = s.run.lives
pit = (0...s.level.columns).find { |c| (0..9).none? { |r| SOLID[s.level.cell(c, r)] || s.level.cell(c, r) == '-' } && (0..9).none? { |r| SOLID[s.level.cell(c + 1, r)] } }
s.p.x = pit * TILE + 12; s.p.y = 300; s.snap
s.step([], 60)
check 'pit kills', s.mode == :dying
s.step([], 200)
check 'life lost', s.run.lives == lives - 1
check 'back to intro', s.mode == :intro

# --- checkpoint respawn ---
s = Sim.new.start(0)
cone = s.iv(:cones)[0]
s.put(cone[:c] + 1)
s.step([], 2)
check 'checkpoint lit', cone[:lit]
s.g.send(:die); s.step([], 200)
s.step([], 1) until s.mode == :play
check 'respawn at checkpoint', (s.p.x - cone[:c] * TILE).abs < 64

# --- timer runs out ---
s = Sim.new.start(0)
s.run.start_shift(1)
s.step([], TICK_LENGTH + 1)
check 'timer death', s.mode == :dying

# --- vent steam hurts ---
s = Sim.new.start(0)
v = s.iv(:vents)[0]
s.put(v[:c])
s.p.x = v[:c] * TILE + 12
hurt = false
200.times { s.step([]); s.p.x = v[:c] * TILE + 12; (hurt = true; break) if s.mode == :dying }
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

# --- every level ends with the boss; the valve only appears once he is beaten ---
check 'every level has a boss', LEVELS.all? { |l| l[:boss] }
check 'eight levels, 1-A to 2-D', LEVELS.map { |l| l[:name][-3..] } == %w[1-A 1-B 1-C 1-D 2-A 2-B 2-C 2-D]
check 'only 1-B (day) and 2-B (sunset) are indoors',
      LEVELS.map { |l| l[:theme] } == %i[day indoor dusk night day indoor_dusk dusk night]
s = Sim.new.start(0)
check 'no valve until the boss is beaten', s.iv(:goal).nil?

# --- goal -> clear -> next level ---
s = Sim.new.start(0).beat_boss
g = s.iv(:goal)
s.put(g[:c] - 3)
s.step([:right], 120)
check 'goal triggers clear', s.mode == :clear
s.step([], 600)
check 'advances to 1-B', s.iv(:level_index) == 1 && %i[intro play].include?(s.mode)

# --- game over and back to title ---
s = Sim.new.start(0)
s.run.lives = 1
s.g.send(:die); s.step([], 200)
check 'game over', s.mode == :gameover
s.step([], 130); s.step([:start])
check 'back to title', s.mode == :title

# --- win after last level ---
s = Sim.new.start(LEVELS.size - 1).beat_boss
g = s.iv(:goal)
s.put(g[:c] - 3); s.step([:right], 120)
check 'last level plays the ending', s.mode == :ending

# --- 50 nuts = 1UP ---
s = Sim.new.start(0)
s.run.nuts = 49; l0 = s.run.lives
s.g.send(:add_nut)
check '50 nuts gives 1UP', s.run.lives == l0 + 1 && s.run.nuts == 0

# --- a thrown wrench that hits the main valve clears the level ---
s = Sim.new.start(0).beat_boss
g = s.iv(:goal)
s.put(g[:c] - 5); s.p.powered = true; s.p.facing = 1
s.iv(:enemies).clear
s.step([:b], 1)
cleared = false
40.times { s.step([]); (cleared = true; break) if s.mode == :clear }
check 'wrench hitting the valve clears the level', cleared && s.p.x < g[:c] * TILE - 3 * TILE
w = s.iv(:wrench)
check 'wrench bounces off the valve', w && w.vx < 0
back = false
120.times { s.step([]); (back = true; break) if s.iv(:wrench).nil? }
check 'bounced wrench flies back to the player during the clear', back && s.mode == :clear
s.step([], 700)
check 'wrench clear advances to 1-B', s.iv(:level_index) == 1

# --- lifts over a pit under a ceiling swing low enough to jump off at full height ---
lv_of = ->(name) { LEVELS.index { |l| l[:name] == name } }
ceil_bottom = Sim.new.level.tile_bottom(0)
s = Sim.new.start(lv_of['JOBSITE 1-B'])
pit = s.iv(:lifts).select { |l| [165, 170].include?((l.base_x / TILE).to_i) }
check '1-B has its two pit lifts', pit.size == 2
check '1-B pit lifts swing half as far', pit.all? { |l| l.amplitude == TILE }
check '1-B pit lifts never come within a full jump of the ceiling',
      pit.all? { |l| l.base_y + l.h + l.amplitude + PLAYER_HEIGHT + Lift::JUMP_RISE <= ceil_bottom }
check '1-B pit lifts stay above the death line', pit.all? { |l| l.base_y - l.amplitude > -140 + PLAYER_HEIGHT }
# jump off the first lift at the top of its swing, running: the head never touches the ceiling
l = pit[0]
top = l.base_y + l.h + l.amplitude
s.set(:lifts, [])
s.p.x = l.x + 40; s.p.y = top; s.p.vx = RUN_MAX; s.p.vy = 0.0; s.p.on_ground = true; s.snap
peak = top
s.step([:right, :b, :a], 1)
60.times { s.step([:right, :b, :a]); peak = [peak, s.p.y].max; break if s.p.vy < 0 }
check "running jump from the 1-B pit lift's highest point peaks below the ceiling (#{peak.to_i} + #{PLAYER_HEIGHT} < #{ceil_bottom})",
      peak + PLAYER_HEIGHT < ceil_bottom && peak > top + Lift::JUMP_RISE * 0.9
# lifts elsewhere keep the full swing: a lift over floor indoors (no level has
# one, so try it in a copy of 1-B), and outdoor lifts
rows = LEVELS[lv_of['JOBSITE 1-B']][:rows].map(&:dup)
fc = (20...150).find { |c| (1..7).all? { |r| rows[r][c, 2] == '..' } && rows[8][c, 2] == 'FF' }
rows[6][fc] = 'L'
# LEVELS is frozen, so swap in a copy with the extra level for this start
levels = LEVELS
extra = levels[lv_of['JOBSITE 1-B']].merge(rows: rows)
Object.send(:remove_const, :LEVELS)
Object.const_set(:LEVELS, (levels + [extra]).freeze)
s = Sim.new.start(LEVELS.size - 1)
Object.send(:remove_const, :LEVELS)
Object.const_set(:LEVELS, levels)
check 'indoor lift over the floor keeps its full swing',
      s.iv(:lifts).any? { |lf| (lf.base_x / TILE).to_i == fc && lf.amplitude == 2 * TILE }
out = LEVELS.index { |l| !THEMES[l[:theme]][:indoor] && l[:rows].any? { |r| r =~ /[LH]/ } }
s = Sim.new.start(out)
check 'outdoor lifts keep their full swing', !s.iv(:lifts).empty? && s.iv(:lifts).all? { |lf| lf.amplitude == 2 * TILE }

# --- a full-speed running jump can land on top of 1-A's wrench crate ---
wc = LEVELS[0][:rows].each_with_index.map { |r, i| [r.index('W'), i] }.find(&:first)
landed = (0..20).step(2).any? do |jx|
  [10, 20, 30].any? do |coast|
    s = Sim.new.start(0); s.iv(:enemies).clear
    s.put(wc[0] - 14); s.p.vx = RUN_MAX
    s.step(%i[right b], 1) until s.p.x >= (wc[0] - 6) * TILE + jx * 8
    s.step(%i[right b a], 1)
    hit = false
    60.times do |f|
      s.step(f < coast ? %i[right b a] : %i[b a])
      next unless s.p.on_ground
      hit = (s.p.y - s.level.tile_top(wc[1])).abs < 1
      break
    end
    hit
  end
end
check "1-A's wrench crate (row #{wc[1]}) can be landed on with a running jump", landed

# --- the coffee break freezes the world clock ---
s = Sim.new.start(1)
s.put(s.iv(:vents)[0][:c] - 4); s.step([], 2)
s.step([:start]); s.step([])
f0 = s.iv(:frame); n0 = s.sounds.size
s.step([], 400)
check 'pause stops the world clock', s.mode == :paused && s.iv(:frame) == f0
check 'vents stay quiet during the pause', !s.sounds[n0..].include?('sounds/steam.wav')
s.step([:start]); s.step([])
check 'lifts carry on smoothly after the pause', s.mode == :play &&
  s.iv(:lifts).all? { |l| l.dx.abs < 5 && l.dy.abs < 5 }
