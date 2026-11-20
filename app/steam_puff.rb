# A big puff of steam in the ending: drifts, slows sideways and swells (a square, `width` across).
class SteamPuff < Struct.new(:x, :y, :vx, :vy, :life, :width)
  DRAG = 0.94

  def update
    self.x += vx
    self.y += vy
    self.vx *= DRAG
    self.life -= 1
    self.width += 1
  end

  def gone? = life <= 0
end
