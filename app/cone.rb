# A checkpoint cone ('K'): lights when the player passes it; a life lost
# after that restarts here.
class Cone
  attr_reader :c, :r, :x, :y

  def initialize(level, c, r)
    @c = c
    @r = r
    @x = c * TILE
    @y = level.tile_bottom(r)
    @lit = false
  end

  def lit? = @lit

  def light
    @lit = true
  end

  def draw(screen, camera_x, frame)
    blink_on = @lit && (frame / 10).even?
    screen.tile('sprites/items.png', @x - camera_x, @y, FRAMES[blink_on ? :cone_lit : :cone_off])
  end
end
