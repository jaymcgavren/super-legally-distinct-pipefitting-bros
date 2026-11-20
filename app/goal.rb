# The main valve on its standpipe ('G', or put down when Big Rusty falls):
# reach it, or hit it with the wrench, to clear the level. Three tiles tall;
# `turn` drives the wheel's animation, and in the ending the valve blows off
# (`gone`).
class Goal
  attr_reader :c, :r, :x, :y
  attr_accessor :turn, :gone

  def initialize(level, c, r)
    @c = c
    @r = r
    @x = c * TILE
    @y = level.tile_bottom(r)
    @turn = 0
    @gone = false
  end

  alias gone? gone

  def draw(screen, camera_x, tiles)
    x = @x - camera_x
    screen.tile(tiles, x, @y, FRAMES[:standpipe])
    screen.tile(tiles, x, @y + TILE, FRAMES[:standpipe])
    return if @gone
    screen.tile('sprites/items.png', x, @y + 2 * TILE, frame(:valve, (@turn / 5) % 3))
    screen.label(x + 32, @y + 3 * TILE + 28, 'MAIN', 2, WHITE, true)
  end
end
