# Reachability check using the game's real player physics. BFS over
# standable tiles; lifts approximated as girders across their travel.
require_relative 'sim'

def analyze(index)
  s = Sim.new.start(index)
  g = s.g
  level = s.level
  g.instance_variable_get(:@lifts).each do |l|
    c = (l.x / TILE).round; r = level.row_at(l.y + l.h - 1)
    offs = l.axis == :x ? [-2, 0, 2].map { |d| [c + d, r] } : [-2, 0, 2].map { |d| [c, r + d] }
    offs.each { |cc, rr| [cc, cc + 1].each { |k| level.set_cell(k, rr, '=') if rr.between?(0, 9) && level.cell(k, rr) == '.' } }
  end
  g.instance_variable_set(:@lifts, [])
  g.instance_variable_set(:@vents, [])
  g.instance_variable_set(:@cones, [])
  goal = g.instance_variable_get(:@goal) || { c: level.columns - 12 }  # boss: reach the arena
  g.instance_variable_set(:@goal, nil)
  cols = level.columns
  standable = ->(c, r) { !SOLID[level.cell(c, r)] && (SOLID[level.cell(c, r + 1)] || level.cell(c, r + 1) == '-') && r < 9 }
  p = s.p
  start = [(p.x / TILE).floor, level.row_at(p.y + 1)]
  seen = { start => true }; q = [start]
  controls = g.instance_variable_get(:@controls)
  sim = lambda do |x, y, vx, dir, hold|
    p.x = x; p.y = y; p.vx = vx; p.vy = 0.0; p.on_ground = true; p.coyote = 0; p.buffer = 0
    p.riding = nil; p.jumping = false
    g.instance_variable_set(:@mode, :play)
    150.times do |f|
      pad = { right: dir > 0, left: dir < 0, run_held: true, throw_pressed: false,
              jump_held: f < hold, jump_pressed: f == 0 && hold > 0 }
      pad.each { |k, v| controls.instance_variable_set(:"@#{k}", v) }
      g.send(:update_player)
      return nil if p.y < 0 || g.instance_variable_get(:@mode) != :play
      return [(p.x + p.w / 2).div(TILE), level.row_at(p.y + 1)] if p.on_ground && f > 0 && (hold == 0 || f > 2)
    end
    nil
  end
  until q.empty?
    c, r = q.shift
    y = level.tile_bottom(r).to_f
    [1, -1].each do |d|
      [c * TILE + 1.0, c * TILE + 23.0].each do |x|
        [0.0, RUN_MAX * d, WALK_MAX * d].each do |vx|
          [0, 5, 10, 18, 40].each do |hold|
            [d, 0].each do |air|
              land = sim.call(x, y, vx, air, hold)
              next unless land && !seen[land] && land[0].between?(0, cols - 1)
              seen[land] = true; q << land
            end
          end
        end
      end
    end
  end
  reached_goal = seen.keys.any? { |c, r| c >= goal[:c] - 1 }
  # unreached standable surfaces (ignoring ones fully enclosed)
  missing = []
  cols.times { |c| 9.times { |r| missing << [c, r] if standable.(c, r) && !seen[[c, r]] } }
  [reached_goal, seen.size, missing]
end

if __FILE__ == $0
  (ARGV.empty? ? (0...LEVELS.size).to_a : ARGV.map(&:to_i)).each do |i|
    ok, n, miss = analyze(i)
    puts "#{LEVELS[i][:name]}: goal #{ok ? 'REACHABLE' : 'UNREACHABLE'}, #{n} spots; unreached: #{miss.map { |c, r| "#{c}/#{r}" }.join(' ')}"
  end
end
