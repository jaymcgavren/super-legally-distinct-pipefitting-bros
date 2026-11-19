# Short-lived eye candy. None of it affects play.

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

# A score (or word) floating up from where it was earned.
class Popup < Struct.new(:x, :y, :text, :t)
  RISE = 1.5
  LIFETIME = 45

  def update
    self.y += RISE
    self.t += 1
  end

  def gone? = t > LIFETIME

  def draw(screen, camera_x)
    screen.label(x.to_i - camera_x + 20, y.to_i, text, 3, WHITE, true)
  end
end

# A big puff of steam in the ending: drifts, slows sideways and swells.
class SteamPuff < Struct.new(:x, :y, :vx, :vy, :life, :size)
  DRAG = 0.94

  def update
    self.x += vx
    self.y += vy
    self.vx *= DRAG
    self.life -= 1
    self.size += 1
  end

  def gone? = life <= 0
end
