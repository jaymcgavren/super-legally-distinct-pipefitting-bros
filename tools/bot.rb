# Crude traversal bot: run right, jump at walls/pits/enemies. Reports where
# it gets stuck or falls. Enemies are ignored (invulnerable) by default.
require_relative 'sim'

def bot(index, frames: 5000, invulnerable: true)
  s = Sim.new.start(index)
  level = s.level
  jump_hold = 0; stuck = 0; lastx = 0; deaths = []
  frames.times do |f|
    return [:clear, f, deaths] if s.mode == :clear
    if s.mode != :play
      deaths << (s.p.x / TILE).round if s.mode == :dying
      s.step([], 1) until s.mode == :play || s.mode == :gameover
      return [:gameover, f, deaths] if s.mode == :gameover
      next
    end
    p = s.p
    p.invulnerable = 5 if invulnerable
    s.run.time = 300
    fx = p.x + p.w + 30
    wall = SOLID[level.cell(level.column_at(fx), level.row_at(p.y + 10))]
    gc = level.column_at(p.x + p.w + 40)
    pit = (0..9).none? { |r| SOLID[level.cell(gc, r)] || %w[-].include?(level.cell(gc, r)) } && p.on_ground
    below = level.cell(gc, level.row_at(p.y - 4))
    pit ||= p.on_ground && level.row_at(p.y - 4) < 10 && !SOLID[below] && below != '-'
    enemy = s.iv(:enemies).any? { |e| e.state == :walk && e.x > p.x && e.x - p.x < 160 && (e.y - p.y).abs < 40 }
    if stuck > 30 then jump_hold = 30; stuck = 0 end
    jump_hold = 30 if p.on_ground && (wall || pit || enemy) && jump_hold <= 0
    held = %i[right b]
    if jump_hold > 0
      held << :a; jump_hold -= 1
      jump_hold = 0 if jump_hold < 25 && p.on_ground
    end
    s.step(held)
    stuck = (p.x - lastx).abs < 0.5 ? stuck + 1 : 0
    lastx = p.x
  end
  [:timeout, (s.p.x / TILE).round, deaths]
end

LEVELS.size.times { |i| puts "#{LEVELS[i][:name]}: #{bot(i).inspect}" } if __FILE__ == $PROGRAM_NAME
