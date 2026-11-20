# A huge blocky burst: three rings of chunky squares racing outward.
class Firework < Struct.new(:x, :y, :color, :timer)
  LIFETIME = 72

  def update
    self.timer += 1
  end

  def gone? = timer > LIFETIME

  def draw(screen)
    age = timer
    star_color = color
    center_x = x
    center_y = y
    alpha = 150 - age * 2
    return if alpha <= 0
    screen.rect(center_x - 80, center_y - 80, 160, 160, WHITE, 200 - age * 30) if age < 5
    droop = age * age * FIREWORK_GRAVITY / 2    # the stars fall under gravity as they spread
    [[1.0, 0.0, 64], [0.72, 0.13, 48], [0.45, 0.26, 32]].each do |radius_factor, offset, size|
      r = (40 + age * 10) * radius_factor
      12.times do |i|
        angle = i * 0.5236 + offset
        star_x = ((center_x + Math.cos(angle) * r) / 16).to_i * 16
        star_y = ((center_y + Math.sin(angle) * r - droop) / 16).to_i * 16
        screen.rect(star_x - size / 2, star_y - size / 2, size, size, star_color, alpha)
      end
    end
  end
end
