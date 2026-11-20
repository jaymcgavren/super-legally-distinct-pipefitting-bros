# Short-lived eye candy (Particle, Popup, SteamPuff). None of it affects play.

# A square bit of steam, dust or sparkle: flies, falls a little, fades.
class Particle < Struct.new(:x, :y, :vx, :vy, :life, :color)
  GRAVITY = 0.15
  SIZE = 8

  def update
    self.x += vx
    self.y += vy
    self.vy -= GRAVITY
    self.life -= 1
  end

  def gone? = life <= 0

  def draw(screen, camera_x)
    screen.rect(x.to_i - camera_x, y.to_i, SIZE, SIZE, color, [life * 20, 255].min)
  end
end
