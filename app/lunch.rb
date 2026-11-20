# The lunchbox (from a hidden crate): an extra life. It slides away and
# bounces off walls, and can fall into a pit.
class Lunch < RisingItem
  def initialize(x, top)
    super(:lunch, x, top)
    @vx = 2.5
  end

  def move(world)
    @vy -= Physics::GRAVITY_FALL
    @vx = -@vx if world.move_x(self)
    world.move_y(self, false, false)
    @state = :gone if @y < -100
  end

  def draw(screen, camera_x, _frame)
    screen.tile('sprites/items.png', @x.to_i - camera_x - 4, @y.to_i, FRAMES[:lunchbox])
  end
end
