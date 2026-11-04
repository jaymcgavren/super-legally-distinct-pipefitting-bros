# Crude traversal bot: run right, jump at walls/pits/enemies. Reports where
# it gets stuck or falls. Enemies are ignored (invulnerable) by default.
require_relative 'sim'

def bot(level, frames: 5000, invuln: true)
  s = Sim.new.start(level)
  g = s.g
  jump_hold = 0; stuck = 0; lastx = 0; deaths = []
  frames.times do |f|
    return [:clear, f, deaths] if s.mode == :clear
    if s.mode != :play
      deaths << (s.p.x / T).round if s.mode == :dying
      s.step([], 1) until s.mode == :play || s.mode == :gameover
      return [:gameover, f, deaths] if s.mode == :gameover
      next
    end
    p = s.p
    p.invuln = 5 if invuln
    s.set(:time, 300)
    fx = p.x + p.w + 30
    wall = SOLID[g.cell(g.col_at(fx), g.row_at(p.y + 10))]
    gc = g.col_at(p.x + p.w + 40)
    pit = !(0..9).any? { |r| SOLID[g.cell(gc, r)] || %w[-].include?(g.cell(gc, r)) } && p.on_ground
    pit ||= p.on_ground && g.row_at(p.y - 4) < 10 && !SOLID[g.cell(gc, g.row_at(p.y - 4))] && g.cell(gc, g.row_at(p.y - 4)) != '-'
    enemy = s.iv(:enemies).any? { |e| e.state == :walk && e.x > p.x && e.x - p.x < 160 && (e.y - p.y).abs < 40 }
    lift_ahead = s.iv(:lifts).any? { |l| l.x > p.x && l.x - p.x < 300 }
    if stuck > 30 then jump_hold = 30; stuck = 0 end
    if p.on_ground && (wall || pit || enemy) && jump_hold <= 0
      jump_hold = 30
    end
    held = %i[right b]
    if jump_hold > 0
      held << :a; jump_hold -= 1
      jump_hold = 0 if jump_hold < 25 && p.on_ground
    end
    s.step(held)
    stuck = (p.x - lastx).abs < 0.5 ? stuck + 1 : 0
    lastx = p.x
  end
  [:timeout, (s.p.x / T).round, deaths]
end

if __FILE__ == $0
  LEVELS.size.times { |i| puts "#{LEVELS[i][:name]}: #{bot(i).inspect}" }
end
