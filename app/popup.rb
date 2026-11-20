# A score (or word) floating up from where it was earned.
class Popup < Struct.new(:x, :y, :text, :timer)
  RISE = 1.5
  LIFETIME = 45

  def update
    self.y += RISE
    self.timer += 1
  end

  def gone? = timer > LIFETIME

  def draw(screen, camera_x)
    screen.label(x.to_i - camera_x + 20, y.to_i, text, 3, WHITE, true)
  end
end
