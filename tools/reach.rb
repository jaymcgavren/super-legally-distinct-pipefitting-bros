# Reachability check using the game's real player physics. BFS over
# standable tiles; lifts approximated as girders across their travel.
require_relative 'sim'

def analyze(level)
  s = Sim.new.start(level)
  g = s.g
  grid = g.instance_variable_get(:@grid)
  g.instance_variable_get(:@lifts).each do |l|
    c = (l.x / T).round; r = g.row_at(l.y + l.h - 1)
    offs = l.data[:axis] == :x ? [-2, 0, 2].map { |d| [c + d, r] } : [-2, 0, 2].map { |d| [c, r + d] }
    offs.each { |cc, rr| [cc, cc + 1].each { |k| grid[rr][k] = '=' if rr.between?(0, 9) && grid[rr][k] == '.' } }
  end
  g.instance_variable_set(:@lifts, [])
  g.instance_variable_set(:@vents, [])
  g.instance_variable_set(:@cones, [])
  goal = g.instance_variable_get(:@goal) || { c: g.instance_variable_get(:@cols) - 12 }  # boss: reach the arena
  g.instance_variable_set(:@goal, nil)
  cols = g.instance_variable_get(:@cols)
  standable = ->(c, r) { !SOLID[g.cell(c, r)] && (SOLID[g.cell(c, r + 1)] || g.cell(c, r + 1) == '-') && r < 9 }
  p = s.p
  start = [(p.x / T).floor, g.row_at(p.y + 1)]
  seen = { start => true }; q = [start]
  sim = lambda do |x, y, vx, dir, hold|
    p.x = x; p.y = y; p.vx = vx; p.vy = 0.0; p.on_ground = true; p.coyote = 0; p.buffer = 0
    p.riding = nil; p.jumping = false
    g.instance_variable_set(:@mode, :play)
    150.times do |f|
      g.instance_variable_set(:@in_right, dir > 0); g.instance_variable_set(:@in_left, dir < 0)
      g.instance_variable_set(:@in_b, true); g.instance_variable_set(:@in_b_down, false)
      g.instance_variable_set(:@in_a, f < hold); g.instance_variable_set(:@in_a_down, f == 0 && hold > 0)
      g.send(:update_player)
      return nil if p.y < 0 || g.instance_variable_get(:@mode) != :play
      return [(p.x + p.w / 2).div(T), g.row_at(p.y + 1)] if p.on_ground && f > 0 && (hold == 0 || f > 2)
    end
    nil
  end
  until q.empty?
    c, r = q.shift
    y = g.tile_bottom(r).to_f
    [1, -1].each do |d|
      [c * T + 1.0, c * T + 23.0].each do |x|
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
